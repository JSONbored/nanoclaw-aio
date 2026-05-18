# nanoclaw-aio

NanoClaw packaged as a Telegram-first Unraid AIO container.

This repo ships one installable Unraid app and two container images from the same source repo:

- `jsonbored/nanoclaw-aio`: the Unraid app container
- `jsonbored/nanoclaw-agent`: the nested helper image spawned by NanoClaw for isolated agent work

`nanoclaw-agent` is not a separate Community Apps template right now. It is a sandbox/helper image used by `nanoclaw-aio`.

## Current Version

- Upstream NanoClaw: [`nanocoai/nanoclaw` `v2.0.63`](https://github.com/nanocoai/nanoclaw/releases/tag/v2.0.63)
- Upstream commit: `975a2f0f5b0ea19bbf35fadfd394df35e5341d3a`
- Channels branch commit: `8e91d37bc9c14b06580bda4b46c85f33cf755b15`
- AIO image tag: `v2.0.63-aio.1`
- Agent helper image tag: `v2.0.63-agent.1`

NanoClaw `main` may move ahead of the latest release. This package tracks stable upstream releases, not unreleased `main`.

## Runtime Model

NanoClaw v2 controls agents through Telegram and launches short-lived helper containers through Docker. On Unraid that means:

- `/appdata` persists databases, logs, groups, channel state, env files, and host-visible runtime source used by helper containers.
- `/var/run/docker.sock` is required so the AIO container can start `jsonbored/nanoclaw-agent` sibling containers.
- `NANOCLAW_HOST_APPDATA_DIR` must match the host path mounted to `/appdata`; the default is `/mnt/user/appdata/nanoclaw-aio`.
- First boot waits for `TELEGRAM_BOT_TOKEN` and one Claude credential, then emits a Telegram pairing code in the container logs.

Docker socket access is host-level trust. This wrapper makes that requirement explicit instead of hiding it.

## Quick Start

1. Install the `nanoclaw-aio` Unraid template.
2. Keep the default `/appdata` path unless you also update `NANOCLAW_HOST_APPDATA_DIR`.
3. Mount `/var/run/docker.sock`.
4. Set `TELEGRAM_BOT_TOKEN`.
5. Set one Claude credential: `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, or `ANTHROPIC_AUTH_TOKEN`.
6. Start the container and watch logs for `PAIR_TELEGRAM_CODE`.
7. Send that code to your Telegram bot to pair the main chat.

## Image Tags

`jsonbored/nanoclaw-aio` publishes:

- `latest`
- `v2.0.63`
- `v2.0.63-aio.1`
- `sha-<commit>`

`jsonbored/nanoclaw-agent` publishes:

- `latest`
- `v2.0.63`
- `v2.0.63-agent.1`
- `sha-<commit>`

Both Docker Hub and GHCR receive the same tags.

## Validation

Local source validation:

```bash
python -m pytest tests/template
```

Container validation:

```bash
python -m pytest tests/integration -m integration
```

The integration suite builds both images, verifies missing-config and smoke-mode behavior, checks appdata persistence, checks the configured agent image, and confirms a missing Docker socket produces a clear waiting state.

## Support

- AIO repo: [JSONbored/nanoclaw-aio](https://github.com/JSONbored/nanoclaw-aio)
- Upstream app: [nanocoai/nanoclaw](https://github.com/nanocoai/nanoclaw)
- Issues: [JSONbored/nanoclaw-aio issues](https://github.com/JSONbored/nanoclaw-aio/issues)

## Funding

If this saves you time, support it here:

- [GitHub Sponsors](https://github.com/sponsors/JSONbored)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=JSONbored/nanoclaw-aio&theme=dark)](https://star-history.com/#JSONbored/nanoclaw-aio&Date)
