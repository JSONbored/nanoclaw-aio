# NanoClaw v1 to v2 Migration Note

This package no longer wraps the old v1 Telegram fork runtime. It now packages upstream `nanocoai/nanoclaw` v2.

Treat the first v2 AIO release as a runtime migration:

- Back up your existing `nanoclaw-aio` appdata before switching image tags.
- Expect Telegram setup to use pairing codes instead of the old direct chat-id registration model.
- Expect appdata layout changes under `/appdata/runtime`.
- Keep the template beta until your own setup has been tested.

If you need to keep a working v1 deployment untouched, pin the old image tag instead of following `latest`.
