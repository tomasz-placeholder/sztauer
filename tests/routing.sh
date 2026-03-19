#!/usr/bin/env bash
set -euo pipefail

NAME="sztauer-routing-$$"
NETWORK="sztauer-routetest-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$NAME" 2>/dev/null || true
    docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Routing Test ==="

docker network create "$NETWORK" 2>/dev/null || true

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

FAIL=0
check() {
    local desc="$1" url="$2" expect="$3"
    local tmpfile
    tmpfile=$(mktemp)
    curl -sL "$url" > "$tmpfile" 2>/dev/null || true
    if grep -qi "$expect" "$tmpfile"; then
        echo "OK: $desc"
    else
        echo "FAIL: $desc (expected '$expect')"
        FAIL=1
    fi
    rm -f "$tmpfile"
}

check_status() {
    local desc="$1" url="$2" expected_status="$3"
    local status
    status=$(curl -so /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
    if [ "$status" = "$expected_status" ]; then
        echo "OK: $desc (HTTP $status)"
    else
        echo "FAIL: $desc (expected HTTP $expected_status, got $status)"
        FAIL=1
    fi
}

# /sztauer → split screen HTML with iframes
check "/sztauer serves split screen" "http://localhost:420/sztauer" "iframe"

# /sztauer/ (trailing slash) → same
check "/sztauer/ serves split screen" "http://localhost:420/sztauer/" "iframe"

# /sztauer/editor/ → code-server (follows 302 redirect)
check "/sztauer/editor/ proxies to code-server" "http://localhost:420/sztauer/editor/" "microsoft"

# /sztauer/terminal/ → ttyd
check "/sztauer/terminal/ proxies to ttyd" "http://localhost:420/sztauer/terminal/" "ttyd"

# / → placeholder (no app running on 3000)
check "/ serves placeholder when no app" "http://localhost:420/" "will appear here"

# Start a test app on port 3000, verify routing
echo "Starting test app on port 3000..."
docker exec -d "$NAME" su -l coder -c "python3 -m http.server 3000"
sleep 2

check_status "/ proxies to app on port 3000" "http://localhost:420/" "200"

if [ "$FAIL" -eq 0 ]; then
    echo "=== All routing tests passed ==="
else
    echo "=== Some routing tests FAILED ==="
    exit 1
fi
