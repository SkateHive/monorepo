#!/bin/bash

# Instagram Cookie Health Monitor
# Checks cookie expiration and alerts when refresh needed

COOKIE_FILE="/home/pi/skatehive-monorepo/skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt"
LOG_FILE="/home/pi/cookie-monitor.log"
ALERT_DAYS=7  # Alert when cookies expire in less than 7 days

echo "🍪 Instagram Cookie Health Check - $(date)" | tee -a "$LOG_FILE"
echo "================================================" | tee -a "$LOG_FILE"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to convert timestamp to days remaining
check_cookie_expiry() {
    local cookie_name=$1
    local expiry_timestamp=$2
    local current_timestamp=$(date +%s)
    
    if [ "$expiry_timestamp" = "0" ]; then
        echo -e "${GREEN}✅ $cookie_name: Session cookie${NC}" | tee -a "$LOG_FILE"
        return 0
    fi
    
    local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    local expire_date=$(date -d "@$expiry_timestamp" "+%Y-%m-%d %H:%M")
    
    if [ $days_left -lt 0 ]; then
        echo -e "${RED}❌ $cookie_name: EXPIRED ${days_left#-} days ago ($expire_date)${NC}" | tee -a "$LOG_FILE"
        return 2
    elif [ $days_left -lt $ALERT_DAYS ]; then
        echo -e "${YELLOW}⚠️  $cookie_name: Expires in $days_left days ($expire_date)${NC}" | tee -a "$LOG_FILE"
        return 1
    else
        echo -e "${GREEN}✅ $cookie_name: $days_left days remaining ($expire_date)${NC}" | tee -a "$LOG_FILE"
        return 0
    fi
}

# Parse cookies and check expiry
expired_count=0
warning_count=0
good_count=0

if [ ! -f "$COOKIE_FILE" ]; then
    echo -e "${RED}❌ Cookie file not found: $COOKIE_FILE${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

while IFS=$'\t' read -r domain flag path secure expiry name value; do
    # Skip comments and empty lines
    [[ $domain =~ ^#.*$ ]] && continue
    [[ -z $domain ]] && continue
    
    check_cookie_expiry "$name" "$expiry"
    case $? in
        0) ((good_count++));;
        1) ((warning_count++));;
        2) ((expired_count++));;
    esac
done < "$COOKIE_FILE"

echo "" | tee -a "$LOG_FILE"
echo "📊 Summary:" | tee -a "$LOG_FILE"
echo "   ✅ Good: $good_count cookies" | tee -a "$LOG_FILE"
echo "   ⚠️  Warning: $warning_count cookies (< $ALERT_DAYS days)" | tee -a "$LOG_FILE"
echo "   ❌ Expired: $expired_count cookies" | tee -a "$LOG_FILE"

# Test service health
echo "" | tee -a "$LOG_FILE"
echo "🔍 Service Health Test:" | tee -a "$LOG_FILE"
response=$(curl -s http://localhost:8000/cookies/status)
if echo "$response" | grep -q '"cookies_valid":true'; then
    echo -e "${GREEN}✅ Instagram service: Cookies working${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ Instagram service: Cookies not working${NC}" | tee -a "$LOG_FILE"
    echo "   Response: $response" | tee -a "$LOG_FILE"
fi

# Recommendations
echo "" | tee -a "$LOG_FILE"
if [ $expired_count -gt 0 ] || [ $warning_count -gt 0 ]; then
    echo -e "${YELLOW}🔄 RECOMMENDATION: Refresh Instagram cookies soon${NC}" | tee -a "$LOG_FILE"
    echo "   1. Login to Instagram in browser" | tee -a "$LOG_FILE"
    echo "   2. Use 'Get cookies.txt LOCALLY' extension" | tee -a "$LOG_FILE"
    echo "   3. Replace $COOKIE_FILE" | tee -a "$LOG_FILE"
    echo "   4. Restart Docker container: docker restart ytipfs-worker" | tee -a "$LOG_FILE"
else
    echo -e "${GREEN}✅ All cookies healthy - no action needed${NC}" | tee -a "$LOG_FILE"
fi

echo "================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Exit codes for automation
if [ $expired_count -gt 0 ]; then
    exit 2  # Critical
elif [ $warning_count -gt 0 ]; then
    exit 1  # Warning
else
    exit 0  # OK
fi
