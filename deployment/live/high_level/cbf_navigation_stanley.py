#!/usr/bin/env python
import json
import math
import time
import threading
from dataclasses import dataclass
from typing import Optional

import numpy as np
import rospy
import pyproj
from std_msgs.msg import Float32, Float64, String
from collections import deque
from scipy.interpolate import PchipInterpolator

# =============================================================================
# GLOBAL STATE (SENSORS / NAV)
# =============================================================================

# GPS / IMU state (updated from callbacks)
lat, lon = -6.882523, 107.610746
prev_lat, prev_lon = -6.882653, 107.610738
imuz = -20.0  # IMU yaw (deg)
velocity = 0.0  # measured velocity (m/s)
jarak = float("inf")  # front distance (m) from /front_distance

# Obstacle info
alpha_obs = 0.0  # avoidance steering from LiDAR (deg) (from upstream node)
obstacle_distance = float("inf")
obstacle_position = "none"  # "front" | "left" | "right" | "none"

# Navigation from dashboard
navigation_active = False
current_trip_name = ""
destination_reached = False
waypoints_loaded = False

# Target waypoint (updated on path regen)
wp_lat_tgt, wp_lon_tgt = -6.88246914, 107.6116346

# =============================================================================
# CONSTANTS / PARAMETERS
# =============================================================================

GOAL_THRESHOLD = 0.5  # meters
L = 1.150  # wheelbase (m)

# Steering smoothing
STEERING_HISTORY_SIZE = 4
steering_history = deque(maxlen=STEERING_HISTORY_SIZE)
for _ in range(STEERING_HISTORY_SIZE):
    steering_history.append(0.0)

# CBF parameters
CBF_ZONE_1 = 0.5
CBF_ZONE_2 = 0.3
CBF_ZONE_3 = 0.01
CBF_CORRECTION_1 = 3.0
CBF_CORRECTION_2 = 5.0
CBF_CORRECTION_3 = 7.0

cbf_active = False
cbf_override_time = 0.0
CBF_OVERRIDE_DURATION = 0.5

# Boundaries
left_boundary = []
right_boundary = []

# =============================================================================
# PATH DATA (THREAD-SAFE)
# =============================================================================

@dataclass
class PathData:
    dataarray: np.ndarray
    spline_x: PchipInterpolator
    spline_y: PchipInterpolator
    xs: np.ndarray
    ys: np.ndarray
    t_dense: np.ndarray
    arc_length: np.ndarray


path_lock = threading.Lock()
path_data: Optional[PathData] = None

# =============================================================================
# ROS PUBLISHERS (INITIALIZED AFTER init_node)
# =============================================================================

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
pub_obstacle_distance = None
pub_obstacle_position = None
pub_cte_term = None
pub_heading_term = None
pub_path_heading = None
pub_ff = None
pub_curvature = None

pub_navigation_status = None
pub_trip_status = None


