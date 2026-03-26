# 🍪 Instagram Cookie Management Operations Guide

**Last Updated:** December 5, 2025  
**Criticality:** 🔴 HIGH - Service Dependent  
**Audience:** DevOps, System Administrators

---

## 📋 Table of Contents
- [Overview](#overview)
- [Cookie Lifecycle](#cookie-lifecycle)
- [Acquisition Methods](#acquisition-methods)
- [Installation & Setup](#installation--setup)
- [Monitoring & Validation](#monitoring--validation)
- [Refresh Procedures](#refresh-procedures)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Automation](#automation)

---

## 🎯 Overview

Instagram cookies are **critical authentication credentials** required for the Instagram Downloader service to function. Without valid cookies:
- ❌ All download requests will fail
- ❌ Service health checks show warnings
- ❌ User-submitted Instagram content cannot be ingested

### Cookie Format: Netscape HTTP Cookie File
```
# Netscape HTTP Cookie File
.instagram.com    TRUE    /    TRUE    1735689600    sessionid    12345%3A...
.instagram.com    TRUE    /    FALSE   1735689600    csrftoken    abc123...
.instagram.com    TRUE    /    TRUE    1735689600    ds_user_id   123456789
```

### Typical Validity Period:
- **Average:** 30-90 days
- **Requires:** Regular monitoring and refresh
- **Warning Threshold:** 7 days before expiration

---

## ⏱️ Cookie Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    Cookie Lifecycle                          │
└─────────────────────────────────────────────────────────────┘

   Login to Instagram          Export Cookies         Install Cookies
         │                           │                        │
         ▼                           ▼                        ▼
   ┌──────────┐              ┌──────────┐            ┌──────────┐
   │ Browser  │─────────────►│ Browser  │───────────►│ Server   │
   │ Session  │              │ Extension│            │ File     │
   └──────────┘              └──────────┘            └──────────┘
         │                                                  │
         │                                                  │
         │                   Monitor Expiration            │
         │◄─────────────────────────────────────────────────┘
         │
         ▼
   ┌──────────────────────────────────────────────────────┐
   │  Cookie Status:                                       │
   │  • Valid (> 7 days until expiry) ✅                   │
   │  • Warning (< 7 days) ⚠️                              │
   │  • Expired / Invalid ❌                               │
   └──────────────────────────────────────────────────────┘
         │
         │ When expired/invalid
         ▼
   Refresh Required (return to login step)
```

---

## 📥 Acquisition Methods

### Method 1: Browser Extension (Recommended) ⭐

**Best For:** Quick setup, reliability, ease of use

#### Chrome/Edge - "Get cookies.txt LOCALLY"
1. Install extension: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
2. Visit `https://www.instagram.com` and log in with your account
3. Click the extension icon
4. Click "Export" → Select "Netscape" format
5. Save as `cookies.txt`

#### Firefox - "cookies.txt"
1. Install extension: [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)
2. Visit `https://www.instagram.com` and log in
3. Click extension icon → "Current Site"
4. Save the exported file as `cookies.txt`

---

### Method 2: Developer Tools (Manual)

**Best For:** Understanding cookie structure, troubleshooting

1. Open Instagram in browser and log in
2. Open Developer Tools (F12)
3. Go to **Application** tab (Chrome) or **Storage** tab (Firefox)
4. Navigate to **Cookies** → `https://www.instagram.com`
5. Manually copy these critical cookies:
   - `sessionid` (most important)
   - `csrftoken`
   - `ds_user_id`
   - `mid`
   - `ig_did`
   - `rur`

6. Format as Netscape file:
```
# Netscape HTTP Cookie File
.instagram.com    TRUE    /    TRUE    [expiry_timestamp]    sessionid    [value]
.instagram.com    TRUE    /    FALSE   [expiry_timestamp]    csrftoken    [value]
.instagram.com    TRUE    /    TRUE    [expiry_timestamp]    ds_user_id   [value]
```

**⚠️ Expiry Timestamp:** Convert from browser (milliseconds) to Unix timestamp (seconds)
```bash
# Browser shows: 1735689600000 (milliseconds)
# Netscape needs: 1735689600 (seconds)
# Divide by 1000
```

---

### Method 3: yt-dlp Cookie Extraction

**Best For:** Automated setups, CI/CD

```bash
# Extract cookies from browser
yt-dlp --cookies-from-browser chrome --cookies cookies.txt

# Or from specific browser profile
yt-dlp --cookies-from-browser firefox:~/.mozilla/firefox/xxxxx.default-release --cookies cookies.txt
```

---

## 📦 Installation & Setup

### Production Setup (Mac Mini M4)

#### Step 1: Prepare Cookie File
```bash
# Ensure proper format (Netscape)
head -1 cookies.txt
# Should output: # Netscape HTTP Cookie File

# Check for critical cookies
grep -E "(sessionid|csrftoken|ds_user_id)" cookies.txt
# Should show at least these 3 cookies
```

#### Step 2: Install on Server

**Option A: Direct Copy** (if you have SSH/local access)
```bash
# Copy to Mac Mini M4
scp cookies.txt user@minivlad.tail83ea3e.ts.net:/path/to/skatehive-monorepo/skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# Set permissions
ssh user@minivlad.tail83ea3e.ts.net "chmod 600 /path/to/cookies/cookies.txt"
```

**Option B: Manual Installation**
```bash
# Backup old cookies
cp skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt \
   skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt.backup

# Install new cookies
cp /path/to/new/cookies.txt \
   skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt

# Restart service
docker restart ytipfs-worker

# Verify
curl http://localhost:6666/cookies/status
```

#### Step 3: Restart Service
```bash
# Restart Instagram downloader container
docker restart ytipfs-worker

# Wait for service to start (2-3 seconds)
sleep 3
```

#### Step 4: Verify Installation
```bash
# Check cookie status endpoint
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status

# Expected output:
# {
#   "cookies_exist": true,
#   "cookies_valid": true,
#   "expires_at": "2025-01-15T00:00:00Z",
#   "days_until_expiry": 41
# }
```

---

### Development Setup (Local)

```bash
# Navigate to Instagram downloader
cd skatehive-instagram-downloader/ytipfs-worker

# Create cookies directory if needed
mkdir -p cookies

# Copy your cookies
cp /path/to/downloaded/cookies.txt cookies/cookies.txt

# Set restrictive permissions
chmod 600 cookies/cookies.txt

# Start service
docker-compose up -d

# Verify
curl http://localhost:6666/cookies/status
```

---

## 🔍 Monitoring & Validation

### Automated Monitoring

The leaderboard API automatically monitors cookie status:

```bash
# Check overall service status (includes cookie info)
curl https://api.skatehive.app/api/status

# Look for Instagram services:
{
  "services": [
    {
      "id": "macmini-insta",
      "name": "Mac Mini IG",
      "category": "Instagram Downloader",
      "isHealthy": true,
      "cookieInfo": {
        "valid": true,
        "exists": true,
        "expiresAt": "2025-01-15T00:00:00Z",
        "daysUntilExpiry": 41
      }
    }
  ]
}
```

### Manual Validation

#### Check Cookie Status:
```bash
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

**Interpretation:**
- ✅ `"cookies_valid": true` - All good, service operational
- ⚠️ `"days_until_expiry": 5` - Warning! Refresh soon
- ❌ `"cookies_valid": false` - Service will fail, refresh immediately

#### Test Download Capability:
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/instagram/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.instagram.com/reel/test123/"}'
```

**Success Indicators:**
- HTTP 200 response
- Returns IPFS CID
- No authentication errors

**Failure Indicators:**
- HTTP 401/403 (authentication failed)
- Error message about cookies
- "Login required" in response

---

## 🔄 Refresh Procedures

### When to Refresh:
1. **Scheduled:** Every 30-60 days (before expiration)
2. **Warning Alert:** When `days_until_expiry < 7`
3. **Failure:** When `cookies_valid: false`
4. **After Instagram Changes:** Password reset, security checkpoints

### Refresh Process:

#### 1. Acquire New Cookies
```bash
# Use browser extension (Method 1) or dev tools (Method 2)
# Export to: new-cookies.txt
```

#### 2. Validate Locally (Optional but Recommended)
```bash
# Test on local instance first
cd skatehive-instagram-downloader/ytipfs-worker
cp new-cookies.txt cookies/cookies.txt
docker-compose restart

# Test
curl http://localhost:6666/cookies/status
```

#### 3. Deploy to Production
```bash
# Use automated script
cd /path/to/skatehive-monorepo
# Manual installation
cp new-cookies.txt skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt
docker restart ytipfs-worker

# Verify
config/scripts/cookie-health-check.sh
```

#### 4. Verify Deployment
```bash
# Check status endpoint
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status

# Verify in monitoring
curl https://api.skatehive.app/api/status | jq '.services[] | select(.category=="Instagram Downloader")'
```

#### 5. Document in Emergency Recovery
```bash
# Note the refresh in logs
echo "$(date): Refreshed Instagram cookies, expires $(date -d '+60 days')" >> cookie-refresh.log
```

---

## 🚨 Troubleshooting

### Problem: "cookies_valid: false" but file exists

**Possible Causes:**
1. Cookies expired
2. Instagram detected suspicious activity
3. Password changed
4. Browser logged out

**Solution:**
```bash
# 1. Check actual expiration dates in file
grep -E "sessionid|csrftoken" cookies/cookies.txt | awk '{print $5}'

# 2. Compare with current time
date +%s

# If expired, refresh cookies using acquisition methods above
```

---

### Problem: Downloads fail with "Login required"

**Diagnosis:**
```bash
# Check cookie file format
head -1 /path/to/cookies/cookies.txt
# Must be: # Netscape HTTP Cookie File

# Check for critical cookies
grep "sessionid" /path/to/cookies/cookies.txt
```

**Solution:**
- Ensure Netscape format header is present
- Verify `sessionid` cookie exists and is not expired
- Re-export cookies from browser while logged in

---

### Problem: Service health shows "cookies_exist: false"

**Diagnosis:**
```bash
# Check if file exists
ls -la skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# Check container mount
docker exec ytipfs-worker ls -la /app/cookies/
```

**Solution:**
```bash
# Ensure file is in correct location
# Ensure docker-compose.yml has volume mount:
# volumes:
#   - ./cookies:/app/cookies

# Restart container
docker restart ytipfs-worker
```

---

### Problem: "Permission denied" reading cookies

**Solution:**
```bash
# Set correct permissions
chmod 600 /path/to/cookies/cookies.txt

# Set correct ownership (if running as different user)
chown dockeruser:dockeruser /path/to/cookies/cookies.txt
```

---

## 🔒 Security Best Practices

### 1. **Restrictive File Permissions**
```bash
# Only owner can read/write
chmod 600 cookies/cookies.txt

# Verify
ls -la cookies/cookies.txt
# Should show: -rw------- (600)
```

### 2. **Never Commit to Git**
```bash
# Ensure .gitignore includes:
**/cookies/cookies.txt
**/.cookies.txt
*cookies*.txt
```

### 3. **Use Dedicated Account**
- ⚠️ **Do NOT use personal Instagram account**
- ✅ Create dedicated service account
- ✅ Use strong, unique password
- ✅ Enable 2FA backup codes (not phone-based)

### 4. **Rotate Regularly**
- Schedule cookie refresh every 30-45 days
- Don't wait for expiration warnings
- Document refresh dates

### 5. **Monitor for Anomalies**
- Watch for unexpected expiration
- Alert on "suspicious activity" from Instagram
- Keep backup cookies ready

### 6. **Backup Strategy**
```bash
# Backup current cookies before refresh
cp cookies/cookies.txt cookies/cookies.txt.backup-$(date +%Y%m%d)

# Keep last 3 backups
ls -t cookies/cookies.txt.backup-* | tail -n +4 | xargs rm -f
```

---

## 🤖 Automation

### Automated Monitoring (Already Configured)

The `cookie-health-check.sh` script runs automatically every 6 hours via launchd.

**Features:**
- ✅ Parses cookie file for expiration dates
- ✅ Tests actual service connectivity
- ✅ Sends Discord alerts when cookies expire soon
- ✅ Detailed logging to `~/cookie-monitor.log`

**Setup (one-time):**
```bash
cd /path/to/skatehive-monorepo

# Install launchd job
cp com.skatehive.cookie-monitor.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.skatehive.cookie-monitor.plist

# Verify it's loaded
launchctl list | grep skatehive
```

**Manual run:**
```bash
config/scripts/cookie-health-check.sh
```

**Configure Discord alerts (optional):**
Add `DISCORD_WEBHOOK_URL` to your `skatehive.config` file to receive alerts.

**See:** `skatehive-instagram-downloader/com.skatehive.cookie-monitor.plist` for launchd config.

---

## 📊 Cookie Status Dashboard

Add to `skatehive-dashboard/dashboard.py`:

```python
def render_cookie_status(self):
    """Display Instagram cookie status"""
    
    cookie_data = self.fetch_cookie_status()
    
    if cookie_data["cookies_valid"]:
        status = "✅ VALID"
        style = "green"
    elif not cookie_data["cookies_exist"]:
        status = "❌ MISSING"
        style = "red"
    else:
        status = "⚠️ INVALID"
        style = "yellow"
    
    days = cookie_data.get("days_until_expiry", "N/A")
    expires = cookie_data.get("expires_at", "Unknown")
    
    return Panel(
        f"[bold]Status:[/bold] [{style}]{status}[/{style}]\n"
        f"[bold]Expires:[/bold] {expires}\n"
        f"[bold]Days Remaining:[/bold] {days}",
        title="🍪 Instagram Cookies",
        border_style=style
    )
```

---

## 📚 Related Documentation

- [Instagram Downloader README](../../skatehive-instagram-downloader/README.md)
- [Service Health Monitoring](../../leaderboard-api/README.md#status-endpoint)
- [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)
- [System Architecture](../architecture/ARCHITECTURE.md)

---

## 🆘 Emergency Contacts

**If cookies cannot be refreshed:**
1. Check Instagram account status (not suspended/banned)
2. Try different browser/device
3. Use yt-dlp extraction method as fallback
4. Consider creating new service account

**Service Impact:**
- Instagram downloads will fail
- Service remains online but non-functional
- Other services (Video Transcoder, Account Manager) unaffected

---

**Document Status:** ✅ Complete  
**Last Cookie Refresh:** Check `/instagram/cookies/status`  
**Next Scheduled Review:** January 5, 2026  
**Maintainer:** SkateHive DevOps Team
