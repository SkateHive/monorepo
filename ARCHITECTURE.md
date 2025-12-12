# 🏗️ SkateHive System Architecture

**Last Updated:** December 5, 2025  
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
2. **Leaderboard API** (Next.js 15) - Content ranking and status monitoring
3. **Video Transcoder** - Automated video processing pipeline
4. **Instagram Downloader** - Social media content ingestion
5. **Account Manager** - Hive blockchain account management
6. **Monitoring Dashboard** - Real-time service health monitoring
7. **VSC Node** - Blockchain integration

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
- **Tailscale Name:** `minivlad.tail9656d3.ts.net`
- **Role:** Primary production services
- **Status:** ✅ Active
- **Services:**
  - Video Transcoder (port 8081)
  - Instagram Downloader (port 6666)
  - Account Manager (port 3001)
  - VSC Node (port 8080)

#### 🥧 Raspberry Pi 5 (Secondary/Backup)
- **Tailscale Name:** `raspberrypi.tail83ea3e.ts.net`
- **Role:** Backup services, development
- **Status:** ⚠️ Currently offline
- **Services (when active):**
  - Video Transcoder
  - Instagram Downloader

---

## 🔧 Service Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌──────────────────────┐       │
│  │   skatehive3.0      │         │   leaderboard-api     │       │
│  │   (Next.js 15)      │◄────────┤   (Next.js 15)        │       │
│  │   Main App          │         │   Status & Rankings   │       │
│  └─────────────────────┘         └──────────────────────┘       │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                        API Gateway Layer                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Tailscale Funnel + HTTPS Routing                                │
│  • minivlad.tail9656d3.ts.net/*                                  │
│  • raspberrypi.tail83ea3e.ts.net/*                               │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                       Service Layer                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ Video Transcoder │  │ Instagram        │  │ Account        │ │
│  │ (Node.js/TS)    │  │ Downloader       │  │ Manager        │ │
│  │                  │  │ (FastAPI/Python) │  │ (Node.js/TS)   │ │
│  │ Port: 8081:8080  │  │ Port: 6666:8000  │  │ Port: 3001:3000│ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
│                                                                   │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                      Storage & Blockchain Layer                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────────┐ │
│  │ Local FS     │  │ IPFS Network   │  │ Hive Blockchain      │ │
│  │ (Video Cache)│  │ (Distributed)  │  │ (VSC Node)           │ │
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
- **Health Endpoint:** `/instagram/health`
- **Key Features:**
  - Cookie-based authentication
  - Multi-platform support
  - Automatic IPFS upload
  - Metadata extraction
  - Expiration monitoring

#### 👤 Account Manager
- **Technology:** Node.js, TypeScript
- **Purpose:** Hive blockchain account creation/management
- **Container:** `skatehive-account-manager`
- **Health Endpoint:** `/healthz`
- **Key Features:**
  - Account creation with RC delegation
  - Key generation and encryption
  - Emergency recovery system
  - Authority management

#### 🏆 Leaderboard API
- **Technology:** Next.js 15, TypeScript
- **Purpose:** Content ranking and service monitoring
- **Status Endpoint:** `/api/status`
- **Key Features:**
  - Multi-service health aggregation
  - Cookie monitoring for Instagram services
  - Real-time status reporting
  - Error tracking

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
   │      ├─► minivlad.tail9656d3.ts.net
   │      │     ├─► /video/* → localhost:8081
   │      │     ├─► /instagram/* → localhost:6666
   │      │     └─► /healthz → localhost:3001
   │      │
   │      └─► raspberrypi.tail83ea3e.ts.net
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
- **Mac Mini Services:** `https://minivlad.tail9656d3.ts.net/*`
- **Raspberry Pi Services:** `https://raspberrypi.tail83ea3e.ts.net/*`

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
| Instagram Downloader | 6666 | 8000 | ytipfs-worker | HTTP |
| Account Manager | 3001 | 3000 | skatehive-account-manager | HTTP |
| VSC Node | 8080 | 8080 | (direct) | HTTP |

### Raspberry Pi 5 (Secondary)

| Service | External Port | Internal Port | Status |
|---------|--------------|---------------|--------|
| Video Transcoder | 8081 | 8080 | ⚠️ Offline |
| Instagram Downloader | 6666 | 8000 | ⚠️ Offline |

### Port Selection Rationale:
- **8081 (Video):** Avoids conflict with VSC node on 8080
- **6666 (Instagram):** Memorable "devil's port" for external content
- **3001 (Account):** Avoids conflict with Next.js dev default (3000)

---

## 🔗 Service Dependencies

```
┌─────────────────────┐
│   skatehive3.0      │
│   (Main App)        │
└──────────┬──────────┘
           │
           ├──► Leaderboard API (rankings)
           ├──► Account Manager (signup)
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
│  Account Manager                            │
│  ├─► Hive Blockchain (API)                  │
│  ├─► RC Delegation Pool (resource credits)  │
│  └─► Local Storage (encrypted keys)         │
│                                             │
│  Leaderboard API                            │
│  ├─► All Service Health Endpoints           │
│  └─► Hive Blockchain (content data)         │
│                                             │
└─────────────────────────────────────────────┘
```

### Critical Dependencies:
1. **IPFS Network** - Required for video and Instagram services
2. **Instagram Cookies** - Required for Instagram downloads
3. **RC Pool** - Required for account creation (9.3T minimum)
4. **Tailscale Network** - Required for all inter-service communication

---

## 📊 Data Flow

### Video Upload Flow:
```
User Upload (skatehive3.0)
    │
    ▼
Video Transcoder (/video/upload)
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

### Account Creation Flow:
```
Signup Form (skatehive3.0)
    │
    ▼
Account Manager (/create)
    │
    ├─► Generate Keys
    │       │
    │       └─► Encrypt & Store
    │
    ├─► Hive Blockchain
    │       │
    │       ├─► Create Account
    │       └─► Delegate RC (9.3T)
    │
    └─► Return Credentials
            │
            └─► User Login
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
│  Account Manager Keys               │
│  └─► emergency-recovery/*.json     │
│      (AES-256 encrypted)            │
│                                     │
│  Environment Variables              │
│  └─► Docker Compose secrets        │
│      (RC_AMOUNT, AUTHORITY_ACCOUNT) │
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
3. **RC Pool Depletion** - Limited account creation capacity (4.6T current)
4. **Local Storage** - Video cache on single host filesystem

### Scale-Out Strategy:
1. **Multi-Host Load Balancing** - Raspberry Pi as active secondary
2. **Cookie Rotation** - Multiple Instagram accounts
3. **RC Pool Monitoring** - Auto-top-up system
4. **Distributed Storage** - IPFS cluster for cache

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
- Leaderboard API polls all services every 30s
- Dashboard provides real-time TUI monitoring
- Cookie expiration tracked automatically

---

## 📝 Related Documentation

- [Infrastructure Operations Guide](./INFRASTRUCTURE_OPERATIONS.md)
- [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)
- [API Reference](./API_REFERENCE.md)
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

---

**Document Status:** ✅ Complete  
**Next Review:** January 5, 2026  
**Maintainer:** SkateHive DevOps Team
