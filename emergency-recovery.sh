#!/bin/bash
# SkateHive Mac Mini Emergency Recovery Script
# Run this manually if services don't start automatically after power outage

echo "🚨 SkateHive Emergency Recovery Starting..."

# Kill any stuck processes
echo "🧹 Cleaning up stuck processes..."
pkill -f "docker"
sleep 5

# Start Docker Desktop
echo "🐳 Starting Docker Desktop..."
open /Applications/Docker.app
sleep 20

# Wait for Docker to be ready
echo "⏳ Waiting for Docker daemon..."
while ! docker info >/dev/null 2>&1; do
    echo "   Docker not ready yet..."
    sleep 5
done
echo "✅ Docker is ready"

# Start containers
echo "📦 Starting containers..."
cd /Users/vladnikolaev/skatehive-monorepo/skatehive-video-transcoder && docker-compose up -d
cd /Users/vladnikolaev/skatehive-monorepo/skatehive-instagram-downloader/ytipfs-worker && docker-compose up -d

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