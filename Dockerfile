# Multi-stage Dockerfile for the Intel RealSense T265 on ROS2 Foxy

# ---------------------------------------------------------------------------
# Stage 1: Build librealsense 2.53.1 (last version supporting the T265)
# ---------------------------------------------------------------------------
FROM ros:foxy-ros-base AS librealsense-builder

# Build deps. gtk/glfw are kept only so the librealsense CMake never trips over
# them; they live in this throwaway stage and never reach the final image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    build-essential \
    pkg-config \
    libusb-1.0-0-dev \
    libssl-dev \
    libgtk-3-dev \
    libglfw3-dev \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    wget -q https://github.com/IntelRealSense/librealsense/archive/refs/tags/v2.53.1.tar.gz && \
    tar -xzf v2.53.1.tar.gz && \
    cd librealsense-2.53.1 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_EXAMPLES=false \
             -DBUILD_TOOLS=true \
             -DBUILD_GRAPHICAL_EXAMPLES=false \
             -DBUILD_PYTHON_BINDINGS=false \
             -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install DESTDIR=/librealsense-install && \
    cd / && rm -rf /tmp/librealsense-2.53.1 /tmp/v2.53.1.tar.gz

# ---------------------------------------------------------------------------
# Stage 2: Build the realsense2_camera ROS2 workspace
# ---------------------------------------------------------------------------
FROM ros:foxy-ros-base AS ros2-builder

# librealsense headers + libs are needed to compile the wrapper
COPY --from=librealsense-builder /librealsense-install /
RUN ldconfig

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-colcon-common-extensions \
    python3-rosdep \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /ros2_ws
RUN mkdir -p src && cd src && \
    git clone --depth 1 https://github.com/IntelRealSense/realsense-ros.git -b ros2-legacy

# Pull in the wrapper's build dependencies (cv_bridge, image_transport, tf2, ...)
# via rosdep. librealsense2 is skipped because we built it from source above.
RUN apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y \
        --skip-keys=librealsense2 \
    && rm -rf /var/lib/apt/lists/*

RUN /bin/bash -c "source /opt/ros/foxy/setup.bash && \
    colcon build --packages-select realsense2_camera_msgs realsense2_camera" && \
    rm -rf /ros2_ws/build /ros2_ws/log /ros2_ws/src

# ---------------------------------------------------------------------------
# Stage 3: Slim runtime image
# ---------------------------------------------------------------------------
FROM ros:foxy-ros-base

# Runtime-only dependencies: librealsense's libs + the exact ROS packages the
# camera node links against at runtime (cv_bridge -> opencv, image_transport,
# tf2_ros, diagnostic_updater) plus the launch tooling.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0 \
    libssl1.1 \
    udev \
    tini \
    ros-foxy-cv-bridge \
    ros-foxy-image-transport \
    ros-foxy-tf2-ros \
    ros-foxy-diagnostic-updater \
    ros-foxy-launch-ros \
    ros-foxy-launch-xml \
    && rm -rf /var/lib/apt/lists/*

# librealsense (incl. rs-enumerate-devices) and the built workspace
COPY --from=librealsense-builder /librealsense-install /
COPY --from=ros2-builder /ros2_ws/install /ros2_ws/install
RUN ldconfig

# udev rules for RealSense devices (informational; --privileged is what grants
# actual device access at runtime)
RUN printf '%s\n' \
    'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0b37", MODE="0666", GROUP="plugdev"' \
    'SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0b37", MODE="0666", GROUP="plugdev"' \
    'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", ATTRS{idProduct}=="2150", MODE="0666", GROUP="plugdev"' \
    > /etc/udev/rules.d/99-realsense-libusb.rules

# Cross-distro DDS interop profile: forces FastDDS to use UDP with unicast
# discovery to 127.0.0.1 (no shared-memory, no multicast). Required so a Humble
# host (FastDDS 2.6.x) can see topics from this Foxy container (FastDDS 2.1.x).
COPY fastdds_localhost.xml /fastdds.xml

ENV ROS_DOMAIN_ID=0 \
    RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    FASTRTPS_DEFAULT_PROFILES_FILE=/fastdds.xml

# Entrypoint sources ROS + the workspace so the baked-in CMD (and any user
# command) runs in a ready environment.
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'source /opt/ros/foxy/setup.bash' \
    'source /ros2_ws/install/setup.bash' \
    'exec "$@"' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD rs-enumerate-devices > /dev/null 2>&1 || exit 1

LABEL description="Intel RealSense T265 tracking camera with ROS2 Foxy" \
      version="0.1" \
      ros.distro="foxy" \
      hardware.support="Intel RealSense T265" \
      librealsense.version="2.53.1"

WORKDIR /ros2_ws

# tini as PID 1 so signals reach ros2 launch properly (a process running as PID 1
# only receives signals it has an explicit handler for; tini fixes that and reaps
# zombies). STOPSIGNAL SIGINT makes `docker stop` send SIGINT instead of SIGTERM
# so the realsense node performs its graceful T265 shutdown and releases the USB
# device cleanly -- preventing the "device busy / re-enumerating" failures on the
# next run. This also makes a single Ctrl-C shut the node down cleanly.
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
# Default: launch the camera with IMU enabled. Override by passing your own
# command, e.g. `... rs_launch.py enable_gyro:=false`, or `bash` for a shell.
CMD ["ros2", "launch", "realsense2_camera", "rs_launch.py", \
     "enable_gyro:=true", "enable_accel:=true", "unite_imu_method:=linear_interpolation"]
