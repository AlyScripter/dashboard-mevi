#!/bin/bash
# ============================================================
# Start MEVI Navigation from Laptop (Docker)
# ============================================================
# Hardware:
#   GPS, LIDAR: WiFi (192.168.1.106, 192.168.1.10)
#   IMU, Steering, Traction: USB
#   Camera: USB Webcam
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  MEVI Dashboard - Laptop Navigation Mode"
echo "=============================================="

# ============================================================
# Check Docker
# ============================================================
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# ============================================================
# Check USB Devices
# ============================================================
echo ""
echo "Checking USB devices..."

# IMU
if [ -e /dev/ttyUSB0 ]; then
    echo -e "  ${GREEN}✓${NC} IMU: /dev/ttyUSB0"
else
    echo -e "  ${YELLOW}⚠${NC} IMU: /dev/ttyUSB0 not found"
fi

# Steering Arduino
if [ -e /dev/ttyACM0 ]; then
    echo -e "  ${GREEN}✓${NC} Steering: /dev/ttyACM0"
else
    echo -e "  ${YELLOW}⚠${NC} Steering: /dev/ttyACM0 not found"
fi

# Traction Arduino
if [ -e /dev/ttyACM1 ]; then
    echo -e "  ${GREEN}✓${NC} Traction: /dev/ttyACM1"
else
    echo -e "  ${YELLOW}⚠${NC} Traction: /dev/ttyACM1 not found"
fi

# Camera
if [ -e /dev/video0 ]; then
    echo -e "  ${GREEN}✓${NC} Camera: /dev/video0"
else
    echo -e "  ${YELLOW}⚠${NC} Camera: /dev/video0 not found"
fi

# ============================================================
# Check Network Connectivity
# ============================================================
echo ""
echo "Checking network connectivity..."

GPS_IP="192.168.1.106"
LIDAR_IP="192.168.1.10"

if ping -c 1 -W 2 $GPS_IP &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} GPS: $GPS_IP reachable"
else
    echo -e "  ${YELLOW}⚠${NC} GPS: $GPS_IP not reachable"
fi

if ping -c 1 -W 2 $LIDAR_IP &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} LIDAR: $LIDAR_IP reachable"
else
    echo -e "  ${YELLOW}⚠${NC} LIDAR: $LIDAR_IP not reachable"
fi

# ============================================================
# Stop existing containers
# ============================================================
echo ""
echo "Stopping existing containers..."
docker stop mevi-navigation mevi-camera 2>/dev/null || true
docker rm mevi-navigation mevi-camera 2>/dev/null || true

# ============================================================
# Start Docker Containers
# ============================================================
echo ""
echo "Starting Docker containers..."
docker compose -f "$SCRIPT_DIR/docker-compose.laptop.yml" up -d

echo ""
echo "Waiting for services to start..."
sleep 3

# ============================================================
# Status
# ============================================================
echo ""
echo "Container Status:"
docker compose -f "$SCRIPT_DIR/docker-compose.laptop.yml" ps

echo ""
echo "=============================================="
echo "  MEVI Laptop Navigation is starting!"
echo "=============================================="
echo ""
echo "  Dashboard WebSocket: ws://localhost:9090"
echo "  Camera Stream:       http://localhost:8080/video_feed"
echo ""
echo "  View logs:"
echo "    docker logs -f mevi-navigation"
echo "    docker logs -f mevi-camera"
echo ""
echo "  Stop all:"
echo "    $SCRIPT_DIR/stop_laptop.sh"
echo "=============================================="