def init_publishers():
    global pubv, pubs, pubs_imu, pubs_gps, pub_debug
    global pub_cte, pub_wp_index, pub_dist_to_nearest, pub_dist_to_next, pub_dist_nearest_to_next
    global pub_cbf_value, pub_boundary_dist, pub_cbf_correction, pub_cbf_active
    global pub_heading_error, pub_obstacle_distance, pub_obstacle_position
    global pub_cte_term, pub_heading_term, pub_path_heading, pub_ff, pub_curvature
    global pub_navigation_status, pub_trip_status

    pubv = rospy.Publisher("/linear", Float32, queue_size=10)
    pubs = rospy.Publisher("/steering_angle", Float32, queue_size=10)
    pubs_imu = rospy.Publisher("/yaw_imu", Float32, queue_size=10)
    pubs_gps = rospy.Publisher("/yaw_gps", Float32, queue_size=10)
    pub_debug = rospy.Publisher("/debug", Float32, queue_size=10)
    pub_cte = rospy.Publisher("/cte", Float32, queue_size=10)

    pub_wp_index = rospy.Publisher("/wp_index", Float32, queue_size=10)
    pub_dist_to_nearest = rospy.Publisher("/dist_to_nearest", Float32, queue_size=10)
    pub_dist_to_next = rospy.Publisher("/dist_to_next", Float32, queue_size=10)
    pub_dist_nearest_to_next = rospy.Publisher("/dist_nearest_to_next", Float32, queue_size=10)

    pub_cbf_value = rospy.Publisher("/cbf_value", Float32, queue_size=10)
    pub_boundary_dist = rospy.Publisher("/boundary_dist", Float32, queue_size=10)
    pub_cbf_correction = rospy.Publisher("/cbf_correction", Float32, queue_size=10)
    pub_cbf_active = rospy.Publisher("/cbf_active", Float32, queue_size=10)
    pub_heading_error = rospy.Publisher("/heading_error", Float32, queue_size=10)

    pub_obstacle_distance = rospy.Publisher("/obstacle_distance", Float32, queue_size=10)
    pub_obstacle_position = rospy.Publisher("/obstacle_position", String, queue_size=10)

    pub_cte_term = rospy.Publisher("/cte_term", Float32, queue_size=10)
    pub_heading_term = rospy.Publisher("/heading_term", Float32, queue_size=10)
    pub_path_heading = rospy.Publisher("/path_heading", Float32, queue_size=10)

    pub_ff = rospy.Publisher("/feedforward", Float32, queue_size=10)
    pub_curvature = rospy.Publisher("/curvature", Float32, queue_size=10)

    pub_navigation_status = rospy.Publisher("/navigation_status", String, queue_size=10)
    pub_trip_status = rospy.Publisher("/trip_status", String, queue_size=10)

# =============================================================================
# UTILITIES
# =============================================================================

def geodesic(lon2, lat2, lon1, lat1):
    g = pyproj.Geod(ellps="WGS84")
    fwd_azimuth, back_azimuth, distance = g.inv(lon1, lat1, lon2, lat2)
    if fwd_azimuth > 180:
        fwd_azimuth -= 360
    elif fwd_azimuth < -180:
        fwd_azimuth += 360
    return fwd_azimuth, back_azimuth, distance


def gps_to_local_coords(lon_, lat_, ref_lon, ref_lat):
    R = 6371000.0
    lat_rad = math.radians(lat_)
    lon_rad = math.radians(lon_)
    ref_lat_rad = math.radians(ref_lat)
    ref_lon_rad = math.radians(ref_lon)

    x = R * (lon_rad - ref_lon_rad) * math.cos(ref_lat_rad)
    y = R * (lat_rad - ref_lat_rad)
    return x, y


def smooth_steering(new_stir):
    """Weighted smoothing: newer samples get higher weight."""
    steering_history.append(float(new_stir))
    n = len(steering_history)
    if n == 0:
        return float(new_stir)

    raw = np.arange(1, n + 1, dtype=float)  # oldest..newest
    weights = raw / raw.sum()

    smoothed = 0.0
    for w, val in zip(weights, steering_history):
        smoothed += w * val
    return float(smoothed)

# =============================================================================
# BOUNDARY / CBF
# =============================================================================

def load_boundary_waypoints():
    global left_boundary, right_boundary

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
        (107.6112394103947, -6.882744766879916),
    ]

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
        (107.6112431702158, -6.882688710973481),
    ]


def distance_point_to_line_segment(px, py, x1, y1, x2, y2):
    A = px - x1
    B = py - y1
    C = x2 - x1
    D = y2 - y1

    dot = A * C + B * D
    len_sq = C * C + D * D
    if len_sq == 0:
        return math.sqrt(A * A + B * B)

    param = dot / len_sq
    if param < 0:
        xx, yy = x1, y1
    elif param > 1:
        xx, yy = x2, y2
    else:
        xx = x1 + param * C
        yy = y1 + param * D

    dx = px - xx
    dy = py - yy
    return math.sqrt(dx * dx + dy * dy)


