#!/bin/bash
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [nanoclaw-aio] $*"; }

WORKSPACE="/workspace"
UPSTREAM_DIR="/opt/nanoclaw"

log "Starting NanoClaw AIO initialization..."

# Copy core files if workspace is empty
if [ ! -f "$WORKSPACE/package.json" ]; then
    log "Initializing empty workspace..."
    cp -r $UPSTREAM_DIR/* "$WORKSPACE/"
    cp -r $UPSTREAM_DIR/.* "$WORKSPACE/" 2>/dev/null || true
    chown -R node:node "$WORKSPACE"
fi

cd "$WORKSPACE"

# Handle Environment Variables
log "Configuring environment..."
cat <<ENV > .env
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
ASSISTANT_NAME=${ASSISTANT_NAME:-nanoclaw}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-}
ENV
chown node:node .env

# Run Auto-Setup if requested
if [ "${AUTO_SETUP_TELEGRAM:-false}" = "true" ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    if [ ! -f "$WORKSPACE/.telegram_setup_complete" ]; then
        log "Auto-Setup: Telegram configuration detected. Applying skill and registering..."
        # Drop privileges to run npm/npx
        su -c "cd $WORKSPACE && npm install" node
        su -c "cd $WORKSPACE && npx tsx scripts/apply-skill.ts .claude/skills/add-telegram" node
        su -c "cd $WORKSPACE && npm run build" node
        
        log "Auto-Setup: Registering Telegram Webhook/Chat ID..."
        su -c "cd $WORKSPACE && npx tsx setup/index.ts --step register \
          --jid \"tg:${TELEGRAM_CHAT_ID}\" \
          --name \"Primary User\" \
          --trigger \"@${ASSISTANT_NAME}\" \
          --folder \"telegram_main\" \
          --channel telegram \
          --assistant-name \"${ASSISTANT_NAME}\" \
          --is-main \
          --no-trigger-required" node
        
        touch "$WORKSPACE/.telegram_setup_complete"
        log "Auto-Setup: Telegram configuration complete."
    else
        log "Auto-Setup: Telegram already configured, skipping."
    fi
fi

# Ensure npm install is run at least once if needed
if [ ! -d "$WORKSPACE/node_modules" ]; then
   log "Installing dependencies..."
   su -c "cd $WORKSPACE && npm ci" node
fi

log "Initialization complete. Starting NanoClaw orchestrator..."
# Start the primary Node.js orchestrator process
exec su -c "cd $WORKSPACE && npm start" node
