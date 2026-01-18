# 🍪 Cookie Monitoring Setup Instructions

## Quick Start

The Instagram cookie health check runs automatically every 6 hours via launchd.

### Install Automation (One-Time Setup)

```bash
cd /Users/vladnikolaev/skatehive-monorepo

# Install the launchd job
cp skatehive-instagram-downloader/com.skatehive.cookie-monitor.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.skatehive.cookie-monitor.plist

# Verify it's running
launchctl list | grep skatehive
```

### Configure Discord Alerts (Optional)

Add to your `skatehive.config`:

```bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
```

### Manual Check

Run anytime to check cookie status:

```bash
./skatehive-instagram-downloader/cookie-health-check.sh
```

### View Logs

```bash
# Monitor log (all health checks)
tail -f ~/cookie-monitor.log

# Service logs (errors)
tail -f /tmp/cookie-monitor.error.log
```

### Stop Automation

```bash
launchctl unload ~/Library/LaunchAgents/com.skatehive.cookie-monitor.plist
```

## How It Works

1. **Every 6 hours**, launchd runs `skatehive-instagram-downloader/cookie-health-check.sh`
2. Script parses cookie file, calculates expiration dates
3. Tests actual service connectivity at `localhost:6666/cookies/status`
4. If cookies expire in < 7 days or are expired:
   - Logs warning to `~/cookie-monitor.log`
   - Sends Discord alert (if webhook configured)
   - Exits with warning/error code

## What's Different Now

**Deleted:** `setup-instagram-cookies.sh` (redundant docs-only script)

**Simplified:** `health-check.sh` now just calls API endpoints instead of parsing cookies

**Organized:** `cookie-health-check.sh` moved to `skatehive-instagram-downloader/` (service-specific)
- Discord alerts
- Automated scheduling
- Detailed expiry analysis
- Actionable recommendations

See: `docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md` for full cookie management guide
