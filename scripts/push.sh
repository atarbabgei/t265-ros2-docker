#!/bin/bash
set -e

# Docker Hub push script for T265 ROS2 Docker image
# Enhanced for better Docker Hub deployment workflow

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="t265-ros2-docker"
DOCKER_USERNAME=""
VERSION="1.0"
DRY_RUN=false
SKIP_LOGIN=false

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
    echo "Usage: $0 -u USERNAME [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -u, --username USER    Docker Hub username"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION  Version tag (default: 1.0)"
    echo "  -i, --image IMAGE      Local image name (default: t265-ros2-docker)"
    echo "  --dry-run              Show what would be pushed without actually pushing"
    echo "  --skip-login           Skip Docker Hub login (assume already logged in)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -u myuser                          # Push with default version"
    echo "  $0 -u myuser -v 2.0                   # Push with specific version"
    echo "  $0 -u myuser --dry-run                # Preview push without executing"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-login)
            SKIP_LOGIN=true
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

# Validate required arguments
if [[ -z "$DOCKER_USERNAME" ]]; then
    print_error "Docker Hub username is required!"
    show_usage
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running or not accessible"
    exit 1
fi

REPO_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"
LOCAL_IMAGE="${IMAGE_NAME}:latest"

print_status "Docker Hub Push Configuration"
print_status "Local image: ${LOCAL_IMAGE}"
print_status "Repository: ${REPO_NAME}"
print_status "Version: ${VERSION}"
print_status "Dry run: ${DRY_RUN}"
echo ""

# Check if local image exists
if ! docker image inspect "${LOCAL_IMAGE}" > /dev/null 2>&1; then
    print_error "Local image ${LOCAL_IMAGE} not found!"
    echo ""
    echo "Build the image first:"
    echo "  ./scripts/build.sh"
    echo ""
    echo "Or build with specific username:"
    echo "  ./scripts/build.sh -u ${DOCKER_USERNAME}"
    exit 1
fi

# Show image information
print_status "Local image information:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""

# Prepare tags
TAGS=(
    "${REPO_NAME}:latest"
    "${REPO_NAME}:${VERSION}"
)

# Tag the images
print_status "Tagging images for Docker Hub..."
for tag in "${TAGS[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would tag: ${LOCAL_IMAGE} -> ${tag}"
    else
        print_status "Tagging: ${LOCAL_IMAGE} -> ${tag}"
        docker tag "${LOCAL_IMAGE}" "${tag}"
    fi
done
echo ""

# Login to Docker Hub
if [[ "$SKIP_LOGIN" == false ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would login to Docker Hub"
    else
        print_status "Checking Docker Hub login status..."
        if ! docker info 2>/dev/null | grep -q "Username: ${DOCKER_USERNAME}"; then
            print_warning "Not logged in as ${DOCKER_USERNAME}. Please login:"
            docker login
        else
            print_success "Already logged in as ${DOCKER_USERNAME}"
        fi
    fi
fi

# Push the images
print_status "Pushing images to Docker Hub..."
for tag in "${TAGS[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would push: ${tag}"
    else
        print_status "Pushing: ${tag}"
        if docker push "${tag}"; then
            print_success "Successfully pushed: ${tag}"
        else
            print_error "Failed to push: ${tag}"
            exit 1
        fi
    fi
done

if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN completed - no images were actually pushed"
    echo ""
    echo "To actually push, run:"
    echo "  $0 -u ${DOCKER_USERNAME} -v ${VERSION}"
else
    print_success "All images pushed successfully to Docker Hub!"
fi

echo ""
print_status "Docker Hub Repository: https://hub.docker.com/r/${REPO_NAME}"
echo ""
print_status "Available tags:"
for tag in "${TAGS[@]}"; do
    echo "  ${tag}"
done

echo ""
print_status "Usage examples:"
echo "  docker pull ${REPO_NAME}:latest"
echo "  docker pull ${REPO_NAME}:${VERSION}"
echo ""
echo "  docker run -it --rm --privileged -v /dev:/dev ${REPO_NAME}:latest"

# Show next steps
if [[ "$DRY_RUN" == false ]]; then
    echo ""
    print_status "Next steps:"
    echo "1. Update Docker Hub repository description with DOCKER_HUB_README.md"
    echo "2. Add repository topics: ros2, realsense, t265, docker, robotics"
    echo "3. Test the published image: docker run -it --rm --privileged -v /dev:/dev ${REPO_NAME}:latest"
fi
