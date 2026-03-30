# syntax=docker/dockerfile:1

ARG UPSTREAM_VERSION=v1.2.42
ARG UPSTREAM_COMMIT=f1bc56ee96119d6197bbb13cda0d5cab134e608b

FROM node:24-slim@sha256:06e5c9f86bfa0aaa7163cf37a5eaa8805f16b9acb48e3f85645b09d459fc2a9f AS build

ARG UPSTREAM_COMMIT

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    make \
    g++ \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/nanoclaw

RUN git clone https://github.com/qwibitai/nanoclaw-telegram.git . && \
    git checkout "${UPSTREAM_COMMIT}"

COPY patches/native-credential-proxy.patch /tmp/native-credential-proxy.patch

RUN git apply /tmp/native-credential-proxy.patch && \
    npm ci && \
    npm run build && \
    rm -rf .git /tmp/native-credential-proxy.patch


FROM node:24-slim@sha256:06e5c9f86bfa0aaa7163cf37a5eaa8805f16b9acb48e3f85645b09d459fc2a9f

ARG UPSTREAM_VERSION
ARG UPSTREAM_COMMIT

LABEL org.opencontainers.image.source="https://github.com/JSONbored/nanoclaw-aio" \
      org.opencontainers.image.title="nanoclaw-aio" \
      org.opencontainers.image.description="NanoClaw Telegram build packaged as a single-container Unraid AIO image" \
      org.opencontainers.image.version="${UPSTREAM_VERSION}" \
      io.jsonbored.upstream.commit="${UPSTREAM_COMMIT}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    docker.io \
    tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/nanoclaw

COPY --from=build /opt/nanoclaw /opt/nanoclaw
COPY --from=build /opt/nanoclaw/groups /opt/nanoclaw-default-groups
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    mkdir -p /appdata

VOLUME ["/appdata"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
  CMD /bin/bash -lc 'if [[ -f /appdata/.waiting-for-config || -f /appdata/.smoke-ready ]]; then exit 0; fi; test -f /appdata/.bootstrap-complete && pgrep -f "node dist/index.js" >/dev/null'

ENTRYPOINT ["tini", "--", "docker-entrypoint.sh"]
