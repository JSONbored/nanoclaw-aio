# syntax=docker/dockerfile:1.24@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89
# checkov:skip=CKV_DOCKER_2: The agent image is a short-lived helper process spawned by nanoclaw-aio, not a standalone service.
# checkov:skip=CKV_DOCKER_3: NanoClaw's upstream agent image runs as node after root installs browser and CLI dependencies.
# checkov:skip=CKV_DOCKER_7: NanoClaw is pinned by release tag and commit SHA because the helper image is built from upstream source.

ARG UPSTREAM_VERSION=v2.0.64
ARG UPSTREAM_COMMIT=975a2f0f5b0ea19bbf35fadfd394df35e5341d3a
ARG AGENT_REVISION=1

FROM alpine/git:v2.52.0@sha256:d453f54c83320412aa89c391b076930bd8569bc1012285e8c68ce2d4435826a3 AS source

ARG UPSTREAM_COMMIT

WORKDIR /src

RUN git clone https://github.com/nanocoai/nanoclaw.git . && \
    git checkout "${UPSTREAM_COMMIT}" && \
    rm -rf .git

FROM node:24-slim@sha256:24dc26ef1e3c3690f27ebc4136c9c186c3133b25563ae4d7f0692e4d1fe5db0e

ARG UPSTREAM_VERSION
ARG UPSTREAM_COMMIT
ARG AGENT_REVISION
ARG INSTALL_CJK_FONTS=false
ARG CLAUDE_CODE_VERSION=2.1.128
ARG AGENT_BROWSER_VERSION=latest
ARG VERCEL_VERSION=52.2.1
ARG BUN_VERSION=1.3.12
ARG PNPM_VERSION=10.33.0

LABEL org.opencontainers.image.source="https://github.com/JSONbored/nanoclaw-aio" \
      org.opencontainers.image.title="nanoclaw-agent" \
      org.opencontainers.image.description="Helper sandbox image spawned by nanoclaw-aio for isolated NanoClaw agent sessions." \
      org.opencontainers.image.version="${UPSTREAM_VERSION}-agent.${AGENT_REVISION}" \
      org.opencontainers.image.licenses="MIT" \
      io.jsonbored.upstream.version="${UPSTREAM_VERSION}" \
      io.jsonbored.upstream.commit="${UPSTREAM_COMMIT}" \
      io.jsonbored.nanoclaw.agent_revision="${AGENT_REVISION}" \
      io.jsonbored.nanoclaw.claude_code_version="${CLAUDE_CODE_VERSION}"

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      chromium \
      fonts-liberation \
      fonts-noto-color-emoji \
      libgbm1 \
      libnss3 \
      libatk-bridge2.0-0 \
      libgtk-3-0 \
      libx11-xcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxrandr2 \
      libasound2 \
      libpangocairo-1.0-0 \
      libcups2 \
      libdrm2 \
      libxshmfence1 \
      ca-certificates \
      curl \
      git \
      tini \
      unzip \
    && if [ "${INSTALL_CJK_FONTS}" = "true" ]; then \
      apt-get install -y --no-install-recommends fonts-noto-cjk; \
    fi \
    && rm -rf /var/lib/apt/lists/*

ENV AGENT_BROWSER_EXECUTABLE_PATH="/usr/bin/chromium" \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="/usr/bin/chromium" \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD="1" \
    PNPM_HOME="/pnpm" \
    PATH="/pnpm:${PATH}"

RUN curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh && \
    bash /tmp/bun-install.sh "bun-v${BUN_VERSION}" && \
    install -m 0755 /root/.bun/bin/bun /usr/local/bin/bun && \
    rm -rf /root/.bun /tmp/bun-install.sh

WORKDIR /app

COPY --from=source /src/container/agent-runner/package.json /src/container/agent-runner/bun.lock ./

RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun install --frozen-lockfile

RUN --mount=type=cache,target=/root/.cache/pnpm \
    corepack enable && \
    corepack prepare "pnpm@${PNPM_VERSION}" --activate && \
    echo "only-built-dependencies[]=agent-browser" > /root/.npmrc && \
    echo "only-built-dependencies[]=@anthropic-ai/claude-code" >> /root/.npmrc && \
    pnpm install -g "vercel@${VERCEL_VERSION}"

RUN --mount=type=cache,target=/root/.cache/pnpm \
    pnpm install -g "agent-browser@${AGENT_BROWSER_VERSION}"

RUN --mount=type=cache,target=/root/.cache/pnpm \
    pnpm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" && \
    printf '#!/bin/sh\nexec bun /app/src/cli/ncl.ts "$@"\n' > /usr/local/bin/ncl && \
    chmod +x /usr/local/bin/ncl

COPY --from=source /src/container/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh && \
    mkdir -p /workspace/group /workspace/extra && \
    chown -R node:node /workspace && \
    chmod 777 /home/node

USER node
WORKDIR /workspace/group

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
