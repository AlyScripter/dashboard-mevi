#!/bin/bash
# Stop MEVI Rosbag Playback containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Stopping rosbag playback containers..."
docker-compose -f "$SCRIPT_DIR/docker-compose.rosbag.yml" down

echo "Done."
