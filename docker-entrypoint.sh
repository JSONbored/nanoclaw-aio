#!/usr/bin/env bash
# shellcheck disable=SC2310
set -euo pipefail

INSTALL_ROOT="/opt/nanoclaw"
DEFAULT_GROUPS_DIR="/opt/nanoclaw-default-groups"
APPDATA_DIR="${NANOCLAW_CONTAINER_APPDATA_DIR:-/appdata}"
RUNTIME_ROOT="${APPDATA_DIR}/runtime"
WAITING_MARKER="${APPDATA_DIR}/.waiting-for-config"
READY_MARKER="${APPDATA_DIR}/.bootstrap-complete"
SMOKE_MARKER="${APPDATA_DIR}/.smoke-ready"
SOCKET_FAILURE_MARKER="${APPDATA_DIR}/.docker-socket-missing"
TELEGRAM_MARKER="${APPDATA_DIR}/.telegram_setup_complete"
PAIRING_LOG="${APPDATA_DIR}/logs/telegram-pairing.log"

log() {
	local timestamp
	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	echo "[${timestamp}] [nanoclaw-aio] $*"
}

truthy() {
	case "${1-}" in
	true | TRUE | 1 | yes | YES | on | ON) return 0 ;;
	*) return 1 ;;
	esac
}

run_as_node() {
	gosu node "$@"
}

ensure_docker_group_access() {
	if [[ ! -S /var/run/docker.sock ]]; then
		return 1
	fi

	local socket_gid group_name
	socket_gid="$(stat -c '%g' /var/run/docker.sock)"
	group_name="$(getent group "${socket_gid}" | cut -d: -f1 || true)"

	if [[ -z ${group_name} ]]; then
		group_name="dockersock"
		groupadd -for -g "${socket_gid}" "${group_name}" >/dev/null 2>&1 || true
	fi

	usermod -aG "${group_name}" node >/dev/null 2>&1 || true
	return 0
}

seed_runtime_layout() {
	mkdir -p \
		"${APPDATA_DIR}/logs" \
		"${RUNTIME_ROOT}/config" \
		"${RUNTIME_ROOT}/data/env" \
		"${RUNTIME_ROOT}/groups" \
		"${RUNTIME_ROOT}/logs" \
		"${RUNTIME_ROOT}/store"

	if [[ ! -f "${RUNTIME_ROOT}/groups/global/CLAUDE.md" ]]; then
		mkdir -p "${RUNTIME_ROOT}/groups/global"
		cp "${DEFAULT_GROUPS_DIR}/global/CLAUDE.md" "${RUNTIME_ROOT}/groups/global/CLAUDE.md"
	fi

	if [[ ! -f "${RUNTIME_ROOT}/groups/main/CLAUDE.md" ]]; then
		mkdir -p "${RUNTIME_ROOT}/groups/main"
		cp "${DEFAULT_GROUPS_DIR}/main/CLAUDE.md" "${RUNTIME_ROOT}/groups/main/CLAUDE.md"
	fi

	rm -rf \
		"${RUNTIME_ROOT}/container/agent-runner/src" \
		"${RUNTIME_ROOT}/container/skills" \
		"${RUNTIME_ROOT}/container/CLAUDE.md"
	mkdir -p "${RUNTIME_ROOT}/container/agent-runner"
	cp -a "${INSTALL_ROOT}/container/agent-runner/src" "${RUNTIME_ROOT}/container/agent-runner/src"
	cp -a "${INSTALL_ROOT}/container/skills" "${RUNTIME_ROOT}/container/skills"
	cp -a "${INSTALL_ROOT}/container/CLAUDE.md" "${RUNTIME_ROOT}/container/CLAUDE.md"

	ln -sfn "${INSTALL_ROOT}/bin" "${RUNTIME_ROOT}/bin"
	ln -sfn "${INSTALL_ROOT}/dist" "${RUNTIME_ROOT}/dist"
	ln -sfn "${INSTALL_ROOT}/node_modules" "${RUNTIME_ROOT}/node_modules"
	ln -sfn "${INSTALL_ROOT}/package.json" "${RUNTIME_ROOT}/package.json"
	ln -sfn "${INSTALL_ROOT}/pnpm-lock.yaml" "${RUNTIME_ROOT}/pnpm-lock.yaml"
	ln -sfn "${INSTALL_ROOT}/setup" "${RUNTIME_ROOT}/setup"
	ln -sfn "${INSTALL_ROOT}/src" "${RUNTIME_ROOT}/src"

	mkdir -p /home/node/.config
	rm -rf /home/node/.config/nanoclaw
	ln -s "${RUNTIME_ROOT}/config" /home/node/.config/nanoclaw

	printf '%s\n' "${NANOCLAW_AIO_VERSION:-unknown}" >"${APPDATA_DIR}/.runtime-version"
	chown -R node:node "${APPDATA_DIR}" /home/node/.config
}

