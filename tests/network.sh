#!/usr/bin/env bash
set -euo pipefail

NAME_A="sztauer-net-a-$$"
NAME_B="sztauer-net-b-$$"
NETWORK="sztauer-nettest-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$NAME_A" "$NAME_B" 2>/dev/null || true
    docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Network Test ==="

# Create test network
docker network create "$NETWORK"

# Start two containers
echo "Starting container A..."
docker run -d --name "$NAME_A" --network "$NETWORK" --cap-add NET_ADMIN sztauer

echo "Starting container B..."
docker run -d --name "$NAME_B" --network "$NETWORK" --cap-add NET_ADMIN sztauer

# Wait for both to be healthy
echo "Waiting for containers to be healthy..."
for i in $(seq 1 60); do
    SA=$(docker inspect --format='{{.State.Health.Status}}' "$NAME_A" 2>/dev/null || echo "unknown")
    SB=$(docker inspect --format='{{.State.Health.Status}}' "$NAME_B" 2>/dev/null || echo "unknown")
    if [ "$SA" = "healthy" ] && [ "$SB" = "healthy" ]; then
        echo "Both containers healthy after ${i}s"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "FAIL: Containers not healthy after 60s (A=$SA, B=$SB)"
        docker logs "$NAME_A"
        docker logs "$NAME_B"
        exit 1
    fi
    sleep 1
done

# A → B communication
echo "Testing A → B communication..."
docker exec "$NAME_A" curl -sf "http://${NAME_B}:420" > /dev/null
echo "OK: A can reach B"

# B → A communication
echo "Testing B → A communication..."
docker exec "$NAME_B" curl -sf "http://${NAME_A}:420" > /dev/null
echo "OK: B can reach A"

echo "=== All network tests passed ==="
