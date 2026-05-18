# Releases

NanoClaw AIO uses upstream-version-plus-AIO-revision release tags.

## User-Facing Release

The Unraid app release is tagged from the AIO image:

- `v2.0.63-aio.1`

That GitHub Release is the user-facing release history and should be marked latest when published.

## Paired Helper Image

The helper image is released on the same train:

- `jsonbored/nanoclaw-agent:v2.0.63-agent.1`

It is included in the AIO release notes but does not need a separate user-facing GitHub Release unless the fleet release tooling later requires component-specific releases.

## Image Tags

`jsonbored/nanoclaw-aio`:

- `latest`
- `v2.0.63`
- `v2.0.63-aio.1`
- `sha-<commit>`

`jsonbored/nanoclaw-agent`:

- `latest`
- `v2.0.63`
- `v2.0.63-agent.1`
- `sha-<commit>`

Both Docker Hub and GHCR should receive the same tag set.

## Upstream Updates

`aio-fleet` monitors stable GitHub Releases from `nanocoai/nanoclaw`. When a newer stable release appears, the fleet monitor should open one PR that updates both:

- root `Dockerfile`
- `components/nanoclaw-agent/Dockerfile`

Unreleased upstream `main` is only a future signal and should not be shipped as production.
