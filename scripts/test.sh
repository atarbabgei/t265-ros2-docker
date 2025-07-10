#!/bin/bash
set -e

# Test script for T265 ROS2 Docker container
echo "Testing T265 ROS2 Docker container..."

CONTAINER_NAME="t265-ros2"

# Check if container is running
if ! docker ps -q -f name="${CONTAINER_NAME}" | grep -q .; then
    echo "Error: Container ${CONTAINER_NAME} is not running!"
    echo "Please start the container first: ./scripts/run.sh"
    exit 1
fi

echo "Container ${CONTAINER_NAME} is running. Running tests..."

# Test 1: Check RealSense SDK detection
echo ""
echo "=== Test 1: RealSense SDK Detection ==="
docker exec "${CONTAINER_NAME}" bash -c "rs-enumerate-devices"

# Test 2: Check ROS2 environment
echo ""
echo "=== Test 2: ROS2 Environment ==="
docker exec "${CONTAINER_NAME}" bash -c "source /ros2_ws/install/setup.bash && ros2 pkg list | grep realsense"

# Test 3: Check if camera node can start (without hardware)
echo ""
echo "=== Test 3: ROS2 Node Check ==="
docker exec "${CONTAINER_NAME}" bash -c "source /ros2_ws/install/setup.bash && ros2 pkg executables realsense2_camera"

echo ""
echo "=== Test Results ==="
echo "✅ All tests completed!"
echo ""
echo "To test with actual hardware:"
echo "1. Connect your T265 camera"
echo "2. Run: docker exec -it ${CONTAINER_NAME} bash"
echo "3. Inside container: source /ros2_ws/install/setup.bash && ros2 run realsense2_camera realsense2_camera_node"
