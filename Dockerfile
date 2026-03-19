# ============================================================
# Stage 1: Builder — download binaries, install code-server
# ============================================================
FROM debian:bookworm-slim AS builder

ARG TARGETARCH
ARG CODE_SERVER_VERSION=4.96.4
ARG TTYD_VERSION=1.7.7
ARG CADDY_VERSION=2.9.1

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ttyd — prebuilt binary
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL -o /usr/local/bin/ttyd \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ARCH}" && \
    chmod +x /usr/local/bin/ttyd

# Caddy — prebuilt binary
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL -o /tmp/caddy.tar.gz \
    "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_${ARCH}.tar.gz" && \
    tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy && \
    chmod +x /usr/local/bin/caddy && \
    rm /tmp/caddy.tar.gz

# code-server
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}


# ============================================================
# Stage 2: Final image
# ============================================================
FROM debian:bookworm-slim

# Runtime dependencies
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 python3-pip python3-venv \
    curl wget jq \
    iptables dnsutils \
    build-essential \
    ripgrep \
    sudo \
    openssh-client \
    ca-certificates \
    procps \
    bats \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS
ARG NODE_MAJOR=22
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Binaries from builder
COPY --from=builder /usr/local/bin/ttyd /usr/local/bin/ttyd
COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy
COPY --from=builder /usr/lib/code-server /usr/lib/code-server
COPY --from=builder /usr/bin/code-server /usr/bin/code-server

# Claude Code CLI
# hadolint ignore=DL3016
RUN npm install -g @anthropic-ai/claude-code

# User: coder (UID 1000, passwordless sudo)
RUN useradd -m -s /bin/bash -u 1000 coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder

# Config files
COPY config/allowlist.txt /etc/sztauer/allowlist.txt
COPY config/Caddyfile /etc/caddy/Caddyfile
COPY config/code-server.yaml /etc/sztauer/code-server.yaml
COPY workspace-template/ /etc/sztauer/workspace-template/

# Web UI (split screen, placeholder)
COPY web/ /opt/sztauer/web/

# Scripts
COPY scripts/lib/ /opt/sztauer/lib/
COPY entrypoint.sh /opt/sztauer/entrypoint.sh
RUN chmod +x /opt/sztauer/entrypoint.sh /opt/sztauer/lib/*.sh

EXPOSE 420

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8080/healthz && curl -sf http://localhost:7681/sztauer/terminal/ || exit 1

ENTRYPOINT ["/opt/sztauer/entrypoint.sh"]
