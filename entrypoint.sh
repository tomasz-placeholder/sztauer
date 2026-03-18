#!/usr/bin/env bash
set -euo pipefail

# --- Validate required env vars ---
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "ERROR: ANTHROPIC_API_KEY is required."
    echo "Set it in your .env file. See .env.example for details."
    exit 1
fi

export ANTHROPIC_API_KEY

# --- Firewall setup ---
setup_firewall() {
    if ! iptables -L OUTPUT -n &>/dev/null; then
        echo "WARN: Cannot configure firewall (missing NET_ADMIN capability)."
        echo "      Add 'cap_add: [NET_ADMIN]' to compose.yml for firewall support."
        return 0
    fi

    echo "Configuring firewall..."

    # Flush existing OUTPUT rules
    iptables -F OUTPUT 2>/dev/null || true

    # Allow loopback
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established/related connections
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow DNS to Docker's embedded DNS
    iptables -A OUTPUT -p udp --dport 53 -d 127.0.0.11 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -d 127.0.0.11 -j ACCEPT

    # Allow Docker internal networks (proxy, inter-container)
    iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
    iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
    iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

    # Resolve and allow domains from allowlist
    resolve_and_allow /etc/sztauer/allowlist.txt

    # Allow additional domains from FIREWALL_ALLOW env
    if [ -n "${FIREWALL_ALLOW:-}" ]; then
        local tmpfile
        tmpfile=$(mktemp)
        echo "${FIREWALL_ALLOW}" | tr ',' '\n' > "$tmpfile"
        resolve_and_allow "$tmpfile"
        rm -f "$tmpfile"
    fi

    # Default deny
    iptables -A OUTPUT -j DROP

    echo "Firewall active (default-deny with allowlist)."
}

resolve_and_allow() {
    local file="$1"
    [ -f "$file" ] || return 0

    while IFS= read -r domain || [ -n "$domain" ]; do
        # Skip comments and empty lines
        [[ "$domain" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${domain// /}" ]] && continue
        domain="${domain// /}"

        local ips
        ips=$(dig +short "$domain" A 2>/dev/null || true)
        for ip in $ips; do
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                iptables -A OUTPUT -d "$ip" -j ACCEPT 2>/dev/null || true
            fi
        done
    done < "$file"
}

# --- Git auto-detection ---
setup_git() {
    if [ -f /root/.gitconfig ]; then
        echo "Git config detected."
    fi

    if [ -d /root/.ssh ]; then
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/* 2>/dev/null || true
        eval "$(ssh-agent -s)" > /dev/null 2>&1
        for key in /root/.ssh/id_*; do
            [ -f "$key" ] && [[ ! "$key" == *.pub ]] && ssh-add "$key" 2>/dev/null || true
        done
        echo "SSH keys loaded."
    fi
}

# --- Workspace initialization ---
init_workspace() {
    cd /workspace
    if [ -z "$(ls -A /workspace 2>/dev/null)" ]; then
        echo "Empty workspace — initializing git repo."
        git init
        echo "# ${PROJECT_NAME:-project}" > README.md
        git add .
        git commit -m "Initial commit" --allow-empty 2>/dev/null || true
    fi
}

# --- Main ---
echo "=== Sztauer ==="
echo "Project: ${PROJECT_NAME:-unknown}"

setup_firewall
setup_git
init_workspace

# Editor
echo "Starting code-server on :8080"
exec code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth none \
    --disable-telemetry \
    --disable-update-check \
    /workspace
