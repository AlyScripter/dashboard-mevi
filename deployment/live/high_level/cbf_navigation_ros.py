#!/usr/bin/env python3
"""
CBF Navigation with ROS-based Waypoint Reception
================================================
This script receives waypoints directly from the Flutter dashboard via ROS topics,
eliminating the need for Firebase. The dashboard sends trip data including waypoints
through rosbridge_websocket.

Topics subscribed:
- /waypoints_array: Receives waypoint array from dashboard
- /trip_data: Receives complete trip information
- /destination_coordinate: Receives destination coordinates
- /navigation_command: Receives start/stop/pause commands

Author: Davin Fausta
Date: December 2025
"""

import numpy as np
import json
import time
import math
import rospy
from std_msgs.msg import Float32, Float64, String
import pyproj
import socket
from collections import deque

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

# Initial GPS coordinates for heading calculation
wplatprev, wplonprev = -6.882589416203811, 107.61072999959  # Previous waypoint coordinates
wp_lat_tgt, wp_lon_tgt = -6.882589416203811, 107.61072999959  # Final target waypoint
wp_lat, wp_lon, wp_alt = -6.881267393366145, 107.6112387443466, 800.8  # Next target waypoint
lat, lon = -6.882648, 107.610730  # Actual GPS position from Emlid
prev_lon, prev_lat = 107.610738, -6.882653  # Previous GPS position

imuz = -20  # Actual IMU yaw value (degrees)
v = 0.0  # Actual velocity (m/s) - published to /linear topic
v_desired = 1.4  # Desired velocity (m/s) ≈ 5 km/h max
alpha_obs = 0.0  # Obstacle detection angle from LiDAR (degrees)
cte = 0.0  # Cross-track error (meters)
k_cte = 0.5  # Gain for cross-track error correction
k_heading = 0.3  # Gain for heading error correction

current_timestamp = 0  # Initial timestamp
t_akt = current_timestamp  # Actual timestamp
t_previous = 0  # Previous timestamp
d_time = 0  # Delta time (seconds)

obstacle_distance = float('inf')
obstacle_position = "none"

# Constants for navigation control
GOAL_THRESHOLD = 0.5  # Threshold distance to goal (meters)
WAYPOINT_THRESHOLD = 1.5  # Threshold for waypoint selection
L = 1.150  # Wheelbase (distance between front and rear wheels, meters)
LOOKAHEAD_DISTANCE = 3.5  # Default lookahead distance (meters)

# Smoothing parameters for steering
STEERING_HISTORY_SIZE = 4  # Number of previous steering values to smooth
steering_history = deque(maxlen=STEERING_HISTORY_SIZE)
for _ in range(STEERING_HISTORY_SIZE):
    steering_history.append(0.0)  # Initialize steering history with zeros

# CBF (Control Barrier Function) parameters
CBF_ZONE_1 = 0.5  # Light correction zone 
CBF_ZONE_2 = 0.3  # Medium correction zone 
CBF_ZONE_3 = 0.01  # Strong correction zone 
CBF_CORRECTION_1 = 3.0  # Light correction angle
CBF_CORRECTION_2 = 5.0  # Medium correction angle
CBF_CORRECTION_3 = 7.0  # Strong correction angle

# CBF state tracking
cbf_active = False  # Flag to indicate if CBF is active
cbf_override_time = 0.0  # Time when CBF correction was last activated
CBF_OVERRIDE_DURATION = 0.5  # Duration to maintain CBF correction (seconds)

# Global variables for steering and waypoint data
stir = 0  # GPS-based steering angle
stir2 = 0  # Final steering angle after corrections
dataarr = [[0, 0]]  # Initial waypoint array
dataarray = np.array(dataarr)  # Converted to numpy array

# Previous GPS heading for smoothing
prev_gps_heading = 0.0

# Navigation state
navigation_active = False
current_trip_name = ""
destination_reached = False

# ============================================================================
# ROS PUBLISHERS
# ============================================================================

pubv = None
pubs = None
pubs_imu = None
pubs_gps = None
pub_debug = None
pub_cte = None
pub_wp_index = None
pub_dist_to_nearest = None
pub_dist_to_next = None
pub_dist_nearest_to_next = None
pub_cbf_value = None
pub_boundary_dist = None
pub_cbf_correction = None
pub_cbf_active = None
pub_heading_error = None
pub_total_error = None
pub_obstacle_distance = None
pub_obstacle_position = None
pub_navigation_status = None
pub_trip_status = None

# ============================================================================
# BOUNDARY WAYPOINTS (CBF Safety)
# ============================================================================

left_boundary = []
right_boundary = []

