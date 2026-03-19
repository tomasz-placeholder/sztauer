#!/usr/bin/env bats
# Firewall tests — must run inside container with --cap-add NET_ADMIN

setup() {
    log() { echo "[test] $*"; }
    export -f log
    source /opt/sztauer/lib/firewall.sh
}

@test "firewall sets up default-deny" {
    setup_firewall
    iptables -L OUTPUT -n | tail -1 | grep -q "DROP"
}

@test "loopback traffic allowed" {
    setup_firewall
    # -v shows interface columns; loopback uses out=lo
    iptables -L OUTPUT -nv | grep -q "ACCEPT.*lo"
}

@test "Docker DNS allowed" {
    setup_firewall
    iptables -L OUTPUT -n | grep -q "ACCEPT.*127.0.0.11"
}

@test "Docker internal networks allowed" {
    setup_firewall
    iptables -L OUTPUT -n | grep -q "ACCEPT.*172.16.0.0/12"
    iptables -L OUTPUT -n | grep -q "ACCEPT.*10.0.0.0/8"
    iptables -L OUTPUT -n | grep -q "ACCEPT.*192.168.0.0/16"
}

@test "allowlist domains resolved" {
    setup_firewall
    local accept_count
    accept_count=$(iptables -L OUTPUT -n | grep -c "ACCEPT")
    [ "$accept_count" -gt 6 ]
}