def find_closest_boundary_segment_distance(lon_, lat_, boundary_points):
    if len(boundary_points) < 2:
        return float("inf"), 0

    ref_lon, ref_lat = boundary_points[0]
    px, py = gps_to_local_coords(lon_, lat_, ref_lon, ref_lat)

    min_distance = float("inf")
    closest_side = 0

    for i in range(len(boundary_points) - 1):
        lon1, lat1 = boundary_points[i]
        lon2, lat2 = boundary_points[i + 1]

        x1, y1 = gps_to_local_coords(lon1, lat1, ref_lon, ref_lat)
        x2, y2 = gps_to_local_coords(lon2, lat2, ref_lon, ref_lat)

        segment_dist = distance_point_to_line_segment(px, py, x1, y1, x2, y2)

        if segment_dist < min_distance:
            min_distance = segment_dist

            cross_product = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)
            if cross_product > 0:
                closest_side = 1
            elif cross_product < 0:
                closest_side = -1
            else:
                closest_side = 0

    return min_distance, closest_side


def calculate_distance_to_boundaries(lon_, lat_, left_b, right_b):
    left_dist, _ = find_closest_boundary_segment_distance(lon_, lat_, left_b)
    right_dist, _ = find_closest_boundary_segment_distance(lon_, lat_, right_b)

    if left_dist < right_dist:
        return left_dist, "left", 1     # closer to left -> steer right
    else:
        return right_dist, "right", -1  # closer to right -> steer left


def calculate_cbf_correction(lon_, lat_, current_heading, left_b, right_b):
    global cbf_active, cbf_override_time

    min_dist, _, correction_direction = calculate_distance_to_boundaries(lon_, lat_, left_b, right_b)

    current_time = time.time()
    cbf_correction = 0.0
    cbf_status = "SAFE"

    if min_dist <= CBF_ZONE_3:
        cbf_correction = correction_direction * CBF_CORRECTION_3
        cbf_status = "CRITICAL"
        cbf_active = True
        cbf_override_time = current_time

    elif min_dist <= CBF_ZONE_2:
        factor = (min_dist - CBF_ZONE_3) / (CBF_ZONE_2 - CBF_ZONE_3)
        cbf_correction = correction_direction * (CBF_CORRECTION_3 + factor * (CBF_CORRECTION_2 - CBF_CORRECTION_3))
        cbf_status = "WARNING"
        cbf_active = True
        cbf_override_time = current_time

    elif min_dist <= CBF_ZONE_1:
        factor = (min_dist - CBF_ZONE_2) / (CBF_ZONE_1 - CBF_ZONE_2)
        cbf_correction = correction_direction * (CBF_CORRECTION_2 + factor * (CBF_CORRECTION_1 - CBF_CORRECTION_2))
        cbf_status = "CAUTION"
        cbf_active = True
        cbf_override_time = current_time

    else:
        if cbf_active and (current_time - cbf_override_time) < CBF_OVERRIDE_DURATION:
            if min_dist <= CBF_ZONE_1 * 1.5:
                cbf_correction = correction_direction * (CBF_CORRECTION_1 * 0.5)
                cbf_status = "RECOVERY"
            else:
                cbf_active = False
                cbf_status = "SAFE"
        else:
            cbf_active = False
            cbf_status = "SAFE"

    return cbf_correction, min_dist, cbf_status

# =============================================================================
# PATH GENERATION (PCHIP - less overshoot)
# =============================================================================

