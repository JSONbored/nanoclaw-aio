# NanoClaw All-in-One for Unraid

A fully featured, easy-to-deploy Unraid Community Applications template for NanoClaw. NanoClaw is a lightweight, secure alternative to OpenClaw that runs AI agents in isolated Docker containers.

## 🚀 Features
- **True AIO:** The Docker entrypoint automatically handles the internal bootstrapping of NanoClaw.
- **Docker-in-Docker Setup:** Configured out-of-the-box to securely mount the Docker socket, enabling the NanoClaw orchestrator to spawn isolated agent containers.
- **Auto-Config:** Use the Unraid WebUI to input your variables. Enable `AUTO_SETUP_TELEGRAM` to have the container automatically register your Telegram bot on first boot!

## 📦 Installation via Unraid CA
If you are using the `awesome-unraid` repository, simply search for "NanoClaw-AIO" in the Apps tab.

### Required Fields
1. **Anthropic API Key:** Your key (`sk-ant-...`) required to run the agents.
2. **Docker Socket:** Required to spawn the isolated containers. (Default: `/var/run/docker.sock`)
3. **Workspace Volume:** The persistent appdata folder. (Default: `/mnt/user/appdata/nanoclaw-aio/workspace`)

### Telegram Setup 
1. Get a bot token from [@BotFather](https://t.me/BotFather).
2. Find your personal Chat ID or a Group ID.
3. In the Unraid Template (Advanced View), enter both tokens.
4. Set **Auto-Setup Telegram** to `true`.
5. Start the container! The entrypoint script will automatically compile the skill and register your specific chat.

## 💻 Technical Details
- Base Image: `node:22-slim` + Docker CLI.
- Entrypoint: Checks if the workspace is empty on boot. If so, it clones the core upstream files into the persistent volume, writes the `.env` file based on your Unraid variables, and runs any requested auto-registration scripts.

## 🔒 Security
NanoClaw's architecture requires the orchestrator process to have Docker socket access in order to spin up the short-lived agent task containers. Ensure your Unraid network is properly secured, as root-level Docker access is technically equivalent to root access on the host. 

---

## 👨‍💻 About the Creator

Built with 🖤 by **[JSONbored](https://github.com/JSONbored)**.

- 🌐 **Portfolio & Services:** [aethereal.dev](https://aethereal.dev)
- 📅 **Book a Call:** [cal.com/aethereal](https://cal.com/aethereal) 
- ☕ **Support my work:** [Sponsor on GitHub](https://github.com/sponsors/JSONbored)
