#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  🛹 SkateHive Node Setup Script
# ═══════════════════════════════════════════════════════════════════════════════
#  Interactive installer for SkateHive infrastructure nodes
#  Works on macOS and Linux (Raspberry Pi, Ubuntu, etc.)
# ═══════════════════════════════════════════════════════════════════════════════

# Don't exit on error for interactive script
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/skatehive.config"
CONFIG_EXAMPLE="$SCRIPT_DIR/skatehive.config.example"

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  ${BOLD}🛹 SkateHive Node Setup${NC}                                      ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}     Decentralized Skateboarding Infrastructure               ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Progress indicator for long operations
progress() {
    local msg="$1"
    echo -e -n "${CYAN}⟳${NC} $msg..."
}

progress_done() {
    echo -e " ${GREEN}done${NC}"
}

progress_fail() {
    echo -e " ${RED}failed${NC}"
}

# Spinner for background tasks
spin() {
    local pid=$1
    local msg="${2:-Processing}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo -e -n "${CYAN}${msg}${NC} "
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#spinstr} ))
        printf "\r${CYAN}${msg}${NC} ${spinstr:$i:1}"
        sleep 0.1
    done
    printf "\r${CYAN}${msg}${NC}  \n"
}

# Check with timeout and progress
check_with_progress() {
    local name="$1"
    local cmd="$2"
    local timeout="${3:-10}"
    
    echo -e -n "  Checking $name... "
    
    if timeout $timeout bash -c "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

ask() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        printf "${BOLD}%s${NC} [${CYAN}%s${NC}]: " "$prompt" "$default" >&2
        read -r result </dev/tty
        result="${result:-$default}"
    else
        printf "${BOLD}%s${NC}: " "$prompt" >&2
        read -r result </dev/tty
    fi
    echo "$result"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local result
    
    if [ "$default" = "y" ]; then
        printf "${BOLD}%s${NC} [${CYAN}Y/n${NC}]: " "$prompt" >&2
    else
        printf "${BOLD}%s${NC} [${CYAN}y/N${NC}]: " "$prompt" >&2
    fi
    
    read -r result </dev/tty
    result="${result:-$default}"
    
    [[ "$result" =~ ^[Yy] ]]
}

ask_secret() {
    local prompt="$1"
    local result
    
    printf "${BOLD}%s${NC}: " "$prompt" >&2
    read -rs result </dev/tty
    echo "" >&2
    echo "$result"
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "raspbian" ]] || [[ "$ID" == "debian" && $(uname -m) == "armv"* ]]; then
            echo "raspberrypi"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Dependency Checks
# ═══════════════════════════════════════════════════════════════════════════════

check_dependencies() {
    print_step "Step 1/7: Checking Dependencies"
    
    local missing=()
    local checks=("git" "curl" "jq" "docker" "docker-compose" "tailscale" "node" "pnpm")
    local total=${#checks[@]}
    local current=0
    
    echo "Checking $total dependencies..."
    echo ""
    
    # Check for required tools
    for cmd in git curl jq; do
        ((current++))
        printf "  [%d/%d] %-20s " "$current" "$total" "$cmd"
        if command -v $cmd &> /dev/null; then
            echo -e "${GREEN}✓ installed${NC}"
        else
            echo -e "${RED}✗ missing${NC}"
            missing+=("$cmd")
        fi
    done
    
    # Check Docker
    ((current++))
    printf "  [%d/%d] %-20s " "$current" "$total" "docker"
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            echo -e "${GREEN}✓ running${NC}"
        else
            echo -e "${YELLOW}⚠ not running${NC}"
            if ask_yes_no "  Start Docker now?"; then
                if [[ "$(detect_os)" == "macos" ]]; then
                    open /Applications/Docker.app
                    echo -e -n "  Waiting for Docker to start..."
                    for i in {1..30}; do
                        sleep 1
                        echo -n "."
                        if docker info &> /dev/null; then
                            echo -e " ${GREEN}ready!${NC}"
                            break
                        fi
                    done
                else
                    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
                fi
            fi
        fi
    else
        echo -e "${RED}✗ not installed${NC}"
        missing+=("docker")
    fi
    
    # Check docker-compose
    ((current++))
    printf "  [%d/%d] %-20s " "$current" "$total" "docker-compose"
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ available${NC}"
    else
        echo -e "${RED}✗ missing${NC}"
        missing+=("docker-compose")
    fi
    
    # Check Tailscale
    ((current++))
    printf "  [%d/%d] %-20s " "$current" "$total" "tailscale"
    if command -v tailscale &> /dev/null; then
        if tailscale status &> /dev/null; then
            echo -e "${GREEN}✓ connected${NC}"
        else
            echo -e "${YELLOW}⚠ not connected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ not installed (optional)${NC}"
    fi
    
    # Check Node.js (optional)
    ((current++))
    printf "  [%d/%d] %-20s " "$current" "$total" "node"
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        echo -e "${GREEN}✓ $node_version${NC}"
    else
        echo -e "${YELLOW}⚠ not installed (optional)${NC}"
    fi
    
    # Check pnpm (optional)
    ((current++))
    printf "  [%d/%d] %-20s " "$current" "$total" "pnpm"
    if command -v pnpm &> /dev/null; then
        echo -e "${GREEN}✓ installed${NC}"
    else
        echo -e "${YELLOW}⚠ not installed (npm i -g pnpm)${NC}"
    fi
    
    echo ""
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "  Install them and run this script again."
        echo ""
        
        # Offer installation guidance
        for dep in "${missing[@]}"; do
            case "$dep" in
                "git")
                    info "  Git: brew install git (macOS) or apt install git (Linux)"
                    ;;
                "curl")
                    info "  Curl: brew install curl (macOS) or apt install curl (Linux)"
                    ;;
                "jq")
                    info "  jq: brew install jq (macOS) or apt install jq (Linux)"
                    ;;
                "docker")
                    info "  Docker: https://docs.docker.com/get-docker/"
                    ;;
                "docker-compose")
                    info "  Docker Compose: Included with Docker Desktop, or: apt install docker-compose"
                    ;;
            esac
        done
        exit 1
    fi
    
    success "All required dependencies installed!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

