#!/bin/bash
# Start MEVI Dashboard with Rosbag Playback
# For testing with recorded sensor data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
export ROSBAG_FILE="${1:-cbf_velo_yaw_cte_merged.bag}"
export LOOP="${LOOP:-true}"
export RATE="${RATE:-1.0}"

echo "=============================================="
echo "  MEVI Dashboard - Rosbag Playback Mode"
echo "=============================================="
echo "  File: $ROSBAG_FILE"
echo "  Loop: $LOOP"
echo "  Rate: ${RATE}x"
echo "=============================================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Check rosbag file exists
if [ ! -f "$SCRIPT_DIR/rosbags/$ROSBAG_FILE" ]; then
    echo "Error: Rosbag file not found: $ROSBAG_FILE"
    echo ""
    echo "Available rosbags:"
    ls -la "$SCRIPT_DIR/rosbags/"*.bag 2>/dev/null || echo "  No .bag files found"
    exit 1
fi

# Start containers
echo ""
echo "Starting ROS containers with rosbag playback..."
docker-compose -f "$SCRIPT_DIR/docker-compose.rosbag.yml" up -d

echo ""
echo "Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "Container Status:"
docker-compose -f "$SCRIPT_DIR/docker-compose.rosbag.yml" ps

echo ""
echo "=============================================="
echo "  Rosbag playback is running!"
echo "  Dashboard should connect to: ws://localhost:9090"
echo ""
echo "  To view logs:  docker logs -f mevi-rosbag-player"
echo "  To stop:       $SCRIPT_DIR/stop_rosbag.sh"
echo "=============================================="
