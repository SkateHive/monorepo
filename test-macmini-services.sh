#!/bin/bash
# Test script for Mac Mini services accessibility via Tailscale
# Usage: ./test-macmini-services.sh

echo "🧪 Mac Mini Services Test Script"
echo "================================"

# Test Instagram Downloader (port 6666)
echo "📥 Testing Instagram Downloader..."
echo "URL: https://macmini.tail83ea3e.ts.net:6666/health"
curl -s --connect-timeout 10 https://macmini.tail83ea3e.ts.net:6666/health | jq . || echo "❌ Instagram service not accessible"

echo

# Test Video Transcoder (port 8081)
echo "🎬 Testing Video Transcoder..."
echo "URL: https://macmini.tail83ea3e.ts.net:8081/healthz"
curl -s --connect-timeout 10 https://macmini.tail83ea3e.ts.net:8081/healthz | jq . || echo "❌ Video transcoder not accessible"

echo

# Test local services (should work)
echo "🏠 Testing Local Services..."
echo "Instagram (local): http://localhost:6666/health"
curl -s http://localhost:6666/health | jq -r '"Status: " + .status + " | Version: " + .version' || echo "❌ Local Instagram service down"

echo "Video (local): http://localhost:8081/healthz"
curl -s http://localhost:8081/healthz | jq -r '"Status: " + (.ok|tostring) + " | Service: " + .service' || echo "❌ Local video service down"

echo
echo "✅ Test complete!"
echo
echo "💡 If Tailscale services fail:"
echo "   1. Make sure Tailscale app is running and authenticated"
echo "   2. Check if 'macmini' is the correct device name in your tailnet"
echo "   3. Verify ports 6666 and 8081 are accessible in macOS firewall"