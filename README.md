# SkateHive Monorepo 🛹

A comprehensive decentralized platform ecosystem that connects skateboarders worldwide through blockchain technology, social media integration, and distributed media processing infrastructure.

## 🌟 Vision & Mission

SkateHive is building the future of decentralized skateboarding culture by:
- **Empowering creators** with blockchain-based content monetization via Hive blockchain
- **Preserving skateboarding culture** through IPFS-based permanent content storage
- **Connecting communities** with real-time social features and interactive maps
- **Rewarding participation** through cryptocurrency tokens and NFTs
- **Providing infrastructure** that runs on accessible hardware (Mac Mini, Raspberry Pi)

## 🏗️ Architecture Overview

The SkateHive ecosystem operates as a **distributed microservices architecture** where:

```
┌─────────────────────────────────────────────────────────────┐
│                    SKATEHIVE3.0 (Next.js)                   │
│              Main Web Application (Vercel)                   │
│     - User Interface & Content Creation                      │
│     - Hive Blockchain Integration                            │
│     - Wallet Management (Hive, Ethereum, Farcaster)          │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌──────────────────┐  ┌──────────────────┐
│  Mac Mini M4     │  │  Raspberry Pi    │
│  (Primary)       │  │  (Secondary)     │
├──────────────────┤  ├──────────────────┤
│ Video Transcoder │  │ Video Transcoder │
│ Instagram DL     │  │ Instagram DL     │
│ Account Manager  │  │ Monitoring       │
│ VSC Node         │  │ Cookie Monitor   │
└────────┬─────────┘  └────────┬─────────┘
         │                     │
         └──────────┬──────────┘
                    ▼
         ┌─────────────────────┐
         │   IPFS (Pinata)     │
         │  Permanent Storage  │
         └─────────────────────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
    ┌─────────┐          ┌──────────┐
    │  Hive   │          │ Ethereum │
    │Blockchain│          │ Network  │
    └─────────┘          └──────────┘
```

### Network Architecture
- **Tailscale Mesh Network**: Secure peer-to-peer connectivity between all infrastructure nodes
- **Funnel Public Access**: HTTPS endpoints exposed via Tailscale for external API access
- **Three-Tier Fallback**: Mac Mini M4 (primary) → Raspberry Pi (secondary) → Render Cloud (tertiary)
- **Auto-Recovery**: Power outage resilience with automatic service restart

## 📁 Repository Structure

### 🎨 **skatehive3.0/** - Main Web Application
**Next.js 15 full-stack application** - The heart of the SkateHive platform

**Key Features:**
- **🔐 Multi-Wallet Support**: Hive Keychain, Farcaster, Ethereum (WalletConnect, MetaMask)
- **📝 Rich Content Creation**: Markdown editor with image/video upload, Instagram integration
- **🎬 Video Processing**: Upload, transcode, and publish videos with IPFS storage
- **📸 Instagram Integration**: Direct posting from Instagram with automatic download
- **🗺️ Interactive Skate Map**: Global skateboarding spots with user contributions
- **💰 Token Economics**: HIGHER token, coin creation, trading, and staking
- **🏆 Leaderboard**: User rankings based on Hive Power and engagement
- **🎨 Magazine/Blog**: Long-form content publication system
- **💬 Social Features**: Comments, notifications, follow/unfollow
- **🎁 Airdrops**: Token distribution campaigns
- **🏛️ DAO Governance**: Community-driven decision making
- **🖼️ Zora Integration**: Zora Coin minting, management and trading
- **📱 Responsive Design**: Mobile-first with Farcaster Frame support

**Technology Stack:**
- **Framework**: Next.js 15.3.2 with App Router
- **Styling**: Tailwind CSS + Shadcn UI components
- **Database**: PostgreSQL (Supabase)
- **Authentication**: Multi-provider (Hive, Farcaster, Ethereum)
- **State Management**: React Context + TanStack Query
- **Blockchain**: Hive.js, Dhive, Viem (Ethereum)
- **Storage**: IPFS via Pinata
- **Deployment**: Vercel with edge functions

**Key Directories:**
- `app/` - Next.js 15 app router pages and API routes
- `components/` - Reusable UI components organized by feature
- `lib/` - Utility functions, blockchain integration, API clients
- `services/` - External service integrations (video, Instagram)
- `hooks/` - Custom React hooks for state and effects
- `types/` - TypeScript type definitions
- `sql/` - Database schemas and migrations

### 🎬 **skatehive-video-transcoder/** - Video Processing Service
**Node.js + FFmpeg service** for video optimization and IPFS upload

