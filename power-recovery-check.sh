#!/bin/bash
# SkateHive Mac Mini Power Recovery & Health Check Script
# This script ensures all services are running after power outages/reboots

# Auto-detect monorepo root (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"

LOG_FILE="$MONOREPO_ROOT/power-recovery.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] 🔋 SkateHive Power Recovery Check Started" | tee -a "$LOG_FILE"
echo "[$TIMESTAMP] 📁 Monorepo root: $MONOREPO_ROOT" | tee -a "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Function to check if a service is responding
check_service() {
    local name="$1"
    local url="$2"
    local timeout="${3:-10}"
    
    log "🔍 Checking $name..."
    
    if curl -s --max-time "$timeout" "$url" >/dev/null 2>&1; then
        log "✅ $name is responding"
        return 0
    else
        log "❌ $name is not responding"
        return 1
    fi
}

# Function to wait for Docker to be ready
wait_for_docker() {
    log "🐳 Waiting for Docker to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker info >/dev/null 2>&1; then
            log "✅ Docker is ready"
            return 0
        fi
        log "⏳ Docker not ready yet (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log "❌ Docker failed to start within expected time"
    return 1
}

# Function to check and restart containers
check_containers() {
    log "🐳 Checking Docker containers..."
    
    # Check video transcoder
    if docker ps | grep -q "skatehive-video-transcoder"; then
        log "✅ Video transcoder container is running"
    else
        log "⚠️ Video transcoder container not running, attempting to start..."
        cd "$MONOREPO_ROOT/skatehive-video-transcoder"
        docker-compose up -d
    fi
    
    # Check Instagram downloader
    if docker ps | grep -q "ytipfs-worker"; then
        log "✅ Instagram downloader container is running"
    else
        log "⚠️ Instagram downloader container not running, attempting to start..."
        cd "$MONOREPO_ROOT/skatehive-instagram-downloader/ytipfs-worker"
        docker-compose up -d
    fi
}

# Function to check Tailscale and enable Funnel
check_tailscale() {
    log "🔗 Checking Tailscale connectivity..."
    
    # Check if Tailscale is running
    if pgrep -f "Tailscale" >/dev/null; then
        log "✅ Tailscale is running"
        
        # Wait a bit for network to be ready
        sleep 10
        
        # Check and re-enable Funnel if needed
        log "🌐 Checking Tailscale Funnel status..."
        funnel_status=$(/Applications/Tailscale.app/Contents/MacOS/Tailscale funnel status 2>&1)
        
        if echo "$funnel_status" | grep -q "minivlad.tail9656d3.ts.net"; then
            log "✅ Tailscale Funnel is configured"
        else
            log "⚠️ Tailscale Funnel not configured, setting up..."
            /Applications/Tailscale.app/Contents/MacOS/Tailscale funnel --bg --set-path=/video 8081
            /Applications/Tailscale.app/Contents/MacOS/Tailscale funnel --bg --set-path=/instagram 6666
            log "✅ Tailscale Funnel configured"
        fi
    else
        log "❌ Tailscale is not running"
        log "🔄 Attempting to start Tailscale..."
        open /Applications/Tailscale.app
        sleep 15
    fi
}

# Main execution
log "🚀 Starting power recovery sequence..."

# Wait a bit for system to fully boot
sleep 30

# Check Docker first
if wait_for_docker; then
    # Check containers
    check_containers
    
    # Wait for containers to start
    sleep 15
    
    # Check Tailscale
    check_tailscale
    
    # Wait for Tailscale to be ready
    sleep 20
    
    # Test external services
    log "🧪 Testing external service accessibility..."
    
    if check_service "Mac Mini Video (External)" "https://minivlad.tail9656d3.ts.net/video/healthz" 15; then
        if check_service "Mac Mini Instagram (External)" "https://minivlad.tail9656d3.ts.net/instagram/health" 15; then
            log "🎉 All services are running and accessible externally!"
            log "🌟 SkateHive Mac Mini is ready to serve as primary server"
        else
            log "⚠️ Instagram service may need more time to start"
        fi
    else
        log "⚠️ Video service may need more time to start"
    fi
    
    # Test local services as backup
    log "🏠 Testing local service accessibility..."
    check_service "Video (Local)" "http://localhost:8081/healthz" 5
    check_service "Instagram (Local)" "http://localhost:6666/health" 5
    
else
    log "❌ Docker failed to start - manual intervention required"
fi

log "🔋 Power recovery check completed"
echo "[$TIMESTAMP] 📋 Check logs at: $LOG_FILE"

# Optional: Send status to dashboard or notification service
# You could add webhook calls here to notify that the system is back online