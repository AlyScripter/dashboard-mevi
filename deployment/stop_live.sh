#!/bin/bash
# Stop MEVI Live Navigation containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Stopping live navigation containers..."
docker-compose -f "$SCRIPT_DIR/docker-compose.live.yml" down

echo "Done."
