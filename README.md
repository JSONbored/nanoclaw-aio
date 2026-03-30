# nanoclaw-aio

NanoClaw packaged as a Telegram-first All-In-One Unraid container.

`nanoclaw-aio` wraps the official NanoClaw Telegram fork with the official native credential proxy patch so the stack can run from a single Unraid container without needing a separate OneCLI service. The image keeps the NanoClaw code immutable inside the container and persists only runtime state under `/appdata`, which makes upgrades much safer than mounting the whole project directory.

## What This Repo Ships

- A single-container `ghcr.io/jsonbored/nanoclaw-aio:latest` image
- Explicit image tags matching the pinned upstream NanoClaw Telegram version, plus `latest` and `sha-...`
- An Unraid CA template at [nanoclaw-aio.xml](/tmp/nanoclaw-aio/nanoclaw-aio.xml)
- A local smoke test at [scripts/smoke-test.sh](/tmp/nanoclaw-aio/scripts/smoke-test.sh)
- Upstream version tracking via [upstream.toml](/tmp/nanoclaw-aio/upstream.toml) and [scripts/check-upstream.py](/tmp/nanoclaw-aio/scripts/check-upstream.py)
- Automated `awesome-unraid` sync for the XML

## Included Behavior

- Official `qwibitai/nanoclaw-telegram` code pinned to a specific upstream commit
- Official native credential proxy patch applied so Anthropic credentials can stay in `.env`
- Telegram main-chat auto-registration on first boot
- Persistent NanoClaw state under `/appdata`
- Docker socket access so NanoClaw can launch isolated agent containers

## Important Runtime Notes

- This image is currently packaged and validated for `linux/amd64`.
- There is no web UI. NanoClaw is controlled through Telegram.
- `/appdata` persists groups, database state, credential-proxy config, sessions, and task data.
- `/var/run/docker.sock` must be mounted so NanoClaw can start agent containers.
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are required for a real working deployment. If they are missing, the container stays up in a waiting-for-config state instead of crash-looping.

## Quick Start

1. Install the Unraid template.
2. Set `ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, and `TELEGRAM_CHAT_ID`.
3. Keep `AUTO_SETUP_TELEGRAM=true` unless you want to register groups manually later.
4. Mount the Docker socket.
5. Start the container and watch the logs for first-boot registration.

## Validation

Local validation completed on March 29, 2026:

- explicit `linux/amd64` Docker build succeeded
- local smoke test passed end-to-end in bootstrap mode
- restart and persistence coverage added for `/appdata`
- build/security workflows were hardened with pinned action SHAs and upstream tracking
- the wrapper was rebuilt around the official `qwibitai/nanoclaw-telegram` upstream instead of cloning an unpinned unrelated repo

## Support

- Issues: [JSONbored/nanoclaw-aio issues](https://github.com/JSONbored/nanoclaw-aio/issues)
- Upstream app: [qwibitai/NanoClaw](https://github.com/qwibitai/NanoClaw)
- Upstream Telegram fork: [qwibitai/nanoclaw-telegram](https://github.com/qwibitai/nanoclaw-telegram)

## Funding

If this work saves you time, support it here:

- [GitHub Sponsors](https://github.com/sponsors/JSONbored)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=JSONbored/nanoclaw-aio&theme=dark)](https://star-history.com/#JSONbored/nanoclaw-aio&Date)
