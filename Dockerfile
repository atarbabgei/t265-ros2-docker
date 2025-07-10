# Multi-stage Dockerfile for T265 RealSense in ROS2 Foxy
# Optimized for Docker Hub deployment with better caching and security

# Stage 1: Build librealsense
FROM osrf/ros:foxy-desktop AS librealsense-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    pkg-config \
    libusb-1.0-0-dev \
    libssl-dev \
    libgtk-3-dev \
    libglfw3-dev \
    python3-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Build specific librealsense2 version 2.53.1 (last version supporting T265)
RUN cd /tmp && \
    wget https://github.com/IntelRealSense/librealsense/archive/refs/tags/v2.53.1.tar.gz && \
    tar -xzf v2.53.1.tar.gz && \
    cd librealsense-2.53.1 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_EXAMPLES=true \
             -DBUILD_TOOLS=true \
             -DBUILD_GRAPHICAL_EXAMPLES=false \
             -DBUILD_PYTHON_BINDINGS=false \
             -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install DESTDIR=/librealsense-install && \
    cd / && rm -rf /tmp/librealsense-2.53.1 /tmp/v2.53.1.tar.gz

# Stage 2: Build ROS2 workspace
FROM osrf/ros:foxy-desktop AS ros2-builder

# Copy librealsense installation from previous stage
COPY --from=librealsense-builder /librealsense-install /

# Install ROS dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3-colcon-common-extensions \
    ros-foxy-diagnostic-updater \
    ros-foxy-sensor-msgs \
    ros-foxy-std-msgs \
    ros-foxy-geometry-msgs \
    ros-foxy-nav-msgs \
    ros-foxy-tf2 \
    ros-foxy-tf2-ros \
    && rm -rf /var/lib/apt/lists/*

# Create ROS2 workspace and clone RealSense wrapper
WORKDIR /ros2_ws
RUN mkdir -p src && \
    cd src && \
    git clone https://github.com/IntelRealSense/realsense-ros.git -b ros2-legacy

# Build the ROS2 workspace
RUN /bin/bash -c "source /opt/ros/foxy/setup.bash && \
    colcon build --symlink-install --packages-select realsense2_camera_msgs realsense2_camera"

# Stage 3: Final runtime image
FROM osrf/ros:foxy-desktop

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libusb-1.0-0 \
    libssl1.1 \
    libgtk-3-0 \
    libglfw3 \
    python3-pip \
    curl \
    udev \
    && rm -rf /var/lib/apt/lists/*

# Copy librealsense installation
COPY --from=librealsense-builder /librealsense-install /

# Copy ROS2 workspace
COPY --from=ros2-builder /ros2_ws /ros2_ws

# Update library cache
RUN ldconfig

# Create non-root user with hardware access groups
RUN groupadd -r ros && \
    useradd -r -g ros -G dialout,plugdev,video -m -s /bin/bash -c "ROS user" ros

# Add udev rules for RealSense devices
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0b37", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0ad1", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0ad2", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0ad3", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0ad4", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0b07", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules && \
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", ATTRS{idProduct}=="2150", MODE="0666", GROUP="plugdev"' >> /etc/udev/rules.d/99-realsense-libusb.rules

# Set proper ownership
RUN chown -R ros:ros /ros2_ws

# Switch to non-root user
USER ros
WORKDIR /ros2_ws

# Setup ROS environment for the user
RUN echo "source /opt/ros/foxy/setup.bash" >> ~/.bashrc && \
    echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc && \
    echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc && \
    echo "export RMW_IMPLEMENTATION=rmw_fastrtps_cpp" >> ~/.bashrc

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD rs-enumerate-devices > /dev/null 2>&1 || exit 1

# Metadata labels for Docker Hub
LABEL maintainer="T265 ROS2 Docker Project" \
      description="Intel RealSense T265 tracking camera with ROS2 Foxy" \
      version="1.0" \
      ros.distro="foxy" \
      hardware.support="Intel RealSense T265" \
      librealsense.version="2.53.1"

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