def load_boundary_waypoints():
    """Load boundary waypoints from KML data for CBF safety"""
    global left_boundary, right_boundary
    
    # Left boundary (jalur 2)
    left_boundary = [
        (107.6107129616743, -6.882591652658984),
        (107.6107204330896, -6.882522549201348),
        (107.610723140925, -6.882449955169578),
        (107.6107399707348, -6.882402343644882),
        (107.610777569654, -6.882375140624378),
        (107.6108505798013, -6.882378381114544),
        (107.6109239580778, -6.882390321094094),
        (107.6110165289676, -6.88240110417109),
        (107.611050832596, -6.882379613476812),
        (107.6110684468284, -6.882338731511386),
        (107.611080631921, -6.882222449215492),
        (107.6110963099444, -6.882087062158672),
        (107.6111147507018, -6.881925145634463),
        (107.6111316094122, -6.881780732893986),
        (107.6111448104185, -6.8816642205398),
        (107.6111552092677, -6.8815529542035),
        (107.6111737414936, -6.881437705054586),
        (107.6111846246042, -6.881304356507288),
        (107.611210466972, -6.881257459213753),
        (107.6112655144907, -6.881242333618232),
        (107.6113792853656, -6.881253231838254),
        (107.6114821130195, -6.881263982296313),
        (107.6116178384106, -6.881278039099625),
        (107.6117266029804, -6.88128862649753),
        (107.6117677655074, -6.881317042536544),
        (107.6117780464344, -6.881352540809383),
        (107.6117671349861, -6.881454783259355),
        (107.6117557675665, -6.881586224584821),
        (107.6117380952449, -6.881737706803546),
        (107.6117228249907, -6.881913778267694),
        (107.6117018211307, -6.882091239810402),
        (107.6116818224464, -6.882285632425517),
        (107.6116579328552, -6.882479760552022),
        (107.611635324994, -6.882668987736431),
        (107.6116061741796, -6.882725875547514),
        (107.6115570687966, -6.882761341448637),
        (107.6113995901822, -6.882756658431421),
        (107.6112394103947, -6.882744766879916)
    ]
    
    # Right boundary (jalur 3)
    right_boundary = [
        (107.6107688182654, -6.882597827812305),
        (107.610775292298, -6.882528086568257),
        (107.6107812741275, -6.882466966763361),
        (107.6107871962255, -6.88244138957796),
        (107.6108082834761, -6.882427988019779),
        (107.610849601609, -6.88242985080984),
        (107.6109267415374, -6.882438375182273),
        (107.6110340225347, -6.882444242935097),
        (107.6110827540581, -6.882421493422925),
        (107.611109300782, -6.882374312776215),
        (107.6111280727393, -6.882228636223775),
        (107.6111451081956, -6.882088962515986),
        (107.6111603858009, -6.881932822485969),
        (107.6111781883465, -6.881785583168773),
        (107.6111904534365, -6.881673619404818),
        (107.6112022771622, -6.881557965101541),
        (107.6112119177158, -6.881440947409624),
        (107.6112250066051, -6.881323911894127),
        (107.6112374664557, -6.881298634265342),
        (107.611265905786, -6.881293672102396),
        (107.6113589905677, -6.881298882835742),
        (107.6114653065174, -6.881306680719275),
        (107.61161749908, -6.881320913919234),
        (107.6117062405625, -6.881331139664565),
        (107.6117236816651, -6.881345939359957),
        (107.6117297723495, -6.881370926777683),
        (107.6117175790554, -6.881470018725399),
        (107.6117064695152, -6.88158048296214),
        (107.6116902428761, -6.881743492970628),
        (107.6116730371215, -6.881910282932123),
        (107.6116552280358, -6.882092038439017),
        (107.6116324282026, -6.882280312966837),
        (107.6116084909667, -6.88247167376973),
        (107.6115887034889, -6.882631404167279),
        (107.6115617638469, -6.882683279788306),
        (107.611516663565, -6.882710446364896),
        (107.6113781785224, -6.882701212164002),
        (107.6112431702158, -6.882688710973481)
    ]
    rospy.loginfo("✅ CBF Boundary waypoints loaded")

# ============================================================================
# WAYPOINT RECEPTION FROM DASHBOARD (No Firebase)
# ============================================================================

