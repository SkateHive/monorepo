# 📚 SkateHive Documentation Index

**Last Updated:** December 5, 2025  
**Purpose:** Central navigation hub for all SkateHive documentation

---

## 🗺️ Quick Navigation

### 🚀 Getting Started
- [Main README](./README.md) - Project overview and quick start
- [Architecture Overview](./ARCHITECTURE.md) - System design and infrastructure
- [Service Setup Guides](#service-documentation)

### 👨‍💻 For Developers
- [API Reference](./API_REFERENCE.md) - Complete API documentation
- [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md) - Common issues and solutions
- [Development Guides](#development-documentation)

### 🔧 For Operations
- [Infrastructure Operations](./INFRASTRUCTURE_OPERATIONS.md) - Deployment and maintenance
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md) - Cookie refresh procedures
- [Emergency Procedures](./INFRASTRUCTURE_OPERATIONS.md#emergency-procedures)

### 📊 Status & Reports
- [Documentation Cleanup Summary](./DOCS_CLEANUP_SUMMARY.md) - Recent documentation work
- [Documentation Action Plan](./DOCUMENTATION_ACTION_PLAN.md) - Ongoing improvements
- [Service Status](https://minivlad.tail9656d3.ts.net/api/status) - Live service health

---

## 📖 Documentation Catalog

### Core Documentation

#### 🏗️ [ARCHITECTURE.md](./ARCHITECTURE.md)
**What:** Complete system architecture documentation  
**When to use:** Understanding system design, planning changes, onboarding new team members  
**Key sections:**
- Infrastructure topology (Mac Mini M4 + Raspberry Pi)
- Service architecture diagrams
- Network architecture (Tailscale mesh)
- Port mapping reference
- Service dependencies
- Data flow diagrams
- Security architecture

**Audience:** Developers, DevOps, System Architects

---

#### 🔧 [INFRASTRUCTURE_OPERATIONS.md](./INFRASTRUCTURE_OPERATIONS.md)
**What:** Day-to-day operations guide  
**When to use:** Deploying services, performing maintenance, emergency response  
**Key sections:**
- Service management (start/stop/restart)
- Deployment workflows (all services)
- Backup & recovery procedures
- Network operations (Tailscale Funnel)
- Monitoring & alerting setup
- Maintenance procedures (weekly/monthly)
- Emergency procedures

**Audience:** DevOps, System Administrators

---

#### 🐛 [TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md)
**What:** Comprehensive troubleshooting reference  
**When to use:** When services fail, debugging issues, resolving errors  
**Key sections:**
- Quick diagnosis decision tree
- Service-specific issues (Video, Instagram, Account Manager)
- Network & connectivity problems
- Docker & container issues
- Authentication & credentials
- Performance issues
- Common error messages with solutions

**Audience:** Developers, DevOps, Support Team

---

#### 📡 [API_REFERENCE.md](./API_REFERENCE.md)
**What:** Complete API documentation for all services  
**When to use:** Integrating services, building clients, API testing  
**Key sections:**
- Video Transcoder API (upload, transcode, IPFS)
- Instagram Downloader API (multi-platform downloads)
- Account Manager API (Hive account creation)
- Leaderboard API (service status monitoring)
- Rate limits and best practices
- SDK examples (JavaScript, Python, cURL)

**Audience:** Developers, API Consumers

---

#### 🍪 [docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
**What:** Instagram cookie acquisition and management  
**When to use:** Setting up Instagram service, refreshing expired cookies, troubleshooting auth  
**Key sections:**
- Cookie lifecycle explanation
- Acquisition methods (browser extensions, dev tools, yt-dlp)
- Installation & setup procedures
- Monitoring & validation
- Refresh procedures (scheduled and emergency)
- Security best practices
- Automation scripts

**Audience:** DevOps, System Administrators

---

### Service Documentation

#### 🎬 [skatehive-video-transcoder/README.md](./skatehive-video-transcoder/README.md)
**What:** Video transcoding service documentation  
**Features:**
- Automated video transcoding (HLS + MP4)
- IPFS upload integration
- FFmpeg-based processing
- Queue management

**Quick Start:**
```bash
cd skatehive-video-transcoder
docker-compose up -d
curl https://minivlad.tail9656d3.ts.net/video/healthz
```

---

#### 📸 [skatehive-instagram-downloader/README.md](./skatehive-instagram-downloader/README.md)
**What:** Social media content downloader  
**Features:**
- Instagram post/reel/story downloads
- TikTok and YouTube support
- Cookie-based authentication
- Automatic IPFS upload
- Metadata extraction

**Quick Start:**
```bash
cd skatehive-instagram-downloader/ytipfs-worker
docker-compose up -d
curl https://minivlad.tail9656d3.ts.net/instagram/health
```

---

#### 👤 [account-manager/README.md](./account-manager/README.md)
**What:** Hive blockchain account management  
**Features:**
- Account creation with RC delegation
- Key generation and encryption
- Emergency recovery system
- Authority management

**Quick Start:**
```bash
cd account-manager
./deploy.sh
curl https://minivlad.tail9656d3.ts.net/healthz
```

---

#### 🏆 [leaderboard-api/README.md](./leaderboard-api/README.md)
**What:** Content ranking and service monitoring  
**Features:**
- Multi-service health aggregation
- Cookie expiration monitoring
- Real-time status reporting
- Next.js 15 API routes

**Quick Start:**
```bash
cd leaderboard-api
pnpm install && pnpm dev
curl http://localhost:3000/api/status
```

---

#### 📊 [skatehive-dashboard/README.md](./skatehive-dashboard/README.md)
**What:** Terminal-based monitoring dashboard  
**Features:**
- Real-time service health checks
- Responsive TUI layouts
- Multi-host monitoring
- Error highlighting
- Cookie expiration tracking

**Quick Start:**
```bash
cd skatehive-dashboard
pip3 install -r requirements.txt
python3 dashboard.py
```

---

#### 🌐 [skatehive3.0/README.md](./skatehive3.0/README.md)
**What:** Main web application  
**Features:**
- Next.js 15 with App Router
- Hive blockchain integration
- Video uploads and transcoding
- User authentication
- Content feed

**Documentation:**
- [AGENTS.md](./skatehive3.0/AGENTS.md) - AI agent integration
- [RULES.md](./skatehive3.0/RULES.md) - Development rules
- [SKATEHIVE_SIGNUP_SYSTEM.md](./skatehive3.0/SKATEHIVE_SIGNUP_SYSTEM.md) - User signup system

---

### Development Documentation

#### 🤖 [skatehive3.0/AGENTS.md](./skatehive3.0/AGENTS.md)
**What:** AI agent integration documentation  
**When to use:** Building AI features, understanding agent architecture

---

#### 📏 [skatehive3.0/RULES.md](./skatehive3.0/RULES.md)
**What:** Development guidelines and coding standards  
**When to use:** Contributing code, reviewing PRs, onboarding

---

#### 📝 [skatehive3.0/SKATEHIVE_SIGNUP_SYSTEM.md](./skatehive3.0/SKATEHIVE_SIGNUP_SYSTEM.md)
**What:** User signup and account creation flow  
**When to use:** Understanding authentication, modifying signup process

---

### Operations Documentation

#### 📋 [DOCUMENTATION_ACTION_PLAN.md](./DOCUMENTATION_ACTION_PLAN.md)
**What:** Documentation improvement roadmap  
**Status:** Living document tracking doc improvements  
**Last Updated:** December 5, 2025

---

#### ✅ [DOCS_CLEANUP_SUMMARY.md](./DOCS_CLEANUP_SUMMARY.md)
**What:** Summary of Phase 1 documentation work  
**Includes:**
- Documentation validation results
- Service testing outcomes
- Files updated and archived
- Code enhancements
- Current documentation health score

---

#### 📊 [DOCS_VALIDATION_REPORT.md](./DOCS_VALIDATION_REPORT.md)
**What:** Detailed documentation audit report  
**When to use:** Understanding doc coverage and gaps

---

### Archived Documentation

Located in [docs/archive/](./docs/archive/)

#### 🔧 [docs/archive/INSTAGRAM_TIMEOUT_FIX_PROMPT.md](./docs/archive/INSTAGRAM_TIMEOUT_FIX_PROMPT.md)
**Status:** ✅ Resolved - December 5, 2025  
**Issue:** Instagram timeout configuration for development vs production  
**Resolution:** Fixed in code with environment-aware server configuration

---

#### 🎉 [docs/archive/dashboard_responsive_success_2025.md](./docs/archive/dashboard_responsive_success_2025.md)
**Status:** Historical reference  
**Content:** Dashboard responsive implementation success report  
**Note:** Information merged into main dashboard README

---

## 🔍 Finding Documentation

### By Task

**I want to...**

- **Deploy a service** → [Infrastructure Operations - Deployment Workflows](./INFRASTRUCTURE_OPERATIONS.md#deployment-workflows)
- **Fix a service failure** → [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)
- **Integrate with an API** → [API Reference](./API_REFERENCE.md)
- **Refresh Instagram cookies** → [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
- **Understand the system** → [Architecture](./ARCHITECTURE.md)
- **Set up monitoring** → [Infrastructure Operations - Monitoring](./INFRASTRUCTURE_OPERATIONS.md#monitoring--alerting)
- **Create a backup** → [Infrastructure Operations - Backup](./INFRASTRUCTURE_OPERATIONS.md#backup--recovery)
- **Handle an emergency** → [Infrastructure Operations - Emergency](./INFRASTRUCTURE_OPERATIONS.md#emergency-procedures)

---

### By Service

**I need docs for...**

- **Video Transcoder** → [Service README](./skatehive-video-transcoder/README.md) | [API](./API_REFERENCE.md#video-transcoder-api) | [Troubleshooting](./TROUBLESHOOTING_GUIDE.md#video-transcoder-issues)
- **Instagram Downloader** → [Service README](./skatehive-instagram-downloader/README.md) | [API](./API_REFERENCE.md#instagram-downloader-api) | [Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
- **Account Manager** → [Service README](./account-manager/README.md) | [API](./API_REFERENCE.md#account-manager-api) | [Troubleshooting](./TROUBLESHOOTING_GUIDE.md#account-manager-issues)
- **Leaderboard API** → [Service README](./leaderboard-api/README.md) | [API](./API_REFERENCE.md#leaderboard-api)
- **Dashboard** → [Service README](./skatehive-dashboard/README.md)
- **Main App** → [Service README](./skatehive3.0/README.md) | [Agents](./skatehive3.0/AGENTS.md) | [Rules](./skatehive3.0/RULES.md)

---

### By Role

**As a...**

#### Developer 👨‍💻
**Start here:**
1. [Main README](./README.md)
2. [Architecture](./ARCHITECTURE.md)
3. [API Reference](./API_REFERENCE.md)
4. [Development Rules](./skatehive3.0/RULES.md)

**Common tasks:**
- [Testing APIs](./API_REFERENCE.md)
- [Running services locally](./INFRASTRUCTURE_OPERATIONS.md#service-management)
- [Debugging issues](./TROUBLESHOOTING_GUIDE.md)

---

#### DevOps Engineer 🔧
**Start here:**
1. [Infrastructure Operations](./INFRASTRUCTURE_OPERATIONS.md)
2. [Architecture](./ARCHITECTURE.md)
3. [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)

**Common tasks:**
- [Deploying services](./INFRASTRUCTURE_OPERATIONS.md#deployment-workflows)
- [Setting up monitoring](./INFRASTRUCTURE_OPERATIONS.md#monitoring--alerting)
- [Managing backups](./INFRASTRUCTURE_OPERATIONS.md#backup--recovery)
- [Refreshing cookies](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
- [Emergency response](./INFRASTRUCTURE_OPERATIONS.md#emergency-procedures)

---

#### System Administrator 🖥️
**Start here:**
1. [Infrastructure Operations](./INFRASTRUCTURE_OPERATIONS.md)
2. [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)
3. [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)

**Common tasks:**
- [Service management](./INFRASTRUCTURE_OPERATIONS.md#service-management)
- [Health checks](./TROUBLESHOOTING_GUIDE.md#quick-diagnosis)
- [Cookie refresh](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md#refresh-procedures)
- [Network configuration](./INFRASTRUCTURE_OPERATIONS.md#network-operations)

---

#### API Consumer 📱
**Start here:**
1. [API Reference](./API_REFERENCE.md)
2. [Service README files](#service-documentation)

**Common tasks:**
- [Video upload API](./API_REFERENCE.md#upload-video-for-transcoding)
- [Instagram download API](./API_REFERENCE.md#download-instagram-content)
- [Status monitoring API](./API_REFERENCE.md#service-status)

---

## 📊 Documentation Health

### Current Status: 🟢 **90/100 - Excellent**

**Coverage by Category:**
- ✅ Core Documentation: Complete (5/5 documents)
- ✅ Service Documentation: Complete (6/6 services)
- ✅ Operations Documentation: Complete (1/1 critical)
- ✅ Development Documentation: Complete (3/3 documents)
- ✅ API Documentation: Complete (1/1)

**Metrics:**
- **Accuracy:** 95/100 (validated against codebase)
- **Completeness:** 90/100 (all critical paths documented)
- **Usability:** 90/100 (clear navigation and examples)
- **Maintainability:** 85/100 (structured, dated, maintainable)

**Last Audit:** December 5, 2025

---

## 🔄 Recent Updates

### December 5, 2025 - Phase 2 Documentation Enhancement
✅ **Created:**
- ARCHITECTURE.md - Complete system architecture
- INFRASTRUCTURE_OPERATIONS.md - Operations playbook
- TROUBLESHOOTING_GUIDE.md - Comprehensive troubleshooting
- API_REFERENCE.md - Complete API documentation
- docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md - Cookie management guide
- DOCS_INDEX.md - This navigation hub

✅ **Updated:**
- skatehive-video-transcoder/README.md - Port clarification and production config
- skatehive-instagram-downloader/README.md - Cookie management section
- skatehive-dashboard/README.md - Comprehensive features
- leaderboard-api status endpoint - Cookie monitoring

✅ **Archived:**
- INSTAGRAM_TIMEOUT_FIX_PROMPT.md (issue resolved)
- RESPONSIVE_IMPLEMENTATION_SUCCESS.md (historical)

---

## 🆘 Getting Help

### Documentation Issues
If documentation is unclear, incorrect, or missing:
1. Check [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md) first
2. Review [Documentation Action Plan](./DOCUMENTATION_ACTION_PLAN.md)
3. Search archived docs in [docs/archive/](./docs/archive/)

### Service Issues
1. Check [Quick Diagnosis](./TROUBLESHOOTING_GUIDE.md#quick-diagnosis)
2. Review service-specific troubleshooting sections
3. Check [Emergency Procedures](./INFRASTRUCTURE_OPERATIONS.md#emergency-procedures)

### API Questions
1. Review [API Reference](./API_REFERENCE.md)
2. Check SDK examples in API docs
3. Test with provided cURL examples

---

## 📝 Contributing to Docs

When adding or updating documentation:

1. **Location:**
   - Core docs → Root directory
   - Service docs → Service directory README.md
   - Operations docs → docs/operations/
   - Archived docs → docs/archive/

2. **Format:**
   - Use Markdown
   - Include table of contents for long docs
   - Add "Last Updated" date
   - Specify audience
   - Include practical examples

3. **Standards:**
   - Follow existing structure
   - Use clear headings (H2, H3)
   - Include code examples
   - Add cross-references
   - Test all commands/examples

4. **Update:**
   - Update DOCS_INDEX.md when adding new docs
   - Update related doc cross-references
   - Archive outdated docs with resolution notes
   - Update documentation health metrics

---

## 🔗 Quick Links

### Live Services
- [Mac Mini M4 Video Transcoder](https://minivlad.tail9656d3.ts.net/video/healthz)
- [Mac Mini M4 Instagram Downloader](https://minivlad.tail9656d3.ts.net/instagram/health)
- [Mac Mini M4 Account Manager](https://minivlad.tail9656d3.ts.net/healthz)
- [Service Status Dashboard](https://minivlad.tail9656d3.ts.net/api/status)

### Tools & Scripts
- [Health Check Script](./health-check.sh)
- [Cookie Setup Script](./setup-instagram-cookies.sh)
- [Emergency Recovery Script](./emergency-recovery.sh)
- [Dashboard Runner](./skatehive-dashboard/run-dashboard.sh)

### External Resources
- Hive Blockchain: https://hive.io
- Tailscale Documentation: https://tailscale.com/kb/
- Docker Documentation: https://docs.docker.com
- IPFS Documentation: https://docs.ipfs.tech

---

## 📅 Maintenance Schedule

### Weekly Tasks
- Review [Service Status](https://minivlad.tail9656d3.ts.net/api/status)
- Check [Cookie Status](https://minivlad.tail9656d3.ts.net/instagram/cookies/status)
- Run health checks

### Monthly Tasks
- Review and update outdated documentation
- Archive resolved issue docs
- Update metrics and status reports
- Clean up old backups

### Quarterly Tasks
- Full documentation audit
- Architecture review
- Update all "Last Updated" dates
- Review and improve documentation based on feedback

---

**Document Status:** ✅ Complete  
**Last Updated:** December 5, 2025  
**Next Review:** January 5, 2026  
**Maintainer:** SkateHive Documentation Team
