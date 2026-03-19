#!/usr/bin/env bash
set -euo pipefail

log() { echo "[sztauer] $*"; }

# shellcheck source=scripts/lib/firewall.sh
source /opt/sztauer/lib/firewall.sh
# shellcheck source=scripts/lib/workspace.sh
source /opt/sztauer/lib/workspace.sh

cleanup() {
    log "Shutting down..."
    # shellcheck disable=SC2046
    kill $(jobs -p) 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup EXIT TERM INT

# --- Main ---
log "Starting Sztauer..."

setup_firewall
setup_workspace
setup_claude_config

# Caddy (reverse proxy on :420)
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
log "Caddy started on :420"

# code-server (web editor on :8080)
su -l coder -c "code-server \
    --config /etc/sztauer/code-server.yaml \
    /home/coder" &
log "code-server started on :8080"

# ttyd (web terminal on :7681, Claude Code CLI)
su -l coder -c "ttyd --port 7681 --writable --base-path /sztauer/terminal claude --dangerously-skip-permissions" &
log "ttyd started on :7681 (Claude Code)"

log "All services running."

# Wait — exit if any child dies
wait -n
exit $?
