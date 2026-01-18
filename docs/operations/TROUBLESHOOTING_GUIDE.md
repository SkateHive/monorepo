# 🔧 SkateHive Troubleshooting Guide

**Last Updated:** December 5, 2025  
**Audience:** Developers, DevOps, Support Team

---

## 📋 Table of Contents
- [Quick Diagnosis](#quick-diagnosis)
- [Service-Specific Issues](#service-specific-issues)
- [Network & Connectivity](#network--connectivity)
- [Docker & Container Issues](#docker--container-issues)
- [Authentication & Credentials](#authentication--credentials)
- [Performance Issues](#performance-issues)
- [Common Error Messages](#common-error-messages)
- [Debugging Tools](#debugging-tools)

---

## 🚀 Quick Diagnosis

### Is Everything Down? Start Here:

```bash
# 1. Check all services at once
curl https://api.skatehive.app/api/status | jq

# 2. Check Docker containers
docker ps -a

# 3. Check Tailscale connectivity
tailscale status

# 4. Check system resources
df -h           # Disk space
free -h         # Memory
top -b -n 1     # CPU usage
```

### Decision Tree:

```
All services unreachable?
├─ Yes → Check Tailscale Network section
└─ No → Continue

Specific service failing?
├─ Video Transcoder → See Video Transcoder Issues
├─ Instagram Downloader → See Instagram Downloader Issues
├─ Account Manager → See Account Manager Issues
└─ Leaderboard API → See Leaderboard API Issues

Container status "Exited"?
└─ Check Docker & Container Issues section

Getting timeout errors?
└─ Check Network & Connectivity section

"Invalid credentials" or "Authentication failed"?
└─ Check Authentication & Credentials section
```

---

## 🎬 Video Transcoder Issues

### Issue: Service Health Check Fails (HTTP 500/503)

**Symptoms:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/healthz
# Returns: HTTP 500 Internal Server Error
```

**Diagnosis:**
```bash
# Check container status
docker ps -f name=video-worker

# Check logs
docker logs video-worker --tail=50
```

**Common Causes & Solutions:**

#### 1. FFmpeg Not Found
**Logs show:** `ffmpeg: command not found`

**Solution:**
```bash
# Verify FFmpeg in container
docker exec video-worker which ffmpeg

# If missing, rebuild image
cd skatehive-video-transcoder
docker-compose build --no-cache
docker-compose up -d
```

---

#### 2. IPFS Connection Failed
**Logs show:** `Connection refused to IPFS node` or `ECONNREFUSED 127.0.0.1:5001`

**Solution:**
```bash
# Check IPFS is running
curl http://localhost:5001/api/v0/version

# If not running, start IPFS
# (Depends on your IPFS setup - local daemon, remote node, etc.)

# Verify IPFS endpoint in environment
docker exec video-worker env | grep IPFS
```

---

#### 3. Disk Space Full
**Logs show:** `ENOSPC: no space left on device`

**Solution:**
```bash
# Check disk usage
df -h

# Clean up Docker resources
docker system prune -f
docker volume prune -f

# Remove old video cache
cd skatehive-video-transcoder/data
find . -type f -mtime +7 -delete  # Remove files older than 7 days
```

---

### Issue: Video Upload Times Out

**Symptoms:**
- Upload hangs indefinitely
- No progress updates
- Client receives timeout

**Diagnosis:**
```bash
# Check processing queue
docker logs video-worker | grep -i "processing"

# Check system load
docker stats video-worker
```

**Solutions:**

#### Large Video File:
```bash
# Check max file size configuration
docker exec video-worker env | grep MAX_FILE_SIZE

# Increase if needed (docker-compose.yml)
environment:
  - MAX_FILE_SIZE=2GB  # Increase this value
```

#### Insufficient Resources:
```bash
# Allocate more resources (docker-compose.yml)
video-worker:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 4G
```

---

### Issue: Transcoding Produces Corrupted Video

**Symptoms:**
- Video uploads successfully but won't play
- Missing audio or video streams
- Incomplete HLS segments

**Diagnosis:**
```bash
# Test FFmpeg directly in container
docker exec -it video-worker /bin/sh

# Inside container:
ffmpeg -i /app/data/input.mp4 -t 5 /app/data/test-output.mp4

# Check if output is valid
ffprobe /app/data/test-output.mp4
```

**Solutions:**

#### Invalid Input Format:
```bash
# Add format validation before processing
# Check video codec support
docker exec video-worker ffmpeg -codecs | grep -i h264
```

#### Incomplete Uploads:
```bash
# Ensure full upload before processing
# Check file size matches expected
```

---

## 📸 Instagram Downloader Issues

### Issue: "Invalid Instagram Cookies" Error

**Symptoms:**
```bash
curl https://minivlad.tail83ea3e.ts.net/instagram/healthz
# Returns: "cookies_valid": false
```

**Diagnosis:**
```bash
# Check cookie status
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status

# Response shows:
{
  "cookies_exist": true,
  "cookies_valid": false,
  "expires_at": "2025-11-01T00:00:00Z",  # Already expired
  "days_until_expiry": -34
}
```

**Solution:**
Follow [Instagram Cookie Management Guide](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md) to refresh cookies.

**Quick Fix:**
```bash
# Use setup script with new cookies
./setup-instagram-cookies.sh /path/to/new/cookies.txt

# Verify
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

---

### Issue: "Login Required" When Downloading

**Symptoms:**
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/instagram/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://instagram.com/p/abc123"}'

# Returns: "Login required" or "User is not authenticated"
```

**Diagnosis:**
```bash
# Check cookie file exists
docker exec ytipfs-worker ls -la /app/cookies/cookies.txt

# Check cookie file format
docker exec ytipfs-worker head -1 /app/cookies/cookies.txt
# Should be: # Netscape HTTP Cookie File

# Check sessionid cookie
docker exec ytipfs-worker grep sessionid /app/cookies/cookies.txt
```

**Solutions:**

#### Missing Cookie File:
```bash
# Verify mount in docker-compose.yml
volumes:
  - ./cookies:/app/cookies

# Copy cookies to correct location
cp /path/to/cookies.txt skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# Restart container
docker restart ytipfs-worker
```

#### Incorrect Cookie Format:
```bash
# Cookie file MUST start with Netscape header
echo "# Netscape HTTP Cookie File" | cat - cookies.txt.tmp > cookies.txt

# Ensure Unix line endings (not Windows CRLF)
dos2unix cookies.txt  # or sed -i 's/\r$//' cookies.txt
```

#### Expired Session:
```bash
# Check expiration timestamps in cookie file
docker exec ytipfs-worker grep sessionid /app/cookies/cookies.txt | awk '{print $5}'

# Compare with current time
date +%s

# If expired, refresh cookies (see Cookie Management Guide)
```

---

### Issue: "Rate Limited by Instagram"

**Symptoms:**
- Downloads work, then suddenly fail
- Error: "Please wait a few minutes before you try again"
- HTTP 429 responses

**Diagnosis:**
```bash
# Check recent request count
docker logs ytipfs-worker | grep -c "download"

# Check rate limit errors
docker logs ytipfs-worker | grep -i "rate limit"
```

**Solutions:**

#### Temporary Rate Limit:
```bash
# Wait 15-30 minutes
# Instagram typically resets rate limits quickly

# Monitor recovery
watch -n 60 'curl -s https://minivlad.tail83ea3e.ts.net/instagram/healthz | jq ".cookies_valid"'
```

#### Persistent Rate Limiting:
```bash
# Consider:
# 1. Multiple Instagram accounts with cookie rotation
# 2. Reduce request frequency
# 3. Use different IP (Tailscale exit nodes)
```

---

### Issue: "yt-dlp: Command Not Found"

**Symptoms:**
- Container fails to start
- Downloads fail immediately
- Logs show: `yt-dlp: command not found`

**Diagnosis:**
```bash
# Check if yt-dlp is installed
docker exec ytipfs-worker which yt-dlp

# Check version
docker exec ytipfs-worker yt-dlp --version
```

**Solution:**
```bash
# Rebuild image with yt-dlp
cd skatehive-instagram-downloader/ytipfs-worker

# Ensure Dockerfile includes:
RUN pip install yt-dlp

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

---

## 👤 Account Manager Issues

### Issue: "Insufficient RC for Account Creation"

**Symptoms:**
```bash
curl https://minivlad.tail83ea3e.ts.net/healthz

# Returns:
{
  "status": "healthy",
  "rc_balance": 4628000000000,      # 4.6T
  "rc_required": 9300000000000,     # 9.3T
  "can_create_accounts": false      # ❌
}
```

**Diagnosis:**
```bash
# Check current RC balance
curl https://minivlad.tail83ea3e.ts.net/rc-status | jq

# Check authority account
docker logs skatehive-account-manager | grep -i "authority"
```

**Solution:**

#### Top Up RC Pool:
```bash
# Manual process:
# 1. Log into Hive authority account (wallet)
# 2. Navigate to RC delegation
# 3. Delegate additional RC to service account
#    Target: At least 9.3T RC
# 4. Wait 1-2 minutes for blockchain propagation

# Verify restoration
curl https://minivlad.tail83ea3e.ts.net/rc-status

# Expected:
{
  "rc_balance": 10000000000000,     # 10T ✅
  "can_create_accounts": true
}
```

---

### Issue: "Authority Account Not Found"

**Symptoms:**
- Account creation fails
- Logs: `Authority account does not exist`
- HTTP 500 errors

**Diagnosis:**
```bash
# Check environment configuration
docker exec skatehive-account-manager env | grep AUTHORITY

# Verify authority account exists on blockchain
# (Use Hive block explorer or API)
```

**Solution:**
```bash
# Update environment variable
cd account-manager
nano .env

# Set correct authority account
AUTHORITY_ACCOUNT=your-hive-account

# Restart service
docker-compose restart

# Verify
docker logs skatehive-account-manager | grep "Authority"
```

---

### Issue: Emergency Recovery Keys Not Accessible

**Symptoms:**
- Created accounts but keys not found
- Logs: `Failed to save emergency recovery keys`
- Directory permissions error

**Diagnosis:**
```bash
# Check emergency recovery directory
ls -la account-manager/emergency-recovery/

# Check permissions
docker exec skatehive-account-manager ls -la /app/emergency-recovery/
```

**Solution:**
```bash
# Ensure directory exists and has correct permissions
mkdir -p account-manager/emergency-recovery
chmod 755 account-manager/emergency-recovery

# Ensure volume mount in docker-compose.yml
volumes:
  - ./emergency-recovery:/app/emergency-recovery

# Restart service
docker-compose restart
```

---

## 🏆 Leaderboard API Issues

### Issue: Status Endpoint Returns Stale Data

**Symptoms:**
- `/api/status` shows outdated information
- Services show healthy when actually down

**Diagnosis:**
```bash
# Check if service is actually down
curl https://minivlad.tail83ea3e.ts.net/video/healthz

# Compare with status API
curl https://api.skatehive.app/api/status | jq '.services[] | select(.id=="macmini-video")'
```

**Solution:**
```bash
# Restart Next.js dev server
cd leaderboard-api
pnpm dev

# Or rebuild production
pnpm build && pnpm start

# For Vercel deployments:
# Push to trigger redeployment
git push origin main
```

---

### Issue: Cookie Info Not Showing in Status

**Symptoms:**
- Status endpoint doesn't include `cookieInfo` field
- Instagram services show healthy but no cookie details

**Diagnosis:**
```bash
# Check status API response
curl https://api.skatehive.app/api/status | jq '.services[] | select(.category=="Instagram Downloader")'

# Should include:
# "cookieInfo": {
#   "valid": true/false,
#   "exists": true/false
# }
```

**Solution:**
```bash
# Ensure you're using updated status API code
cd leaderboard-api
git pull origin main

# Verify route.ts includes cookieInfo handling
grep -A 10 "cookieInfo" src/app/api/status/route.ts

# Restart server
pnpm dev
```

---

## 🌐 Network & Connectivity

### Issue: "Cannot Connect to Service" (ECONNREFUSED)

**Symptoms:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/healthz
# curl: (7) Failed to connect to minivlad.tail83ea3e.ts.net port 443: Connection refused
```

**Diagnosis:**
```bash
# Check Tailscale is running
tailscale status

# Check Funnel configuration
tailscale funnel status

# Ping the host
ping minivlad.tail83ea3e.ts.net
```

**Solutions:**

#### Tailscale Not Running:
```bash
# Start Tailscale
sudo tailscale up

# Verify connection
tailscale status
```

#### Funnel Not Enabled:
```bash
# Serve and funnel service paths
sudo tailscale serve --bg --set-path /video http://localhost:8081
sudo tailscale serve --bg --set-path /instagram http://localhost:6666
sudo tailscale serve --bg --set-path /healthz http://localhost:3001
sudo tailscale funnel --bg 443

# Verify
tailscale funnel status
```

#### Service Not Running:
```bash
# Check container status
docker ps -f name=video-worker

# If not running, start it
docker-compose up -d video-worker
```

---

### Issue: Intermittent Connection Timeouts

**Symptoms:**
- Some requests succeed, others timeout
- Logs show: `ETIMEDOUT` or `socket hang up`

**Diagnosis:**
```bash
# Test connection stability
for i in {1..10}; do 
  curl -w "Response time: %{time_total}s\n" https://minivlad.tail83ea3e.ts.net/video/healthz
  sleep 1
done

# Check network latency
ping -c 20 minivlad.tail83ea3e.ts.net
```

**Solutions:**

#### High Network Latency:
```bash
# Check Tailscale routing
tailscale ping minivlad.tail83ea3e.ts.net

# Consider using direct IP if on same network
tailscale ip -4  # Get Tailscale IP

# Use IP directly for local services
curl http://100.x.x.x:8081/video/healthz
```

#### Service Overloaded:
```bash
# Check container resources
docker stats video-worker

# Increase resources if needed (docker-compose.yml)
deploy:
  resources:
    limits:
      memory: 4G
```

---

### Issue: "DNS Resolution Failed"

**Symptoms:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/healthz
# curl: (6) Could not resolve host: minivlad.tail83ea3e.ts.net
```

**Diagnosis:**
```bash
# Check DNS resolution
nslookup minivlad.tail83ea3e.ts.net

# Check Tailscale DNS (MagicDNS)
tailscale status | grep -i dns
```

**Solution:**
```bash
# Restart Tailscale
sudo tailscale down
sudo tailscale up --accept-dns

# Verify MagicDNS is enabled
tailscale status
# Should show: MagicDNS enabled
```

---

## 🐳 Docker & Container Issues

### Issue: Container Keeps Restarting

**Symptoms:**
```bash
docker ps -a
# STATUS: Restarting (1) 5 seconds ago
```

**Diagnosis:**
```bash
# Check last 100 log lines
docker logs --tail=100 <container_name>

# Check exit codes
docker inspect <container_name> | jq '.[].State'
```

**Common Exit Codes:**
- **Exit 1:** General error (check logs)
- **Exit 137:** Out of memory (OOM killed)
- **Exit 139:** Segmentation fault
- **Exit 143:** Graceful termination (SIGTERM)

**Solutions:**

#### Exit 137 (OOM):
```bash
# Increase memory limit
# docker-compose.yml:
services:
  video-worker:
    deploy:
      resources:
        limits:
          memory: 4G  # Increase this
```

#### Crash on Startup:
```bash
# Run container interactively to debug
docker run -it --rm \
  -v $(pwd)/data:/app/data \
  video-transcoder:latest \
  /bin/sh

# Manually run the startup command
node server.js  # or whatever the command is
```

---

### Issue: "Port Already in Use"

**Symptoms:**
- Container fails to start
- Logs: `Error: listen EADDRINUSE: address already in use :::8081`

**Diagnosis:**
```bash
# Find what's using the port
sudo lsof -i :8081
# or
sudo netstat -tulpn | grep 8081
```

**Solutions:**

#### Stop Conflicting Process:
```bash
# Kill the process
sudo kill <PID>

# Or stop conflicting container
docker stop <container_using_port>
```

#### Change Port Mapping:
```bash
# Edit docker-compose.yml
ports:
  - "8082:8080"  # Use different external port

# Restart
docker-compose up -d
```

---

### Issue: Volume Mount Permission Denied

**Symptoms:**
- Container starts but can't read/write files
- Logs: `EACCES: permission denied, open '/app/data/video.mp4'`

**Diagnosis:**
```bash
# Check volume permissions on host
ls -la skatehive-video-transcoder/data/

# Check inside container
docker exec video-worker ls -la /app/data/
```

**Solution:**
```bash
# Fix permissions on host
chmod -R 755 skatehive-video-transcoder/data/
chown -R $USER:$USER skatehive-video-transcoder/data/

# Restart container
docker restart video-worker
```

---

## 🔐 Authentication & Credentials

### Issue: Instagram Cookies Expire Too Quickly

**Symptoms:**
- Cookies valid for only a few days
- Frequent refresh required

**Possible Causes:**
- Using incognito/private browsing to obtain cookies
- Instagram detects suspicious activity
- Using VPN/proxy when logging in

**Solutions:**
```bash
# 1. Use regular browser session (not incognito)
# 2. Log in from stable IP
# 3. Complete any security challenges
# 4. Wait 24 hours after login before exporting
# 5. Export cookies from a trusted device
```

---

### Issue: Hive Account Authority Issues

**Symptoms:**
- Account creation fails with "Missing required authority"
- Logs: `Authority account cannot sign transactions`

**Diagnosis:**
```bash
# Verify authority account keys are correct
docker logs skatehive-account-manager | grep -i "authority"

# Check .env configuration
cat account-manager/.env | grep AUTHORITY
```

**Solution:**
```bash
# Ensure authority account has:
# 1. Active authority keys in environment
# 2. Sufficient RC delegated
# 3. Correct permissions on Hive blockchain

# Update .env with correct keys
cd account-manager
nano .env

AUTHORITY_ACCOUNT=correct-account
AUTHORITY_ACTIVE_KEY=correct-private-key

# Restart
docker-compose restart
```

---

## ⚡ Performance Issues

### Issue: Slow Video Transcoding

**Symptoms:**
- Transcoding takes much longer than expected
- CPU not fully utilized

**Diagnosis:**
```bash
# Check CPU usage during transcoding
docker stats video-worker

# Check FFmpeg threads configuration
docker exec video-worker env | grep THREADS
```

**Solutions:**

#### Increase CPU Allocation:
```bash
# docker-compose.yml
services:
  video-worker:
    deploy:
      resources:
        limits:
          cpus: '4'  # Use more CPU cores
```

#### Optimize FFmpeg Settings:
```bash
# Set threads in environment
environment:
  - FFMPEG_THREADS=4
  - FFMPEG_PRESET=veryfast  # Trade quality for speed
```

---

### Issue: High Memory Usage

**Symptoms:**
- System becomes sluggish
- OOM (Out of Memory) errors
- Containers killed unexpectedly

**Diagnosis:**
```bash
# Check system memory
free -h

# Check container memory usage
docker stats --no-stream

# Check for memory leaks
docker logs video-worker | grep -i "memory"
```

**Solutions:**

#### Limit Container Memory:
```bash
# docker-compose.yml
services:
  video-worker:
    deploy:
      resources:
        limits:
          memory: 2G  # Prevent runaway memory usage
        reservations:
          memory: 1G  # Guarantee minimum
```

#### Clear Caches:
```bash
# Clear video cache
rm -rf skatehive-video-transcoder/data/cache/*

# Clear Docker build cache
docker builder prune -f
```

---

## 🐛 Common Error Messages

### "Error: ENOSPC: no space left on device"

**Meaning:** Disk is full

**Solution:**
```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -af --volumes

# Remove old files
find /path/to/cache -type f -mtime +7 -delete
```

---

### "Error: Maximum call stack size exceeded"

**Meaning:** Recursion limit or memory issue

**Solution:**
```bash
# Increase Node.js memory
environment:
  - NODE_OPTIONS="--max-old-space-size=4096"

# Restart container
docker-compose restart
```

---

### "Error: Cannot find module 'xyz'"

**Meaning:** Missing dependency

**Solution:**
```bash
# Rebuild container
docker-compose build --no-cache <service>
docker-compose up -d <service>
```

---

### "Error: Connection refused ECONNREFUSED"

**Meaning:** Service not running or unreachable

**Solution:**
```bash
# Check if service is running
docker ps -f name=<service>

# Check network connectivity
curl http://localhost:<port>/healthz

# Restart service
docker restart <service>
```

---

## 🛠️ Debugging Tools

### Essential Commands:

```bash
# Comprehensive health check
./health-check.sh

# Check all services
curl https://api.skatehive.app/api/status | jq

# Monitor containers in real-time
docker stats

# Follow logs
docker-compose logs -f

# Interactive container debugging
docker exec -it <container> /bin/sh

# Check container configuration
docker inspect <container> | jq

# Network debugging
docker network inspect skatehive_network

# Volume debugging
docker volume ls
docker volume inspect <volume_name>
```

---

### Monitoring Dashboard:

```bash
cd skatehive-dashboard
python3 dashboard.py

# Provides real-time monitoring of:
# - Service health status
# - Cookie expiration
# - Docker container status
# - Error highlighting
```

---

### Log Analysis:

```bash
# Search for errors
docker-compose logs | grep -i error

# Find specific error patterns
docker logs video-worker 2>&1 | grep -E "(ERROR|FATAL|Exception)"

# Export logs for analysis
docker-compose logs > logs/debug-$(date +%Y%m%d).log
```

---

## 📚 Related Documentation

- [Infrastructure Operations](./INFRASTRUCTURE_OPERATIONS.md)
- [System Architecture](../architecture/ARCHITECTURE.md)
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
- [API Reference](../reference/API_REFERENCE.md)

---

## 🆘 Still Stuck?

1. **Check logs carefully** - Most issues have clear error messages
2. **Review recent changes** - What changed before the issue started?
3. **Test in isolation** - Does the service work outside Docker?
4. **Check dependencies** - Are external services (IPFS, Hive) accessible?
5. **Review documentation** - Might be a known limitation
6. **Emergency recovery** - See `./emergency-recovery.sh`

---

**Document Status:** ✅ Complete  
**Last Updated:** December 5, 2025  
**Maintainer:** SkateHive DevOps Team
