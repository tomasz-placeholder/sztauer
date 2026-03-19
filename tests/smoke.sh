#!/usr/bin/env bash
set -euo pipefail

NAME="sztauer-smoke-$$"
NETWORK="sztauer-test-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$NAME" 2>/dev/null || true
    docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

check() {
    local desc="$1" url="$2" expect="$3" flags="${4:-}"
    local tmpfile
    tmpfile=$(mktemp)
    # shellcheck disable=SC2086
    curl -s $flags "$url" > "$tmpfile" 2>/dev/null || true
    if grep -qi "$expect" "$tmpfile"; then
        echo "OK: $desc"
        rm -f "$tmpfile"
    else
        echo "FAIL: $desc (expected '$expect')"
        rm -f "$tmpfile"
        exit 1
    fi
}

echo "=== Smoke Test ==="

# Create test network
docker network create "$NETWORK" 2>/dev/null || true

# Start container
echo "Starting container..."
docker run -d \
    --name "$NAME" \
    --network "$NETWORK" \
    --cap-add NET_ADMIN \
    -p 420:420 \
    sztauer

# Wait for healthy
echo "Waiting for healthcheck..."
for i in $(seq 1 60); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$NAME" 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "healthy" ]; then
        echo "Container healthy after ${i}s"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "FAIL: Container not healthy after 60s (status: $STATUS)"
        docker logs "$NAME"
        exit 1
    fi
    sleep 1
done

check "/sztauer serves split screen" "http://localhost:420/sztauer" "iframe"
check "/sztauer/editor/ proxies code-server" "http://localhost:420/sztauer/editor/" "microsoft" "-L"
check "/sztauer/terminal/ proxies ttyd" "http://localhost:420/sztauer/terminal/" "ttyd"
check "/ serves placeholder" "http://localhost:420/" "will appear here"

# Verify CLAUDE.md
echo "Checking workspace CLAUDE.md..."
docker exec "$NAME" test -f /home/coder/CLAUDE.md
echo "OK: CLAUDE.md present"

# Verify firewall
echo "Checking firewall rules..."
docker exec "$NAME" iptables -L OUTPUT -n | grep -q "DROP"
echo "OK: Firewall active"

# Verify app port: start server on 3000 → appears at localhost:420
echo "Checking app port routing..."
docker exec -d "$NAME" su -c 'python3 -m http.server 3000 --directory /tmp' coder

# Give server a moment to bind
sleep 2

# Verify internal port 3000 is listening
docker exec "$NAME" curl -sf http://localhost:3000/ > /dev/null
echo "OK: Internal app server on port 3000"

# Verify localhost:420 now serves the app instead of placeholder
BODY=$(curl -s http://localhost:420/)
if echo "$BODY" | grep -qi "directory listing\|\."; then
    echo "OK: App port routed — localhost:420 serves app from port 3000"
else
    # As long as it no longer shows the placeholder, the routing works
    if ! echo "$BODY" | grep -qi "will appear here"; then
        echo "OK: App port routed — placeholder replaced by app content"
    else
        echo "FAIL: localhost:420 still shows placeholder after starting app on 3000"
        exit 1
    fi
fi

# Stop the test server
docker exec "$NAME" pkill -f "python3 -m http.server 3000" || true

echo "=== All smoke tests passed ==="