def callback_waypoints_array(msg):
    """
    Receive waypoints array from Flutter dashboard via ROS
    Message format: JSON string with waypoints array
    
    IMPORTANT: This function finds the nearest waypoint that is AHEAD of the car
    (not behind) based on the car's current heading from IMU.
    """
    global dataarray, navigation_active, current_trip_name, lat, lon, imuz
    
    try:
        data = json.loads(msg.data)
        waypoints = data.get('waypoints', [])
        total_count = data.get('total_count', 0)
        
        if not waypoints:
            rospy.logwarn("⚠️ Received empty waypoints array")
            return
        
        # Convert waypoints to numpy array [[lon, lat], ...]
        wp_list = []
        for wp in waypoints:
            lat_val = wp.get('latitude', 0.0)
            lon_val = wp.get('longitude', 0.0)
            wp_list.append([lon_val, lat_val])
        
        full_waypoints = np.array(wp_list)
        
        # Get current heading from IMU
        current_heading = imuz  # IMU yaw in degrees
        
        # Find the nearest waypoint that is AHEAD of the car (within ±90° of heading)
        best_idx = 0
        min_dist = float('inf')
        
        for i, wp in enumerate(full_waypoints):
            wp_lon, wp_lat = wp[0], wp[1]
            
            # Calculate azimuth from current position to waypoint
            azimuth, _, dist = geodesic(wp_lon, wp_lat, lon, lat)
            
            # Calculate heading difference
            heading_diff = azimuth - current_heading
            
            # Normalize to [-180, 180]
            if heading_diff > 180:
                heading_diff -= 360
            elif heading_diff < -180:
                heading_diff += 360
            
            # Only consider waypoints that are roughly ahead (within ±90° of heading)
            # This prevents selecting waypoints behind the car
            is_ahead = abs(heading_diff) < 90
            
            # For waypoints ahead, find the nearest one
            if is_ahead and dist < min_dist:
                min_dist = dist
                best_idx = i
        
        # If no waypoint found ahead, fallback to nearest overall
        if min_dist == float('inf'):
            rospy.logwarn("⚠️ No waypoint ahead found, using nearest overall")
            for i, wp in enumerate(full_waypoints):
                wp_lon, wp_lat = wp[0], wp[1]
                _, _, dist = geodesic(wp_lon, wp_lat, lon, lat)
                if dist < min_dist:
                    min_dist = dist
                    best_idx = i
        
        # If we're very close to the waypoint (< 5m), move to the next one
        if min_dist < 5.0 and best_idx < len(full_waypoints) - 1:
            start_idx = best_idx + 1
        else:
            start_idx = best_idx
        
        dataarray = full_waypoints[start_idx:]
        navigation_active = True
        
        rospy.loginfo(f"📍 Received {len(wp_list)} waypoints from dashboard")
        rospy.loginfo(f"📌 Current position: ({lat:.6f}, {lon:.6f})")
        rospy.loginfo(f"🧭 Current heading: {current_heading:.1f}°")
        rospy.loginfo(f"🎯 Best waypoint ahead: WP{best_idx + 1} (distance: {min_dist:.1f}m)")
        rospy.loginfo(f"🚗 Starting navigation from WP{start_idx + 1}")
        rospy.loginfo(f"🗺️  Remaining waypoints: {len(dataarray)}")
        rospy.loginfo(f"🏁 Destination: ({full_waypoints[-1][1]:.6f}, {full_waypoints[-1][0]:.6f})")
        
        # Publish status back to dashboard
        pub_trip_status.publish(f"waypoints_loaded:{len(dataarray)}")
        
    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse waypoints JSON: {e}")
    except Exception as e:
        rospy.logerr(f"❌ Error processing waypoints: {e}")

def callback_trip_data(msg):
    """
    Receive complete trip data from Flutter dashboard
    Message format: JSON string with trip information
    """
    global current_trip_name, navigation_active, wp_lat_tgt, wp_lon_tgt, dataarray
    
    try:
        data = json.loads(msg.data)
        
        mission_name = data.get('mission_name', 'Unknown')
        description = data.get('description', '')
        total_waypoints = data.get('total_waypoints', 0)
        waypoints = data.get('waypoints', [])
        
        current_trip_name = mission_name
        
        rospy.loginfo("=" * 60)
        rospy.loginfo(f"🚗 TRIP RECEIVED FROM DASHBOARD")
        rospy.loginfo(f"   Mission: {mission_name}")
        rospy.loginfo(f"   Description: {description}")
        rospy.loginfo(f"   Total waypoints: {total_waypoints}")
        rospy.loginfo("=" * 60)
        
        # Convert waypoints to numpy array
        if waypoints:
            wp_list = []
            for wp in waypoints:
                lat_val = wp.get('latitude', 0.0)
                lon_val = wp.get('longitude', 0.0)
                wp_list.append([lon_val, lat_val])
            
            dataarray = np.array(wp_list)
            
            # Set final destination from last waypoint
            if len(wp_list) > 0:
                wp_lon_tgt = wp_list[-1][0]
                wp_lat_tgt = wp_list[-1][1]
                rospy.loginfo(f"🏁 Final destination set: ({wp_lat_tgt:.6f}, {wp_lon_tgt:.6f})")
            
            navigation_active = True
            pub_trip_status.publish(f"trip_started:{mission_name}")
        
    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse trip data JSON: {e}")
    except Exception as e:
        rospy.logerr(f"❌ Error processing trip data: {e}")

def callback_destination_coordinate(msg):
    """
    Receive destination coordinates from dashboard
    Message format: JSON string with x (longitude), y (latitude), z (altitude)
    """
    global wp_lat_tgt, wp_lon_tgt
    
    try:
        data = json.loads(msg.data)
        wp_lon_tgt = data.get('x', wp_lon_tgt)
        wp_lat_tgt = data.get('y', wp_lat_tgt)
        
        rospy.loginfo(f"📍 Destination received: ({wp_lat_tgt:.6f}, {wp_lon_tgt:.6f})")
        pub_trip_status.publish(f"destination_set:{wp_lat_tgt},{wp_lon_tgt}")
        
    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse destination JSON: {e}")
    except Exception as e:
        rospy.logerr(f"❌ Error processing destination: {e}")

