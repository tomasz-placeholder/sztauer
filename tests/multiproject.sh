#!/usr/bin/env bash
set -euo pipefail

NAME_A="sztauer-multi-a-$$"
NAME_B="sztauer-multi-b-$$"
NETWORK="sztauer-multitest-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$NAME_A" "$NAME_B" 2>/dev/null || true
    docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

wait_healthy() {
    local name="$1"
    for i in $(seq 1 60); do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
        if [ "$STATUS" = "healthy" ]; then
            echo "  $name healthy after ${i}s"
            return 0
        fi
        sleep 1
    done
    echo "FAIL: $name not healthy after 60s"
    docker logs "$name"
    return 1
}

echo "=== Multi-project Test ==="

docker network create "$NETWORK" 2>/dev/null || true

# Start two projects on different host ports
echo "Starting project A (port 420)..."
docker run -d \
    --name "$NAME_A" \
    --network "$NETWORK" \
    --cap-add NET_ADMIN \
    -p 420:420 \
    -l "sztauer.project=project-a" \
    sztauer

echo "Starting project B (port 421)..."
docker run -d \
    --name "$NAME_B" \
    --network "$NETWORK" \
    --cap-add NET_ADMIN \
    -p 421:420 \
    -l "sztauer.project=project-b" \
    sztauer

echo "Waiting for containers..."
wait_healthy "$NAME_A"
wait_healthy "$NAME_B"

FAIL=0

# Both accessible on their ports
check_url() {
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

check_url "Project A split screen" "http://localhost:420/sztauer" "iframe"
check_url "Project B split screen" "http://localhost:421/sztauer" "iframe"

# Cross-container communication via network
echo "Testing A → B communication..."
docker exec "$NAME_A" curl -sf "http://${NAME_B}:420" > /dev/null 2>&1 || true
# Use placeholder response as signal — if Caddy responds, network works
RESPONSE=$(docker exec "$NAME_A" curl -s "http://${NAME_B}:420" 2>/dev/null | head -c 1000 || true)
if echo "$RESPONSE" | grep -qi "will appear here\|sztauer"; then
    echo "OK: A can reach B"
else
    echo "FAIL: A cannot reach B"
    FAIL=1
fi

# Each has its own workspace
docker exec "$NAME_A" test -f /home/coder/CLAUDE.md
docker exec "$NAME_B" test -f /home/coder/CLAUDE.md
echo "OK: Both have CLAUDE.md"

# Labels present
LABEL_A=$(docker inspect --format='{{index .Config.Labels "sztauer.project"}}' "$NAME_A" 2>/dev/null || echo "none")
LABEL_B=$(docker inspect --format='{{index .Config.Labels "sztauer.project"}}' "$NAME_B" 2>/dev/null || echo "none")
if [ "$LABEL_A" = "project-a" ] && [ "$LABEL_B" = "project-b" ]; then
    echo "OK: Labels correct"
else
    echo "FAIL: Labels wrong (A=$LABEL_A, B=$LABEL_B)"
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== All multi-project tests passed ==="
else
    echo "=== Some multi-project tests FAILED ==="
    exit 1
fi