**Features:**
- **Format Conversion**: Any video → web-optimized H.264/AAC MP4
- **IPFS Upload**: Automatic Pinata upload with CID generation
- **File Size Limits**: Configurable max upload (currently 200MB)
- **Rich Logging**: JSON logs with user info, file details, processing time
- **Statistics API**: Success rates, processing metrics, user activity
- **Docker Containerized**: Easy deployment and scaling

**Technology Stack:** Node.js, Express, FFmpeg, Multer, Pinata SDK

**API Endpoints:**
- `POST /transcode` - Upload and process video files
- `GET /healthz` - Service health check
- `GET /logs` - Recent processing operations (JSON)
- `GET /stats` - Aggregated statistics and metrics

**Configuration:**
- Port: `8081`
- Max Upload: `200MB` (configurable via `MAX_UPLOAD_MB`)
- External URL: `https://minivlad.tail9656d3.ts.net/video/transcode`

### 📱 **mobileapp/** - React Native Mobile Application
**Expo/React Native app** for iOS and Android - Native mobile experience for SkateHive

**Features:**
- **📱 Native Experience**: Optimized for iOS and Android platforms
- **🔐 Secure Authentication**: Encrypted keychain storage for Hive keys
- **📝 Content Creation**: Post photos and videos with IPFS upload
- **🎬 Video Feed**: Dedicated video content browsing
- **🏆 Leaderboard**: Community rankings and engagement metrics
- **🔔 Notifications**: Real-time notification system
- **👤 Profiles**: User profiles with followers/following
- **📰 Feed**: Infinite scroll with following/trending tabs

**Technology Stack:** React Native, Expo, TypeScript, React Query, @hiveio/dhive

**Key Directories:**
- `app/` - Expo Router screens and navigation
- `components/` - Reusable UI components
- `lib/` - Hive utilities, upload services, API clients
- `assets/` - Images, fonts, and static files

---

### 📱 **skatehive-instagram-downloader/** - Social Media Content Service
**FastAPI service** for downloading Instagram/YouTube content with IPFS storage

**Features:**
- **Multi-Platform**: Instagram, YouTube, TikTok, 1000+ sites via yt-dlp
- **Cookie Authentication**: Instagram authentication to bypass rate limits
- **IPFS Integration**: Automatic Pinata upload with gateway URLs
- **RESTful + Slug API**: JSON POST and base64 URL slug support
- **Health Monitoring**: Cookie validation and expiration tracking
- **File Management**: Configurable retention and size limits (max 1.5GB)

**Technology Stack:** Python 3.11, FastAPI, yt-dlp, Pinata SDK

**API Endpoints:**
- `POST /download` - Download content via JSON payload
- `GET /d/<base64_slug>` - Download via URL slug
- `GET /health` - Service health with cookie status
- `POST /cookies/validate` - Validate Instagram cookies
- `GET /cookies/status` - Cookie expiration status

**Configuration:**
- Port: `8000` (local)
- Cookie File: `data/instagram_cookies.txt` (Netscape format)
- External URL: `https://vladsberry.tail83ea3e.ts.net/instagram/download` (via Tailscale Funnel on 443)
- **Blockchain Integration**: Hive blockchain posting, Ethereum/Farcaster protocols
- **Content Management**: Video uploads, blog posts, community interactions
- **Skate Mapping**: Interactive maps for skate spot sharing
- **Community Features**: Bounties, leaderboards, DAO governance
- **Multi-protocol Support**: Aioha (Hive), Wagmi/Viem (Ethereum), React Query

**Technology Stack:** Next.js 14, TypeScript, Chakra UI, Tailwind CSS, React Query

**Key Integrations:**
- Backend video processing services
- IPFS content delivery
- Multiple blockchain networks
- Social authentication systems

## 🔗 Shared Infrastructure

The **webapp (skatehive3.0)** consumes shared backend services:

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARED INFRASTRUCTURE                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐     ┌──────────────┐                     │
│  │   Webapp     │     │  Mobile App  │                     │
│  │ (skatehive3.0)     │ (mobileapp)  │                     │
│  └──────┬───────┘     └──────┬───────┘                     │
│         │                    │                              │
│         ▼                    ▼                              │
│  ┌─────────────────────────────────────────┐               │
│  │     api.skatehive.app (leaderboard-api) │               │
│  │  • /api/v1/feed, /api/v1/leaderboard   │               │
│  │  • /api/transcode/status               │               │
│  └─────────────────────────────────────────┘               │
│                      │                                      │
│         ┌────────────┼────────────┐                        │
│         ▼            ▼            ▼                        │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐                │
│  │  Oracle   │ │ Mac Mini  │ │Raspberry Pi│                │
│  │ Transcoder│ │ Transcoder│ │ Transcoder │                │
│  └───────────┘ └───────────┘ └───────────┘                │
│                      │                                      │
│                      ▼                                      │
│  ┌─────────────────────────────────────────┐               │
│  │         ipfs.skatehive.app              │               │
│  │         (IPFS Gateway)                  │               │
│  └─────────────────────────────────────────┘               │
│                      │                                      │
│                      ▼                                      │
│  ┌─────────────────────────────────────────┐               │
│  │         Hive Blockchain Nodes           │               │
│  │  • api.deathwing.me, api.hive.blog     │               │
│  └─────────────────────────────────────────┘               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 🏗️ Backend APIs (leaderboard-api)

