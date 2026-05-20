# nanoclaw-aio

NanoClaw packaged as a Telegram-first, Unraid-oriented AIO container.

This repo ships one installable Community Apps template and two container images
from the same source repo:

- `jsonbored/nanoclaw-aio`: the Unraid app container
- `jsonbored/nanoclaw-agent`: the nested helper image spawned by NanoClaw for
  isolated agent work

`nanoclaw-agent` is not a separate Community Apps template right now. It is a
sandbox/helper image used by `nanoclaw-aio`.

## Current Release

- Upstream NanoClaw:
  [`nanocoai/nanoclaw` `v2.0.64`](https://github.com/nanocoai/nanoclaw/releases/tag/v2.0.64)
- Upstream commit: `0683c6ec589ec0df74c2a3d99f9544127317b490`
- Channels branch commit: `36fb78092c27737a2313c07244748a98b26c7d03`
- AIO image tag: `v2.0.64-aio.4`
- Agent helper image tag: `v2.0.64-agent.2`

NanoClaw `main` may move ahead of the latest release. This package tracks stable
upstream releases, not unreleased `main`.

## What This Image Includes

- NanoClaw v2 pinned to the current stable upstream release.
- A Telegram-first control surface for starting and managing agent work.
- A paired `jsonbored/nanoclaw-agent` helper image for isolated task containers.
- A Docker-socket sibling-container model, matching NanoClaw v2's current
  runtime architecture.
- Persistent appdata for databases, logs, groups, channel state, generated env
  files, and the host-visible runtime source used by helper containers.
- A vendored Telegram channel adapter and pinned channels branch commit so first
  boot does not depend on a runtime `git fetch`.
- A validated Unraid XML template in [`nanoclaw-aio.xml`](nanoclaw-aio.xml).

## Beginner Install

1. Install the `nanoclaw-aio` template from Unraid Community Applications.
2. Keep the default `/appdata` path unless you also update
   `NANOCLAW_HOST_APPDATA_DIR`.
3. Mount `/var/run/docker.sock`.
4. Set `TELEGRAM_BOT_TOKEN`.
5. Set one Claude credential:
   - `ANTHROPIC_API_KEY`
   - `CLAUDE_CODE_OAUTH_TOKEN`
   - `ANTHROPIC_AUTH_TOKEN`
6. Start the container and watch logs for `PAIR_TELEGRAM_CODE`.
7. Send that code to your Telegram bot to pair the main chat.

The template is marked beta while the v2 wrapper gets more real-world Unraid
runtime coverage.

## Power User Surface

The Unraid template keeps advanced NanoClaw controls visible without making them
required for first boot:

- Claude/Anthropic credentials and `ANTHROPIC_BASE_URL`
- OneCLI endpoint and API key overrides
- helper image overrides through `CONTAINER_IMAGE` and `CONTAINER_IMAGE_BASE`
- container timeout, idle timeout, max output size, prompt message limit, and
  max concurrent container controls
- assistant identity settings
- timezone through `TZ`

The default helper image is:

```text
CONTAINER_IMAGE=jsonbored/nanoclaw-agent:v2.0.64-agent.2
CONTAINER_IMAGE_BASE=jsonbored/nanoclaw-agent
```

Advanced users can override those values if they build their own helper image.
The Community Apps template still installs only `nanoclaw-aio`.

## Runtime Notes

NanoClaw v2 controls agents through Telegram and launches short-lived helper
containers through Docker. On Unraid that means:

- `/appdata` persists databases, logs, groups, channel state, env files, and
  host-visible runtime source used by helper containers.
- `/var/run/docker.sock` is required so the AIO container can start
  `jsonbored/nanoclaw-agent` sibling containers.
- `NANOCLAW_HOST_APPDATA_DIR` must match the host path mounted to `/appdata`;
  the default is `/mnt/user/appdata/nanoclaw-aio`.
- First boot waits for `TELEGRAM_BOT_TOKEN` and one Claude credential, then emits
  a Telegram pairing code in the container logs.

Docker socket access is host-level trust. This wrapper makes that requirement
explicit instead of hiding it.

If you used an older v1 wrapper image, read
[`docs/migration-v2.md`](docs/migration-v2.md) before following `latest`.

## Publishing and Releases

App repo publishing is controlled by `aio-fleet` from this repo's
[`.aio-fleet.yml`](.aio-fleet.yml). Formal GitHub Releases use the AIO image
version, while the helper image ships on the same release train.

`jsonbored/nanoclaw-aio` and `ghcr.io/jsonbored/nanoclaw-aio` publish:

- `latest`
- `v2.0.64`
- `v2.0.64-aio.4`
- `sha-<commit>`

`jsonbored/nanoclaw-agent` and `ghcr.io/jsonbored/nanoclaw-agent` publish:

- `latest`
- `v2.0.64`
- `v2.0.64-agent.2`
- `sha-<commit>`

See [`docs/releases.md`](docs/releases.md) for the release model.

## Validation

Local source validation:

```bash
python -m pytest tests/template
xmllint --noout nanoclaw-aio.xml
```

Container validation:

```bash
python -m pytest tests/integration -m integration
```

The integration suite builds both images, verifies missing-config and smoke-mode
behavior, checks appdata persistence, checks the configured agent image, and
confirms a missing Docker socket produces a clear waiting state.

## Support

- AIO repo: [JSONbored/nanoclaw-aio](https://github.com/JSONbored/nanoclaw-aio)
- Upstream app: [nanocoai/nanoclaw](https://github.com/nanocoai/nanoclaw)
- Issues:
  [JSONbored/nanoclaw-aio issues](https://github.com/JSONbored/nanoclaw-aio/issues)

## Funding

If this saves you time, support it here:

- [GitHub Sponsors](https://github.com/sponsors/JSONbored)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=JSONbored/nanoclaw-aio&theme=dark)](https://star-history.com/#JSONbored/nanoclaw-aio&Date)