def callback_navigation_command(msg):
    """
    Receive navigation commands from dashboard
    Commands: start, stop, pause, resume
    """
    global navigation_active, destination_reached
    
    command = msg.data.lower().strip()
    
    if command == "start":
        navigation_active = True
        destination_reached = False
        rospy.loginfo("▶️ Navigation STARTED")
        pub_trip_status.publish("navigation:started")
        
    elif command == "stop":
        navigation_active = False
        rospy.loginfo("⏹️ Navigation STOPPED")
        pub_trip_status.publish("navigation:stopped")
        
    elif command == "pause":
        navigation_active = False
        rospy.loginfo("⏸️ Navigation PAUSED")
        pub_trip_status.publish("navigation:paused")
        
    elif command == "resume":
        navigation_active = True
        rospy.loginfo("▶️ Navigation RESUMED")
        pub_trip_status.publish("navigation:resumed")
        
    else:
        rospy.logwarn(f"⚠️ Unknown navigation command: {command}")

# ============================================================================
# SENSOR CALLBACKS
# ============================================================================

def callbackimuz(dataimu):
    global imuz
    imuz = dataimu.data

def callbacklat(datalat):
    global lat
    lat = datalat.data

def callbacklon(datalon):
    global lon
    lon = datalon.data

def callbackwplon(datawplon):
    global wp_lon
    wp_lon = datawplon.data

def callbackwplat(datawplat):
    global wp_lat
    wp_lat = datawplat.data

def callbacklidar(datalidar):
    global alpha_obs
    alpha_obs = datalidar.data

def callback_obstacle_distance(data):
    global obstacle_distance
    obstacle_distance = data.data

def callback_obstacle_position(data):
    global obstacle_position
    obstacle_position = data.data

# ============================================================================
# VELOCITY PROFILE CONTROL
# ============================================================================

def calculate_velocity_profile(dist_to_target, dist_to_goal, curvature=0.0):
    """
    Calculate velocity based on distance to target, goal, and path curvature
    Same logic as cbf_navigation4.py for consistency with low-level controller
    
    Returns velocity in m/s (will be published to /linear topic)
    Conversion: 1 m/s = 3.6 km/h
    """
    # Base velocity limits in m/s
    # 5 km/h = 1.39 m/s, 1 km/h = 0.28 m/s
    v_max = 1.4   # Maximum velocity (~5 km/h)
    v_min = 0.3   # Minimum velocity (~1 km/h)
    
    # More aggressive speed reduction based on curvature
    curvature_factor = 1.0 / (1.0 + 8.0 * abs(curvature))
    
    # Reduce speed when approaching goal
    if dist_to_goal > 10.0:
        v = v_max
    elif dist_to_goal > 2.0:
        v = v_min + (dist_to_goal - 2.0) * 0.14  # Gradual increase
    elif dist_to_goal > 0.3:
        v = v_min
    else:
        v = 0.0
    
    # Apply curvature factor
    v = v * curvature_factor
    
    # Ensure velocity stays within bounds
    v = max(min(v, v_max), 0.0)
    
    return v

def calculate_path_curvature(dataarray, current_idx):
    """
    Calculate path curvature at current waypoint
    Returns curvature value (0 = straight, higher = sharper turn)
    """
    if len(dataarray) < 3 or current_idx < 1 or current_idx >= len(dataarray) - 1:
        return 0.0
    
    # Get three consecutive waypoints
    p1 = dataarray[current_idx - 1]
    p2 = dataarray[current_idx]
    p3 = dataarray[current_idx + 1]
    
    # Convert to local coordinates for curvature calculation
    x1, y1 = gps_to_local_coords(p1[0], p1[1], p2[0], p2[1])
    x2, y2 = 0.0, 0.0  # Reference point
    x3, y3 = gps_to_local_coords(p3[0], p3[1], p2[0], p2[1])
    
    # Calculate vectors
    v1 = np.array([x1 - x2, y1 - y2])
    v2 = np.array([x3 - x2, y3 - y2])
    
    # Calculate angle between vectors
    dot_product = np.dot(v1, v2)
    mag1 = np.linalg.norm(v1)
    mag2 = np.linalg.norm(v2)
    
    if mag1 == 0 or mag2 == 0:
        return 0.0
    
    cos_angle = dot_product / (mag1 * mag2)
    cos_angle = np.clip(cos_angle, -1.0, 1.0)
    angle = np.arccos(cos_angle)
    
    # Curvature is roughly inversely proportional to the angle
    # Straight path (180 degrees) = 0 curvature
    # Sharp turn (90 degrees) = high curvature
    curvature = abs(np.pi - angle) / np.pi
    
    return curvature

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def geodesic(lon2, lat2, lon1, lat1):
    """Calculate geodesic distance and azimuth between two GPS coordinates"""
    geod = pyproj.Geod(ellps='WGS84')
    fwd_azimuth, back_azimuth, distance = geod.inv(lon1, lat1, lon2, lat2)
    
    # Normalize azimuth to [-180, 180] range
    if fwd_azimuth > 180:
        fwd_azimuth -= 360
    elif fwd_azimuth < -180:
        fwd_azimuth += 360
        
    return fwd_azimuth, back_azimuth, distance

