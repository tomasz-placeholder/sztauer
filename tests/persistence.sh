#!/usr/bin/env bash
set -euo pipefail

NAME="sztauer-persist-$$"
NETWORK="sztauer-persisttest-$$"
VOLUME="sztauer-claude-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$NAME" 2>/dev/null || true
    docker volume rm "$VOLUME" 2>/dev/null || true
    docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

wait_healthy() {
    for i in $(seq 1 60); do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$NAME" 2>/dev/null || echo "unknown")
        if [ "$STATUS" = "healthy" ]; then
            echo "Container healthy after ${i}s"
            return 0
        fi
        sleep 1
    done
    echo "FAIL: Container not healthy after 60s"
    docker logs "$NAME"
    return 1
}

echo "=== Persistence Test ==="

docker network create "$NETWORK" 2>/dev/null || true

# Start with named volume for ~/.claude/
echo "Starting container (first run)..."
docker run -d \
    --name "$NAME" \
    --network "$NETWORK" \
    --cap-add NET_ADMIN \
    -v "$VOLUME:/home/coder/.claude" \
    sztauer

wait_healthy

# Verify CLAUDE.md present
docker exec "$NAME" test -f /home/coder/CLAUDE.md
echo "OK: CLAUDE.md present"

# Verify Claude Code settings persisted in volume
docker exec "$NAME" test -f /home/coder/.claude/settings.json
echo "OK: Claude settings in volume"

# Simulate a token file (as Claude Max auth would create)
docker exec "$NAME" sh -c 'echo "test-token-data" > /home/coder/.claude/.credentials.json'
docker exec "$NAME" sh -c 'chown coder:coder /home/coder/.claude/.credentials.json'
echo "OK: Token file created"

# Stop and remove container (keep volume)
echo "Stopping container..."
docker rm -f "$NAME"

# Restart with same volume
echo "Starting container (second run)..."
docker run -d \
    --name "$NAME" \
    --network "$NETWORK" \
    --cap-add NET_ADMIN \
    -v "$VOLUME:/home/coder/.claude" \
    sztauer

wait_healthy

# Verify token survived restart
TOKEN=$(docker exec "$NAME" cat /home/coder/.claude/.credentials.json 2>/dev/null || echo "MISSING")
if [ "$TOKEN" = "test-token-data" ]; then
    echo "OK: Token persisted across restart"
else
    echo "FAIL: Token not found after restart (got: $TOKEN)"
    exit 1
fi

# Verify settings also survived (not overwritten)
docker exec "$NAME" test -f /home/coder/.claude/settings.json
echo "OK: Settings persisted across restart"

# Verify CLAUDE.md not overwritten on second start
docker exec "$NAME" grep -q "Sztauer" /home/coder/CLAUDE.md
echo "OK: CLAUDE.md still present"

echo "=== All persistence tests passed ==="
