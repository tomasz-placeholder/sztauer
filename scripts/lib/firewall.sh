#!/usr/bin/env bash
# Firewall: iptables default-deny + allowlist

setup_firewall() {
    if ! iptables -L OUTPUT -n &>/dev/null; then
        log "WARN: No iptables capability. Add --cap-add NET_ADMIN. Firewall disabled."
        return 0
    fi

    log "Setting up firewall..."

    iptables -F OUTPUT 2>/dev/null || true

    # Loopback
    iptables -A OUTPUT -o lo -j ACCEPT

    # Established/related connections
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Docker embedded DNS
    iptables -A OUTPUT -p udp --dport 53 -d 127.0.0.11 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -d 127.0.0.11 -j ACCEPT

    # Docker internal networks (covers sztauer bridge network)
    iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
    iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
    iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

    # Allowlist
    resolve_and_allow /etc/sztauer/allowlist.txt

    # Default deny
    iptables -A OUTPUT -j DROP

    log "Firewall active (default-deny + allowlist)."
}

resolve_and_allow() {
    local file="$1"
    [ -f "$file" ] || return 0

    while IFS= read -r domain || [ -n "$domain" ]; do
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
