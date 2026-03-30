#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-nanoclaw-aio:test}"
CONTAINER_NAME="nanoclaw-aio-smoke"
READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-300}"
KEEP_SMOKE_ARTIFACTS="${KEEP_SMOKE_ARTIFACTS:-0}"

TMP_APPDATA="$(mktemp -d /tmp/nanoclaw-aio-appdata.XXXXXX)"
cleanup_needed=1

cleanup() {
  local exit_code=$?
  if [[ "$cleanup_needed" -eq 1 ]]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    rm -rf "$TMP_APPDATA"
  elif [[ "$exit_code" -ne 0 ]]; then
    echo "Smoke test failed; preserving artifacts for debugging."
    echo "SMOKE_CONTAINER_NAME=$CONTAINER_NAME"
    echo "SMOKE_APPDATA_DIR=$TMP_APPDATA"
  fi
  exit "$exit_code"
}
trap cleanup EXIT

start_container() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker run -d \
    --platform linux/amd64 \
    --name "$CONTAINER_NAME" \
    -e ANTHROPIC_API_KEY="sk-ant-smoke-test" \
    -e ASSISTANT_NAME="nanoclaw" \
    -e TELEGRAM_BOT_TOKEN="smoke-token" \
    -e TELEGRAM_CHAT_ID="123456789" \
    -e TELEGRAM_CHAT_NAME="Smoke Test" \
    -e AUTO_SETUP_TELEGRAM="true" \
    -e SMOKE_TEST_MODE="true" \
    -e TZ="UTC" \
    -v "${TMP_APPDATA}:/appdata" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE_TAG" >/dev/null
}

wait_for_ready() {
  local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if docker exec "$CONTAINER_NAME" test -f /appdata/.smoke-ready >/dev/null 2>&1; then
      return 0
    fi
    docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"
    sleep 2
  done
  echo "NanoClaw smoke bootstrap did not complete in time."
  docker logs "$CONTAINER_NAME" || true
  return 1
}

verify_persistence() {
  docker exec "$CONTAINER_NAME" test -f /appdata/.bootstrap-complete
  docker exec "$CONTAINER_NAME" test -f /appdata/.telegram_setup_complete
  docker exec "$CONTAINER_NAME" test -f /appdata/store/messages.db
  docker exec "$CONTAINER_NAME" test -f /appdata/groups/telegram_main/CLAUDE.md
}

start_container
wait_for_ready
verify_persistence

docker restart "$CONTAINER_NAME" >/dev/null
wait_for_ready
verify_persistence

if [[ "$KEEP_SMOKE_ARTIFACTS" -eq 1 ]]; then
  cleanup_needed=0
fi
