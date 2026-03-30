#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/opt/nanoclaw"
DEFAULT_GROUPS_DIR="/opt/nanoclaw-default-groups"
APPDATA_DIR="/appdata"
WAITING_MARKER="${APPDATA_DIR}/.waiting-for-config"
READY_MARKER="${APPDATA_DIR}/.bootstrap-complete"
SMOKE_MARKER="${APPDATA_DIR}/.smoke-ready"
TELEGRAM_MARKER="${APPDATA_DIR}/.telegram_setup_complete"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [nanoclaw-aio] $*"
}

ensure_docker_group_access() {
  if [[ ! -S /var/run/docker.sock ]]; then
    log "Docker socket not mounted at /var/run/docker.sock."
    return
  fi

  local socket_gid group_name
  socket_gid="$(stat -c '%g' /var/run/docker.sock)"
  group_name="$(getent group "${socket_gid}" | cut -d: -f1 || true)"

  if [[ -z "${group_name}" ]]; then
    group_name="dockersock"
    groupadd -for -g "${socket_gid}" "${group_name}" >/dev/null 2>&1 || true
  fi

  usermod -aG "${group_name}" node >/dev/null 2>&1 || true
}

seed_persistent_layout() {
  mkdir -p \
    "${APPDATA_DIR}/store" \
    "${APPDATA_DIR}/data" \
    "${APPDATA_DIR}/groups" \
    "${APPDATA_DIR}/config"

  if [[ ! -f "${APPDATA_DIR}/groups/global/CLAUDE.md" ]]; then
    mkdir -p "${APPDATA_DIR}/groups/global"
    cp "${DEFAULT_GROUPS_DIR}/global/CLAUDE.md" "${APPDATA_DIR}/groups/global/CLAUDE.md"
  fi

  if [[ ! -f "${APPDATA_DIR}/groups/main/CLAUDE.md" ]]; then
    mkdir -p "${APPDATA_DIR}/groups/main"
    cp "${DEFAULT_GROUPS_DIR}/main/CLAUDE.md" "${APPDATA_DIR}/groups/main/CLAUDE.md"
  fi

  mkdir -p /home/node/.config
  rm -rf /home/node/.config/nanoclaw
  ln -s "${APPDATA_DIR}/config" /home/node/.config/nanoclaw

  rm -rf "${PROJECT_ROOT}/store" "${PROJECT_ROOT}/data" "${PROJECT_ROOT}/groups"
  ln -s "${APPDATA_DIR}/store" "${PROJECT_ROOT}/store"
  ln -s "${APPDATA_DIR}/data" "${PROJECT_ROOT}/data"
  ln -s "${APPDATA_DIR}/groups" "${PROJECT_ROOT}/groups"

  chown -R node:node "${APPDATA_DIR}" /home/node/.config
}

write_runtime_env() {
  cat > "${PROJECT_ROOT}/.env" <<EOF
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN:-}
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-}
ASSISTANT_NAME=${ASSISTANT_NAME:-nanoclaw}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
TZ=${TZ:-UTC}
EOF
  chown node:node "${PROJECT_ROOT}/.env"
}

register_telegram_main() {
  if [[ "${AUTO_SETUP_TELEGRAM:-true}" != "true" ]]; then
    return
  fi

  if [[ -z "${TELEGRAM_CHAT_ID:-}" || -f "${TELEGRAM_MARKER}" ]]; then
    return
  fi

  log "Registering Telegram main chat in NanoClaw state..."
  su -s /bin/bash node -c "cd '${PROJECT_ROOT}' && npm run setup -- --step register -- --jid 'tg:${TELEGRAM_CHAT_ID}' --name '${TELEGRAM_CHAT_NAME:-Telegram Main}' --folder 'telegram_main' --trigger '@${ASSISTANT_NAME:-nanoclaw}' --channel telegram --no-trigger-required --is-main"
  touch "${TELEGRAM_MARKER}"
}

main() {
  log "Preparing NanoClaw runtime..."
  ensure_docker_group_access
  seed_persistent_layout
  write_runtime_env
  register_telegram_main

  touch "${READY_MARKER}"
  rm -f "${WAITING_MARKER}" "${SMOKE_MARKER}"

  if [[ "${SMOKE_TEST_MODE:-false}" == "true" ]]; then
    touch "${SMOKE_MARKER}"
    log "Smoke test bootstrap complete."
    exec tail -f /dev/null
  fi

  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    touch "${WAITING_MARKER}"
    log "Waiting for configuration. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID to start NanoClaw."
    exec tail -f /dev/null
  fi

  log "Starting NanoClaw Telegram runtime..."
  exec su -s /bin/bash node -c "cd '${PROJECT_ROOT}' && exec npm start"
}

main "$@"
