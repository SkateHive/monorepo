#!/bin/bash

# Instagram Cookie Setup Test Script
echo "🍪 Instagram Cookie Authentication Setup"
echo "======================================="
echo ""

# Auto-detect monorepo root (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="${SKATEHIVE_MONOREPO:-$SCRIPT_DIR}"

CONTAINER_NAME="ytipfs-worker"
COOKIES_PATH="$MONOREPO_ROOT/skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt"

echo "1. Current cookie status:"
curl -s http://localhost:8000/cookies/status | jq .
echo ""

echo "2. Sample cookies file location:"
echo "   Host: $COOKIES_PATH"
echo "   Container: /data/instagram_cookies.txt"
echo ""

if [ -f "$COOKIES_PATH" ]; then
    echo "3. Sample cookies file content (first 10 lines):"
    head -10 "$COOKIES_PATH"
    echo ""
else
    echo "3. No cookies file found. Trigger creation with a download..."
    curl -X POST http://localhost:8000/download \
         -H "Content-Type: application/json" \
         -d '{"url": "https://www.instagram.com/skate_dev/"}' \
         > /dev/null 2>&1
    echo "   Sample file should now be created."
    echo ""
fi

echo "4. To add real Instagram cookies:"
echo "   Method 1 - Browser Extension:"
echo "   • Install 'Get cookies.txt LOCALLY' extension"
echo "   • Login to Instagram and download cookies.txt"
echo "   • Replace: cp cookies.txt '$COOKIES_PATH'"
echo ""
echo "   Method 2 - Manual command:"
echo "   • docker cp your_cookies.txt $CONTAINER_NAME:/data/instagram_cookies.txt"
echo ""

echo "5. Test validation after adding cookies:"
echo "   curl -X POST http://localhost:8000/cookies/validate"
echo ""

echo "6. Enhanced health check with cookie status:"
echo "   curl http://localhost:8000/health | jq ."
echo ""

echo "📋 Current service status:"
echo "   Version: 2.0.0 (Enhanced with cookie authentication)"
echo "   Container: $CONTAINER_NAME"
echo "   Status: $(docker ps --filter name=$CONTAINER_NAME --format '{{.Status}}')"
echo ""

echo "🎯 Next steps:"
echo "   1. Add real Instagram cookies using one of the methods above"
echo "   2. Validate cookies: curl -X POST http://localhost:8000/cookies/validate"
echo "   3. Test downloads will now use authentication and avoid rate limits"