def gps_to_local_coords(lon_point, lat_point, ref_lon, ref_lat):
    """Convert GPS coordinates to local Cartesian coordinates"""
    geod = pyproj.Geod(ellps='WGS84')
    
    # Calculate x (east-west) distance
    _, _, x_dist = geod.inv(ref_lon, ref_lat, lon_point, ref_lat)
    if lon_point < ref_lon:
        x_dist = -x_dist
    
    # Calculate y (north-south) distance
    _, _, y_dist = geod.inv(ref_lon, ref_lat, ref_lon, lat_point)
    if lat_point < ref_lat:
        y_dist = -y_dist
    
    return x_dist, y_dist

def distance_point_to_line_segment(px, py, x1, y1, x2, y2):
    """Calculate perpendicular distance from point to line segment"""
    dx = x2 - x1
    dy = y2 - y1
    length_squared = dx * dx + dy * dy
    
    if length_squared == 0:
        return math.sqrt((px - x1) ** 2 + (py - y1) ** 2)
    
    t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / length_squared))
    proj_x = x1 + t * dx
    proj_y = y1 + t * dy
    
    return math.sqrt((px - proj_x) ** 2 + (py - proj_y) ** 2)

def calculate_cte(lon_curr, lat_curr, lon_prev, lat_prev, lon_next, lat_next):
    """Calculate cross-track error"""
    ref_lon, ref_lat = lon_curr, lat_curr
    
    x_curr, y_curr = 0, 0
    x_prev, y_prev = gps_to_local_coords(lon_prev, lat_prev, ref_lon, ref_lat)
    x_next, y_next = gps_to_local_coords(lon_next, lat_next, ref_lon, ref_lat)
    
    cte_val = distance_point_to_line_segment(x_curr, y_curr, x_prev, y_prev, x_next, y_next)
    
    # Determine sign of CTE
    path_vector_x = x_next - x_prev
    path_vector_y = y_next - y_prev
    to_vehicle_x = x_curr - x_prev
    to_vehicle_y = y_curr - y_prev
    
    cross_product = path_vector_x * to_vehicle_y - path_vector_y * to_vehicle_x
    
    if cross_product < 0:
        cte_val = -cte_val
    
    return cte_val

def smooth_steering(new_stir):
    """Apply smoothing to steering angle"""
    global steering_history
    steering_history.append(new_stir)
    weights = [0.1, 0.15, 0.25, 0.5]
    smoothed = sum(w * s for w, s in zip(weights, steering_history))
    return smoothed

def select_waypoint_pure_pursuit(dataarray, lat, lon, last_selected_idx=0):
    """Select waypoint using Pure Pursuit algorithm"""
    if len(dataarray) < 2:
        return 0, 0.0, 0.0, 0.0
    
    min_dist = float('inf')
    nearest_idx = 0
    
    # Find nearest waypoint
    for i, wp in enumerate(dataarray):
        wp_lon, wp_lat = wp[0], wp[1]
        _, _, dist = geodesic(wp_lon, wp_lat, lon, lat)
        if dist < min_dist:
            min_dist = dist
            nearest_idx = i
    
    dist_to_nearest = min_dist
    
    # Select next waypoint based on lookahead
    selected_idx = nearest_idx
    if nearest_idx < len(dataarray) - 1:
        next_wp = dataarray[nearest_idx + 1]
        _, _, dist_to_next = geodesic(next_wp[0], next_wp[1], lon, lat)
        
        if dist_to_nearest < WAYPOINT_THRESHOLD:
            selected_idx = nearest_idx + 1
    else:
        dist_to_next = dist_to_nearest
    
    # Distance between nearest and next waypoint
    if nearest_idx < len(dataarray) - 1:
        wp_nearest = dataarray[nearest_idx]
        wp_next = dataarray[nearest_idx + 1]
        _, _, dist_nearest_to_next = geodesic(wp_next[0], wp_next[1], wp_nearest[0], wp_nearest[1])
    else:
        dist_nearest_to_next = 0.0
    
    return selected_idx, dist_to_nearest, dist_to_next, dist_nearest_to_next

