# Changelog

All notable changes to this project will be documented in this file.

## v2.0.64-aio.2 - 2026-05-19

### Fixes

- Move the Docker socket mount behind Advanced View and mark it optional in the Unraid template while keeping the security warning explicit.
- Update the default helper image reference to `jsonbored/nanoclaw-agent:v2.0.64-agent.1`.

## v2.0.64-aio.1 - 2026-05-19

### Dependency Updates

- Update non-major infrastructure updates
- Update node.js to v24

### Documentation

- Normalize nanoclaw ca description
- Modernize nanoclaw aio docs

### Fixes

- Normalize nanoclaw ca metadata
- Align nanoclaw fleet target metadata

### Maintenance

- Update upstream pins for nanoclaw-aio

### Tests

- Format template policy assertions

## v2.0.63-aio.1 - 2026-05-18

### Features

- Rebuild the AIO image around upstream `nanocoai/nanoclaw` `v2.0.63`.
- Add the paired `jsonbored/nanoclaw-agent:v2.0.63-agent.1` helper image for nested agent sessions.
- Vendor the Telegram channel adapter at build time from the upstream `channels` branch instead of fetching adapter code at runtime.
- Add Unraid-safe host appdata path mapping for Docker-socket-spawned helper containers.

### Documentation

- Rewrite the README and setup docs for NanoClaw v2, Telegram pairing, Docker socket trust, and the AIO/agent image split.
- Rewrite the Unraid XML template with current v2 environment variables, beta status, and explicit pairing-code first boot guidance.

### Tests

- Add pytest coverage for XML metadata, Dockerfile pins, image/tag identity, v2 env surface, and runtime smoke behavior.
- Add a release-readiness guard that fails if the stale upstream gitlink returns and breaks fleet checkout.

### Notes

- This release replaces the old `nanocoai/nanoclaw-telegram` `v1.2.x` wrapper model. Existing v1 users should treat v2 as a migration, not an in-place compatible runtime.
- The user-facing GitHub Release is `v2.0.63-aio.1`; the paired helper image tag is `v2.0.63-agent.1`.
- The release gate cleanup normalized formatting and lint metadata only; it does not change the package revision or runtime defaults.
- The CI runtime smoke now tolerates Docker-owned appdata files during test cleanup.
