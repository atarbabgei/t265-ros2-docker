#!/bin/bash
set -e

# Run script for T265 ROS2 Docker container
# Enhanced for better Docker Hub integration and user experience

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="t265-ros2-docker"
TAG="latest"
CONTAINER_NAME="t265-ros2"
RUN_MODE="interactive"
AUTO_PULL=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --image IMAGE      Docker image name (default: t265-ros2-docker)"
    echo "  -t, --tag TAG          Docker image tag (default: latest)"
    echo "  -n, --name NAME        Container name (default: t265-ros2)"
    echo "  -d, --detached         Run in detached mode"
    echo "  --pull                 Pull image before running"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run local image interactively"
    echo "  $0 -i myuser/t265-ros2-docker --pull # Pull and run from Docker Hub"
    echo "  $0 -d                                # Run in detached mode"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -d|--detached)
            RUN_MODE="detached"
            shift
            ;;
        --pull)
            AUTO_PULL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Handle image name with or without tag
if [[ "$IMAGE_NAME" == *":"* ]]; then
    FULL_IMAGE_NAME="$IMAGE_NAME"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"
fi

print_status "Starting T265 ROS2 Docker container..."
print_status "Configuration:"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "  Container: ${CONTAINER_NAME}"
echo "  Mode: ${RUN_MODE}"
echo ""

# Pull image if requested
if [[ "$AUTO_PULL" == true ]]; then
    print_status "Pulling image: ${FULL_IMAGE_NAME}"
    if docker pull "${FULL_IMAGE_NAME}"; then
        print_success "Image pulled successfully"
    else
        print_error "Failed to pull image"
        exit 1
    fi
fi

# Check if image exists
if ! docker image inspect "${FULL_IMAGE_NAME}" > /dev/null 2>&1; then
    print_error "Docker image ${FULL_IMAGE_NAME} not found!"
    echo ""
    echo "Options:"
    echo "1. Build locally: ./scripts/build.sh"
    echo "2. Pull from Docker Hub: $0 --pull -i <username>/t265-ros2-docker"
    exit 1
fi

# Stop existing container if running
if docker ps -q -f name="${CONTAINER_NAME}" | grep -q .; then
    print_warning "Stopping existing container: ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" > /dev/null
fi

# Remove existing container if exists
if docker ps -aq -f name="${CONTAINER_NAME}" | grep -q .; then
    print_warning "Removing existing container: ${CONTAINER_NAME}"
    docker rm "${CONTAINER_NAME}" > /dev/null
fi

# Set environment variables for cross-distribution communication
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE=/dev/null

print_status "Environment variables:"
echo "  ROS_DOMAIN_ID=${ROS_DOMAIN_ID}"
echo "  RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION}"
echo "  FASTRTPS_DEFAULT_PROFILES_FILE=${FASTRTPS_DEFAULT_PROFILES_FILE}"
echo ""

# Prepare Docker run arguments
DOCKER_ARGS=(
    --name "${CONTAINER_NAME}"
    --privileged
    -v /dev:/dev
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw
    -v /run/udev:/run/udev:ro
    --device-cgroup-rule="c 81:* rmw"
    --device-cgroup-rule="c 189:* rmw"
    -e DISPLAY="${DISPLAY}"
    -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID}"
    -e RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION}"
    -e FASTRTPS_DEFAULT_PROFILES_FILE="${FASTRTPS_DEFAULT_PROFILES_FILE}"
)

# Set run mode specific arguments
if [[ "$RUN_MODE" == "detached" ]]; then
    DOCKER_ARGS+=(-d)
    CMD_ARGS=("tail" "-f" "/dev/null")
    print_status "Starting container in detached mode..."
else
    DOCKER_ARGS+=(-it --rm)
    CMD_ARGS=("bash")
    print_status "Starting container in interactive mode..."
fi

# Run the container
print_status "Executing: docker run ${DOCKER_ARGS[*]} ${FULL_IMAGE_NAME} ${CMD_ARGS[*]}"
echo ""

if docker run "${DOCKER_ARGS[@]}" "${FULL_IMAGE_NAME}" "${CMD_ARGS[@]}"; then
    if [[ "$RUN_MODE" == "detached" ]]; then
        print_success "Container started successfully in detached mode"
        echo ""
        echo "To access the container:"
        echo "  docker exec -it ${CONTAINER_NAME} bash"
        echo ""
        echo "To stop the container:"
        echo "  docker stop ${CONTAINER_NAME}"
        echo ""
        echo "To run tests:"
        echo "  ./scripts/test.sh"
    fi
else
    print_error "Failed to start container"
    exit 1
fi
