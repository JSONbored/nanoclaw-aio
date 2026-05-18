# syntax=docker/dockerfile:1.7@sha256:2780b5c3bab67f1f76c781860de469442999ed1a0d7992a5efdf2cffc0e3d769
# checkov:skip=CKV_DOCKER_2: Healthcheck is defined in this Dockerfile.
# checkov:skip=CKV_DOCKER_3: The wrapper starts as root to align Docker socket group permissions, then runs NanoClaw as node.
# checkov:skip=CKV_DOCKER_7: NanoClaw is pinned by tag and commit SHA because upstream does not publish a Docker image for this AIO runtime.

ARG UPSTREAM_VERSION=v2.0.63
ARG UPSTREAM_COMMIT=975a2f0f5b0ea19bbf35fadfd394df35e5341d3a
ARG CHANNELS_COMMIT=8e91d37bc9c14b06580bda4b46c85f33cf755b15
ARG AIO_REVISION=1
ARG PNPM_VERSION=10.33.0
ARG TELEGRAM_ADAPTER_VERSION=4.26.0

FROM node:22-slim@sha256:689c11043dad91472750cd824c97dd5e2318e9dd6f954e492fe7af0135d33ceb AS build

ARG UPSTREAM_COMMIT
ARG CHANNELS_COMMIT
ARG PNPM_VERSION
ARG TELEGRAM_ADAPTER_VERSION

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      make \
      g++ \
      python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/nanoclaw

RUN git clone https://github.com/nanocoai/nanoclaw.git . && \
    git checkout "${UPSTREAM_COMMIT}" && \
    git clone --depth 1 --branch channels https://github.com/nanocoai/nanoclaw.git /tmp/nanoclaw-channels && \
    git -C /tmp/nanoclaw-channels checkout "${CHANNELS_COMMIT}" && \
    for file in \
      src/channels/telegram.ts \
      src/channels/telegram-pairing.ts \
      src/channels/telegram-pairing.test.ts \
      src/channels/telegram-markdown-sanitize.ts \
      src/channels/telegram-markdown-sanitize.test.ts; do \
      mkdir -p "$(dirname "${file}")"; \
      cp "/tmp/nanoclaw-channels/${file}" "${file}"; \
    done && \
    if ! grep -q "^import './telegram.js';" src/channels/index.ts; then \
      printf "\nimport './telegram.js';\n" >> src/channels/index.ts; \
    fi && \
    rm -rf /tmp/nanoclaw-channels .git

COPY patches/unraid-host-paths.patch /tmp/unraid-host-paths.patch

RUN git apply /tmp/unraid-host-paths.patch && \
    corepack enable && \
    corepack prepare "pnpm@${PNPM_VERSION}" --activate && \
    pnpm install --frozen-lockfile && \
    pnpm install "@chat-adapter/telegram@${TELEGRAM_ADAPTER_VERSION}" && \
    pnpm run build && \
    rm -rf /tmp/unraid-host-paths.patch ~/.local/share/pnpm/store

FROM node:22-slim@sha256:689c11043dad91472750cd824c97dd5e2318e9dd6f954e492fe7af0135d33ceb

ARG UPSTREAM_VERSION
ARG UPSTREAM_COMMIT
ARG CHANNELS_COMMIT
ARG AIO_REVISION
ARG PNPM_VERSION
ARG TELEGRAM_ADAPTER_VERSION

LABEL org.opencontainers.image.source="https://github.com/JSONbored/nanoclaw-aio" \
      org.opencontainers.image.title="nanoclaw-aio" \
      org.opencontainers.image.description="Telegram-first Unraid AIO wrapper for NanoClaw v2 with a paired nested NanoClaw agent helper image." \
      org.opencontainers.image.version="${UPSTREAM_VERSION}-aio.${AIO_REVISION}" \
      org.opencontainers.image.licenses="MIT" \
      io.jsonbored.upstream.version="${UPSTREAM_VERSION}" \
      io.jsonbored.upstream.commit="${UPSTREAM_COMMIT}" \
      io.jsonbored.upstream.channels_commit="${CHANNELS_COMMIT}" \
      io.jsonbored.nanoclaw.telegram_adapter_version="${TELEGRAM_ADAPTER_VERSION}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      docker.io \
      gosu \
      tini \
    && rm -rf /var/lib/apt/lists/*

ENV NANOCLAW_AIO_VERSION="${UPSTREAM_VERSION}-aio.${AIO_REVISION}" \
    NANOCLAW_UPSTREAM_VERSION="${UPSTREAM_VERSION}" \
    NANOCLAW_CHANNELS_COMMIT="${CHANNELS_COMMIT}" \
    CONTAINER_IMAGE="jsonbored/nanoclaw-agent:${UPSTREAM_VERSION}-agent.1" \
    CONTAINER_IMAGE_BASE="jsonbored/nanoclaw-agent" \
    NANOCLAW_CONTAINER_APPDATA_DIR="/appdata" \
    NANOCLAW_HOST_APPDATA_DIR="/mnt/user/appdata/nanoclaw-aio" \
    NANOCLAW_AUTO_PAIR_TELEGRAM="true" \
    TZ="UTC"

WORKDIR /opt/nanoclaw

COPY --from=build /opt/nanoclaw /opt/nanoclaw
COPY --from=build /opt/nanoclaw/groups /opt/nanoclaw-default-groups
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    mkdir -p /appdata && \
    chown -R node:node /appdata /opt/nanoclaw

VOLUME ["/appdata"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD /bin/bash -lc 'if [[ -f /appdata/.waiting-for-config || -f /appdata/.smoke-ready ]]; then exit 0; fi; test -f /appdata/.bootstrap-complete && pgrep -f "dist/index.js" >/dev/null'

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
