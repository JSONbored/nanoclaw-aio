# nanoclaw-aio Agent Notes

`nanoclaw-aio` packages NanoClaw Telegram as a Telegram-first single-container Unraid deployment.

## Runtime Shape

- Upstream base: official `qwibitai/nanoclaw-telegram`
- Official native credential proxy patch applied
- Persistent runtime state under `/appdata`
- Docker socket access required so NanoClaw can launch agent containers

## Important Behavior

- There is no web UI; Telegram is the control plane.
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are mandatory for a real deployment.
- If real credentials are missing, the container should wait safely for config instead of crash-looping.
- The packaged image is currently validated for `linux/amd64`.

## CI And Publish Policy

- Validation and smoke tests should run on PRs and branch pushes.
- Publish should happen only from the default branch.
- GHCR image naming must stay lowercase.

## What To Preserve

- Keep the code immutable inside the image and persist only runtime state.
- Keep Telegram auto-registration and first-boot ergonomics intact.
- Smoke tests should validate bootstrap, restart, and persistence in smoke mode.