write_runtime_env() {
	local env_file="${RUNTIME_ROOT}/.env"
	local container_env_file="${RUNTIME_ROOT}/data/env/env"
	local keys=(
		ANTHROPIC_API_KEY
		CLAUDE_CODE_OAUTH_TOKEN
		ANTHROPIC_AUTH_TOKEN
		ANTHROPIC_BASE_URL
		ONECLI_URL
		ONECLI_API_KEY
		TELEGRAM_BOT_TOKEN
		ASSISTANT_NAME
		ASSISTANT_HAS_OWN_NUMBER
		CONTAINER_IMAGE
		CONTAINER_IMAGE_BASE
		CONTAINER_TIMEOUT
		IDLE_TIMEOUT
		CONTAINER_MAX_OUTPUT_SIZE
		MAX_MESSAGES_PER_PROMPT
		MAX_CONCURRENT_CONTAINERS
		LOG_LEVEL
		TZ
		NANOCLAW_HOST_APPDATA_DIR
		NANOCLAW_CONTAINER_APPDATA_DIR
	)

	umask 077
	: >"${env_file}"
	for key in "${keys[@]}"; do
		printf '%s=%s\n' "${key}" "${!key-}" >>"${env_file}"
	done
	cp "${env_file}" "${container_env_file}"
	chown node:node "${env_file}" "${container_env_file}"
	chmod 600 "${env_file}" "${container_env_file}"
}

has_credential() {
	[[ -n ${ANTHROPIC_API_KEY-} || -n ${CLAUDE_CODE_OAUTH_TOKEN-} || -n ${ANTHROPIC_AUTH_TOKEN-} ]]
}

wait_forever() {
	local message="$1"
	touch "${WAITING_MARKER}"
	rm -f "${SMOKE_MARKER}"
	log "${message}"
	exec tail -f /dev/null
}

start_telegram_pairing_watcher() {
	if ! truthy "${NANOCLAW_AUTO_PAIR_TELEGRAM:-true}"; then
		return
	fi
	if [[ -f ${TELEGRAM_MARKER} ]]; then
		return
	fi
	if [[ -z ${TELEGRAM_BOT_TOKEN-} ]]; then
		return
	fi

	log "Telegram pairing is enabled. Watch ${PAIRING_LOG} for PAIR_TELEGRAM_CODE and send that code to your Telegram bot."
	(
		set -o pipefail
		sleep "${NANOCLAW_PAIRING_START_DELAY_SECONDS:-8}"
		mkdir -p "$(dirname "${PAIRING_LOG}")"
		if run_as_node bash -lc "cd '${RUNTIME_ROOT}' && '${INSTALL_ROOT}/node_modules/.bin/tsx' '${INSTALL_ROOT}/setup/index.ts' --step pair-telegram --intent main" 2>&1 | tee -a "${PAIRING_LOG}"; then
			touch "${TELEGRAM_MARKER}"
			chown node:node "${TELEGRAM_MARKER}"
			log "Telegram pairing completed."
		else
			log "Telegram pairing command exited before pairing completed. Check ${PAIRING_LOG}."
		fi
	) &
}

main() {
	log "Preparing NanoClaw ${NANOCLAW_AIO_VERSION:-AIO} runtime..."
	seed_runtime_layout
	write_runtime_env
	touch "${READY_MARKER}"
	rm -f "${WAITING_MARKER}" "${SOCKET_FAILURE_MARKER}" "${SMOKE_MARKER}"

	if truthy "${SMOKE_TEST_MODE:-false}"; then
		touch "${SMOKE_MARKER}"
		log "Smoke mode initialized /appdata and persistent runtime layout."
		exec tail -f /dev/null
	fi

	if [[ -z ${TELEGRAM_BOT_TOKEN-} ]]; then
		wait_forever "Waiting for configuration. Set TELEGRAM_BOT_TOKEN, then restart the container to begin Telegram pairing."
	fi

	if ! has_credential; then
		wait_forever "Waiting for configuration. Set one Claude credential: ANTHROPIC_API_KEY, CLAUDE_CODE_OAUTH_TOKEN, or ANTHROPIC_AUTH_TOKEN."
	fi

	if ! ensure_docker_group_access; then
		touch "${SOCKET_FAILURE_MARKER}"
		wait_forever "Docker socket is required but /var/run/docker.sock is not mounted. Mount it read-write so NanoClaw can spawn nested agent containers."
	fi

	start_telegram_pairing_watcher

	log "Starting NanoClaw v2 runtime. Nested agents will use ${CONTAINER_IMAGE:-jsonbored/nanoclaw-agent:v2.0.64-agent.2}."
	exec run_as_node bash -lc "cd '${RUNTIME_ROOT}' && exec node '${INSTALL_ROOT}/dist/index.js'"
}

main "$@"