def regenerate_spline(wp_array: np.ndarray) -> Optional[PathData]:
    """
    Build PCHIP spline + dense samples + arc length, then atomically swap into path_data.
    wp_array format: [[lon, lat], ...]
    """
    global wp_lat_tgt, wp_lon_tgt, waypoints_loaded, path_data

    if wp_array is None or len(wp_array) < 2:
        rospy.logwarn("⚠️ Need at least 2 waypoints for path generation")
        return None

    # Destination = last waypoint
    wp_lon_tgt = float(wp_array[-1, 0])
    wp_lat_tgt = float(wp_array[-1, 1])

    ref_lon, ref_lat = float(wp_array[0, 0]), float(wp_array[0, 1])

    # Convert to local coords (meters)
    xy = []
    for i in range(len(wp_array)):
        x, y = gps_to_local_coords(float(wp_array[i, 0]), float(wp_array[i, 1]), ref_lon, ref_lat)
        xy.append([x, y])
    xy = np.array(xy, dtype=float)

    # Drop near-duplicates to ensure strictly increasing parameter
    keep = [0]
    min_step = 0.05  # meters
    for i in range(1, len(xy)):
        if np.linalg.norm(xy[i] - xy[keep[-1]]) >= min_step:
            keep.append(i)

    if len(keep) < 2:
        rospy.logwarn("⚠️ Waypoints too close/duplicated; cannot build path")
        return None

    wp_array = wp_array[keep]
    xy = xy[keep]

    # Arc-length-like parameter t
    t = [0.0]
    for i in range(1, len(xy)):
        dist = float(np.linalg.norm(xy[i] - xy[i - 1]))
        t.append(t[-1] + dist)
    t = np.array(t, dtype=float)

    if t[-1] <= 0.0:
        rospy.logwarn("⚠️ Path length is zero; cannot build path")
        return None

    # PCHIP interpolators (less overshoot than CubicSpline)
    spline_x = PchipInterpolator(t, xy[:, 0])
    spline_y = PchipInterpolator(t, xy[:, 1])

    # Dense sampling: ~8 samples per meter, min 200
    n = max(200, int(t[-1] * 8))
    t_dense = np.linspace(t[0], t[-1], n)
    xs = spline_x(t_dense)
    ys = spline_y(t_dense)

    # Arc length along dense samples
    dist_dense = np.hypot(xs[1:] - xs[:-1], ys[1:] - ys[:-1])
    arc_length = np.concatenate(([0.0], np.cumsum(dist_dense)))

    new_path = PathData(
        dataarray=wp_array,
        spline_x=spline_x,
        spline_y=spline_y,
        xs=xs,
        ys=ys,
        t_dense=t_dense,
        arc_length=arc_length,
    )

    with path_lock:
        path_data = new_path

    waypoints_loaded = True
    rospy.loginfo(f"✅ Path regenerated with {len(wp_array)} waypoints (PCHIP)")
    rospy.loginfo(f"🏁 Destination: ({wp_lat_tgt:.6f}, {wp_lon_tgt:.6f})")
    return new_path


def load_default_waypoints():
    """
    Fallback path (loaded after init_node).
    NOTE: This is only used if dashboard hasn't sent new waypoints yet.
    """
    default_waypoints = np.array(
        [
            [107.61073832, -6.88248358],
            [107.61075495, -6.88243801],
            [107.61078367, -6.88241414],
            [107.61082751, -6.88240763],
            [107.61088042, -6.88240980],
            [107.61093484, -6.88241631],
            [107.61100136, -6.88242065],
            [107.61103915, -6.88241631],
            [107.61106636, -6.88239895],
            [107.61108450, -6.88237725],
            [107.61109509, -6.88235121],
            [107.61110265, -6.88229696],
            [107.61111172, -6.88220148],
            [107.61113137, -6.88200618],
            [107.61115404, -6.88180003],
            [107.61117521, -6.88160039],
            [107.61119788, -6.88140508],
            [107.61120695, -6.88133130],
            [107.61123870, -6.88127488],
            [107.61128556, -6.88126186],
            [107.61133243, -6.88126620],
            [107.61146546, -6.88128139],
            [107.61160152, -6.88129658],
            [107.61169676, -6.88130526],
            [107.61173908, -6.88133564],
            [107.61174816, -6.88137470],
            [107.61174664, -6.88142895],
            [107.61173606, -6.88149839],
            [107.61172699, -6.88156350],
            [107.61170129, -6.88180437],
            [107.61168164, -6.88200618],
            [107.61165896, -6.88220365],
            [107.61163629, -6.88240546],
        ],
        dtype=float,
    )

    regenerate_spline(default_waypoints)
    rospy.loginfo("📍 Default waypoints loaded (fallback, PCHIP). Waiting for dashboard...")

