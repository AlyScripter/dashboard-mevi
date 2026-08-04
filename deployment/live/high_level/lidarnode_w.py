#!/usr/bin/env python3

import rospy
from sensor_msgs.msg import LaserScan
from std_msgs.msg import Float32
from std_msgs.msg import String
import math

# Lidar Test Waypoint
# Description : Steering angle value setpoints publishing based on object direction with different thresholds per segment
# Status      : Successful
# Changes     : Different thresholds for segments, added /obstacle_distance and /obstacle_position topics, minimized debugging with specific logs retained
# Improvement : Enhanced obstacle detection for early prediction
# Issue       : None

segment3          = False
segment2          = False
segment1          = False
segmentminus1     = False
segmentminus2     = False
segmentminus3     = False
objectRight       = False
objectFront       = False
objectLeft        = False
steering          = 0.0
obstacle_distance = float('inf')
obstacle_position = "none"
def callback(data):
    global segment1, segment2, segment3, segmentminus1, segmentminus2, segmentminus3
    global objectRight, objectFront, objectLeft, steering, obstacle_distance, obstacle_position

    angle_min_deg       = math.degrees(data.angle_min)
    angle_increment_deg = math.degrees(data.angle_increment)
    desired_angles_deg  = [40, 30, 20, 0, -20, -30, -40]
    thresholds         = {40: 1.0, 30: 2.0, 20: 3.0, 0: 3.0, -20: 3.0, -30: 2.0, -40: 1.0}
    segment1    = segment2    = segment3   = segmentminus1 = segmentminus2 = segmentminus3 = False
    objectRight = objectFront = objectLeft = False
    obstacle_distance   = float('inf')
    obstacle_position   = "none"

    # Reset the segments and object flags
    for angle_deg in desired_angles_deg:
        index = int((angle_deg - angle_min_deg) / angle_increment_deg)
        reversed_angle_deg = -angle_deg
        if 0 <= index < len(data.ranges):
            distance = data.ranges[index]
            if math.isfinite(distance) and distance > 0.0 and distance < thresholds[angle_deg]:
                obstacle_distance = min(obstacle_distance, distance)
                if     0 <= reversed_angle_deg <= 20: segment1      = True
                elif  20 < reversed_angle_deg <= 30: segment2      = True
                elif  30 < reversed_angle_deg <= 40: segment3      = True
                elif -20 <= reversed_angle_deg <  0: segmentminus1 = True
                elif -30 <= reversed_angle_deg < -20: segmentminus2 = True
                elif -40 <= reversed_angle_deg < -30: segmentminus3 = True

    # Determine the object position and steering angle based on the segments
    if segment1 and not segmentminus1:
        objectRight = True
        steering    = -15.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segment2:
        objectRight = True
        steering    = -10.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segment3:
        objectRight = True
        steering    = -5.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segment1 and segment2:
        objectRight = True
        steering    = -10.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segment2 and segment3:
        objectRight = True
        steering    = -7.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segment1 and segment2 and segment3:
        objectRight = True
        steering    = -15.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segmentminus1 and segment1 and segment2:
        objectRight = True
        steering    = -15.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segmentminus1 and segment1 and segment2 and segment3:
        objectRight = True
        steering    = -10.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segmentminus2 and segmentminus1 and segment1 and segment2 and segment3:
        objectRight = True
        steering    = -15.0
        obstacle_position = "right"
        print("Object on the right", objectRight)
    elif segmentminus1 and segment1:
        objectFront = True
        steering    = 15.0
        obstacle_position = "front"
        print("Object at the front", objectFront)
    elif segmentminus1 and not segment1:
        objectLeft  = True
        steering    = 15.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segmentminus2:
        objectLeft  = True
        steering    = 10.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segmentminus3:
        objectLeft  = True
        steering    = 10.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segmentminus1 and segmentminus2:
        objectLeft  = True
        steering    = 13.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segmentminus2 and segmentminus3:
        objectLeft  = True
        steering    = 7.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segmentminus1 and segmentminus2 and segmentminus3:
        objectLeft  = True
        steering    = 15.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segment1 and segmentminus1 and segmentminus2:
        objectLeft  = True
        steering    = 15.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segment1 and segmentminus1 and segmentminus2 and segmentminus3:
        objectLeft  = True
        steering    = 10.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    elif segment2 and segment1 and segmentminus1 and segmentminus2 and segmentminus3:
        objectLeft  = True
        steering    = 15.0
        obstacle_position = "left"
        print("Object on the left", objectLeft)
    else:
        steering    = 0.0
        obstacle_distance = float('inf')
        obstacle_position = "none"
        print("No object detected")

    # Publish the steering angle and obstacle information
    pub_steering.publish(steering)
    pub_obstacle_distance.publish(obstacle_distance)
    pub_obstacle_position.publish(obstacle_position)

if __name__ == '__main__':
    try:
        rospy.init_node('lidarlistenernode', anonymous=False)
        pub_steering = rospy.Publisher('lidar', Float32, queue_size=10)
        pub_obstacle_distance = rospy.Publisher('obstacle_distance', Float32, queue_size=10)
        pub_obstacle_position = rospy.Publisher('obstacle_position', String, queue_size=10)
        rospy.Subscriber("/scan", LaserScan, callback)
        rospy.loginfo("Lidar node started, subscribing to /scan, publishing to /lidar, /obstacle_distance, /obstacle_position")
        rospy.spin()
    except rospy.ROSInterruptException:
        rospy.logerr("ROS interrupted")
    except Exception as e:
        rospy.logerr(f"Unexpected error: {e}")