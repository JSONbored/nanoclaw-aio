# NanoClaw AIO Setup Guide

`nanoclaw-aio` is a Telegram-first packaging of NanoClaw for Unraid.

## Required Inputs

- `ANTHROPIC_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- Docker socket mount at `/var/run/docker.sock`

Optional:

- `ASSISTANT_NAME`
- `TELEGRAM_CHAT_NAME`
- `CLAUDE_CODE_OAUTH_TOKEN` as an alternative auth mode
- `ANTHROPIC_BASE_URL` for Anthropic-compatible endpoints

## First Boot Behavior

On first start the container will:

1. prepare `/appdata/store`, `/appdata/data`, `/appdata/groups`, and `/appdata/config`
2. seed default `groups/global` and `groups/main` `CLAUDE.md` files
3. write the runtime `.env`
4. auto-register your Telegram main chat if `AUTO_SETUP_TELEGRAM=true`
5. start NanoClaw

## Persistence Model

The NanoClaw code lives inside the image.

Persistent data lives in `/appdata`:

- `store/` for SQLite data
- `data/` for runtime state, sessions, and IPC data
- `groups/` for group memory and CLAUDE.md files
- `config/` for NanoClaw config files

This makes image updates much safer than mounting the whole project tree from appdata.

## Security Notes

- Docker socket access is powerful and should be treated as host-level trust.
- The image does not add `SYS_ADMIN` or run fully privileged.
- Anthropic credentials stay in the NanoClaw host process and are proxied into agent containers instead of being mounted directly into them.

## Smoke Testing

The local smoke test uses `SMOKE_TEST_MODE=true` to validate:

- appdata bootstrap
- Telegram registration state creation
- persistence across container restarts

It does not attempt a live Telegram Bot API conversation because that would require real external credentials.