# =============================================================================
# DASHBOARD CALLBACKS
# =============================================================================

def callback_waypoints_array(msg):
    global navigation_active, destination_reached

    try:
        data = json.loads(msg.data)
        waypoints = data.get("waypoints", [])
        if not waypoints:
            rospy.logwarn("⚠️ Received empty waypoints array")
            return

        wp_list = []
        for wp in waypoints:
            lat_val = float(wp.get("latitude", 0.0))
            lon_val = float(wp.get("longitude", 0.0))
            wp_list.append([lon_val, lat_val])

        wp_array = np.array(wp_list, dtype=float)
        ok = regenerate_spline(wp_array)
        if ok is None:
            return

        navigation_active = True
        destination_reached = False

        rospy.loginfo(f"📍 Received {len(wp_list)} waypoints from dashboard")
        if pub_trip_status is not None:
            pub_trip_status.publish(f"waypoints_loaded:{len(wp_list)}")

    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse waypoints JSON: {e}")
    except Exception as e:
        rospy.logerr(f"❌ Error processing waypoints: {e}")


def callback_trip_data(msg):
    global current_trip_name, navigation_active, destination_reached

    try:
        data = json.loads(msg.data)

        mission_name = data.get("mission_name", "Unknown")
        description = data.get("description", "")
        total_waypoints = int(data.get("total_waypoints", 0))
        waypoints = data.get("waypoints", [])

        current_trip_name = mission_name

        rospy.loginfo("=" * 60)
        rospy.loginfo("🚗 TRIP RECEIVED FROM DASHBOARD")
        rospy.loginfo(f"   Mission: {mission_name}")
        rospy.loginfo(f"   Description: {description}")
        rospy.loginfo(f"   Total waypoints: {total_waypoints}")
        rospy.loginfo("=" * 60)

        if waypoints:
            wp_list = []
            for wp in waypoints:
                lat_val = float(wp.get("latitude", 0.0))
                lon_val = float(wp.get("longitude", 0.0))
                wp_list.append([lon_val, lat_val])

            wp_array = np.array(wp_list, dtype=float)
            ok = regenerate_spline(wp_array)
            if ok is None:
                return

            navigation_active = True
            destination_reached = False

            if pub_trip_status is not None:
                pub_trip_status.publish(f"trip_started:{mission_name}")

    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse trip data JSON: {e}")
    except Exception as e:
        rospy.logerr(f"❌ Error processing trip data: {e}")


def callback_navigation_command(msg):
    global navigation_active, destination_reached

    command = msg.data.lower().strip()

    if command == "start":
        navigation_active = True
        destination_reached = False
        rospy.loginfo("▶️ Navigation STARTED")
        if pub_trip_status is not None:
            pub_trip_status.publish("navigation:started")

    elif command == "stop":
        navigation_active = False
        rospy.loginfo("⏹️ Navigation STOPPED")
        if pub_trip_status is not None:
            pub_trip_status.publish("navigation:stopped")

    elif command == "pause":
        navigation_active = False
        rospy.loginfo("⏸️ Navigation PAUSED")
        if pub_trip_status is not None:
            pub_trip_status.publish("navigation:paused")

    elif command == "resume":
        navigation_active = True
        rospy.loginfo("▶️ Navigation RESUMED")
        if pub_trip_status is not None:
            pub_trip_status.publish("navigation:resumed")

    else:
        rospy.logwarn(f"⚠️ Unknown navigation command: {command}")