def find_closest_boundary_segment_distance(lon_point, lat_point, boundary_points):
    """Find closest distance to boundary"""
    if len(boundary_points) < 2:
        return float('inf')
    
    ref_lon, ref_lat = lon_point, lat_point
    px, py = 0, 0
    
    min_dist = float('inf')
    
    for i in range(len(boundary_points) - 1):
        x1, y1 = gps_to_local_coords(boundary_points[i][0], boundary_points[i][1], ref_lon, ref_lat)
        x2, y2 = gps_to_local_coords(boundary_points[i+1][0], boundary_points[i+1][1], ref_lon, ref_lat)
        
        dist = distance_point_to_line_segment(px, py, x1, y1, x2, y2)
        min_dist = min(min_dist, dist)
    
    return min_dist

def calculate_distance_to_boundaries(lon_point, lat_point, left_boundary, right_boundary):
    """Calculate distance to both boundaries"""
    left_dist = find_closest_boundary_segment_distance(lon_point, lat_point, left_boundary)
    right_dist = find_closest_boundary_segment_distance(lon_point, lat_point, right_boundary)
    return left_dist, right_dist

def calculate_cbf_correction(lon_point, lat_point, current_heading, left_boundary, right_boundary):
    """Calculate CBF steering correction"""
    global cbf_active, cbf_override_time
    
    left_dist, right_dist = calculate_distance_to_boundaries(lon_point, lat_point, left_boundary, right_boundary)
    min_boundary_dist = min(left_dist, right_dist)
    
    correction = 0.0
    
    if min_boundary_dist < CBF_ZONE_3:
        correction = CBF_CORRECTION_3
    elif min_boundary_dist < CBF_ZONE_2:
        correction = CBF_CORRECTION_2
    elif min_boundary_dist < CBF_ZONE_1:
        correction = CBF_CORRECTION_1
    
    # Apply correction direction
    if correction > 0:
        cbf_active = True
        cbf_override_time = time.time()
        
        if left_dist < right_dist:
            correction = correction  # Steer right (away from left boundary)
        else:
            correction = -correction  # Steer left (away from right boundary)
    else:
        if time.time() - cbf_override_time > CBF_OVERRIDE_DURATION:
            cbf_active = False
    
    return correction, min_boundary_dist

def print_waypoint_status(no, d_nearest, d_next, d_nearest_to_next, selected_wp):
    """Print waypoint status to console"""
    rospy.loginfo(f"WP Status: nearest={no}, selected={selected_wp}, "
                  f"dist_nearest={d_nearest:.2f}m, dist_next={d_next:.2f}m")

def print_navigation_status(current_yaw, gps_heading, f_az, dist_target, dist_goal, v, stir, stir2, 
                            cte_val, cbf_correction, boundary_dist, control_mode, heading_error, 
                            total_error, obs_dist, obs_pos):
    """Print navigation status to console"""
    status = f"NAV: yaw={current_yaw:.1f}° heading={gps_heading:.1f}° steer={stir2:.1f}° " \
             f"cte={cte_val:.2f}m cbf={cbf_correction:.1f}° dist={dist_goal:.1f}m"
    rospy.loginfo(status)

# ============================================================================
# MAIN NAVIGATION LOOP
# ============================================================================

last_selected_waypoint = 0

