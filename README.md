# nanoclaw-aio 🚀

The unofficial, fully-automated All-In-One (AIO) Unraid container for [NanoClaw](https://nanoclaw.dev/).

Docker Hub / GHCR Image: `ghcr.io/jsonbored/nanoclaw-aio`

## What is this?
NanoClaw is a lightweight alternative to OpenClaw that runs AI agents in containers for security.
Normally, NanoClaw is strictly meant to run from your personal terminal via CLI bootstrapping. 
This AIO repacks NanoClaw to work perfectly as a background Docker container on Unraid, completely automating the registration loops and Docker-in-Docker proxying.

## Features
* **Zero-Touch Config:** Supply your Anthropic Token and Telegram Bot details in the Unraid GUI and the script does the rest.
* **Auto-Telegram:** Uses Unraid variables to automatically invoke NanoClaw's `/add-telegram` build scripts.
* **Persistent Workspace:** Automatically copies core files to your `/mnt/user/appdata` on first boot, so your AI memory is never lost. 

## Documentation
Please see the [Documentation](./docs/README.md) folder for setup and advanced usage.

## 📈 Star History
[![Star History Chart](https://api.star-history.com/svg?repos=JSONbored/nanoclaw-aio&theme=dark)](https://star-history.com/#JSONbored/nanoclaw-aio&Date)
