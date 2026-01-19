#!/bin/bash

# Comprehensive Health Check Script for SkateHive Services
# Tests both local and Tailscale endpoints

# Auto-detect monorepo root (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"

# Load configuration
source "$MONOREPO_ROOT/load-config.sh"

echo "🏥 SkateHive Services Health Check"
echo "=================================="
echo "📁 Node: $NODE_NAME ($NODE_ROLE)"
echo "📁 Monorepo: $MONOREPO_ROOT"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tailscale info
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")
TAILSCALE_URL="${TAILSCALE_HOSTNAME:-$TAILSCALE_IP}"

echo -e "${BLUE}📡 Tailscale Status:${NC}"
echo "   IP: $TAILSCALE_IP"
if [ -n "$TAILSCALE_HOSTNAME" ]; then
    echo "   Hostname: $TAILSCALE_HOSTNAME"
fi
echo ""

# Function to test endpoint
test_endpoint() {
    local url=$1
    local name=$2
    local expected_field=$3
    
    echo -e "${YELLOW}Testing $name:${NC} $url"
    
    # Test with timeout
    response=$(curl -s --max-time 5 "$url" 2>/dev/null)
    curl_exit_code=$?
    
    if [ $curl_exit_code -eq 0 ]; then
        if echo "$response" | grep -q "$expected_field"; then
            echo -e "   ${GREEN}✅ HEALTHY${NC} - $response"
        else
            echo -e "   ${RED}⚠️  UNHEALTHY${NC} - Unexpected response: $response"
        fi
    else
        echo -e "   ${RED}❌ FAILED${NC} - Connection error (exit code: $curl_exit_code)"
    fi
    echo ""
}

echo -e "${BLUE}🎬 Video Transcoder Service (Port 8081):${NC}"
test_endpoint "http://localhost:8081/healthz" "Local Health" "ok"
test_endpoint "http://$TAILSCALE_URL:8081/healthz" "Tailscale Health" "ok"

echo -e "${BLUE}📱 Instagram Downloader Service (Port $INSTAGRAM_DOWNLOADER_PORT):${NC}"
test_endpoint "http://localhost:$INSTAGRAM_DOWNLOADER_PORT/healthz" "Local Health" "status"
test_endpoint "http://$TAILSCALE_URL:$INSTAGRAM_DOWNLOADER_PORT/healthz" "Tailscale Health" "status"

echo -e "${BLUE}🍪 Instagram Cookie Status:${NC}"
cookie_response=$(curl -s --max-time 5 "http://localhost:$INSTAGRAM_DOWNLOADER_PORT/cookies/status" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$cookie_response" | jq '.'
    
    cookies_valid=$(echo "$cookie_response" | jq -r '.cookies_valid // false')
    if [ "$cookies_valid" = "true" ]; then
        echo -e "   ${GREEN}✅ Cookies valid and working${NC}"
    else
        echo -e "   ${YELLOW}⚠️ Cookies may be invalid or expired${NC}"
        echo -e "   ${YELLOW}Run: skatehive-instagram-downloader/cookie-health-check.sh for detailed analysis${NC}"
    fi
else
    echo -e "   ${RED}❌ Could not check cookie status${NC}"
fi
echo ""

echo -e "${BLUE}🔍 External Services Check:${NC}"
test_endpoint "https://skate-insta.onrender.com/healthz" "Render Service" "status"

echo -e "${BLUE}🧪 Live Download Test (Instagram Reel):${NC}"
echo "Testing with: https://www.instagram.com/skate_dev/reel/DNw52r3WFU_/"
echo ""

# Test local Instagram downloader
echo -e "${YELLOW}Testing Local Instagram Downloader:${NC}"
echo "   POST http://localhost:6666/download"
response=$(curl -s --max-time 30 -X POST http://localhost:6666/download \
    -H "Content-Type: application/json" \
    -d '{"url": "https://www.instagram.com/skate_dev/reel/DNw52r3WFU_/"}' 2>/dev/null)
curl_exit_code=$?

if [ $curl_exit_code -eq 0 ]; then
    if echo "$response" | grep -q "cid"; then
        cid=$(echo "$response" | grep -o '"cid":"[^"]*"' | cut -d'"' -f4)
        filename=$(echo "$response" | grep -o '"filename":"[^"]*"' | cut -d'"' -f4)
        bytes=$(echo "$response" | grep -o '"bytes":[0-9]*' | cut -d':' -f2)
        echo -e "   ${GREEN}✅ SUCCESS${NC}"
        echo "   📁 File: $filename"
        echo "   📦 CID: $cid"
        echo "   💾 Size: $bytes bytes"
    else
        echo -e "   ${RED}❌ FAILED${NC} - No CID in response"
        echo "   Response: $response"
    fi
else
    echo -e "   ${RED}❌ FAILED${NC} - Connection error (exit code: $curl_exit_code)"
fi
echo ""

# Test Tailscale Instagram downloader
echo -e "${YELLOW}Testing Tailscale Instagram Downloader:${NC}"
echo "   POST http://$TAILSCALE_URL:$INSTAGRAM_DOWNLOADER_PORT/download"
response=$(curl -s --max-time 30 -X POST http://$TAILSCALE_URL:$INSTAGRAM_DOWNLOADER_PORT/download \
    -H "Content-Type: application/json" \
    -d '{"url": "https://www.instagram.com/skate_dev/reel/DNw52r3WFU_/"}' 2>/dev/null)
curl_exit_code=$?

if [ $curl_exit_code -eq 0 ]; then
    if echo "$response" | grep -q "cid"; then
        cid=$(echo "$response" | grep -o '"cid":"[^"]*"' | cut -d'"' -f4)
        filename=$(echo "$response" | grep -o '"filename":"[^"]*"' | cut -d'"' -f4)
        bytes=$(echo "$response" | grep -o '"bytes":[0-9]*' | cut -d':' -f2)
        gateway_url=$(echo "$response" | grep -o '"pinata_gateway":"[^"]*"' | cut -d'"' -f4)
        echo -e "   ${GREEN}✅ SUCCESS${NC}"
        echo "   📁 File: $filename"
        echo "   📦 CID: $cid"
        echo "   💾 Size: $bytes bytes"
        echo "   🌐 Gateway: $gateway_url"
    else
        echo -e "   ${RED}❌ FAILED${NC} - No CID in response"
        echo "   Response: $response"
    fi
else
    echo -e "   ${RED}❌ FAILED${NC} - Connection error (exit code: $curl_exit_code)"
fi
echo ""

echo -e "${BLUE}📊 Docker Container Status:${NC}"
echo "Video Worker:"
docker ps --filter "name=video-worker" --format "   {{.Names}}: {{.Status}}" 2>/dev/null || echo "   ❌ Not running"
echo ""
echo "Instagram Worker:"
docker ps --filter "name=ytipfs-worker" --format "   {{.Names}}: {{.Status}}" 2>/dev/null || echo "   ❌ Not running"
echo ""

echo -e "${BLUE}💾 Storage Status:${NC}"
echo "Disk Usage:"
df -h "$MONOREPO_ROOT" | tail -n +2 | awk '{print "   Available: " $4 " (" $5 " used)"}'
echo ""

echo -e "${BLUE}🌐 Network Test:${NC}"
if ping -c 1 google.com &> /dev/null; then
    echo -e "   ${GREEN}✅ Internet connectivity${NC}"
else
    echo -e "   ${RED}❌ No internet connectivity${NC}"
fi
echo ""

echo "🏁 Health check completed at $(date)"
