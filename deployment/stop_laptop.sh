#!/bin/bash
# Stop MEVI Laptop Navigation containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Stopping MEVI Laptop Navigation containers..."
docker compose -f "$SCRIPT_DIR/docker-compose.laptop.yml" down

echo "Done!"
