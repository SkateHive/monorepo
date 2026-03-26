# 🏗️ SkateHive System Architecture

**Last Updated:** March 26, 2026  
**Status:** Production

---

## 📋 Table of Contents
- [System Overview](#system-overview)
- [Infrastructure Topology](#infrastructure-topology)
- [Service Architecture](#service-architecture)
- [Network Architecture](#network-architecture)
- [Port Mapping Reference](#port-mapping-reference)
- [Service Dependencies](#service-dependencies)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)

---

## 🎯 System Overview

SkateHive is a decentralized social media platform for skateboarders, built as a monorepo with microservices architecture. The system spans multiple physical hosts connected via Tailscale mesh network and serves content globally.

### Core Components:
1. **Main Application** (Next.js 15) - User-facing web application
2. **skatehive-api** - Hive blockchain API (leaderboard, profiles, feed)
3. **Video Transcoder** - Automated video processing pipeline
4. **Instagram Downloader** - Social media content ingestion
5. **Monitoring Dashboard** - Real-time service health monitoring

---

## 🌐 Infrastructure Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                     INTERNET / PUBLIC ACCESS                     │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │  Tailscale Funnel     │
                    │  (Public Gateway)     │
                    └───────────┬───────────┘
                                │
        ┌───────────────────────┴───────────────────────┐
        │         Tailscale Mesh Network                 │
        │         (100.x.x.x private IPs)               │
        └─────┬──────────────────────────┬──────────────┘
              │                          │
    ┌─────────▼────────┐      ┌─────────▼────────┐
    │   Mac Mini M4    │      │  Raspberry Pi 5   │
    │   (PRIMARY)      │      │   (SECONDARY)     │
    │                  │      │                   │
    │ minivlad.tail... │      │ raspberrypi.t...  │
    └──────────────────┘      └───────────────────┘
```

### Physical Hosts:

#### 🖥️ Mac Mini M4 (Primary Production)
- **Tailscale Name:** `minivlad.tail83ea3e.ts.net`
- **Role:** Primary production services
- **Status:** ✅ Active
- **Services:**
  - Video Transcoder (port 8081)
  - Instagram Downloader (port 6666 -> 8000, served via `/instagram` on 443)

#### 🥧 Raspberry Pi 5 (Secondary/Backup)
- **Tailscale Name:** `vladsberry.tail83ea3e.ts.net`
- **Role:** Backup services, development
- **Status:** ✅ Active
- **Services:**
  - Video Transcoder (port 8081)
  - Instagram Downloader (port 6666 -> 8000, served via `/instagram` on 443)

---

## 🔧 Service Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌──────────────────────┐       │
│  │   skatehive3.0      │         │   skatehive-api       │       │
│  │   (Next.js 15)      │◄────────┤   Hive Blockchain API │       │
│  │   Main App          │         │   Profiles & Feed     │       │
│  └─────────────────────┘         └──────────────────────┘       │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                        API Gateway Layer                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Tailscale Funnel + HTTPS Routing                                │
│  • minivlad.tail83ea3e.ts.net/*                                  │
│  • vladsberry.tail83ea3e.ts.net/*                               │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                       Service Layer                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ Video Transcoder │  │ Instagram        │                     │
│  │ (Node.js/TS)    │  │ Downloader       │                     │
│  │                  │  │ (FastAPI/Python) │                     │
│  │ Port: 8081:8080  │  │ Port: 6666:8000  │                     │
│  └──────────────────┘  └──────────────────┘                     │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                      Storage & Blockchain Layer                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────────┐ │
│  │ Local FS     │  │ IPFS Network   │  │ Hive Blockchain      │ │
│  │ (Video Cache)│  │ (Distributed)  │  │ (API Nodes)          │ │
│  └──────────────┘  └────────────────┘  └──────────────────────┘ │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Service Details:

#### 🎬 Video Transcoder
- **Technology:** Node.js, TypeScript, FFmpeg
- **Purpose:** Automated video transcoding and IPFS upload
- **Container:** `video-worker`
- **Health Endpoint:** `/video/healthz`
- **Key Features:**
  - Multi-format transcoding (HLS, MP4)
  - Automatic IPFS pinning
  - Queue management
  - Progress tracking

#### 📸 Instagram Downloader
- **Technology:** Python, FastAPI
- **Purpose:** Social media content ingestion (Instagram, TikTok, YouTube)
- **Container:** `ytipfs-worker`
- **Health Endpoint:** `/instagram/healthz`
- **Key Features:**
  - Cookie-based authentication
  - Multi-platform support
  - Automatic IPFS upload
  - Metadata extraction
  - Expiration monitoring

#### 🏆 skatehive-api
- **Technology:** Next.js 15, TypeScript
- **Purpose:** Hive blockchain API (leaderboard, profiles, feed)
- **Status Endpoint:** `/api/status`
- **Key Features:**
  - Leaderboard and content ranking
  - User profiles and feed aggregation
  - Multi-service health aggregation
  - Real-time status reporting

#### 📊 Monitoring Dashboard
- **Technology:** Python, Textual TUI
- **Purpose:** Terminal-based service monitoring
- **Key Features:**
  - Real-time health checks
  - Responsive layouts (small/medium/large)
  - Multi-host monitoring
  - Error highlighting

---

## 🌐 Network Architecture

### Tailscale Mesh Configuration

```
Internet
   │
   ├─► Tailscale Funnel (HTTPS Public Gateway)
   │      │
   │      ├─► minivlad.tail83ea3e.ts.net
   │      │     ├─► /video/* → localhost:8081
   │      │     └─► /instagram/* → localhost:6666
   │      │
   │      └─► vladsberry.tail83ea3e.ts.net
   │            ├─► /video/* → localhost:8081
   │            └─► /instagram/* → localhost:6666
   │
   └─► Private Mesh Network (100.x.x.x)
          │
          ├─► Mac Mini M4 (100.x.x.x)
          ├─► Raspberry Pi 5 (100.x.x.x)
          └─► [Other authorized devices]
```

### Public Access URLs:
- **Mac Mini Services:** `https://minivlad.tail83ea3e.ts.net/*`
- **Raspberry Pi Services:** `https://vladsberry.tail83ea3e.ts.net/*`

### Internal Communication:
- All services communicate via Tailscale private network (100.x.x.x)
- No port forwarding required
- Encrypted mesh connections
- DNS resolution via Tailscale MagicDNS

---

## 🔌 Port Mapping Reference

### Mac Mini M4 (Primary)

| Service | External Port | Internal Port | Container Name | Protocol |
|---------|--------------|---------------|----------------|----------|
| Video Transcoder | 8081 | 8080 | video-worker | HTTP |
| Instagram Downloader | 443 (`/instagram`) | 6666 → 8000 | ytipfs-worker | HTTP |

### Raspberry Pi 5 (Secondary)

| Service | External Port | Internal Port | Status |
|---------|--------------|---------------|--------|
| Video Transcoder | 8081 | 8080 | ✅ Active |
| Instagram Downloader | 443 (`/instagram`) | 6666 → 8000 | ✅ Active |

### Port Selection Rationale:
- **8081 (Video):** Standard port for video transcoder service
- **6666 → 8000 (Instagram):** Host port 6666 maps to FastAPI 8000, exposed via HTTPS `/instagram`

---

## 🔗 Service Dependencies

```
┌─────────────────────┐
│   skatehive3.0      │
│   (Main App)        │
└──────────┬──────────┘
           │
           ├──► skatehive-api (rankings, profiles, feed)
           ├──► Video Transcoder (uploads)
           └──► Instagram Downloader (content)
                      │
┌─────────────────────▼──────────────────────┐
│         Service Dependencies                │
├────────────────────────────────────────────┤
│                                             │
│  Video Transcoder                           │
│  ├─► FFmpeg (binary)                        │
│  ├─► IPFS Network (pinning)                 │
│  └─► Local Storage (cache)                  │
│                                             │
│  Instagram Downloader                       │
│  ├─► yt-dlp (binary)                        │
│  ├─► Instagram Cookies (auth)               │
│  ├─► IPFS Network (storage)                 │
│  └─► Local Storage (temp)                   │
│                                             │
│  skatehive-api                              │
│  ├─► Hive Blockchain (content data)         │
│  └─► All Service Health Endpoints           │
│                                             │
└─────────────────────────────────────────────┘
```

### Critical Dependencies:
1. **IPFS Network** - Required for video and Instagram services
2. **Instagram Cookies** - Required for Instagram downloads
3. **Tailscale Network** - Required for all inter-service communication

---

## 📊 Data Flow

### Video Upload Flow:
```
User Upload (skatehive3.0)
    │
    ▼
Video Transcoder (/video/transcode)
    │
    ├─► FFmpeg Processing
    │       │
    │       ├─► HLS Segments
    │       └─► MP4 Output
    │
    ├─► IPFS Upload
    │       │
    │       └─► CID Generation
    │
    └─► Hive Blockchain Post
            │
            └─► Content Indexing
```

### Instagram Content Ingestion:
```
URL Submission (skatehive3.0)
    │
    ▼
Instagram Downloader (/download)
    │
    ├─► Cookie Authentication
    │       │
    │       └─► Instagram API Request
    │
    ├─► Media Download
    │       │
    │       └─► Metadata Extraction
    │
    ├─► IPFS Upload
    │       │
    │       └─► CID Generation
    │
    └─► Return to Caller
```

---

## 🔒 Security Architecture

### Authentication Layers:

1. **Public Access**
   - Tailscale Funnel provides HTTPS (automatic TLS)
   - No API keys required for health endpoints
   - Rate limiting at Tailscale level

2. **Service-to-Service**
   - Tailscale ACLs control inter-service communication
   - Private mesh network (100.x.x.x)
   - No direct internet exposure

3. **External APIs**
   - Instagram: Cookie-based authentication (Netscape format)
   - Hive Blockchain: Key-based signing
   - IPFS: Public network, content-addressed

### Secrets Management:

```
┌─────────────────────────────────────┐
│      Secrets Storage                 │
├─────────────────────────────────────┤
│                                     │
│  Instagram Cookies                  │
│  └─► /cookies/cookies.txt          │
│      (Netscape format)              │
│                                     │
│  Environment Variables              │
│  └─► Docker Compose secrets        │
│                                     │
└─────────────────────────────────────┘
```

### Network Security:
- ✅ All external traffic via HTTPS (Tailscale Funnel)
- ✅ Private mesh network for service communication
- ✅ No port forwarding or router configuration needed
- ✅ Automatic certificate management
- ✅ ACL-based access control

---

## 📈 Scalability Considerations

### Current Limitations:
1. **Single Host Processing** - Mac Mini M4 handles all production load
2. **Instagram Cookie Single-Point-of-Failure** - One cookie for all requests
3. **Local Storage** - Video cache on single host filesystem

### Scale-Out Strategy:
1. **Multi-Host Load Balancing** - Raspberry Pi as active secondary
2. **Cookie Rotation** - Multiple Instagram accounts
3. **Distributed Storage** - IPFS cluster for cache

---

## 🔄 High Availability

### Current Setup (Active-Passive):
- **Primary:** Mac Mini M4 (all production traffic)
- **Secondary:** Raspberry Pi 5 (offline, manual failover)

### Failover Process:
1. Monitor detects Mac Mini failure
2. Manual DNS/routing update to Raspberry Pi
3. Instagram cookies copied to secondary
4. Services restart on new host

### Health Monitoring:
- skatehive-api polls all services every 30s
- Dashboard provides real-time TUI monitoring
- Cookie expiration tracked automatically

---

## 📝 Related Documentation

- [Infrastructure Operations Guide](../operations/INFRASTRUCTURE_OPERATIONS.md)
- [Troubleshooting Guide](../operations/TROUBLESHOOTING_GUIDE.md)
- [API Reference](../reference/API_REFERENCE.md)
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

---

**Document Status:** ✅ Complete  
**Next Review:** June 26, 2026  
**Maintainer:** SkateHive DevOps Team
