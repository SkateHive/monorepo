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

# Start Tailscale
echo "🔗 Starting Tailscale..."
open /Applications/Tailscale.app
sleep 15

# Setup Funnel
echo "🌐 Setting up Tailscale Funnel..."
sleep 10
/Applications/Tailscale.app/Contents/MacOS/Tailscale funnel --bg --set-path=/video 8081
/Applications/Tailscale.app/Contents/MacOS/Tailscale funnel --bg --set-path=/instagram 6666

echo "⏳ Waiting for services to stabilize..."
sleep 30

# Test services
echo "🧪 Testing services..."
echo "Video Local: $(curl -s http://localhost:8081/healthz | jq -r .service || echo 'FAILED')"
echo "Instagram Local: $(curl -s http://localhost:6666/health | jq -r .status || echo 'FAILED')"

sleep 10

echo "Video External: $(curl -s https://minivlad.tail9656d3.ts.net/video/healthz | jq -r .service || echo 'FAILED')"
echo "Instagram External: $(curl -s https://minivlad.tail9656d3.ts.net/instagram/health | jq -r .status || echo 'FAILED')"

echo "🎉 Emergency recovery completed!"
echo "🌐 Your Mac Mini should now be accessible at:"
echo "   Video: https://minivlad.tail9656d3.ts.net/video/"
echo "   Instagram: https://minivlad.tail9656d3.ts.net/instagram/"