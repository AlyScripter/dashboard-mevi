#!/bin/bash
# Start MEVI Navigation (Live Mode)
# For use with real vehicle hardware

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "  MEVI Dashboard - Live Navigation Mode"
echo "=============================================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Start containers
echo "Starting ROS navigation containers..."
docker-compose -f "$SCRIPT_DIR/docker-compose.live.yml" up -d

echo ""
echo "Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "Container Status:"
docker-compose -f "$SCRIPT_DIR/docker-compose.live.yml" ps

echo ""
echo "=============================================="
echo "  Navigation controller is running!"
echo "  Dashboard should connect to: ws://localhost:9090"
echo ""
echo "  To view logs:  docker logs -f mevi-navigation"
echo "  To stop:       $SCRIPT_DIR/stop_live.sh"
echo "=============================================="