# =============================================================================
# SENSOR CALLBACKS
# =============================================================================

def callbackimuz(dataimu):
    global imuz
    imuz = float(dataimu.data)


def callbacklat(datalat):
    global lat, prev_lat
    prev_lat = lat
    lat = float(datalat.data)


def callbacklon(datalon):
    global lon, prev_lon
    prev_lon = lon
    lon = float(datalon.data)


def callbacklidar(datalidar):
    global alpha_obs
    alpha_obs = float(datalidar.data)


def callback_obstacle_distance(data):
    global obstacle_distance
    val = float(data.data)
    obstacle_distance = val if math.isfinite(val) and val >= 0.0 else float("inf")


def callback_obstacle_position(data):
    global obstacle_position
    obstacle_position = data.data if data.data in ["front", "left", "right", "none"] else "none"


def callbackvelocity(data):
    global velocity
    velocity = float(data.data)


def callback_dist(data):
    global jarak
    jarak = float(data.data)

# =============================================================================
# STANLEY CONTROLLER
# =============================================================================

# Debug globals (published)
cte = 0.0
cte_term = 0.0
heading_error = 0.0
heading_term = 0.0
path_heading = 0.0
feedforward = 0.0
curvature = 0.0


def stanley_controller(
    xv, yv, heading_vehicle_deg, v_mps,
    xs, ys, t_dense, spline_x, spline_y,
    arc_length,
    k_cte=0.35, k_heading=0.5,
    wheelbase=1.150,
    t_ff=0.5,
    vmax=1.5,
):
    """
    Stanley controller.
    Output steering is heading_term + cte_term (feedforward computed for debug/speed planning).
    """
    global cte, cte_term, heading_error, path_heading, heading_term
    global feedforward, curvature

    dist_array = np.hypot(xv - xs, yv - ys)
    idx = int(np.argmin(dist_array))

    min_dist = float(dist_array[idx])
    x_closest = float(xs[idx])
    y_closest = float(ys[idx])

    dx = float(spline_x(t_dense[idx], 1))
    dy = float(spline_y(t_dense[idx], 1))
    path_heading = math.degrees(math.atan2(dy, dx))

    heading_error = float(heading_vehicle_deg - path_heading)
    if heading_error > 180:
        heading_error -= 360
    elif heading_error < -180:
        heading_error += 360

    vx = xv - x_closest
    vy = yv - y_closest
    cross = dx * vy - dy * vx
    cte = float(np.sign(cross) * min_dist)

    if v_mps < 0.5:
        v_mps = 0.5

    cte_term = math.degrees(math.atan2(k_cte * cte, v_mps))
    heading_term = k_heading * heading_error

    # Feedforward preview curvature (for debug + speed target)
    s = float(arc_length[idx])
    s_ff = float(v_mps * t_ff)
    s_target = s + s_ff
    idx_ff = int(np.argmin(np.abs(arc_length - s_target)))

    dx_ff = float(spline_x(t_dense[idx_ff], 1))
    dy_ff = float(spline_y(t_dense[idx_ff], 1))
    ddx_ff = float(spline_x(t_dense[idx_ff], 2))
    ddy_ff = float(spline_y(t_dense[idx_ff], 2))

    denom = (dx_ff**2 + dy_ff**2) ** 1.5
    curvature = (dx_ff * ddy_ff - dy_ff * ddx_ff) / denom if denom > 1e-9 else 0.0

    v_target = vmax - (abs(curvature) * 1.5) - (abs(cte) * 0.1)
    v_target = max(0.0, min(vmax, v_target))

    feedforward = -math.degrees(math.atan(wheelbase * curvature))

    steering = heading_term + cte_term
    steering = max(min(steering, 15.0), -15.0)

    return float(steering), float(v_target)

# =============================================================================
# MAIN LOOP
# =============================================================================