def main(event):
    global lat, lon, imuz, v, dataarray, stir, stir2, cte, alpha_obs
    global last_selected_waypoint, wp_lat, wp_lon, prev_gps_heading
    global cbf_active, cbf_override_time, wplatprev, wplonprev
    global navigation_active, destination_reached, obstacle_distance, obstacle_position
    
    # Skip if navigation is not active or no waypoints loaded
    if not navigation_active or len(dataarray) < 2:
        return
    
    # Check if destination reached
    _, _, dist_to_goal = geodesic(wp_lon_tgt, wp_lat_tgt, lon, lat)
    if dist_to_goal < GOAL_THRESHOLD:
        if not destination_reached:
            destination_reached = True
            rospy.loginfo("🏁 DESTINATION REACHED!")
            pub_trip_status.publish(f"destination_reached:{current_trip_name}")
        return
    
    # Select waypoint using Pure Pursuit
    selected_wp_idx, dist_to_nearest, dist_to_next, dist_nearest_to_next = \
        select_waypoint_pure_pursuit(dataarray, lat, lon, last_selected_waypoint)
    last_selected_waypoint = selected_wp_idx
    
    nearest_wp_idx = max(0, selected_wp_idx - 1) if selected_wp_idx > 0 else 0
    
    # Get target waypoint coordinates
    wp_lon = dataarray[selected_wp_idx][0]
    wp_lat = dataarray[selected_wp_idx][1]
    
    # Get previous waypoint for CTE calculation
    if selected_wp_idx > 0:
        wplonprev = dataarray[selected_wp_idx - 1][0]
        wplatprev = dataarray[selected_wp_idx - 1][1]
    
    # Calculate CTE
    cte = calculate_cte(lon, lat, wplonprev, wplatprev, wp_lon, wp_lat)
    
    # Calculate steering based on GPS heading
    f_az, _, d = geodesic(wp_lon, wp_lat, lon, lat)
    f_az_np, _, d2 = geodesic(wp_lon_tgt, wp_lat_tgt, lon, lat)
    
    current_yaw = imuz
    
    # Calculate GPS-based steering
    stir = f_az - current_yaw
    if stir > 180:
        stir -= 360
    elif stir < -180:
        stir += 360
    
    # Apply CTE correction
    stir_cte = stir + k_cte * cte
    
    # Calculate CBF correction
    cbf_correction, boundary_dist = calculate_cbf_correction(lon, lat, current_yaw, left_boundary, right_boundary)
    
    # Calculate path curvature for velocity profile
    path_curvature = calculate_path_curvature(dataarray, selected_wp_idx)
    
    # Calculate target velocity based on distance and curvature
    v_target = calculate_velocity_profile(d, d2, path_curvature)
    
    # ========================================================================
    # CONTROL PRIORITY SYSTEM (Same as cbf_navigation4.py)
    # Priority 1: Lidar obstacle avoidance
    # Priority 2: CBF boundary safety
    # Priority 3: Waypoint navigation
    # ========================================================================
    
    if alpha_obs != 0.0:
        # Priority 1: Lidar obstacle detected
        # Velocity values in m/s (1 m/s ≈ 3.6 km/h)
        if obstacle_position == "front" and obstacle_distance < 0.5:
            stir2 = alpha_obs
            v = 0.0           # STOP
            control_mode = "LIDAR_FRONT_STOP"
        elif obstacle_position == "front" and obstacle_distance < 3.0:
            stir2 = alpha_obs
            v = 0.6           # ~2 km/h
            control_mode = "LIDAR_FRONT"
        elif obstacle_position in ["left", "right"] and obstacle_distance < 1.5:
            stir2 = alpha_obs
            v = 0.6           # ~2 km/h
            control_mode = f"LIDAR_{obstacle_position.upper()}_CLOSE"
        elif obstacle_position in ["left", "right"] and obstacle_distance < 3.0:
            stir2 = alpha_obs
            v = 0.8           # ~3 km/h
            control_mode = f"LIDAR_{obstacle_position.upper()}"
        else:
            stir2 = alpha_obs
            v = 1.4           # ~5 km/h (max)
            control_mode = "LIDAR_FAR"
            
    elif cbf_active:
        # Priority 2: CBF boundary safety
        waypoint_influence = max(0.1, min(0.3, boundary_dist / CBF_ZONE_1))
        stir2 = cbf_correction + (waypoint_influence * stir_cte)
        v = v_target * max(0.4, boundary_dist / CBF_ZONE_1)
        control_mode = "CBF_ACTIVE"
        
    else:
        # Priority 3: Normal waypoint navigation
        stir2 = stir_cte
        v = v_target
        control_mode = "WAYPOINT"
    
    # Apply steering limits
    stir2 = max(min(stir2, 15.0), -15.0)
    
    # Smooth steering
    stir2 = smooth_steering(stir2)
    
    # Stop when reached final goal
    if d2 < GOAL_THRESHOLD:
        v = 0.0
        stir2 = 0.0
        control_mode = "GOAL_REACHED"
        destination_reached = True
        rospy.loginfo("🏁 DESTINATION REACHED - Stopping vehicle!")
        pub_trip_status.publish(f"destination_reached:{current_trip_name}")
    
    # Calculate heading error
    heading_error = f_az - current_yaw
    if heading_error > 180:
        heading_error -= 360
    elif heading_error < -180:
        heading_error += 360
    
    # Calculate total error
    normalized_heading_error = (abs(heading_error) / 180) * LOOKAHEAD_DISTANCE
    total_error = k_heading * normalized_heading_error + k_cte * abs(cte)
    
    # Print status
    print_waypoint_status(nearest_wp_idx, dist_to_nearest, dist_to_next, dist_nearest_to_next, selected_wp_idx)
    print_navigation_status(current_yaw, f_az_np, f_az, d, d2, v, stir, stir2, cte, 
                           cbf_correction, boundary_dist, control_mode, heading_error, 
                           total_error, obstacle_distance, obstacle_position)
    
    # Publish to ROS topics
    pubv.publish(Float32(v))
    pubs.publish(Float32(stir2))
    pubs_imu.publish(Float32(current_yaw))
    pubs_gps.publish(Float32(stir))
    pub_debug.publish(Float32(d2))
    pub_cte.publish(Float32(cte))
    pub_wp_index.publish(Float32(selected_wp_idx))
    pub_dist_to_nearest.publish(Float32(dist_to_nearest))
    pub_dist_to_next.publish(Float32(dist_to_next))
    pub_dist_nearest_to_next.publish(Float32(dist_nearest_to_next))
    pub_boundary_dist.publish(Float32(boundary_dist))
    pub_cbf_correction.publish(Float32(cbf_correction))
    pub_cbf_active.publish(Float32(1.0 if cbf_active else 0.0))
    pub_heading_error.publish(Float32(heading_error))
    pub_total_error.publish(Float32(total_error))
    pub_obstacle_distance.publish(Float32(obstacle_distance))
    pub_obstacle_position.publish(obstacle_position)
    
    # Publish navigation status for dashboard
    nav_status = json.dumps({
        'active': navigation_active,
        'trip_name': current_trip_name,
        'current_wp': selected_wp_idx,
        'total_wp': len(dataarray),
        'dist_to_goal': d2,
        'cte': cte,
        'steering': stir2,
        'control_mode': control_mode,
        'cbf_active': cbf_active
    })
    pub_navigation_status.publish(nav_status)

