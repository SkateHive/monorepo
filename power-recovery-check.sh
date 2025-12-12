#!/bin/bash
# SkateHive Power Recovery & Health Check Script
# This script ensures all services are running after power outages/reboots

# Auto-detect monorepo root (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"

# Load configuration
source "$MONOREPO_ROOT/load-config.sh"

LOG_FILE="$MONOREPO_ROOT/power-recovery.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] 🔋 SkateHive Power Recovery Check Started" | tee -a "$LOG_FILE"
echo "[$TIMESTAMP] 📁 Node: $NODE_NAME ($NODE_ROLE)" | tee -a "$LOG_FILE"
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
    
    # Determine Tailscale binary path
    if [[ "$OSTYPE" == "darwin"* ]]; then
        TAILSCALE_BIN="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    else
        TAILSCALE_BIN="tailscale"
    fi
    
    # Check if Tailscale is running
    if pgrep -f "Tailscale\|tailscaled" >/dev/null; then
        log "✅ Tailscale is running"
        
        # Wait a bit for network to be ready
        sleep 10
        
        # Check and re-enable Funnel if needed
        log "🌐 Checking Tailscale Funnel status..."
        funnel_status=$($TAILSCALE_BIN funnel status 2>&1)
        
        if [ -n "$TAILSCALE_HOSTNAME" ] && echo "$funnel_status" | grep -q "$TAILSCALE_HOSTNAME"; then
            log "✅ Tailscale Funnel is configured"
        else
            log "⚠️ Tailscale Funnel not configured, setting up..."
            $TAILSCALE_BIN funnel --bg --set-path="$VIDEO_FUNNEL_PATH" "$VIDEO_TRANSCODER_PORT"
            $TAILSCALE_BIN funnel --bg --set-path="$INSTAGRAM_FUNNEL_PATH" "$INSTAGRAM_DOWNLOADER_PORT"
            log "✅ Tailscale Funnel configured"
        fi
    else
        log "❌ Tailscale is not running"
        log "🔄 Attempting to start Tailscale..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open /Applications/Tailscale.app
        else
            sudo systemctl start tailscaled 2>/dev/null || true
        fi
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
    if [ -n "$VIDEO_EXTERNAL_URL" ]; then
        log "🧪 Testing external service accessibility..."
        
        if check_service "$NODE_NAME Video (External)" "$VIDEO_EXTERNAL_URL/healthz" 15; then
            if check_service "$NODE_NAME Instagram (External)" "$INSTAGRAM_EXTERNAL_URL/health" 15; then
                log "🎉 All services are running and accessible externally!"
                log "🌟 SkateHive $NODE_NAME is ready to serve as $NODE_ROLE server"
            else
                log "⚠️ Instagram service may need more time to start"
            fi
        else
            log "⚠️ Video service may need more time to start"
        fi
    fi
    
    # Test local services as backup
    log "🏠 Testing local service accessibility..."
    check_service "Video (Local)" "$VIDEO_LOCAL_URL/healthz" 5
    check_service "Instagram (Local)" "$INSTAGRAM_LOCAL_URL/health" 5
    
else
    log "❌ Docker failed to start - manual intervention required"
fi

log "🔋 Power recovery check completed"
echo "[$TIMESTAMP] 📋 Check logs at: $LOG_FILE"

# Optional: Send status to dashboard or notification service
# You could add webhook calls here to notify that the system is back online