def publish_stop(control_mode="STOPPED"):
    if pubv is None or pubs is None:
        return
    pubv.publish(Float32(0.0))
    pubs.publish(Float32(0.0))

    if pub_navigation_status is not None:
        nav_status = json.dumps({
            "active": False,
            "trip_name": current_trip_name,
            "dist_to_goal": float("nan"),
            "cte": 0.0,
            "steering": 0.0,
            "velocity": 0.0,
            "control_mode": control_mode,
            "cbf_active": False,
        })
        pub_navigation_status.publish(nav_status)


def main(_event):
    global destination_reached

    # Gate by dashboard command
    if not navigation_active:
        publish_stop("PAUSED_OR_STOPPED")
        return

    # Read path snapshot safely
    with path_lock:
        p = path_data
    if p is None:
        publish_stop("NO_PATH")
        return

    dataarray = p.dataarray
    spline_x = p.spline_x
    spline_y = p.spline_y
    xs = p.xs
    ys = p.ys
    t_dense = p.t_dense
    arc_length = p.arc_length

    # Yaw (your convention)
    current_yaw = imuz + 90.0
    if current_yaw > 180:
        current_yaw -= 360
    elif current_yaw < -180:
        current_yaw += 360

    # Vehicle local ENU
    xv, yv = gps_to_local_coords(lon, lat, float(dataarray[0, 0]), float(dataarray[0, 1]))

    # Distance to goal
    _, _, d2 = geodesic(wp_lon_tgt, wp_lat_tgt, lon, lat)

    # Stanley
    steering_cmd, v_target = stanley_controller(
        xv, yv, current_yaw, velocity,
        xs, ys, t_dense, spline_x, spline_y, arc_length,
        k_cte=0.35, k_heading=0.5, wheelbase=L, t_ff=0.5, vmax=1.5
    )
    nominal_steering = smooth_steering(steering_cmd)

    # CBF correction
    cbf_corr, boundary_dist, cbf_status = calculate_cbf_correction(
        lon, lat, current_yaw, left_boundary, right_boundary
    )

    # Control priority
    control_mode = "UNDEFINED"
    v_cmd = v_target
    steer_cmd = nominal_steering

    if alpha_obs != 0.0:
        # Priority 1: obstacle override
        if obstacle_position == "front" and obstacle_distance < 1.2:
            steer_cmd = alpha_obs
            v_cmd = 0.0
            control_mode = "LIDAR_FRONT_STOP"
        elif obstacle_position == "front" and obstacle_distance < 3.0:
            steer_cmd = alpha_obs
            v_cmd = 0.4
            control_mode = "LIDAR_FRONT"
        elif obstacle_position in ["left", "right"] and obstacle_distance < 1.5:
            steer_cmd = alpha_obs
            v_cmd = 0.4
            control_mode = f"LIDAR_{obstacle_position.upper()}_CLOSE"
        elif obstacle_position in ["left", "right"] and obstacle_distance < 3.0:
            steer_cmd = alpha_obs
            v_cmd = 0.4
            control_mode = f"LIDAR_{obstacle_position.upper()}"
        else:
            steer_cmd = alpha_obs
            v_cmd = 0.4
            control_mode = "LIDAR_FAR"

    elif cbf_active:
        # Priority 2: boundary safety
        waypoint_influence = max(0.1, min(0.3, boundary_dist / CBF_ZONE_1))
        steer_cmd = cbf_corr + (waypoint_influence * nominal_steering)
        v_cmd = v_target * max(0.4, boundary_dist / CBF_ZONE_1)
        control_mode = f"CBF_{cbf_status}"

    else:
        control_mode = "WAYPOINT"

    # Steering clamp
    steer_cmd = max(min(float(steer_cmd), 15.0), -15.0)

    # Front-distance speed gating
    if math.isfinite(jarak):
        if 8.0 < jarak <= 10.0:
            v_cmd = min(v_cmd, 1.1)
        elif 6.0 < jarak <= 8.0:
            v_cmd = min(v_cmd, 0.8)
        elif 4.0 < jarak <= 6.0:
            v_cmd = min(v_cmd, 0.6)
        elif 1.5 < jarak <= 4.0:
            v_cmd = min(v_cmd, 0.4)
        elif 1.3 < jarak <= 2.0:
            v_cmd = min(v_cmd, 0.2)
        elif jarak <= 0.6:
            v_cmd = 0.0

    # Goal stop
    if d2 < GOAL_THRESHOLD:
        v_cmd = 0.0
        steer_cmd = 0.0
        control_mode = "GOAL_REACHED"
        if not destination_reached:
            destination_reached = True
            rospy.loginfo("🏁 DESTINATION REACHED!")
            if pub_trip_status is not None:
                pub_trip_status.publish(f"destination_reached:{current_trip_name}")

    # Publish commands + debug
    pubv.publish(Float32(v_cmd))
    pubs.publish(Float32(steer_cmd))
    pubs_imu.publish(Float32(current_yaw))
    pub_debug.publish(Float32(d2))
    pub_cte.publish(Float32(cte))

    pub_boundary_dist.publish(Float32(boundary_dist))
    pub_cbf_correction.publish(Float32(cbf_corr))
    pub_cbf_active.publish(Float32(1.0 if cbf_active else 0.0))

    pub_obstacle_distance.publish(Float32(obstacle_distance))
    pub_obstacle_position.publish(obstacle_position)

    pub_cte_term.publish(Float32(cte_term))
    pub_heading_term.publish(Float32(heading_term))
    pub_path_heading.publish(Float32(path_heading))
    pub_heading_error.publish(Float32(heading_error))

    pub_ff.publish(Float32(feedforward))
    pub_curvature.publish(Float32(curvature))

    # Dashboard status
    if pub_navigation_status is not None:
        nav_status = json.dumps({
            "active": navigation_active,
            "trip_name": current_trip_name,
            "dist_to_goal": float(d2),
            "cte": float(cte),
            "steering": float(steer_cmd),
            "velocity": float(v_cmd),
            "control_mode": control_mode,
            "cbf_active": bool(cbf_active),
        })
        pub_navigation_status.publish(nav_status)

