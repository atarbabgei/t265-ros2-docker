# T265 ROS2 Docker

![Build Status](https://github.com/atarbabgei/t265-ros2-docker/workflows/Build%20and%20Push%20Docker%20Image/badge.svg)
![Docker Pulls](https://img.shields.io/docker/pulls/atarbabgei/t265-ros2-docker)
![Docker Image Size](https://img.shields.io/docker/image-size/atarbabgei/t265-ros2-docker/latest)

Revives the discontinued Intel RealSense T265 on ROS2. Runs ROS2 Foxy +
librealsense 2.53.1 (last T265-compatible SDK) in the container, and publishes
straight to a ROS2 Humble host with no host-side setup.

**Docker Hub:** https://hub.docker.com/r/atarbabgei/t265-ros2-docker

---

## Run

```bash
docker run --network host --privileged atarbabgei/t265-ros2-docker:latest
```

Launches pose, fisheye, and IMU; topics show up on the host immediately. Stop
with a single `Ctrl+C`. To grab a newer build: `docker pull atarbabgei/t265-ros2-docker:latest`.

It's a thin layer — override the default by passing your own command:
```bash
# custom launch args
docker run --network host --privileged atarbabgei/t265-ros2-docker:latest \
  ros2 launch realsense2_camera rs_launch.py enable_gyro:=false enable_accel:=false

# shell, or check detection
docker run -it --privileged atarbabgei/t265-ros2-docker:latest bash
docker run --rm --privileged atarbabgei/t265-ros2-docker:latest rs-enumerate-devices
```

---

## Build locally

```bash
git clone https://github.com/atarbabgei/t265-ros2-docker.git
cd t265-ros2-docker
docker build -t t265-ros2-docker:latest .
docker run --network host --privileged t265-ros2-docker:latest
```

---

## Topics

- `/camera/odom/sample` — pose / odometry
- `/camera/fisheye1/image_raw`, `/camera/fisheye2/image_raw` — fisheye (848×800)
- `/camera/imu` — fused gyro + accel @ 200 Hz

---

## Image

Base `ros:foxy-ros-base` (~1.9 GB) · librealsense 2.53.1 · linux/amd64

---

## License

MIT
