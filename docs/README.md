# NanoClaw AIO Setup

`nanoclaw-aio` is a beta Unraid wrapper for NanoClaw v2. It is intentionally Telegram-first and uses a paired helper image for agent execution.

## Required Inputs

- `/appdata` mounted to a persistent Unraid path
- `/var/run/docker.sock` mounted read-write
- `NANOCLAW_HOST_APPDATA_DIR` matching the host-side appdata path
- `TELEGRAM_BOT_TOKEN`
- one Claude credential:
  - `ANTHROPIC_API_KEY`
  - `CLAUDE_CODE_OAUTH_TOKEN`
  - `ANTHROPIC_AUTH_TOKEN`

## First Boot

On first start the container:

1. seeds `/appdata/runtime` with the host-visible NanoClaw runtime files needed by nested helper containers
2. creates persistent `data`, `store`, `groups`, `logs`, `config`, and env paths
3. writes `.env` and `data/env/env` with `0600` permissions
4. waits if Telegram or Claude credentials are missing
5. starts NanoClaw once the Docker socket and required credentials are present
6. emits a `PAIR_TELEGRAM_CODE` in the logs so you can pair the main Telegram chat

The pairing code is expected. Send it to your bot from the Telegram chat you want NanoClaw to use.

## Persistence Model

The immutable application build lives in the image at `/opt/nanoclaw`.

Persistent and host-visible runtime state lives under `/appdata`:

- `/appdata/runtime/data`
- `/appdata/runtime/store`
- `/appdata/runtime/groups`
- `/appdata/runtime/logs`
- `/appdata/runtime/config`
- `/appdata/runtime/container/agent-runner/src`
- `/appdata/runtime/container/skills`

The last two paths are copied from the image so the host Docker daemon can mount them into `jsonbored/nanoclaw-agent` sibling containers.

## Security Notes

The Docker socket is required for NanoClaw v2's current architecture. That mount lets the AIO container control Docker on the host. Treat this as host-level trust and do not install the template unless that is acceptable for your server.

The template stays beta until the v2 wrapper has enough real-world Unraid runtime confidence.

## Agent Helper Image

The AIO image defaults to:

```text
CONTAINER_IMAGE=jsonbored/nanoclaw-agent:v2.0.64-agent.2
CONTAINER_IMAGE_BASE=jsonbored/nanoclaw-agent
```

Advanced users can override these if they build a custom helper image, but the Community Apps template only installs `nanoclaw-aio`.