# =============================================================================
# ROS NODE
# =============================================================================

def talker():
    rospy.init_node("stanley_navigation", anonymous=True)
    init_publishers()

    load_boundary_waypoints()
    load_default_waypoints()

    # Sensor topics
    rospy.Subscriber("/latitude", Float64, callbacklat)
    rospy.Subscriber("/longitude", Float64, callbacklon)
    rospy.Subscriber("/0dataz", Float32, callbackimuz)
    rospy.Subscriber("/lidar", Float32, callbacklidar)
    rospy.Subscriber("/obstacle_distance", Float32, callback_obstacle_distance)
    rospy.Subscriber("/obstacle_position", String, callback_obstacle_position)
    rospy.Subscriber("/front_distance", Float32, callback_dist)
    rospy.Subscriber("/velocity", Float32, callbackvelocity)

    # Dashboard topics
    rospy.Subscriber("/waypoints_array", String, callback_waypoints_array)
    rospy.Subscriber("/trip_data", String, callback_trip_data)
    rospy.Subscriber("/navigation_command", String, callback_navigation_command)

    rospy.loginfo("=" * 60)
    rospy.loginfo("🚗 STANLEY NAVIGATION (ROS + Dashboard) STARTED")
    rospy.loginfo("   Smoothing: PCHIPInterpolator (reduced overshoot)")
    rospy.loginfo("   Waiting for dashboard waypoints / commands...")
    rospy.loginfo("=" * 60)

    rospy.Timer(rospy.Duration(0.2), main)  # 5 Hz
    rospy.spin()


if __name__ == "__main__":
    try:
        talker()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr(f"Unexpected error: {e}")