configure_node() {
    print_step "Step 2/7: Node Configuration"
    
    # Check if config already exists
    if [ -f "$CONFIG_FILE" ]; then
        warn "Configuration file already exists: $CONFIG_FILE"
        if ! ask_yes_no "Overwrite existing configuration?"; then
            info "Keeping existing configuration"
            return
        fi
    fi
    
    echo "Let's configure your SkateHive node!"
    echo ""
    
    # Node name
    local default_name=$(hostname | tr '[:upper:]' '[:lower:]')
    NODE_NAME=$(ask "Node name" "$default_name")
    
    # Node role
    echo ""
    echo "Node roles:"
    echo "  1) primary   - Main node, handles most traffic"
    echo "  2) secondary - Backup node, takes over if primary fails"
    echo "  3) tertiary  - Third-level backup"
    echo ""
    local role_choice=$(ask "Select role (1-3)" "1")
    case $role_choice in
        1) NODE_ROLE="primary" ;;
        2) NODE_ROLE="secondary" ;;
        3) NODE_ROLE="tertiary" ;;
        *) NODE_ROLE="primary" ;;
    esac
    
    # Tailscale hostname
    echo ""
    local ts_hostname=""
    if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
        ts_hostname=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
        if [ -n "$ts_hostname" ]; then
            info "Detected Tailscale hostname: $ts_hostname"
        fi
    fi
    TAILSCALE_HOSTNAME=$(ask "Tailscale hostname" "$ts_hostname")
    
    # Service ports
    echo ""
    VIDEO_TRANSCODER_PORT=$(ask "Video transcoder port" "8081")
    INSTAGRAM_DOWNLOADER_PORT=$(ask "Instagram downloader port" "6666")
    
    # Funnel paths
    echo ""
    VIDEO_FUNNEL_PATH=$(ask "Video funnel path" "/video")
    INSTAGRAM_FUNNEL_PATH=$(ask "Instagram funnel path" "/instagram")
    
    # Pinata JWT
    echo ""
    info "Pinata is used for IPFS storage. Get your JWT at https://app.pinata.cloud"
    if ask_yes_no "Configure Pinata now?" "n"; then
        PINATA_JWT=$(ask_secret "Pinata JWT")
    else
        PINATA_JWT=""
    fi
    
    # Hive blockchain
    echo ""
    if ask_yes_no "Configure Hive blockchain credentials?" "n"; then
        HIVE_ACCOUNT=$(ask "Hive account name")
        HIVE_POSTING_KEY=$(ask_secret "Hive posting key")
    else
        HIVE_ACCOUNT=""
        HIVE_POSTING_KEY=""
    fi
    
    # Other nodes for failover
    echo ""
    info "Enter other SkateHive node URLs for health checks (comma-separated)"
    info "Example: https://node1.ts.net,https://node2.ts.net"
    OTHER_NODES=$(ask "Other nodes" "")
    
    # Discord webhook
    echo ""
    if ask_yes_no "Configure Discord alerts?" "n"; then
        DISCORD_WEBHOOK_URL=$(ask_secret "Discord webhook URL")
    else
        DISCORD_WEBHOOK_URL=""
    fi
    
    # Write config file
    cat > "$CONFIG_FILE" << EOF
