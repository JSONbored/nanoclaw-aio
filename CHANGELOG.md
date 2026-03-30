# Changelog

## Unreleased

- Rebuilt `nanoclaw-aio` around the official `qwibitai/nanoclaw-telegram` upstream instead of cloning an unrelated repository
- Applied the official native credential proxy patch so the image does not depend on an external OneCLI service
- Switched persistence to a single `/appdata` root with immutable application code in the image
- Added Telegram auto-registration and a safe waiting-for-config mode instead of crash loops
- Added local smoke testing with restart and persistence coverage
- Added pinned-SHA workflows, security review, upstream monitoring, and PR-only Renovate
- Added the missing Unraid CA template and synchronized repo docs with the actual runtime model
