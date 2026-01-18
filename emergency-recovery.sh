#!/bin/bash
# SkateHive Mac Mini Emergency Recovery Script
# Run this manually if services don't start automatically after power outage

# Auto-detect monorepo root (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"

echo "🚨 SkateHive Emergency Recovery Starting..."
echo "📁 Monorepo root: $MONOREPO_ROOT"

# Kill any stuck processes
echo "🧹 Cleaning up stuck processes..."
pkill -f "docker"
sleep 5

# Start Docker Desktop (macOS) or Docker daemon (Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🐳 Starting Docker Desktop..."
    open /Applications/Docker.app
    sleep 20
else
    echo "🐳 Starting Docker service..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
    sleep 10
fi

# Wait for Docker to be ready
echo "⏳ Waiting for Docker daemon..."
while ! docker info >/dev/null 2>&1; do
    echo "   Docker not ready yet..."
    sleep 5
done
echo "✅ Docker is ready"

# Start containers
echo "📦 Starting containers..."
cd "$MONOREPO_ROOT/skatehive-video-transcoder" && docker-compose up -d
cd "$MONOREPO_ROOT/skatehive-instagram-downloader/ytipfs-worker" && docker-compose up -d

# Load configuration
source "$MONOREPO_ROOT/load-config.sh"

# Start Tailscale
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🔗 Starting Tailscale..."
    open /Applications/Tailscale.app
    sleep 15
    TAILSCALE_BIN="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
else
    echo "🔗 Starting Tailscale..."
    sudo systemctl start tailscaled 2>/dev/null || true
    sleep 5
    TAILSCALE_BIN="tailscale"
fi

# Setup Funnel
echo "🌐 Setting up Tailscale Funnel..."
sleep 10
$TAILSCALE_BIN funnel --bg --set-path="$VIDEO_FUNNEL_PATH" "$VIDEO_TRANSCODER_PORT"
$TAILSCALE_BIN funnel --bg --set-path="$INSTAGRAM_FUNNEL_PATH" "$INSTAGRAM_DOWNLOADER_PORT"

echo "⏳ Waiting for services to stabilize..."
sleep 30

# Test services
echo "🧪 Testing services..."
echo "Video Local: $(curl -s $VIDEO_LOCAL_URL/healthz | jq -r .service || echo 'FAILED')"
echo "Instagram Local: $(curl -s $INSTAGRAM_LOCAL_URL/healthz | jq -r .status || echo 'FAILED')"

sleep 10

if [ -n "$VIDEO_EXTERNAL_URL" ]; then
    echo "Video External: $(curl -s $VIDEO_EXTERNAL_URL/healthz | jq -r .service || echo 'FAILED')"
    echo "Instagram External: $(curl -s $INSTAGRAM_EXTERNAL_URL/healthz | jq -r .status || echo 'FAILED')"
fi

echo "🎉 Emergency recovery completed!"
echo "🌐 Your node ($NODE_NAME) should now be accessible at:"
if [ -n "$VIDEO_EXTERNAL_URL" ]; then
    echo "   Video: $VIDEO_EXTERNAL_URL/"
    echo "   Instagram: $INSTAGRAM_EXTERNAL_URL/"
else
    echo "   Video: $VIDEO_LOCAL_URL/"
    echo "   Instagram: $INSTAGRAM_LOCAL_URL/"
fi