# SkateHive Node Configuration
# Generated by setup.sh on $(date)

# Node Identity
NODE_NAME="$NODE_NAME"
NODE_ROLE="$NODE_ROLE"

# Tailscale
TAILSCALE_HOSTNAME="$TAILSCALE_HOSTNAME"

# Service Ports
VIDEO_TRANSCODER_PORT=$VIDEO_TRANSCODER_PORT
INSTAGRAM_DOWNLOADER_PORT=$INSTAGRAM_DOWNLOADER_PORT

# Funnel Paths
VIDEO_FUNNEL_PATH="$VIDEO_FUNNEL_PATH"
INSTAGRAM_FUNNEL_PATH="$INSTAGRAM_FUNNEL_PATH"

# Pinata (IPFS)
PINATA_JWT="$PINATA_JWT"

# Hive Blockchain
HIVE_ACCOUNT="$HIVE_ACCOUNT"
HIVE_POSTING_KEY="$HIVE_POSTING_KEY"

# Failover Nodes
OTHER_NODES="$OTHER_NODES"

# Alerts
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL"
ALERT_EMAIL=""
EOF
    
    success "Configuration saved to $CONFIG_FILE"
    
    # Add to .gitignore if not already there
    if ! grep -q "skatehive.config" "$SCRIPT_DIR/.gitignore" 2>/dev/null; then
        echo -e "\n# Local node configuration (contains secrets)\nskatehive.config" >> "$SCRIPT_DIR/.gitignore"
        success "Added skatehive.config to .gitignore"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Repository Management
# ═══════════════════════════════════════════════════════════════════════════════

# List of all SkateHive repositories
SKATEHIVE_REPOS=(
    "apps/skatehive3.0"
    "apps/mobileapp"
    "apps/skatehive-dashboard"
    "apps/skatehive-docs"
    "services/skatehive-api"
    "services/skatehive-video-transcoder"
    "services/skatehive-instagram-downloader"
)

check_repo_status() {
    local repo_dir="$1"
    local repo_name=$(basename "$repo_dir")
    
    if [ ! -d "$repo_dir/.git" ]; then
        echo "missing"
        return
    fi
    
    cd "$repo_dir"
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "dirty"
        cd - > /dev/null
        return
    fi
    
    # Fetch latest (silently)
    git fetch origin 2>/dev/null || true
    
    # Check if behind remote
    local local_hash=$(git rev-parse HEAD 2>/dev/null)
    local remote_hash=$(git rev-parse origin/$(git rev-parse --abbrev-ref HEAD) 2>/dev/null)
    
    if [ "$local_hash" != "$remote_hash" ] 2>/dev/null; then
        local behind=$(git rev-list --count HEAD..origin/$(git rev-parse --abbrev-ref HEAD) 2>/dev/null || echo "0")
        if [ "$behind" -gt 0 ] 2>/dev/null; then
            echo "behind:$behind"
            cd - > /dev/null
            return
        fi
    fi
    
    echo "ok"
    cd - > /dev/null
}

