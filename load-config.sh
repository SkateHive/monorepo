#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SkateHive Configuration Loader
# Source this file at the top of any script to load configuration
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/load-config.sh"
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-detect monorepo root
if [ -z "$MONOREPO_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"
fi

# Config file path
CONFIG_FILE="$MONOREPO_ROOT/skatehive.config"

# Load configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    SKATEHIVE_CONFIG_LOADED=true
else
    SKATEHIVE_CONFIG_LOADED=false
    
    # Set sensible defaults
    NODE_NAME="${NODE_NAME:-$(hostname)}"
    NODE_ROLE="${NODE_ROLE:-primary}"
    VIDEO_TRANSCODER_PORT="${VIDEO_TRANSCODER_PORT:-8081}"
    INSTAGRAM_DOWNLOADER_PORT="${INSTAGRAM_DOWNLOADER_PORT:-6666}"
    ACCOUNT_MANAGER_PORT="${ACCOUNT_MANAGER_PORT:-3001}"
    VIDEO_FUNNEL_PATH="${VIDEO_FUNNEL_PATH:-/video}"
    INSTAGRAM_FUNNEL_PATH="${INSTAGRAM_FUNNEL_PATH:-/instagram}"
    
    # Try to auto-detect Tailscale hostname
    if [ -z "$TAILSCALE_HOSTNAME" ] && command -v tailscale &> /dev/null; then
        TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
    fi
fi

# Computed values
if [ -n "$TAILSCALE_HOSTNAME" ]; then
    VIDEO_EXTERNAL_URL="https://$TAILSCALE_HOSTNAME$VIDEO_FUNNEL_PATH"
    INSTAGRAM_EXTERNAL_URL="https://$TAILSCALE_HOSTNAME$INSTAGRAM_FUNNEL_PATH"
else
    VIDEO_EXTERNAL_URL=""
    INSTAGRAM_EXTERNAL_URL=""
fi

VIDEO_LOCAL_URL="http://localhost:$VIDEO_TRANSCODER_PORT"
INSTAGRAM_LOCAL_URL="http://localhost:$INSTAGRAM_DOWNLOADER_PORT"
ACCOUNT_MANAGER_LOCAL_URL="http://localhost:$ACCOUNT_MANAGER_PORT"

# Export for child processes
export MONOREPO_ROOT
export NODE_NAME
export NODE_ROLE
export TAILSCALE_HOSTNAME
export VIDEO_TRANSCODER_PORT
export INSTAGRAM_DOWNLOADER_PORT
export ACCOUNT_MANAGER_PORT
export VIDEO_FUNNEL_PATH
export INSTAGRAM_FUNNEL_PATH
export VIDEO_EXTERNAL_URL
export INSTAGRAM_EXTERNAL_URL
export VIDEO_LOCAL_URL
export INSTAGRAM_LOCAL_URL
export ACCOUNT_MANAGER_LOCAL_URL
export VIDEO_LOCAL_URL
export INSTAGRAM_LOCAL_URL
