#!/bin/bash
set -e

# Build script for T265 ROS2 Docker image
# Enhanced for Docker Hub deployment with better practices

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="t265-ros2-docker"
TAG="latest"
DOCKER_USERNAME=""
PLATFORM="linux/amd64"
BUILD_ARGS=""
PUSH_TO_HUB=false
NO_CACHE=false

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
    echo "  -t, --tag TAG           Docker image tag (default: latest)"
    echo "  -n, --name NAME         Docker image name (default: t265-ros2-docker)"
    echo "  -u, --username USER     Docker Hub username (for tagging)"
    echo "  -p, --platform PLATFORM Target platform (default: linux/amd64)"
    echo "  --push                  Push to Docker Hub after build"
    echo "  --no-cache              Build without using cache"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Basic build"
    echo "  $0 -u myuser --push                  # Build and push to Docker Hub"
    echo "  $0 -t v1.0 --no-cache               # Build with version tag, no cache"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -u|--username)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        --push)
            PUSH_TO_HUB=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
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

# Validate Docker Hub push requirements
if [[ "$PUSH_TO_HUB" == true && -z "$DOCKER_USERNAME" ]]; then
    print_error "Docker Hub username is required when using --push"
    show_usage
    exit 1
fi

# Set build arguments
if [[ "$NO_CACHE" == true ]]; then
    BUILD_ARGS="$BUILD_ARGS --no-cache"
fi

# Determine final image name
if [[ -n "$DOCKER_USERNAME" ]]; then
    FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="$IMAGE_NAME"
fi

print_status "Building T265 ROS2 Docker image..."
print_status "Configuration:"
echo "  Image: ${FULL_IMAGE_NAME}:${TAG}"
echo "  Platform: ${PLATFORM}"
echo "  Push to Hub: ${PUSH_TO_HUB}"
echo "  Use cache: $([[ "$NO_CACHE" == true ]] && echo "No" || echo "Yes")"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running or not accessible"
    exit 1
fi

# Build the Docker image
print_status "Starting Docker build..."
docker build \
    --platform="${PLATFORM}" \
    --tag "${FULL_IMAGE_NAME}:${TAG}" \
    --tag "${FULL_IMAGE_NAME}:latest" \
    $BUILD_ARGS \
    .

if [[ $? -eq 0 ]]; then
    print_success "Build completed successfully!"
else
    print_error "Build failed!"
    exit 1
fi

# Add additional tags for Docker Hub
if [[ -n "$DOCKER_USERNAME" ]]; then
    print_status "Adding additional tags..."
    # Only create latest and version tags - no foxy variants
fi

# Show image information
print_status "Image information:"
docker images "${FULL_IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Push to Docker Hub if requested
if [[ "$PUSH_TO_HUB" == true ]]; then
    print_status "Pushing to Docker Hub..."
    
    # Login check
    if ! docker info | grep -q "Username"; then
        print_warning "Not logged into Docker Hub. Please login:"
        docker login
    fi
    
    # Push all tags
    docker push "${FULL_IMAGE_NAME}:${TAG}"
    docker push "${FULL_IMAGE_NAME}:latest"
    docker push "${FULL_IMAGE_NAME}:foxy"
    
    if [[ "$TAG" != "latest" ]]; then
        docker push "${FULL_IMAGE_NAME}:${TAG}-foxy"
    fi
    
    print_success "Successfully pushed to Docker Hub!"
    echo ""
    echo "Available at:"
    echo "  docker pull ${FULL_IMAGE_NAME}:latest"
    echo "  docker pull ${FULL_IMAGE_NAME}:${TAG}"
    echo "  docker pull ${FULL_IMAGE_NAME}:foxy"
fi

print_success "Build process completed!"
echo ""
echo "To run the container:"
echo "  ./scripts/run.sh -i ${FULL_IMAGE_NAME}"
echo ""
echo "To test the container:"
echo "  ./scripts/test.sh"