check_repositories() {
    print_step "Step 3/7: Check Repository Status"
    
    local missing_repos=()
    local outdated_repos=()
    local dirty_repos=()
    local ok_repos=()
    local total=${#SKATEHIVE_REPOS[@]}
    local current=0
    
    echo "Checking $total repositories (fetching updates)..."
    echo ""
    
    for repo in "${SKATEHIVE_REPOS[@]}"; do
        ((current++))
        local repo_path="$SCRIPT_DIR/$repo"
        
        # Show progress
        printf "  [%2d/%d] %-35s " "$current" "$total" "$repo"
        
        local status=$(check_repo_status "$repo_path")
        
        case "$status" in
            "missing")
                echo -e "${RED}✗ Not cloned${NC}"
                missing_repos+=("$repo")
                ;;
            "dirty")
                echo -e "${YELLOW}⚠ Uncommitted changes${NC}"
                dirty_repos+=("$repo")
                ;;
            behind:*)
                local count="${status#behind:}"
                echo -e "${YELLOW}↓ $count commits behind${NC}"
                outdated_repos+=("$repo")
                ;;
            "ok")
                echo -e "${GREEN}✓ Up to date${NC}"
                ok_repos+=("$repo")
                ;;
        esac
    done
    
    echo ""
    
    # Summary
    echo -e "${BOLD}Summary:${NC}"
    echo "  ✓ Up to date: ${#ok_repos[@]}"
    [ ${#outdated_repos[@]} -gt 0 ] && echo "  ↓ Need update: ${#outdated_repos[@]}"
    [ ${#dirty_repos[@]} -gt 0 ] && echo "  ⚠ Uncommitted: ${#dirty_repos[@]}"
    [ ${#missing_repos[@]} -gt 0 ] && echo "  ✗ Missing: ${#missing_repos[@]}"
    echo ""
    
    # Clone missing repos
    if [ ${#missing_repos[@]} -gt 0 ]; then
        if ask_yes_no "Clone ${#missing_repos[@]} missing repositories?"; then
            for repo in "${missing_repos[@]}"; do
                info "Cloning $repo..."
                if git clone "git@github.com:SkateHive/$repo.git" "$SCRIPT_DIR/$repo" 2>/dev/null; then
                    success "Cloned $repo"
                else
                    warn "Failed to clone $repo (may not exist or no SSH access)"
                    # Try HTTPS as fallback
                    if git clone "https://github.com/SkateHive/$repo.git" "$SCRIPT_DIR/$repo" 2>/dev/null; then
                        success "Cloned $repo (via HTTPS)"
                    fi
                fi
            done
        fi
    fi
    
    # Update outdated repos
    if [ ${#outdated_repos[@]} -gt 0 ]; then
        if ask_yes_no "Update ${#outdated_repos[@]} outdated repositories?"; then
            for repo in "${outdated_repos[@]}"; do
                info "Updating $repo..."
                cd "$SCRIPT_DIR/$repo"
                if git pull --ff-only 2>/dev/null; then
                    success "Updated $repo"
                else
                    warn "Failed to update $repo (may have conflicts)"
                fi
                cd "$SCRIPT_DIR"
            done
        fi
    fi
    
    # Warn about dirty repos
    if [ ${#dirty_repos[@]} -gt 0 ]; then
        warn "The following repos have uncommitted changes:"
        for repo in "${dirty_repos[@]}"; do
            echo "    - $repo"
        done
        echo ""
        info "Commit or stash changes before updating these repos."
    fi
}

clone_repositories() {
    # This function is now deprecated, use check_repositories instead
    check_repositories
}

# ═══════════════════════════════════════════════════════════════════════════════
# Setup Services
# ═══════════════════════════════════════════════════════════════════════════════

setup_services() {
    print_step "Step 4/7: Setup Services"
    
    # Source config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    echo "Which services do you want to set up?"
    echo ""
    
    # Video Transcoder
    if ask_yes_no "Setup Video Transcoder?"; then
        local transcoder_dir="$SCRIPT_DIR/services/skatehive-video-transcoder"
        if [ -d "$transcoder_dir" ]; then
            info "Building Video Transcoder..."
            cd "$transcoder_dir"

            # Create .env if Pinata JWT is set
            if [ -n "$PINATA_JWT" ]; then
                echo "PINATA_JWT=$PINATA_JWT" > .env
                success "Created .env with Pinata credentials"
            else
                warn "No Pinata JWT configured - videos won't upload to IPFS"
            fi

            docker-compose build
            success "Video Transcoder built"
        else
            warn "Video Transcoder directory not found"
            info "Run: git clone git@github.com:SkateHive/skatehive-video-transcoder.git services/skatehive-video-transcoder"
        fi
    fi
    
    echo ""
    
    # Instagram Downloader
    if ask_yes_no "Setup Instagram Downloader?"; then
        local instagram_dir="$SCRIPT_DIR/services/skatehive-instagram-downloader/ytipfs-worker"
        if [ -d "$instagram_dir" ]; then
            info "Building Instagram Downloader..."
            cd "$instagram_dir"

            # Create .env if Pinata JWT is set
            if [ -n "$PINATA_JWT" ]; then
                echo "PINATA_JWT=$PINATA_JWT" > .env
                success "Created .env with Pinata credentials"
            else
                warn "No Pinata JWT configured - downloads won't upload to IPFS"
            fi

            # Check for cookies file
            if [ -f "$instagram_dir/data/instagram_cookies.txt" ]; then
                success "Instagram cookies file found"
            else
                warn "No Instagram cookies found - downloads may fail"
                info "See: docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md"
            fi

            docker-compose build
            success "Instagram Downloader built"
        else
            warn "Instagram Downloader directory not found"
            info "Run: git clone git@github.com:SkateHive/skatehive-instagram-downloader.git services/skatehive-instagram-downloader"
        fi
    fi
    

    cd "$SCRIPT_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Setup Tailscale Funnel
# ═══════════════════════════════════════════════════════════════════════════════

setup_tailscale() {
    print_step "Step 5/7: Tailscale Funnel Setup"
    
    if ! command -v tailscale &> /dev/null; then
        warn "Tailscale is not installed. Skipping funnel setup."
        info "Install Tailscale: https://tailscale.com/download"
        return
    fi
    
    if ! tailscale status &> /dev/null; then
        warn "Tailscale is not connected. Please connect first."
        return
    fi
    
    # Source config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    echo "Tailscale Funnel exposes your services to the internet securely."
    echo ""
    echo "Current settings:"
    echo "  Video:     https://$TAILSCALE_HOSTNAME$VIDEO_FUNNEL_PATH -> localhost:$VIDEO_TRANSCODER_PORT"
    echo "  Instagram: https://$TAILSCALE_HOSTNAME$INSTAGRAM_FUNNEL_PATH -> localhost:$INSTAGRAM_DOWNLOADER_PORT"
    echo ""
    
    if ask_yes_no "Configure Tailscale Funnel now?"; then
        local tailscale_bin="tailscale"
        if [[ "$(detect_os)" == "macos" ]]; then
            tailscale_bin="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        fi
        
        info "Setting up Video Transcoder funnel..."
        $tailscale_bin funnel --bg --set-path="$VIDEO_FUNNEL_PATH" "$VIDEO_TRANSCODER_PORT" 2>/dev/null && \
            success "Video funnel configured" || warn "Video funnel setup failed"
        
        info "Setting up Instagram Downloader funnel..."
        $tailscale_bin funnel --bg --set-path="$INSTAGRAM_FUNNEL_PATH" "$INSTAGRAM_DOWNLOADER_PORT" 2>/dev/null && \
            success "Instagram funnel configured" || warn "Instagram funnel setup failed"
        
        echo ""
        info "Funnel status:"
        $tailscale_bin funnel status 2>/dev/null || true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Start Services
# ═══════════════════════════════════════════════════════════════════════════════

start_services() {
    print_step "Step 6/7: Start Services"
    
    # Source config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    if ! ask_yes_no "Start services now?"; then
        info "You can start services later with:"
        echo "  cd services/skatehive-video-transcoder && docker-compose up -d"
        echo "  cd services/skatehive-instagram-downloader/ytipfs-worker && docker-compose up -d"
        return
    fi
    
    # Start Video Transcoder
    local transcoder_dir="$SCRIPT_DIR/services/skatehive-video-transcoder"
    if [ -f "$transcoder_dir/docker-compose.yml" ]; then
        info "Starting Video Transcoder..."
        cd "$transcoder_dir"
        docker-compose up -d
        success "Video Transcoder started"
    fi
    
    # Start Instagram Downloader
    local instagram_dir="$SCRIPT_DIR/services/skatehive-instagram-downloader/ytipfs-worker"
    if [ -f "$instagram_dir/docker-compose.yml" ]; then
        info "Starting Instagram Downloader..."
        cd "$instagram_dir"
        docker-compose up -d
        success "Instagram Downloader started"
    fi
    
    cd "$SCRIPT_DIR"
    
    echo ""
    info "Waiting for services to start..."
    sleep 5
}

# ═══════════════════════════════════════════════════════════════════════════════
# Verify Everything is Running
# ═══════════════════════════════════════════════════════════════════════════════

verify_services() {
    print_step "Step 7/7: Verify Services"
    
    # Source config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    source "$SCRIPT_DIR/load-config.sh" 2>/dev/null || true
    
    local all_ok=true
    local issues=()
    
    echo -e "${BOLD}Docker Containers:${NC}"
    echo ""
    
    # Check Video Transcoder container
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "video"; then
        local video_status=$(docker ps --filter "name=video" --format "{{.Status}}" 2>/dev/null)
        success "Video Transcoder container: $video_status"
    else
        error "Video Transcoder container: Not running"
        issues+=("video_container")
        all_ok=false
    fi
    
    # Check Instagram Downloader container
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "ytipfs"; then
        local insta_status=$(docker ps --filter "name=ytipfs" --format "{{.Status}}" 2>/dev/null)
        success "Instagram Downloader container: $insta_status"
    else
        error "Instagram Downloader container: Not running"
        issues+=("instagram_container")
        all_ok=false
    fi
    
    echo ""
    echo -e "${BOLD}Service Health Checks:${NC}"
    echo ""
    
    # Test Video Transcoder
    local video_port="${VIDEO_TRANSCODER_PORT:-8081}"
    if curl -s --max-time 5 "http://localhost:$video_port/healthz" | jq -e '.ok' &>/dev/null; then
        success "Video Transcoder API: Responding on port $video_port"
    else
        error "Video Transcoder API: Not responding on port $video_port"
        issues+=("video_api")
        all_ok=false
    fi
    
    # Test Instagram Downloader
    local insta_port="${INSTAGRAM_DOWNLOADER_PORT:-6666}"
    local insta_response=$(curl -s --max-time 5 "http://localhost:$insta_port/healthz" 2>/dev/null)
    if echo "$insta_response" | jq -e '.status' &>/dev/null; then
        success "Instagram Downloader API: Responding on port $insta_port"
        
        # Check cookie status
        local cookies_valid=$(echo "$insta_response" | jq -r '.authentication.cookies_valid // false')
        local cookies_exist=$(echo "$insta_response" | jq -r '.authentication.cookies_exist // false')
        
        if [ "$cookies_valid" = "true" ]; then
            success "Instagram Cookies: Valid ✓"
        elif [ "$cookies_exist" = "true" ]; then
            warn "Instagram Cookies: Exist but invalid/expired"
            issues+=("instagram_cookies")
        else
            warn "Instagram Cookies: Not configured"
            issues+=("instagram_cookies_missing")
        fi
    else
        error "Instagram Downloader API: Not responding on port $insta_port"
        issues+=("instagram_api")
        all_ok=false
    fi
    
    echo ""
    echo -e "${BOLD}External Access (Tailscale):${NC}"
    echo ""
    
    if [ -n "$TAILSCALE_HOSTNAME" ]; then
        # Test external video
        if curl -s --max-time 10 "https://$TAILSCALE_HOSTNAME$VIDEO_FUNNEL_PATH/healthz" | jq -e '.ok' &>/dev/null; then
            success "Video (External): https://$TAILSCALE_HOSTNAME$VIDEO_FUNNEL_PATH"
        else
            warn "Video (External): Not accessible"
            issues+=("video_funnel")
        fi
        
        # Test external instagram
        if curl -s --max-time 10 "https://$TAILSCALE_HOSTNAME$INSTAGRAM_FUNNEL_PATH/healthz" | jq -e '.status' &>/dev/null; then
            success "Instagram (External): https://$TAILSCALE_HOSTNAME$INSTAGRAM_FUNNEL_PATH"
        else
            warn "Instagram (External): Not accessible"
            issues+=("instagram_funnel")
        fi
    else
        warn "Tailscale hostname not configured"
        issues+=("tailscale_hostname")
    fi
    
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        success "Config file: $CONFIG_FILE"
    else
        warn "Config file: Not found"
        issues+=("config_missing")
    fi
    
    if [ -n "$PINATA_JWT" ]; then
        success "Pinata IPFS: Configured"
    else
        warn "Pinata IPFS: Not configured"
        issues+=("pinata_missing")
    fi
    
    echo ""
    
    # Offer to fix issues
    if [ ${#issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Found ${#issues[@]} issue(s) that may need attention${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        offer_fixes "${issues[@]}"
    else
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ All core services are running!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Offer Fixes for Issues
# ═══════════════════════════════════════════════════════════════════════════════

offer_fixes() {
    local issues=("$@")
    
    for issue in "${issues[@]}"; do
        case "$issue" in
            "video_container")
                echo -e "${BOLD}Video Transcoder container not running${NC}"
                if ask_yes_no "  Start Video Transcoder container?"; then
                    cd "$SCRIPT_DIR/services/skatehive-video-transcoder" 2>/dev/null && docker-compose up -d && success "  Started!" || error "  Failed to start"
                    cd "$SCRIPT_DIR"
                else
                    info "  To fix manually: cd services/skatehive-video-transcoder && docker-compose up -d"
                fi
                echo ""
                ;;
                
            "instagram_container")
                echo -e "${BOLD}Instagram Downloader container not running${NC}"
                if ask_yes_no "  Start Instagram Downloader container?"; then
                    cd "$SCRIPT_DIR/services/skatehive-instagram-downloader/ytipfs-worker" 2>/dev/null && docker-compose up -d && success "  Started!" || error "  Failed to start"
                    cd "$SCRIPT_DIR"
                else
                    info "  To fix manually: cd services/skatehive-instagram-downloader/ytipfs-worker && docker-compose up -d"
                fi
                echo ""
                ;;
                
            "video_api"|"instagram_api")
                echo -e "${BOLD}Service API not responding${NC}"
                info "  The container may still be starting up. Wait 30 seconds and try again."
                info "  Check logs: docker logs video-worker  OR  docker logs ytipfs-worker"
                echo ""
                ;;
                
            "instagram_cookies")
                echo -e "${BOLD}Instagram cookies invalid/expired${NC}"
                info "  You need to refresh your Instagram cookies."
                echo ""
                echo "  Steps to fix:"
                echo "    1. Install browser extension: 'Get cookies.txt LOCALLY'"
                echo "    2. Login to Instagram in your browser"
                echo "    3. Export cookies using the extension"
                echo "    4. Copy to: services/skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt"
                echo ""
                info "  Full guide: docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md"
                echo ""
                ;;
                
            "instagram_cookies_missing")
                echo -e "${BOLD}Instagram cookies not configured${NC}"
                info "  Instagram downloads will fail without valid cookies."
                echo ""
                echo "  Steps to configure:"
                echo "    1. Install browser extension: 'Get cookies.txt LOCALLY'"
                echo "    2. Login to Instagram in your browser"
                echo "    3. Export cookies using the extension (Netscape format)"
                echo "    4. Save to: services/skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt"
                echo ""
                info "  Full guide: docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md"
                echo ""
                ;;
                
            "video_funnel"|"instagram_funnel")
                echo -e "${BOLD}Tailscale Funnel not accessible${NC}"
                if ask_yes_no "  Configure Tailscale Funnel now?"; then
                    setup_tailscale_funnel
                else
                    info "  To fix manually:"
                    info "    tailscale funnel --bg --set-path=/video 8081"
                    info "    tailscale funnel --bg --set-path=/instagram 6666"
                fi
                echo ""
                ;;
                
            "tailscale_hostname")
                echo -e "${BOLD}Tailscale hostname not configured${NC}"
                if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
                    local detected_hostname=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
                    if [ -n "$detected_hostname" ]; then
                        info "  Detected hostname: $detected_hostname"
                        if ask_yes_no "  Save this hostname to config?"; then
                            if [ -f "$CONFIG_FILE" ]; then
                                sed -i.bak "s/^TAILSCALE_HOSTNAME=.*/TAILSCALE_HOSTNAME=\"$detected_hostname\"/" "$CONFIG_FILE"
                            else
                                echo "TAILSCALE_HOSTNAME=\"$detected_hostname\"" >> "$CONFIG_FILE"
                            fi
                            success "  Hostname saved!"
                            export TAILSCALE_HOSTNAME="$detected_hostname"
                        fi
                    fi
                else
                    info "  Tailscale is not running or not installed."
                    info "  Install from: https://tailscale.com/download"
                fi
                echo ""
                ;;
                
            "config_missing")
                echo -e "${BOLD}Configuration file not found${NC}"
                if ask_yes_no "  Run interactive configuration now?"; then
                    configure_node
                else
                    info "  To fix: ./setup.sh (run full setup)"
                fi
                echo ""
                ;;
                
            "pinata_missing")
                echo -e "${BOLD}Pinata IPFS not configured${NC}"
                info "  Videos and downloads won't be uploaded to IPFS."
                echo ""
                echo "  To configure:"
                echo "    1. Create account at https://app.pinata.cloud"
                echo "    2. Generate API key (JWT)"
                echo "    3. Add to skatehive.config: PINATA_JWT=\"your-jwt-here\""
                echo ""
                ;;
        esac
    done
}

# Helper to setup Tailscale Funnel
setup_tailscale_funnel() {
    local tailscale_bin="tailscale"
    if [[ "$(detect_os)" == "macos" ]]; then
        tailscale_bin="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    fi
    
    local video_port="${VIDEO_TRANSCODER_PORT:-8081}"
    local insta_port="${INSTAGRAM_DOWNLOADER_PORT:-6666}"
    local video_path="${VIDEO_FUNNEL_PATH:-/video}"
    local insta_path="${INSTAGRAM_FUNNEL_PATH:-/instagram}"
    
    info "Setting up Tailscale Funnel..."
    $tailscale_bin funnel --bg --set-path="$video_path" "$video_port" 2>/dev/null && success "Video funnel: $video_path -> :$video_port" || warn "Video funnel failed"
    $tailscale_bin funnel --bg --set-path="$insta_path" "$insta_port" 2>/dev/null && success "Instagram funnel: $insta_path -> :$insta_port" || warn "Instagram funnel failed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Finish
# ═══════════════════════════════════════════════════════════════════════════════

print_summary() {
    # Source config for summary
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🎉 Setup Complete!${NC}                                          ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your SkateHive node is configured!"
    echo ""
    echo -e "${BOLD}Node Details:${NC}"
    echo "  Name: $NODE_NAME"
    echo "  Role: $NODE_ROLE"
    if [ -n "$TAILSCALE_HOSTNAME" ]; then
        echo "  URL:  https://$TAILSCALE_HOSTNAME"
    fi
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  config/scripts/health-check.sh       - Check all services"
    echo "  config/scripts/emergency-recovery.sh - Restart all services"
    echo "  docker ps                  - View running containers"
    echo ""
    echo -e "${BOLD}Service URLs:${NC}"
    if [ -n "$TAILSCALE_HOSTNAME" ]; then
        echo "  Video:     https://$TAILSCALE_HOSTNAME$VIDEO_FUNNEL_PATH/healthz"
        echo "  Instagram: https://$TAILSCALE_HOSTNAME$INSTAGRAM_FUNNEL_PATH/healthz"
    else
        echo "  Video:     http://localhost:$VIDEO_TRANSCODER_PORT/healthz"
        echo "  Instagram: http://localhost:$INSTAGRAM_DOWNLOADER_PORT/healthz"
    fi
    echo ""
    echo -e "${CYAN}Thank you for running a SkateHive node! 🛹${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    
    local os=$(detect_os)
    info "Detected OS: $os"
    info "Monorepo: $SCRIPT_DIR"
    echo ""
    
    if ! ask_yes_no "Ready to set up your SkateHive node?"; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_dependencies
    configure_node
    check_repositories
    setup_services
    setup_tailscale
    start_services
    verify_services
    print_summary
}

# Status-only check (no interaction)
status_only() {
    print_banner
    
    local os=$(detect_os)
    info "Detected OS: $os"
    info "Monorepo: $SCRIPT_DIR"
    echo ""
    
    # Load config if exists
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        source "$SCRIPT_DIR/load-config.sh" 2>/dev/null || true
    fi
    
    # Check repos
    print_step "Repository Status"
    for repo in "${SKATEHIVE_REPOS[@]}"; do
        local repo_path="$SCRIPT_DIR/$repo"
        local status=$(check_repo_status "$repo_path")
        
        case "$status" in
            "missing")
                echo -e "  ${RED}✗${NC} $repo - ${RED}Not cloned${NC}"
                ;;
            "dirty")
                echo -e "  ${YELLOW}⚠${NC} $repo - ${YELLOW}Has uncommitted changes${NC}"
                ;;
            behind:*)
                local count="${status#behind:}"
                echo -e "  ${YELLOW}↓${NC} $repo - ${YELLOW}$count commits behind${NC}"
                ;;
            "ok")
                echo -e "  ${GREEN}✓${NC} $repo - ${GREEN}Up to date${NC}"
                ;;
        esac
    done
    
    echo ""
    verify_services
}

# Pull all repos
pull_all() {
    print_banner
    info "Pulling all repositories..."
    echo ""
    
    # Pull root monorepo first
    echo -e "${BOLD}monorepo (root)${NC}"
    git -C "$SCRIPT_DIR" pull --ff-only 2>/dev/null && success "Updated" || warn "Failed or has changes"
    echo ""
    
    for repo in "${SKATEHIVE_REPOS[@]}"; do
        local repo_path="$SCRIPT_DIR/$repo"
        if [ -d "$repo_path/.git" ]; then
            echo -e "${BOLD}$repo${NC}"
            git -C "$repo_path" pull --ff-only 2>/dev/null && success "Updated" || warn "Failed or has changes"
        fi
    done
    
    echo ""
    success "Done!"
}

# Show help
show_help() {
    echo "🛹 SkateHive Node Setup Script"
    echo ""
    echo "Usage: ./setup.sh [command]"
    echo ""
    echo "Commands:"
    echo "  (none)      Interactive setup wizard"
    echo "  --status    Check status of all repos and services"
    echo "  --pull      Pull updates for all repositories"
    echo "  --verify    Verify services are running"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh              # Run interactive setup"
    echo "  ./setup.sh --status     # Quick status check"
    echo "  ./setup.sh --pull       # Update all repos"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --status|-s)
            status_only
            ;;
        --pull|-p)
            pull_all
            ;;
        --verify|-v)
            print_banner
            verify_services
            ;;
        --help|-h)
            show_help
            ;;
        "")
            main
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
fi
