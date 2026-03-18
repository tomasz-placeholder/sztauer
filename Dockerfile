FROM node:20-bookworm

ARG TARGETARCH
ARG CODE_SERVER_VERSION=4.96.4

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    wget \
    jq \
    iptables \
    dnsutils \
    build-essential \
    ripgrep \
    sudo \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# code-server (web editor)
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Firewall allowlist
COPY allowlist.txt /etc/sztauer/allowlist.txt

# Port router for dynamic subdomain routing
COPY port-router.js /opt/sztauer/port-router.js

# Entrypoint
COPY entrypoint.sh /opt/sztauer/entrypoint.sh
RUN chmod +x /opt/sztauer/entrypoint.sh

WORKDIR /workspace

EXPOSE 8080 9091

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/opt/sztauer/entrypoint.sh"]
