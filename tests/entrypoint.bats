#!/usr/bin/env bats
# Unit tests for workspace init (entrypoint functions)

setup() {
    export CODER_HOME="$(mktemp -d)"
    mkdir -p /etc/sztauer/workspace-template
    echo "# Test CLAUDE.md" > /etc/sztauer/workspace-template/CLAUDE.md

    # Create coder user dirs if testing locally
    useradd -m -s /bin/bash -u 1000 coder 2>/dev/null || true

    # Override CODER_HOME for testing
    log() { echo "[test] $*"; }
    export -f log

    source /opt/sztauer/lib/workspace.sh
}

teardown() {
    rm -rf "$CODER_HOME"
}

@test "CLAUDE.md copied when missing" {
    [ ! -f "$CODER_HOME/CLAUDE.md" ]
    setup_workspace
    [ -f "$CODER_HOME/CLAUDE.md" ]
    grep -q "Test CLAUDE.md" "$CODER_HOME/CLAUDE.md"
}

@test "CLAUDE.md not overwritten when present" {
    echo "# Existing" > "$CODER_HOME/CLAUDE.md"
    setup_workspace
    grep -q "Existing" "$CODER_HOME/CLAUDE.md"
}

@test "Claude config directory created" {
    [ ! -d "$CODER_HOME/.claude" ]
    setup_claude_config
    [ -d "$CODER_HOME/.claude" ]
    [ -f "$CODER_HOME/.claude/settings.json" ]
}

@test "Claude config not overwritten when present" {
    mkdir -p "$CODER_HOME/.claude"
    echo '{"custom": true}' > "$CODER_HOME/.claude/settings.json"
    setup_claude_config
    grep -q "custom" "$CODER_HOME/.claude/settings.json"
}
