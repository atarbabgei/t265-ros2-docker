# T265 ROS2 Docker

Docker image for Intel RealSense T265 tracking camera with ROS2 Foxy on Ubuntu 20 04. Tested to work across distributions with ROS2 Humble on Ubuntu 22 04. It may work on other distributions

## Quick Start

### Test T265 Detection
```bash
docker run -it --rm --privileged --user root -v /dev:/dev \
  atarbabgei/t265-ros2-docker:latest rs-enumerate-devices
```

### Run ROS2 Camera Node
```bash
docker run -it --rm --privileged --user root -v /dev:/dev \
  -e ROS_DOMAIN_ID=0 -e RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
  atarbabgei/t265-ros2-docker:latest \
  bash -c "source /ros2_ws/install/setup.bash && ros2 run realsense2_camera realsense2_camera_node"
```


## Key Features

- T265 Support: Works with T265 cameras 
- ROS2 Foxy: Compatible with librealsense SDK 2.53.1
- Tested Cross-distribution: e.g. Docker Foxy ↔ Host Humble communication
- All streams: Fisheye cameras, IMU, pose, odometry

## ROS2 Topics

- `/camera/pose/sample` - 6DOF pose data
- `/camera/odom/sample` - Odometry data  
- `/camera/fisheye1/image_raw` - Left fisheye (848x800)
- `/camera/fisheye2/image_raw` - Right fisheye (848x800)
- `/camera/gyro/sample` - Gyroscope data
- `/camera/accel/sample` - Accelerometer data

## Troubleshooting

- **Always use `--user root`** for hardware access
- **T265 may appear as**: `03e7:2150 Intel Myriad VPU [Movidius Neural Compute Stick]`
- **Check connection**: `lsusb | grep -E "(8086|03e7)"`

## Image Info

- **Base**: `osrf/ros:foxy-desktop`
- **librealsense**: 2.53.1 (last T265-compatible version)
- **Architecture**: linux/amd64

---

Make sure to **Run as root** for hardware access. 