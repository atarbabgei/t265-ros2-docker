# T265 ROS2 Docker

[![Build Status](https://github.com/atarbabgei/t265-ros2-docker/workflows/Build%20and%20Push%20Docker%20Image/badge.svg)](https://github.com/atarbabgei/t265-ros2-docker/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/atarbabgei/t265-ros2-docker)](https://hub.docker.com/r/atarbabgei/t265-ros2-docker)
[![Docker Image Size](https://img.shields.io/docker/image-size/atarbabgei/t265-ros2-docker/latest)](https://hub.docker.com/r/atarbabgei/t265-ros2-docker)

Docker image for Intel RealSense T265 tracking camera with ROS2 Foxy on Ubuntu 20.04

This effort revives the discontinued Intel T265 tracking camera and makes it work with ROS2. This repository provides a Docker container based on Ubuntu 20.04 and ROS2 Foxy, including the latest T265-compatible SDK (librealsense SDK 2.53.1)

Tested across distributions with ROS2 Humble on Ubuntu 22.04 and may work on other distributions

**Docker Hub:** [atarbabgei/t265-ros2-docker](https://hub.docker.com/r/atarbabgei/t265-ros2-docker)

> **Note:** Docker images are automatically built and pushed to Docker Hub via GitHub Actions on every commit to the main branch.

## Development Workflow

This repository uses a development branch workflow:

- **`main`** - Production-ready code, automatically builds and pushes to Docker Hub
- **`develop`** - Development branch for new features and changes

### Contributing

1. **Create feature branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and test locally

3. **Create Pull Request** to merge into `develop`

4. **Merge to main** when ready for production (triggers Docker build)

### Automated Builds

Docker builds are triggered only when these files change:
- `Dockerfile`
- `docker-compose.yml`
- `scripts/**`
- `.dockerignore`
- `.github/workflows/docker-build.yml`

Documentation changes (README, etc.) will NOT trigger Docker builds.

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
