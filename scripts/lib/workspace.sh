#!/usr/bin/env bash
# Workspace initialization

CODER_HOME="${CODER_HOME:-/home/coder}"

setup_workspace() {
    if [ ! -f "$CODER_HOME/CLAUDE.md" ]; then
        cp /etc/sztauer/workspace-template/CLAUDE.md "$CODER_HOME/CLAUDE.md"
        chown coder:coder "$CODER_HOME/CLAUDE.md"
        log "Default CLAUDE.md copied to workspace."
    else
        log "Existing CLAUDE.md found — not overwriting."
    fi
}

setup_claude_config() {
    local claude_dir="$CODER_HOME/.claude"
    mkdir -p "$claude_dir"

    if [ ! -f "$claude_dir/settings.json" ]; then
        cat > "$claude_dir/settings.json" << 'SETTINGS'
{
  "model": "opus",
  "effort": "high"
}
SETTINGS
        log "Claude Code settings created."
    fi

    chown -R coder:coder "$claude_dir"
}
