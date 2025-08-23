#!/bin/bash

# UP Nginx Deployment Script
# This script deploys nginx configuration to /opt/up/nginx

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for non-interactive mode (CI/CD environment)
FORCE_YES=false
if [[ "$CI" == "true" ]] || [[ "$GITHUB_ACTIONS" == "true" ]] || [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
    FORCE_YES=true
    print_status "Running in non-interactive mode"
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root. Use sudo when needed."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Starting UP Nginx deployment..."

# Set target directory
TARGET_DIR="/opt/up/nginx"
print_status "Target directory: $TARGET_DIR"

# В CI/CD режиме мы уже в правильной директории с правильными правами
if [[ "$FORCE_YES" == "true" ]]; then
    print_status "CI/CD mode: working in current directory $(pwd)"
    
    # Проверяем, что мы в правильной директории
    if [[ "$(pwd)" != "$TARGET_DIR" ]]; then
        print_error "Expected to be in $TARGET_DIR, but currently in $(pwd)"
        exit 1
    fi
    
    # Проверяем права доступа к директории
    if [[ ! -w "$TARGET_DIR" ]]; then
        print_error "No write permission to $TARGET_DIR"
        exit 1
    fi
else
    # В локальном режиме проверяем/создаем директорию
    if [[ -d "$TARGET_DIR" ]]; then
        print_warning "Directory $TARGET_DIR already exists."
        read -p "Do you want to continue and overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled."
            exit 0
        fi
    fi
    
    # В локальном режиме создаем директорию с sudo
    if [[ ! -d "$TARGET_DIR" ]]; then
        sudo mkdir -p "$TARGET_DIR"
    fi
    
    # Copy configuration files
    print_status "Copying nginx configuration files..."
    sudo cp -r ./* "$TARGET_DIR/"
    sudo chown -R root:root "$TARGET_DIR"
    sudo chmod +x "$TARGET_DIR/deploy.sh"
    sudo chmod +x "$TARGET_DIR/init-letsencrypt.sh"
    
    # Create TLS directory
    print_status "Creating TLS directory..."
    sudo mkdir -p "$TARGET_DIR/tls"
    
    # Change to target directory
    cd "$TARGET_DIR"
fi

# Create TLS directory if it doesn't exist
if [[ ! -d "tls" ]]; then
    print_status "Creating TLS directory..."
    mkdir -p tls
fi

# Create Docker network
print_status "Creating Docker network 'up_network'..."
if docker network inspect up_network >/dev/null 2>&1; then
    print_warning "Network 'up_network' already exists."
else
    docker network create up_network
    print_status "Docker network 'up_network' created."
fi

# Create external volume for frontend static files
print_status "Creating external volume for frontend static files..."
if docker volume inspect frontend_dist >/dev/null 2>&1; then
    print_warning "Volume 'frontend_dist' already exists."
else
    docker volume create frontend_dist
    print_status "Volume 'frontend_dist' created."
fi

# Start services
print_status "Starting nginx services..."

# Stop existing services first
print_status "Stopping existing services..."
docker compose down

# Pull latest images
print_status "Pulling latest images..."
docker compose pull

# Start services with build
print_status "Starting services with build..."
docker compose up -d --build

# Check if services are running
print_status "Checking service status..."
sleep 5

if docker compose ps | grep -q "Up"; then
    print_status "✅ Nginx services are running successfully!"
    print_status "You can check the status with: docker compose ps"
    print_status "View logs with: docker logs up_nginx"
else
    print_error "❌ Some services failed to start. Check logs with: docker compose logs"
    exit 1
fi

# Display useful information
print_status "🎉 Deployment completed successfully!"
echo

if [[ "$FORCE_YES" != "true" ]]; then
    print_status "Next steps:"
    print_status "1. Configure TLS certificates:"
    print_status "   cd $TARGET_DIR && sudo ./init-letsencrypt.sh"
    print_status "2. Build and deploy your frontend:"
    print_status "   cd ../frontend && docker compose -f docker-compose.yml up --build -d"
    print_status "3. Make sure your backend is running with the same 'up_network'"
    print_status "4. Update your DNS to point to this server:"
    print_status "   24up.dev → your-server-ip"
    print_status "   www.24up.dev → your-server-ip"
    print_status "   api.24up.dev → your-server-ip"
    print_status "   www.api.24up.dev → your-server-ip"
    echo
    print_status "Architecture:"
    print_status "  - Frontend: Builds static files into 'frontend_dist' volume"
    print_status "  - Nginx: Serves static files and proxies API to backend"
    print_status "  - Backend: Runs separately in same Docker network"
    print_status "  - TLS: Configure manually with init-letsencrypt.sh"
    echo
    print_status "Useful commands:"
    print_status "  View status: cd $TARGET_DIR && sudo docker compose ps"
    print_status "  View logs: sudo docker logs up_nginx"
    print_status "  Restart: cd $TARGET_DIR && sudo docker compose restart"
    print_status "  Stop: cd $TARGET_DIR && sudo docker compose down"
    print_status "  Setup TLS: cd $TARGET_DIR && sudo ./init-letsencrypt.sh"
fi 