# ============================================================================
# ROS NODE INITIALIZATION
# ============================================================================

def init_publishers():
    """Initialize all ROS publishers"""
    global pubv, pubs, pubs_imu, pubs_gps, pub_debug, pub_cte
    global pub_wp_index, pub_dist_to_nearest, pub_dist_to_next, pub_dist_nearest_to_next
    global pub_cbf_value, pub_boundary_dist, pub_cbf_correction, pub_cbf_active
    global pub_heading_error, pub_total_error, pub_obstacle_distance, pub_obstacle_position
    global pub_navigation_status, pub_trip_status
    
    pubv = rospy.Publisher('/linear', Float32, queue_size=10)
    pubs = rospy.Publisher('/steering_angle', Float32, queue_size=10)
    pubs_imu = rospy.Publisher('/yaw_imu', Float32, queue_size=10)
    pubs_gps = rospy.Publisher('/yaw_gps', Float32, queue_size=10)
    pub_debug = rospy.Publisher('/debug', Float32, queue_size=10)
    pub_cte = rospy.Publisher('/cte', Float32, queue_size=10)
    pub_wp_index = rospy.Publisher('/wp_index', Float32, queue_size=10)
    pub_dist_to_nearest = rospy.Publisher('/dist_to_nearest', Float32, queue_size=10)
    pub_dist_to_next = rospy.Publisher('/dist_to_next', Float32, queue_size=10)
    pub_dist_nearest_to_next = rospy.Publisher('/dist_nearest_to_next', Float32, queue_size=10)
    pub_cbf_value = rospy.Publisher('/cbf_value', Float32, queue_size=10)
    pub_boundary_dist = rospy.Publisher('/boundary_dist', Float32, queue_size=10)
    pub_cbf_correction = rospy.Publisher('/cbf_correction', Float32, queue_size=10)
    pub_cbf_active = rospy.Publisher('/cbf_active', Float32, queue_size=10)
    pub_heading_error = rospy.Publisher('/heading_error', Float32, queue_size=10)
    pub_total_error = rospy.Publisher('/total_error', Float32, queue_size=10)
    pub_obstacle_distance = rospy.Publisher('/obstacle_distance', Float32, queue_size=10)
    pub_obstacle_position = rospy.Publisher('/obstacle_position', String, queue_size=10)
    
    # New publishers for dashboard communication
    pub_navigation_status = rospy.Publisher('/navigation_status', String, queue_size=10)
    pub_trip_status = rospy.Publisher('/trip_status', String, queue_size=10)

def talker():
    """Main ROS node function"""
    rospy.init_node('cbf_navigation_ros', anonymous=True)
    
    # Initialize publishers
    init_publishers()
    
    # Subscribe to sensor topics
    rospy.Subscriber("/latitude", Float64, callbacklat)
    rospy.Subscriber("/longitude", Float64, callbacklon)
    rospy.Subscriber("/0dataz", Float32, callbackimuz)
    rospy.Subscriber("/tar_lat", Float32, callbackwplat)
    rospy.Subscriber("/tar_long", Float32, callbackwplon)
    rospy.Subscriber("/lidar", Float32, callbacklidar)
    rospy.Subscriber("/obstacle_distance", Float32, callback_obstacle_distance)
    rospy.Subscriber("/obstacle_position", String, callback_obstacle_position)
    
    # Subscribe to dashboard topics (NEW - No Firebase needed!)
    rospy.Subscriber("/waypoints_array", String, callback_waypoints_array)
    rospy.Subscriber("/trip_data", String, callback_trip_data)
    rospy.Subscriber("/destination_coordinate", String, callback_destination_coordinate)
    rospy.Subscriber("/navigation_command", String, callback_navigation_command)
    
    rospy.loginfo("=" * 60)
    rospy.loginfo("🚗 CBF NAVIGATION (ROS-BASED) STARTED")
    rospy.loginfo("   Waiting for waypoints from dashboard...")
    rospy.loginfo("   No Firebase required!")
    rospy.loginfo("=" * 60)
    
    # Main navigation loop at 2Hz
    rospy.Timer(rospy.Duration(0.5), main)
    rospy.spin()

if __name__ == '__main__':
    load_boundary_waypoints()
    try:
        talker()
    except rospy.ROSInterruptException:
        rospy.logerr("ROS interrupted")
    except Exception as e:
        rospy.logerr(f"Unexpected error: {e}")
