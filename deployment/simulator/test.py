#!/usr/bin/env python3
import rospy
import json
from std_msgs.msg import Float64, String
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import CubicSpline
import math

# Initial State (Start Point)
current_lat = -6.88245496
current_lon = 107.6107489
move_speed = 0.00003  # Degrees per tick (~3 meters)

# Waypoints queue from Dashboard
waypoints_queue = []
current_wp_index = 0
navigation_active = False

def gps_to_local_coords(lon, lat, ref_lon, ref_lat):
    """
    Convert GPS coordinates to local Cartesian coordinates
    Using approximate conversion for small distances
    """
    R = 6371000.0
    lat_rad = math.radians(lat)
    lon_rad = math.radians(lon)
    ref_lat_rad = math.radians(ref_lat)
    ref_lon_rad = math.radians(ref_lon)
    x = R * (lon_rad - ref_lon_rad) * math.cos(ref_lat_rad)
    y = R * (lat_rad - ref_lat_rad)
    return x, y

# Callbacks for Waypoints (From Dashboard)
def waypoints_callback(msg):
    global waypoints_queue, current_wp_index, navigation_active
    try:
        data = json.loads(msg.data)
        waypoints_queue = data.get('waypoints', [])
        current_wp_index = 0
        navigation_active = len(waypoints_queue) > 0
        rospy.loginfo(f"✅ Received {len(waypoints_queue)} waypoints from Dashboard")
        if waypoints_queue:
            rospy.loginfo(f"🚗 Starting navigation to first waypoint: {waypoints_queue[0].get('name', 'Unknown')}")
    except json.JSONDecodeError as e:
        rospy.logerr(f"❌ Failed to parse waypoints JSON: {e}")

def navigation_command_callback(msg):
    global navigation_active
    command = msg.data.strip().lower()
    if command == 'start':
        navigation_active = True
        rospy.loginfo("▶️ Navigation started")
    elif command == 'stop':
        navigation_active = False
        rospy.loginfo("⏹️ Navigation stopped")
    elif command == 'pause':
        navigation_active = False
        rospy.loginfo("⏸️ Navigation paused")
    elif command == 'resume':
        navigation_active = True
        rospy.loginfo("▶️ Navigation resumed")

# Data for visualization background
dataarray = np.array(
[[107.61073832, -6.88248358],
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
[107.61163629, -6.88240546]]
)

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

# Create Spline for visualization
xy = []
for i in range(len(dataarray)):
    x,y = gps_to_local_coords(dataarray[i,0], dataarray[i,1], dataarray[0,0], dataarray[0,1])
    xy.append([x,y])
xy = np.array(xy)
t = [0]
for i in range(1, len(xy)):
    dist = np.linalg.norm(xy[i] - xy[i-1])
    t.append(t[-1] + dist)
t = np.array(t)

spline_x = CubicSpline(t, xy[:, 0])
spline_y = CubicSpline(t, xy[:, 1])

left_xy = np.array([gps_to_local_coords(lon, lat, dataarray[0,0], dataarray[0,1])
                    for lon, lat in left_boundary])

right_xy = np.array([gps_to_local_coords(lon, lat, dataarray[0,0], dataarray[0,1])
                     for lon, lat in right_boundary])

if __name__ == "__main__":
    rospy.init_node("mevi_simulator")

    # PUBLISHERS: Report current status to Dashboard
    pub_lat = rospy.Publisher("/latitude", Float64, queue_size=10)
    pub_lon = rospy.Publisher("/longitude", Float64, queue_size=10)
    pub_wp_index = rospy.Publisher("/wp_index", Float64, queue_size=10)

    # SUBSCRIBERS: Receive orders from Dashboard
    rospy.Subscriber("/waypoints_array", String, waypoints_callback)
    rospy.Subscriber("/navigation_command", String, navigation_command_callback)

    plt.ion()
    fig, ax = plt.subplots(figsize=(10, 10))

    rate = rospy.Rate(10) # 10 Hz
    
    rospy.loginfo("🚗 MEVI Simulator Started. Waiting for waypoints...")

    while not rospy.is_shutdown():
        # Update Position Logic - Follow Waypoints
        if navigation_active and waypoints_queue and current_wp_index < len(waypoints_queue):
            target_wp = waypoints_queue[current_wp_index]
            target_lat = target_wp.get('latitude', current_lat)
            target_lon = target_wp.get('longitude', current_lon)

            d_lat = target_lat - current_lat
            d_lon = target_lon - current_lon
            dist = math.sqrt(d_lat**2 + d_lon**2)

            # Check if reached current waypoint (within ~5 meters)
            if dist < 0.00005:
                rospy.loginfo(f"✅ Reached waypoint {current_wp_index + 1}/{len(waypoints_queue)}: {target_wp.get('name', 'Unknown')}")
                current_wp_index += 1
                
                if current_wp_index >= len(waypoints_queue):
                    rospy.loginfo("🏁 Navigation complete! All waypoints reached.")
                    navigation_active = False
                else:
                    rospy.loginfo(f"🚗 Moving to next waypoint: {waypoints_queue[current_wp_index].get('name', 'Unknown')}")
            else:
                # Move towards current waypoint
                ratio = min(move_speed, dist) / dist
                current_lat += d_lat * ratio
                current_lon += d_lon * ratio

        # Publish current position
        pub_lat.publish(current_lat)
        pub_lon.publish(current_lon)
        pub_wp_index.publish(float(current_wp_index))

        # Visualization
        x, y = gps_to_local_coords(current_lon, current_lat, dataarray[0,0], dataarray[0,1])
        
        ax.clear()

        ax.plot(left_xy[:,0], left_xy[:,1], "orange", label="Left Boundary")
        ax.plot(right_xy[:,0], right_xy[:,1], "purple", label="Right Boundary")

        ax.scatter(spline_x(np.linspace(t[0], t[-1], 300)), spline_y(np.linspace(t[0], t[-1], 300)), marker="o", s=2, label="Reference Path", color="green")
        ax.scatter(xy[:, 0], xy[:, 1], color="red", s=30, marker="o", label="Reference Waypoints")
        
        # Plot received waypoints from Dashboard
        if waypoints_queue:
            wp_coords = []
            for wp in waypoints_queue:
                wx, wy = gps_to_local_coords(wp['longitude'], wp['latitude'], dataarray[0,0], dataarray[0,1])
                wp_coords.append([wx, wy])
            wp_coords = np.array(wp_coords)
            ax.scatter(wp_coords[:, 0], wp_coords[:, 1], color="cyan", s=50, marker="^", label="Mission Waypoints", zorder=5)
            
            # Highlight current target waypoint
            if current_wp_index < len(waypoints_queue):
                target_wp = waypoints_queue[current_wp_index]
                tx, ty = gps_to_local_coords(target_wp['longitude'], target_wp['latitude'], dataarray[0,0], dataarray[0,1])
                ax.scatter(tx, ty, color="yellow", s=150, marker="*", label="Current Target", zorder=6)
        
        # Current Car Position (Blue)
        ax.scatter(x, y, color="blue", s=100, marker="o", label="MEVI Car", zorder=7)

        status_text = "IDLE" if not navigation_active else f"Moving to WP {current_wp_index + 1}/{len(waypoints_queue)}"
        ax.set_xlabel("X (meters)")
        ax.set_ylabel("Y (meters)")
        ax.set_title(f"MEVI Simulator | {status_text} | Lat: {current_lat:.6f}, Lon: {current_lon:.6f}")
        ax.legend(loc='upper right')
        ax.grid(True)

        plt.draw()
        plt.pause(0.01)
        rate.sleep()