| Endpoint | Description | Webapp | Mobile |
|----------|-------------|:------:|:------:|
| `/api/v1/feed` | Main community feed | ✅ | ✅ |
| `/api/v2/feed` | Enhanced feed (v2) | ✅ | ❌ |
| `/api/v1/leaderboard` | Community leaderboard | ✅ | ✅ |
| `/api/v1/balance/{user}` | User balance data | ✅ | ✅ |
| `/api/v1/balance/{user}/rewards` | User rewards | ✅ | ✅ |
| `/api/v1/feed/{user}/following` | Following feed | ✅ | ✅ |
| `/api/transcode/status` | Video transcoding status | ✅ | ✅ |

### 🎬 Video Transcoding (with failover)

| Service | URL | Priority |
|---------|-----|:--------:|
| Oracle (Primary) | `146-235-239-243.sslip.io/transcode` | 1 |
| Mac Mini M4 (Secondary) | `minivlad.tail9656d3.ts.net/video/transcode` | 2 |
| Raspberry Pi (Tertiary) | `vladsberry.tail83ea3e.ts.net/video/transcode` | 3 |

### 🔗 Other Shared Services

| Service | URL | Purpose |
|---------|-----|---------|
| **IPFS Gateway** | `ipfs.skatehive.app/ipfs/{cid}` | Decentralized media storage |
| **Hive Images** | `images.hive.blog/{user}/{sig}` | Image upload & avatars |
| **Community Tag** | `hive-173115` | Skatehive community identifier |

### ⛓️ Shared Hive Nodes
Both apps use the same Hive RPC nodes: `api.deathwing.me`, `techcoderx.com`, `api.hive.blog`, `anyx.io`, `hive-api.arcange.eu`, `hive-api.3speak.tv`

---

## 📊 Webapp vs Mobile Feature Comparison

| Feature | Webapp | Mobile | Notes |
|---------|:------:|:------:|-------|
| **Core** ||||
| Feed (infinite scroll) | ✅ | ✅ | Mobile uses v1 API |
| Video feed | ✅ | ✅ | |
| Leaderboard | ✅ | ✅ | |
| Notifications | ✅ | ✅ | |
| Profile view | ✅ | ✅ | |
| Create posts | ✅ | ✅ | |
| Comments/Replies | ✅ | ✅ | |
| Following/Trending | ✅ | ✅ | |
| **Wallet & Crypto** ||||
| Full Wallet | ✅ | ⚠️ | Disabled for App Store |
| Ethereum/NFTs | ✅ | ❌ | |
| Swap functionality | ✅ | ❌ | |
| Send tokens | ✅ | ❌ | |
| SkateBank | ✅ | ❌ | |
| Portfolio charts | ✅ | ❌ | |
| **Community Features** ||||
| Spot Map | ✅ | ❌ | |
| Bounties | ✅ | ❌ | |
| DAO/Governance | ✅ | ❌ | |
| Chat | ✅ | ❌ | |
| Auction system | ✅ | ❌ | |
| Airdrop system | ✅ | ❌ | |
| **Profile Management** ||||
| Edit profile | ✅ | ❌ | |
| Video parts | ✅ | ❌ | |
| Merge accounts | ✅ | ❌ | |
| **Content Creation** ||||
| Beneficiaries | ✅ | ❌ | |
| Full markdown editor | ✅ | ⚠️ | Basic in mobile |
| Thumbnail picker | ✅ | ❌ | |
| **Other** ||||
| Magazine | ✅ | ❌ | |
| Game | ✅ | ❌ | |
| Witness voting | ✅ | ❌ | |
| Zora/Coin trading | ✅ | ❌ | |

## 🔄 Service Integration Flow

### Content Processing Pipeline
1. **Content Acquisition**: `skatehive-instagram-downloader` fetches media from social platforms
2. **Video Processing**: `skatehive-video-transcoder` optimizes videos for web delivery
3. **IPFS Storage**: Both services upload processed content to decentralized storage
4. **Frontend Display**: `skatehive3.0` presents content to users with blockchain integration

