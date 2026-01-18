#!/bin/bash
# Test script for SkateHive services accessibility
# Usage: ./test-macmini-services.sh

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-config.sh"

echo "🧪 SkateHive Services Test Script"
echo "=================================="
echo "Node: $NODE_NAME ($NODE_ROLE)"
echo ""

# Test local services first
echo "🏠 Testing Local Services..."
echo "Video (local): $VIDEO_LOCAL_URL/healthz"
curl -s --connect-timeout 5 "$VIDEO_LOCAL_URL/healthz" | jq -r '"Status: " + (.ok|tostring) + " | Service: " + .service' || echo "❌ Local video service down"

echo "Instagram (local): $INSTAGRAM_LOCAL_URL/healthz"
curl -s --connect-timeout 5 "$INSTAGRAM_LOCAL_URL/healthz" | jq -r '"Status: " + .status + " | Version: " + .version' || echo "❌ Local Instagram service down"

echo ""

# Test external services via Tailscale
if [ -n "$VIDEO_EXTERNAL_URL" ]; then
    echo "🌐 Testing External Services (Tailscale)..."
    
    echo "Video (external): $VIDEO_EXTERNAL_URL/healthz"
    curl -s --connect-timeout 10 "$VIDEO_EXTERNAL_URL/healthz" | jq . || echo "❌ Video transcoder not accessible"
    
    echo "Instagram (external): $INSTAGRAM_EXTERNAL_URL/healthz"
    curl -s --connect-timeout 10 "$INSTAGRAM_EXTERNAL_URL/healthz" | jq . || echo "❌ Instagram service not accessible"
else
    echo "⚠️ Tailscale not configured. Run ./setup.sh to configure."
fi

echo ""
echo "✅ Test complete!"
echo ""
echo "💡 If Tailscale services fail:"
echo "   1. Make sure Tailscale app is running and authenticated"
echo "   2. Run ./setup.sh to configure your node"
echo "   3. Check firewall settings for ports $VIDEO_TRANSCODER_PORT and $INSTAGRAM_DOWNLOADER_PORT"
