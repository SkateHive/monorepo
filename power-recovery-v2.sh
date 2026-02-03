#!/bin/bash
# SkateHive Power Recovery v2 - Improved by Zezinho 🦎
# Robust startup after power outages with proper Docker wait

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"
LOG_FILE="$MONOREPO_ROOT/power-recovery.log"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

log "🔋 SkateHive Power Recovery v2 Started"

# Load configuration if exists
if [[ -f "$MONOREPO_ROOT/load-config.sh" ]]; then
    source "$MONOREPO_ROOT/load-config.sh"
    log "📁 Node: ${NODE_NAME:-unknown} (${NODE_ROLE:-unknown})"
fi

# ============================================
# PHASE 1: Wait for Docker Desktop to be ready
# ============================================
wait_for_docker() {
    local max_wait=180  # 3 minutes max
    local waited=0
    local interval=5
    
    log "🐳 Phase 1: Waiting for Docker Desktop..."
    
    # First, ensure Docker app is launched
    if ! pgrep -x "Docker" >/dev/null 2>&1; then
        log "🚀 Docker not running, launching..."
        open -a Docker --background
        sleep 10
    fi
    
    # Wait for docker daemon to respond
    while [[ $waited -lt $max_wait ]]; do
        if docker info >/dev/null 2>&1; then
            log "✅ Docker is ready (waited ${waited}s)"
            return 0
        fi
        
        log "⏳ Docker starting... (${waited}s/${max_wait}s)"
        sleep $interval
        waited=$((waited + interval))
    done
    
    log "❌ Docker failed to start within ${max_wait}s"
    return 1
}

# ============================================
# PHASE 2: Start containers
# ============================================
start_containers() {
    log "🐳 Phase 2: Starting containers..."
    
    # Video Transcoder
    if ! docker ps --format '{{.Names}}' | grep -q "video-worker"; then
        log "🎬 Starting video-worker..."
        cd "$MONOREPO_ROOT/skatehive-video-transcoder"
        docker compose up -d 2>&1 | tee -a "$LOG_FILE" || true
    else
        log "✅ video-worker already running"
    fi
    
    # Instagram Downloader
    if ! docker ps --format '{{.Names}}' | grep -q "ytipfs-worker"; then
        log "📸 Starting ytipfs-worker..."
        cd "$MONOREPO_ROOT/skatehive-instagram-downloader/ytipfs-worker"
        docker compose up -d 2>&1 | tee -a "$LOG_FILE" || true
    else
        log "✅ ytipfs-worker already running"
    fi
    
    # MongoDB (if separate)
    if ! docker ps --format '{{.Names}}' | grep -q "mongo"; then
        log "🗄️ Starting MongoDB..."
        # Add mongo start command if needed
    else
        log "✅ MongoDB already running"
    fi
    
    # Wait for containers to be healthy
    sleep 10
}

# ============================================
# PHASE 3: Verify Tailscale
# ============================================
verify_tailscale() {
    log "🔗 Phase 3: Verifying Tailscale..."
    
    local TAILSCALE_BIN="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    
    if ! pgrep -f "Tailscale" >/dev/null 2>&1; then
        log "🚀 Starting Tailscale..."
        open -a Tailscale
        sleep 15
    fi
    
    if $TAILSCALE_BIN status >/dev/null 2>&1; then
        log "✅ Tailscale connected"
        
        # Verify Funnel is configured
        local funnel_status=$($TAILSCALE_BIN funnel status 2>&1 || true)
        if echo "$funnel_status" | grep -q "443"; then
            log "✅ Tailscale Funnel active"
        else
            log "⚠️ Funnel may need manual setup"
        fi
    else
        log "⚠️ Tailscale not connected - check manually"
    fi
}

# ============================================
# PHASE 4: Health checks
# ============================================
health_checks() {
    log "🏥 Phase 4: Running health checks..."
    
    local all_ok=true
    
    # Video transcoder
    if curl -sf --max-time 10 "http://localhost:8081/healthz" >/dev/null 2>&1; then
        log "✅ Video transcoder healthy"
    else
        log "❌ Video transcoder not responding"
        all_ok=false
    fi
    
    # Instagram downloader
    if curl -sf --max-time 10 "http://localhost:6666/healthz" >/dev/null 2>&1; then
        log "✅ Instagram downloader healthy"
    else
        log "❌ Instagram downloader not responding"
        all_ok=false
    fi
    
    # MongoDB
    if docker exec mongo_vsc mongosh --eval "db.runCommand('ping')" >/dev/null 2>&1; then
        log "✅ MongoDB healthy"
    else
        log "⚠️ MongoDB check skipped or failed"
    fi
    
    if $all_ok; then
        log "🎉 All services healthy!"
    else
        log "⚠️ Some services need attention"
    fi
}

# ============================================
# MAIN EXECUTION
# ============================================
main() {
    # Initial delay for system boot (only on fresh boot, not periodic check)
    if [[ "${1:-}" == "--boot" ]]; then
        log "💤 Boot mode: waiting 45s for system to stabilize..."
        sleep 45
    fi
    
    if wait_for_docker; then
        start_containers
        verify_tailscale
        sleep 5
        health_checks
    else
        log "❌ Cannot proceed without Docker - manual intervention required"
        exit 1
    fi
    
    log "🔋 Power recovery complete"
}

main "$@"
