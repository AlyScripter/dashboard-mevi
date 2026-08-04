#!/usr/bin/env python
#import numpy as np
#import math import round
import rospy
from witmotion import IMU
from sensor_msgs.msg import Imu
import serial
from std_msgs.msg import Float32
#Float32MultiArray imu_pesan[]
def publish_imu_data(imu):
    imu_msg = Imu()
    imu_msg.header.stamp = rospy.Time.now()
    imu_msg.header.frame_id = 'imu_link'
    
    # Assuming IMU object has methods to get acceleration and angular velocity
    acceleration = imu.get_acceleration()
    angular_velocity = imu.get_angular_velocity()
    sudut = imu.get_angle()
        
    if sudut:
        z = sudut[2]
        #rospy.loginfo("data z : {}".format(z,v,a))
        #rospy.loginfo(z)
        imu_kirimz.publish(z)
        #imu_msg.orientation.w = sudut [3]
    if acceleration:
        a = acceleration[0]
        #rospy.loginfo("data a : {}".format(a))
        #rospy.loginfo(a)
        imu_kirima.publish(a)
    
    if angular_velocity:
        v = angular_velocity[1]
        #rospy.loginfo("Published IMU data v : {}".format(v))
        rospy.loginfo("data z : {}".format(z)+' a: {}'.format(v)+' v: {}'.format(a))
        #rospy.loginfo(v)
        imu_kirimv.publish(v)

    #imu_pub.publish(imu_msg)
    
    

def imu_callback(data):
    rospy.loginfo("Received IMU data: {}".format(data))

try:
    rospy.init_node('witmotion_publisher', anonymous=True)
    #imu_pub = rospy.Publisher('witmotion/data', Imu, queue_size=10)
    imu_kirimz= rospy.Publisher('0dataz',Float32 ,queue_size=10)
    imu_kirima= rospy.Publisher('0dataa',Float32 ,queue_size=10)
    imu_kirimv= rospy.Publisher('0datav',Float32 ,queue_size=10)
    #imu_sub = rospy.Subscriber('witmotion/data', Imu, imu_callback)
    #pub = rospy.Publisher('chatter', String, queue_size=10)
    imu = IMU('/dev/ttyUSB0')
    
    rate = rospy.Rate(5)  # 1 Hz rate, you can adjust this as needed
    rospy.loginfo("IMU publisher node started.")  # Logging node initialization

    while not rospy.is_shutdown():
        publish_imu_data(imu)
        rate.sleep()

except serial.SerialException as e:
    rospy.logerr("Serial port error: {}".format(e))
except rospy.ROSInterruptException:
    pass
except Exception as e:  # Catch other errors and log
    rospy.logerr("An error occurred: {}".format(e))
