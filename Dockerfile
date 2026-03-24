FROM node:22-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    python3 \
    docker.io \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Add node user to docker group (so it can spawn containers)
RUN usermod -aG docker node

WORKDIR /opt/nanoclaw

# Clone upstream repo
RUN git clone https://github.com/dh7/NanoClaw.git . && \
    git config --global --add safe.directory /workspace

# Install global dependencies that might be needed by scripts
RUN npm install -g typescript tsx pm2

# Copy custom entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# The mapped Unraid appdata volume
VOLUME ["/workspace"]

# Let the entrypoint handle file-copying and dependency installation at runtime 
# to ensure the persistent volume is properly populated.
ENTRYPOINT ["docker-entrypoint.sh"]
