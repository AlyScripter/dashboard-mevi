# MEVI Deployment

Docker and scripts for running the MEVI autonomous vehicle system.

## Quick Start

```bash
# Testing with recorded data
./start_rosbag.sh

# Live vehicle navigation
./start_live.sh
```

Dashboard connection: `ws://localhost:9090`

---

## Folder Structure

```
deployment/
├── live/           # Vehicle navigation code
├── rosbags/        # Recorded sensor data
├── camera/         # Camera streaming scripts
├── simulator/      # ROS simulator for testing
└── *.sh            # Startup scripts
```

---

## Modes

### 1. Rosbag Playback (Testing)

Plays recorded `.bag` files for dashboard development.

```bash
./start_rosbag.sh                         # Default: cbf_velo_yaw_cte_merged.bag
./start_rosbag.sh lidar_dashboard1.bag    # Specific file
RATE=2.0 ./start_rosbag.sh                # 2x speed
LOOP=false ./start_rosbag.sh              # Play once
./stop_rosbag.sh
```

### 2. Live Navigation (Vehicle)

Runs CBF navigation controller for real vehicle.

```bash
./start_live.sh
./stop_live.sh
```

---

## Components

### `live/` - Navigation Code

| Folder | Description |
|--------|-------------|
| `high_level/` | CBF navigation controller (Python) - calculates steering/velocity |
| `low_level/` | Arduino code for steering and traction motors |
| `launch/` | ROS launch files |

**CBF Navigation** (`high_level/cbf_navigation_ros.py`):
- Receives waypoints from dashboard via `/waypoints_array`
- Calculates steering angle using Control Barrier Function
- Publishes to `/steering_angle` and `/linear`

**Arduino Controllers** (`low_level/`):
- `steering/mpc_kalibrasi.ino` - MPC steering controller
- `traction/traction_control.ino` - Velocity PID controller

### `rosbags/` - Recorded Data

| File | Size | Contents |
|------|------|----------|
| `cbf_velo_yaw_cte_merged.bag` | 78MB | GPS, velocity, yaw, CTE |
| `lidar_dashboard1.bag` | 30MB | LIDAR data |
| `merged.bag` | 37MB | Combined sensors |

### `camera/` - Camera Streaming

| Script | Purpose |
|--------|---------|
| `zed_mjpeg_server.py` | ZED camera MJPEG stream |
| `usb_webcam_server.py` | USB webcam stream |

Run on vehicle:
```bash
python3 zed_mjpeg_server.py --port 8080
```

### `simulator/` - ROS Simulator

Python simulator for testing navigation without real vehicle.

```bash
python3 simulator/test.py
```

Simulates:
- GPS position updates
- Waypoint following
- Steering/velocity publishing

---

## Docker Commands

```bash
# View logs
docker logs -f mevi-rosbag-player
docker logs -f mevi-navigation
docker logs -f mevi-rosbridge

# List topics
docker exec -it mevi-ros-master bash -c "source /opt/ros/noetic/setup.bash && rostopic list"

# Echo topic
docker exec -it mevi-ros-master bash -c "source /opt/ros/noetic/setup.bash && rostopic echo /steering_angle"
```

---

## ROS Topics

### Subscribed by Navigation

| Topic | Type | Description |
|-------|------|-------------|
| `/latitude` | Float64 | GPS latitude |
| `/longitude` | Float64 | GPS longitude |
| `/0dataz` | Float32 | IMU yaw angle |
| `/waypoints_array` | String | Waypoints JSON from dashboard |
| `/navigation_command` | String | start/stop/pause commands |

### Published by Navigation

| Topic | Type | Description |
|-------|------|-------------|
| `/steering_angle` | Float32 | Steering command (degrees) |
| `/linear` | Float32 | Velocity command (m/s) |
| `/wp_index` | Float32 | Current waypoint index |
| `/navigation_status` | String | Status JSON for dashboard |
