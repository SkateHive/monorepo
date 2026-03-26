# 🏗️ Infrastructure Operations Guide

**Last Updated:** December 5, 2025  
**Audience:** DevOps, System Administrators, Senior Developers

---

## 📋 Table of Contents
- [Overview](#overview)
- [Service Management](#service-management)
- [Deployment Workflows](#deployment-workflows)
- [Backup & Recovery](#backup--recovery)
- [Network Operations](#network-operations)
- [Monitoring & Alerting](#monitoring--alerting)
- [Maintenance Procedures](#maintenance-procedures)
- [Emergency Procedures](#emergency-procedures)

---

## 🎯 Overview

This guide covers day-to-day operations for the SkateHive infrastructure, including service management, deployments, and emergency procedures.

### Infrastructure Components:
- **Primary Host:** Mac Mini M4 (minivlad.tail83ea3e.ts.net)
- **Secondary Host:** Raspberry Pi 5 (vladsberry.tail83ea3e.ts.net)
- **Container Runtime:** Docker with Docker Compose
- **Network:** Tailscale mesh with Funnel for public access
- **Services:** 3 primary services across 2 hosts

---

## 🔧 Service Management

### Starting Services

#### Mac Mini M4 (Primary)

```bash
# Navigate to monorepo
cd /path/to/skatehive-monorepo

# Start all services
docker-compose up -d

# Or start individual services:
docker-compose up -d video-worker       # Video Transcoder
docker-compose up -d ytipfs-worker      # Instagram Downloader
```

#### Raspberry Pi 5 (Secondary)

```bash
# Navigate to monorepo
cd /path/to/skatehive-monorepo

# Start services (when Pi is active)
docker-compose up -d video-worker ytipfs-worker
```

---

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop specific service
docker-compose stop video-worker

# Stop and remove containers (preserves volumes)
docker-compose down --volumes
```

---

### Restarting Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker restart ytipfs-worker

# Restart after configuration changes
docker-compose up -d --force-recreate video-worker
```

---

### Checking Service Status

#### Docker Container Status:
```bash
# List running containers with health status
docker ps

# Expected output:
# CONTAINER ID   IMAGE                          STATUS                      PORTS
# def456         video-worker                   Up 2 days (unhealthy)      0.0.0.0:8081->8080/tcp
# ghi789         ytipfs-worker                  Up 2 days (healthy)        0.0.0.0:6666->8000/tcp
```

#### Service Health Endpoints:
```bash
# Video Transcoder
curl https://minivlad.tail83ea3e.ts.net/video/healthz

# Instagram Downloader
curl https://minivlad.tail83ea3e.ts.net/instagram/healthz

# All services via Status API
curl https://api.skatehive.app/api/status | jq
```

---

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f ytipfs-worker

# Last 100 lines
docker-compose logs --tail=100 video-worker

# Logs for specific time range
docker-compose logs --since 2h video-worker

# Container logs directly
docker logs ytipfs-worker -f --tail=50
```

---

## 🚀 Deployment Workflows

### Video Transcoder Deployment

#### Prerequisites:
- Docker installed
- FFmpeg available
- IPFS node running or accessible
- Port 8081 available

#### Deployment Steps:

```bash
# 1. Navigate to service directory
cd skatehive-video-transcoder

# 2. Build image (if changes made)
docker build -t video-transcoder:latest .

# 3. Stop existing container
docker stop video-worker && docker rm video-worker

# 4. Start new container
docker-compose up -d

# 5. Verify deployment
sleep 3
curl https://minivlad.tail83ea3e.ts.net/video/healthz

# 6. Check logs for errors
docker logs video-worker --tail=50
```

#### Rollback Procedure:
```bash
# Restore from backup image
docker stop video-worker
docker run -d \
  --name video-worker \
  --restart unless-stopped \
  -p 8081:8080 \
  -v $(pwd)/data:/app/data \
  video-transcoder:backup-YYYYMMDD

# Verify
curl https://minivlad.tail83ea3e.ts.net/video/healthz
```

---

### Instagram Downloader Deployment

#### Prerequisites:
- Valid Instagram cookies (see [INSTAGRAM_COOKIE_MANAGEMENT.md](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md))
- yt-dlp installed in image
- IPFS access
- Port 6666 available

#### Deployment Steps:

```bash
# 1. Navigate to service
cd skatehive-instagram-downloader/ytipfs-worker

# 2. Backup current cookies
cp cookies/cookies.txt cookies/cookies.txt.backup-$(date +%Y%m%d)

# 3. Rebuild image if code changed
docker build -t instagram-downloader:latest .

# 4. Deploy new version
docker-compose down
docker-compose up -d

# 5. Verify cookies are mounted
docker exec ytipfs-worker ls -la /app/cookies/

# 6. Test functionality
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

---

### Leaderboard API Deployment (Next.js)

#### Prerequisites:
- Node.js 18+ and pnpm
- Valid environment variables
- Access to all service health endpoints

#### Development Deployment:

```bash
# 1. Navigate to leaderboard-api
cd leaderboard-api

# 2. Install dependencies
pnpm install

# 3. Build production bundle
pnpm build

# 4. Start dev server (for testing)
pnpm dev

# 5. Test status endpoint
curl http://localhost:3000/api/status
```

#### Production Deployment (Vercel):

```bash
# 1. Commit changes
git add .
git commit -m "Update leaderboard API"

# 2. Push to main branch
git push origin main

# Vercel auto-deploys on push to main

# 3. Verify deployment
curl https://api.skatehive.app/api/status
```

---

## 💾 Backup & Recovery

### What to Backup:

1. **Instagram Cookies** (Critical - before any changes)
2. **Docker Volumes** (Important - video cache, processing queues)
3. **Configuration Files** (Important - .env, docker-compose.yml)
4. **Logs** (Optional - for debugging historical issues)

---

### Backup Procedures

#### Daily Automated Backup:

Create: `/etc/cron.daily/skatehive-backup.sh`

```bash
#!/bin/bash
BACKUP_DIR="/backup/skatehive/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup Instagram cookies
cp /path/to/skatehive-monorepo/skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt \
   "$BACKUP_DIR/cookies.txt"

# Backup docker volumes
docker run --rm \
  -v skatehive-video-data:/data \
  -v "$BACKUP_DIR:/backup" \
  alpine tar czf /backup/video-data.tar.gz /data

# Backup configurations
tar czf "$BACKUP_DIR/configs.tar.gz" \
  /path/to/skatehive-monorepo/*/docker-compose.yml \
  /path/to/skatehive-monorepo/*/.env

# Keep last 30 days
find /backup/skatehive -type d -mtime +30 -exec rm -rf {} \;

echo "$(date): Backup completed to $BACKUP_DIR" >> /var/log/skatehive-backup.log
```

---

#### Manual Pre-Deployment Backup:

```bash
#!/bin/bash
# pre-deploy-backup.sh

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="./backups/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# Backup current state
docker-compose config > "$BACKUP_DIR/docker-compose.yml"
cp .env "$BACKUP_DIR/.env"

# Export current container images
docker save video-transcoder:latest > "$BACKUP_DIR/video-transcoder.tar"
docker save instagram-downloader:latest > "$BACKUP_DIR/instagram-downloader.tar"

# Backup cookies
cp skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt \
   "$BACKUP_DIR/cookies.txt"

echo "Backup created: $BACKUP_DIR"
```

---

### Recovery Procedures

#### Restore Instagram Cookies:

```bash
# Stop service
docker stop ytipfs-worker

# Restore from backup
cp /backup/skatehive/20251204/cookies.txt \
   skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# Verify permissions
chmod 600 skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# Restart service
docker start ytipfs-worker

# Verify
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

---

#### Full Service Restore:

```bash
# 1. Stop all services
docker-compose down

# 2. Restore configurations
cp /backup/skatehive/20251204/docker-compose.yml ./
cp /backup/skatehive/20251204/.env ./

# 3. Load container images
docker load < /backup/skatehive/20251204/video-transcoder.tar
docker load < /backup/skatehive/20251204/instagram-downloader.tar

# 4. Restore volumes
docker run --rm \
  -v skatehive-video-data:/data \
  -v /backup/skatehive/20251204:/backup \
  alpine tar xzf /backup/video-data.tar.gz -C /

# 5. Restore critical files
cp /backup/skatehive/20251204/cookies.txt \
   skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt

# 6. Start services
docker-compose up -d

# 7. Verify all services
curl https://api.skatehive.app/api/status
```

---

## 🌐 Network Operations

### Tailscale Funnel Setup

#### Enable Funnel on Mac Mini M4:

```bash
# Serve local services on the tailnet
sudo tailscale serve --bg --set-path /video http://localhost:8081
sudo tailscale serve --bg --set-path /instagram http://localhost:6666

# Expose over the internet on 443
sudo tailscale funnel --bg 443

# Verify status
tailscale serve status
tailscale funnel status

# Expected output:
# https://minivlad.tail83ea3e.ts.net (Funnel on)
#   |-- /video -> http://localhost:8081
#   |-- /instagram -> http://localhost:6666
```

---

### Network Troubleshooting

#### Check Tailscale Connection:

```bash
# Verify Tailscale is running
tailscale status

# Check IP assignments
tailscale ip -4

# Test mesh connectivity
ping vladsberry.tail83ea3e.ts.net
```

---

#### Test Service Accessibility:

```bash
# From within Tailscale network
curl http://100.x.x.x:8081/video/healthz

# From public internet (via Funnel)
curl https://minivlad.tail83ea3e.ts.net/video/healthz

# Check DNS resolution
nslookup minivlad.tail83ea3e.ts.net
```

---

## 📊 Monitoring & Alerting

### Health Check Script

Create: `/usr/local/bin/skatehive-health-check.sh`

```bash
#!/bin/bash

SERVICES=(
  "https://minivlad.tail83ea3e.ts.net/video/healthz|Video Transcoder"
  "https://minivlad.tail83ea3e.ts.net/instagram/healthz|Instagram Downloader"
)

for service in "${SERVICES[@]}"; do
  IFS='|' read -r url name <<< "$service"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 5)
  
  if [ "$response" -eq 200 ]; then
    echo "✅ $name: OK"
  else
    echo "❌ $name: FAILED (HTTP $response)"
    # Send alert (email, Slack, etc.)
  fi
done
```

---

### Monitoring Dashboard

Use the provided TUI dashboard:

```bash
# Navigate to dashboard
cd skatehive-dashboard

# Install dependencies (first time)
pip3 install -r requirements.txt

# Run dashboard
python3 dashboard.py

# Or use the script
./run-dashboard.sh
```

The dashboard provides:
- ✅ Real-time service health
- 🍪 Cookie expiration tracking
- 📊 Docker container status
- ⚠️ Error highlighting
- 📱 Responsive layouts (small/medium/large terminals)

---

## 🛠️ Maintenance Procedures

### Weekly Maintenance Tasks:

```bash
# 1. Check service health
curl https://api.skatehive.app/api/status | jq

# 2. Review logs for errors
docker-compose logs --since 7d | grep -i error

# 3. Check disk usage
df -h
docker system df

# 4. Review cookie expiration
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status

# 5. Verify backups
ls -lh /backup/skatehive/
```

---

### Monthly Maintenance Tasks:

```bash
# 1. Update dependencies
cd skatehive-monorepo
docker-compose pull  # Pull latest base images

# 2. Clean up Docker resources
docker system prune -f
docker volume prune -f

# 3. Rotate logs
docker-compose logs > logs/archive-$(date +%Y%m).log
# (Configure log rotation in docker-compose.yml)

# 4. Review and clean old backups
find /backup/skatehive -type d -mtime +60 -exec rm -rf {} \;

# 5. Test failover to Raspberry Pi (if applicable)
```

---

### Updating Service Images:

```bash
# Pull latest code
cd /path/to/skatehive-monorepo
git pull origin main

# Navigate to service
cd skatehive-video-transcoder

# Rebuild image
docker build -t video-transcoder:latest .

# Tag for rollback
docker tag video-transcoder:latest video-transcoder:backup-$(date +%Y%m%d)

# Deploy new version
docker-compose up -d --force-recreate

# Monitor logs
docker logs video-worker -f
```

---

## 🚨 Emergency Procedures

### Service Down - Emergency Response

#### 1. Identify Failed Service:

```bash
# Check all containers
docker ps -a

# Identify stopped/unhealthy containers
docker ps -f status=exited
docker ps -f health=unhealthy
```

---

#### 2. Quick Restart:

```bash
# Try simple restart first
docker restart <container_name>

# Wait 5 seconds
sleep 5

# Check if resolved
curl https://minivlad.tail83ea3e.ts.net/<service>/healthz
```

---

#### 3. Check Logs for Root Cause:

```bash
# View recent logs
docker logs <container_name> --tail=100

# Common issues:
# - "Permission denied" → Check file permissions
# - "Address already in use" → Check port conflicts
# - "Connection refused" → Check dependent services (IPFS, etc.)
```

---

#### 4. Full Service Restart:

```bash
# Stop container
docker stop <container_name>
docker rm <container_name>

# Remove volumes if corrupted (⚠️ data loss)
# docker volume rm <volume_name>

# Restart via docker-compose
docker-compose up -d <service_name>
```

---

### Instagram Cookies Invalid - Emergency Fix

```bash
# 1. Verify issue
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
# If "cookies_valid": false

# 2. Quick refresh using manual installation
cp /path/to/new/cookies.txt skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt
docker restart ytipfs-worker

# 3. If no new cookies available, service degradation:
# - Downloads will fail
# - Service remains online
# - Other services unaffected
# - Obtain new cookies ASAP (see INSTAGRAM_COOKIE_MANAGEMENT.md)
```

---

### Complete Infrastructure Failure (Mac Mini Down):

#### Failover to Raspberry Pi:

```bash
# 1. Verify Raspberry Pi is accessible
ping vladsberry.tail83ea3e.ts.net

# 2. Copy critical files to Pi:
scp skatehive-instagram-downloader/ytipfs-worker/cookies/cookies.txt \
    pi@vladsberry.tail83ea3e.ts.net:/path/to/monorepo/skatehive-instagram-downloader/ytipfs-worker/cookies/

# 3. Start services on Pi:
ssh pi@vladsberry.tail83ea3e.ts.net
cd /path/to/skatehive-monorepo
docker-compose up -d

# 4. Update DNS/routing (if needed)
# - Update application to point to vladsberry.tail83ea3e.ts.net
# - Or reconfigure Tailscale Funnel

# 5. Verify services
curl https://vladsberry.tail83ea3e.ts.net/video/healthz
curl https://vladsberry.tail83ea3e.ts.net/instagram/healthz
```

---

### Container Won't Start - Debugging:

```bash
# 1. Check Docker daemon
docker info

# 2. Check port conflicts
sudo lsof -i :8081
sudo lsof -i :6666

# 3. Check volume mounts
docker inspect <container_name> | jq '.[].Mounts'

# 4. Try interactive debugging
docker run -it --rm \
  -v $(pwd)/data:/app/data \
  video-transcoder:latest \
  /bin/sh

# Inside container:
# - Check file permissions
# - Test dependencies (ffmpeg, yt-dlp)
# - Run service manually
```

---

## 📚 Related Documentation

- [System Architecture](../architecture/ARCHITECTURE.md)
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
- [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)
- [API Reference](../reference/API_REFERENCE.md)

---

## 🔗 Quick Reference Commands

```bash
# Service Status
docker ps
curl https://api.skatehive.app/api/status

# Restart All Services
docker-compose restart

# View Logs
docker-compose logs -f

# Health Checks
config/scripts/health-check.sh

# Monitoring Dashboard
cd skatehive-dashboard && python3 dashboard.py

# Backup
./pre-deploy-backup.sh

# Cookie Refresh
# Manual cookie installation
cp /path/to/cookies.txt skatehive-instagram-downloader/ytipfs-worker/data/instagram_cookies.txt
docker restart ytipfs-worker

# Or use the health check for detailed status
config/scripts/cookie-health-check.sh
```

---

**Document Status:** ✅ Complete  
**Emergency Contact:** See team documentation  
**Next Review:** January 5, 2026  
**Maintainer:** SkateHive DevOps Team