### Monitoring & Operations
1. **Health Monitoring**: `skatehive-dashboard` continuously monitors all backend services
2. **Performance Tracking**: Real-time metrics, response times, and resource usage
3. **Log Aggregation**: Centralized logging from all services for debugging and analytics
4. **Automated Alerts**: Service downtime and performance degradation detection

### Data Flow Architecture
```
External Content → Instagram Downloader → Video Transcoder → IPFS Storage
                                              ↓
User Uploads ────────────────────────────→ Video Transcoder → IPFS Storage
                                              ↓
All Services ←─────────── Dashboard Monitoring ←─────────── Main App (skatehive3.0)
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Python 3.8+ (for dashboard)
- Node.js 18+ (for main app)
- pnpm (`npm install -g pnpm`)
- Pinata account with JWT token
- Git with SSH key configured for GitHub

### 🔧 Assembling the Monorepo Locally

This monorepo uses a **hybrid Git structure**: the root folder is a Git repository that tracks documentation and scripts, while each service subdirectory is an independent Git repository.

#### Fresh Clone (New Machine)

```bash
# 1. Clone the root monorepo
git clone git@github.com:SkateHive/monorepo.git skatehive-monorepo
cd skatehive-monorepo

# 2. Clone all service repositories
git clone git@github.com:SkateHive/skatehive3.0.git
git clone git@github.com:SkateHive/leaderboard-api.git
git clone git@github.com:SkateHive/mobileapp.git
git clone git@github.com:SkateHive/account-manager.git
git clone git@github.com:SkateHive/skatehive-video-transcoder.git
git clone git@github.com:SkateHive/skatehive-instagram-downloader.git
git clone git@github.com:SkateHive/skatehive-dashboard.git
git clone git@github.com:SkateHive/skatehive-docs.git
git clone git@github.com:SkateHive/oracle-video-worker.git
git clone git@github.com:SkateHive/vsc-node.git
```

#### Sync Existing Installation (e.g., Raspberry Pi, Mac Mini)

If you already have the folder structure with service repos but the root isn't tracked:

```bash
cd ~/skatehive-monorepo

# Initialize root repo and sync with GitHub
git init
git remote add origin git@github.com:SkateHive/monorepo.git
git fetch origin
git reset --hard origin/main
```

#### Pull All Repositories

Create a helper script to update everything at once:

```bash
# Save as: ~/skatehive-monorepo/pull-all.sh
#!/bin/bash
echo "📦 Pulling root monorepo..."
git pull

echo "📦 Pulling all service repositories..."
for dir in skatehive3.0 leaderboard-api mobileapp account-manager \
           skatehive-video-transcoder skatehive-instagram-downloader \
           skatehive-dashboard skatehive-docs oracle-video-worker vsc-node; do
    if [ -d "$dir/.git" ]; then
        echo "  → $dir"
        (cd "$dir" && git pull)
    fi
done
echo "✅ All repositories updated!"
```

Make it executable: `chmod +x pull-all.sh`

### Service Setup
Each service includes its own README with detailed setup instructions:

1. **Dashboard**: `cd skatehive-dashboard && python3 dashboard.py`
2. **Instagram Downloader**: `cd skatehive-instagram-downloader/ytipfs-worker && docker compose up -d`
3. **Video Transcoder**: `cd skatehive-video-transcoder && docker build -t video-worker . && docker run -p 8081:8081 video-worker`
4. **Main App**: `cd skatehive3.0 && pnpm install && pnpm dev`

### Environment Configuration
Critical environment variables across services:
- `PINATA_JWT` - IPFS storage authentication
- `HIVE_POSTING_KEY` - Blockchain integration
- `NEXT_PUBLIC_*` - Frontend configuration
- Service-specific ports and endpoints

## 🛠️ Development & Deployment

This monorepo is designed for **Raspberry Pi deployment** with:
- Containerized services for easy management
- Resource-optimized configurations
- Health monitoring and auto-recovery
- Modular architecture for independent scaling

Each service can be developed and deployed independently while maintaining integration through well-defined APIs and shared storage systems.

## 📊 Monitoring & Maintenance

The dashboard provides comprehensive monitoring including:
- Service uptime and response times
- Resource utilization (CPU, memory, disk)
- Processing statistics and success rates
- Real-time log streaming and error tracking
- Internet connectivity and speed monitoring

## 🤝 Contributing

Each subdirectory contains its own development guidelines. The modular architecture allows for independent development while maintaining system integration through standardized APIs and monitoring interfaces.
