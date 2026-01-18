# 📡 SkateHive API Reference

**Last Updated:** December 5, 2025  
**Version:** 1.0  
**Base URLs:** See service-specific sections

---

## 📋 Table of Contents
- [Overview](#overview)
- [Authentication](#authentication)
- [Video Transcoder API](#video-transcoder-api)
- [Instagram Downloader API](#instagram-downloader-api)
- [Account Manager API](#account-manager-api)
- [Leaderboard API](#leaderboard-api)
- [Common Response Codes](#common-response-codes)
- [Rate Limits](#rate-limits)
- [SDKs & Libraries](#sdks--libraries)

---

## 🎯 Overview

SkateHive provides multiple REST APIs for different services. All APIs return JSON responses and use standard HTTP methods and status codes.

### Service Endpoints:

| Service | Production URL | Dev URL | Port |
|---------|---------------|----------|------|
| Video Transcoder | `https://minivlad.tail83ea3e.ts.net/video` | `http://localhost:8081` | 8081:8080 |
| Instagram Downloader | `https://minivlad.tail83ea3e.ts.net/instagram` | `http://localhost:6666` | 6666:8000 |
| Account Manager | `https://minivlad.tail83ea3e.ts.net` | `http://localhost:3001` | 3001:3000 |
| Leaderboard API | `https://api.skatehive.app` | `http://localhost:3000` | 3000 |

---

## 🔐 Authentication

### Video Transcoder & Instagram Downloader:
- **Type:** None (Public access)
- **Note:** Services are publicly accessible via Tailscale Funnel
- Rate limiting may apply

### Account Manager:
- **Type:** None for health checks
- **Note:** Account creation requires backend service access
- Not exposed for public account creation

### Instagram Downloader (Internal):
- **Type:** Cookie-based authentication
- **Location:** `/app/cookies/cookies.txt` (Netscape format)
- **Management:** See [Cookie Management Guide](../operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

---

## 🎬 Video Transcoder API

**Base URL (Production):** `https://minivlad.tail83ea3e.ts.net/video`  
**Base URL (Development):** `http://localhost:8081`

---

### Health Check

Get service health status.

**Endpoint:** `GET /video/healthz`

**Response:**
```json
{
  "ok": true,
  "service": "video-worker",
  "timestamp": "2025-12-05T10:30:00Z"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `500 Internal Server Error` - Service unhealthy

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/healthz
```

---

### Get Statistics

Get video processing statistics.

**Endpoint:** `GET /video/stats`

**Response:**
```json
{
  "total": 1247,
  "successful": 1210,
  "failed": 20,
  "inProgress": 3,
  "avgDuration": 42800,
  "successRate": 97
}
```

**Status Codes:**
- `200 OK` - Statistics retrieved
- `500 Internal Server Error` - Failed to get stats

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/stats
```

---

### Get Recent Logs

Get recent processing logs.

**Endpoint:** `GET /video/logs`

**Query Parameters:**
- `limit` (optional): Number of log entries (default: 10, max: 100)

**Response:**
```json
{
  "logs": [
    {
      "id": "abc123",
      "timestamp": "2025-12-05T10:30:00Z",
      "user": "creator-name",
      "filename": "kickflip.mp4",
      "status": "completed",
      "duration": 42000,
      "cid": "bafy...",
      "clientIP": "203.0.113.10",
      "platform": "web",
      "deviceInfo": "desktop/macos/chrome",
      "node": "macmini"
    }
  ],
  "stats": {
    "total": 1247,
    "successful": 1210,
    "failed": 20,
    "inProgress": 3,
    "avgDuration": 42800,
    "successRate": 97
  }
}
```

**Example:**
```bash
curl "https://minivlad.tail83ea3e.ts.net/video/logs?limit=5"
```

---

### Transcode Video

Upload a video file for processing and IPFS upload.

**Endpoint:** `POST /video/transcode`

**Content-Type:** `multipart/form-data`

**Parameters (multipart form):**
- `video` (required): Video file (MP4, MOV, AVI, etc.)
- `creator` (optional): Creator username
- `platform` (optional): Client platform (web, mobile, etc.)
- `deviceInfo` (optional): Client device info string
- `browserInfo` (optional): Client browser string
- `userHP` (optional): Hive power if available
- `correlationId` (optional): Client-provided request ID for SSE progress
- `viewport` (optional): Client viewport info
- `connectionType` (optional): Network type info
- `thumbnail` or `thumbnailUrl` (optional): Preview image URL

**Request:**
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/video/transcode   -F "video=@/path/to/video.mp4"   -F "creator=skater123"   -F "platform=web"   -F "correlationId=client-req-123"
```

**Response (Success):**
```json
{
  "cid": "bafy...",
  "gatewayUrl": "https://gateway.pinata.cloud/ipfs/bafy...",
  "requestId": "client-req-123",
  "duration": 42000,
  "creator": "skater123",
  "timestamp": "2025-12-05T10:31:00Z"
}
```

**Status Codes:**
- `400 Bad Request` - Invalid request (missing file, wrong format)
- `413 Payload Too Large` - File exceeds size limit
- `500 Internal Server Error` - Processing failed

---

### Progress Stream

Subscribe to progress events for an in-flight transcode.

**Endpoint:** `GET /video/progress/:requestId`

**Response:** Server-Sent Events (SSE)

**Example:**
```bash
curl -N https://minivlad.tail83ea3e.ts.net/video/progress/client-req-123
```

**Event payload example:**
```
data: {"progress": 35, "stage": "transcoding"}
```


## 📸 Instagram Downloader API

**Base URL (Production):** `https://minivlad.tail83ea3e.ts.net/instagram`  
**Base URL (Development):** `http://localhost:6666`

---

### Health Check

Get service health and cookie status.

**Endpoint:** `GET /instagram/healthz`

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-12-05T10:35:00Z",
  "authentication": {
    "cookies_enabled": true,
    "cookies_exist": true,
    "cookies_valid": true,
    "last_validation": "2025-12-05T10:00:00Z",
    "cookies_path": "/data/instagram_cookies.txt"
  },
  "version": "2.0.0"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `500 Internal Server Error` - Service unhealthy

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/instagram/healthz
```

---

### Download Instagram Content

Download Instagram content and upload to IPFS.

**Endpoint:** `POST /instagram/download`

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "url": "https://www.instagram.com/p/abc123/"
}
```

**Parameters:**
- `url` (required): Instagram post/reel/story URL

**Response (Success):**
```json
{
  "status": "ok",
  "cid": "bafy...",
  "ipfs_uri": "ipfs://bafy...",
  "pinata_gateway": "https://ipfs.skatehive.app/ipfs/bafy...",
  "filename": "instagram_video_ABC123.mp4",
  "bytes": 14839234,
  "source_url": "https://www.instagram.com/p/abc123/"
}
```

**Status Codes:**
- `200 OK` - Download completed
- `400 Bad Request` - Invalid request
- `500 Internal Server Error` - Download failed

**Example:**
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/instagram/download   -H 'content-type: application/json'   -d '{"url":"https://www.instagram.com/p/abc123/"}'
```

---

### Cookie Status

Check cookie authentication status.

**Endpoint:** `GET /instagram/cookies/status`

**Response:**
```json
{
  "cookies_enabled": true,
  "cookies_exist": true,
  "cookies_valid": true,
  "last_validation": "2025-12-05T10:00:00Z",
  "cookies_path": "/data/instagram_cookies.txt"
}
```

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

---

### Validate Cookies

Force cookie validation.

**Endpoint:** `POST /instagram/cookies/validate`

**Response:**
```json
{
  "valid": true,
  "timestamp": "2025-12-05T10:05:00Z",
  "message": "Cookies are valid"
}
```

**Example:**
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/instagram/cookies/validate
```


## 👤 Account Manager API

**Base URL (Production):** `https://minivlad.tail83ea3e.ts.net`  
**Base URL (Development):** `http://localhost:3001`

---

### Health Check

Get service health and RC status.

**Endpoint:** `GET /healthz`

**Response:**
```json
{
  "status": "healthy",
  "rc_balance": 10000000000000,
  "rc_required": 9300000000000,
  "can_create_accounts": true,
  "authority_account": "skatehive-authority",
  "uptime": 172800
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `500 Internal Server Error` - Service unhealthy

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/healthz
```

---

### Check RC Status

Get detailed RC (Resource Credits) status.

**Endpoint:** `GET /rc-status`

**Response:**
```json
{
  "authority_account": "skatehive-authority",
  "rc_balance": 10000000000000,
  "rc_required": 9300000000000,
  "rc_available": 700000000000,
  "can_create_accounts": true,
  "max_accounts_possible": 75,
  "last_checked": "2025-12-05T10:00:00Z"
}
```

**Example:**
```bash
curl https://minivlad.tail83ea3e.ts.net/rc-status
```

---

### Create Account (Internal Use)

Create a new Hive account with RC delegation.

**Endpoint:** `POST /create`

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "username": "new-skater",
  "email": "skater@example.com"
}
```

**Response (Success):**
```json
{
  "success": true,
  "username": "new-skater",
  "keys": {
    "owner": "5J...",
    "active": "5K...",
    "posting": "5H...",
    "memo": "5M..."
  },
  "recovery_key_id": "2025-10-31T15-17-39-627Z-new-skater-keys.json",
  "rc_delegated": 9300000000000,
  "created_at": "2025-12-05T10:30:00Z"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Insufficient RC for account creation",
  "rc_balance": 4600000000000,
  "rc_required": 9300000000000
}
```

**Status Codes:**
- `201 Created` - Account created successfully
- `400 Bad Request` - Invalid username or parameters
- `409 Conflict` - Username already exists
- `503 Service Unavailable` - Insufficient RC
- `500 Internal Server Error` - Account creation failed

**Note:** This endpoint is for backend integration only, not exposed for public access.

---

### Get Recovery Keys

List available emergency recovery keys.

**Endpoint:** `GET /recovery-keys`

**Response:**
```json
{
  "keys": [
    {
      "filename": "2025-10-31T15-17-39-627Z-user1-keys.json",
      "username": "user1",
      "created_at": "2025-10-31T15:17:39Z",
      "encrypted": true
    }
  ],
  "total": 1
}
```

---

## 🏆 Leaderboard API

**Base URL (Production):** `https://api.skatehive.app`  
**Base URL (Development):** `http://localhost:3000`

---

### Service Status

Get comprehensive status of all SkateHive services.

**Endpoint:** `GET /api/status`

**Response:**
```json
{
  "timestamp": "2025-12-05T10:30:00Z",
  "services": [
    {
      "id": "macmini-video",
      "name": "Mac Mini Video",
      "category": "Video Transcoder",
      "url": "https://minivlad.tail83ea3e.ts.net/video/healthz",
      "isHealthy": true,
      "responseTime": 45,
      "lastChecked": "2025-12-05T10:29:55Z"
    },
    {
      "id": "macmini-insta",
      "name": "Mac Mini IG",
      "category": "Instagram Downloader",
      "url": "https://minivlad.tail83ea3e.ts.net/instagram/healthz",
      "isHealthy": true,
      "responseTime": 32,
      "lastChecked": "2025-12-05T10:29:55Z",
      "cookieInfo": {
        "valid": true,
        "exists": true,
        "expiresAt": "2026-01-15T00:00:00Z",
        "daysUntilExpiry": 41
      }
    },
    {
      "id": "macmini-account",
      "name": "Account Manager",
      "category": "Account Manager",
      "url": "https://minivlad.tail83ea3e.ts.net/healthz",
      "isHealthy": true,
      "responseTime": 28,
      "lastChecked": "2025-12-05T10:29:55Z",
      "data": {
        "rc_balance": 10000000000000,
        "can_create_accounts": true
      }
    }
  ],
  "summary": {
    "total": 6,
    "healthy": 3,
    "unhealthy": 0,
    "offline": 3
  }
}
```

**Status Codes:**
- `200 OK` - Status retrieved successfully

**Example:**
```bash
curl https://api.skatehive.app/api/status | jq
```

---

### Filter by Category

Get status for specific service category.

**Query Parameters:**
- `category`: Filter by category (`Video Transcoder`, `Instagram Downloader`, `Account Manager`)

**Example:**
```bash
curl "https://api.skatehive.app/api/status?category=Instagram%20Downloader"
```

---

## 📊 Common Response Codes

### Success Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 OK | Request successful | GET requests, successful operations |
| 201 Created | Resource created | Account creation |
| 202 Accepted | Request accepted for processing | Video upload queued |
| 204 No Content | Successful, no content to return | DELETE operations |

### Client Error Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 400 Bad Request | Invalid request | Missing parameters, invalid format |
| 401 Unauthorized | Authentication failed | Invalid or expired cookies |
| 403 Forbidden | Access denied | Insufficient permissions |
| 404 Not Found | Resource not found | Invalid job ID, private post |
| 409 Conflict | Resource conflict | Username already exists |
| 413 Payload Too Large | File too large | Video exceeds size limit |
| 429 Too Many Requests | Rate limited | Too many requests, Instagram throttling |

### Server Error Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 500 Internal Server Error | Server error | Processing failure, uncaught exception |
| 503 Service Unavailable | Service temporarily unavailable | Insufficient RC, maintenance |

---

## ⚡ Rate Limits

### Instagram Downloader

Instagram applies rate limits based on:
- Requests per minute: ~30-60 requests
- Daily request limit: ~500-1000 requests
- May vary based on account age and activity

**Best Practices:**
- Implement retry with exponential backoff
- Cache results when possible
- Monitor for 429 responses
- Use multiple Instagram accounts if needed

**Rate Limit Response:**
```json
{
  "success": false,
  "error": "Rate limited by Instagram. Please try again in 15 minutes.",
  "code": "RATE_LIMITED",
  "retry_after": 900
}
```

---

### Video Transcoder

No explicit rate limits enforced in code. Throughput depends on host resources.
- Large uploads can take several minutes.
- Keep client concurrency reasonable.

---

## 🛠️ SDKs & Libraries

### JavaScript/TypeScript

```typescript
// Example service client
class SkateHiveClient {
  constructor(
    private instagramBaseUrl: string,
    private videoBaseUrl: string,
    private statusBaseUrl: string
  ) {}

  async downloadInstagram(url: string) {
    const response = await fetch(`${this.instagramBaseUrl}/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });
    return response.json();
  }

  async transcodeVideo(file: File) {
    const formData = new FormData();
    formData.append('video', file);
    
    const response = await fetch(`${this.videoBaseUrl}/transcode`, {
      method: 'POST',
      body: formData
    });
    return response.json();
  }

  async getServiceStatus() {
    const response = await fetch(`${this.statusBaseUrl}/api/status`);
    return response.json();
  }
}

// Usage
const client = new SkateHiveClient(
  'https://minivlad.tail83ea3e.ts.net/instagram',
  'https://minivlad.tail83ea3e.ts.net/video',
  'https://api.skatehive.app'
);
const result = await client.downloadInstagram('https://instagram.com/p/abc123');
```

---

### Python

```python
import requests

class SkateHiveClient:
    def __init__(self, instagram_base_url: str, video_base_url: str, status_base_url: str):
        self.instagram_base_url = instagram_base_url
        self.video_base_url = video_base_url
        self.status_base_url = status_base_url
    
    def download_instagram(self, url: str):
        response = requests.post(
            f"{self.instagram_base_url}/download",
            json={"url": url}
        )
        return response.json()
    
    def transcode_video(self, file_path: str):
        with open(file_path, 'rb') as f:
            files = {'video': f}
            response = requests.post(
                f\"{self.video_base_url}/transcode\",
                files=files
            )
        return response.json()
    
    def get_service_status(self):
        response = requests.get(f"{self.status_base_url}/api/status")
        return response.json()

# Usage
client = SkateHiveClient(
    "https://minivlad.tail83ea3e.ts.net/instagram",
    "https://minivlad.tail83ea3e.ts.net/video",
    "https://api.skatehive.app"
)
result = client.download_instagram("https://instagram.com/p/abc123")
```

---

### cURL Examples Collection

```bash
# Health checks
curl https://minivlad.tail83ea3e.ts.net/video/healthz
curl https://minivlad.tail83ea3e.ts.net/instagram/healthz
curl https://minivlad.tail83ea3e.ts.net/healthz

# Download Instagram
curl -X POST https://minivlad.tail83ea3e.ts.net/instagram/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://instagram.com/p/abc123"}'

# Transcode video
curl -X POST https://minivlad.tail83ea3e.ts.net/video/transcode \
  -F "video=@video.mp4" \
  -F "creator=skater123"

# Stream progress
curl -N https://minivlad.tail83ea3e.ts.net/video/progress/abc123

# Get service status
curl https://api.skatehive.app/api/status

# Check cookie status
curl https://minivlad.tail83ea3e.ts.net/instagram/cookies/status
```

---

## 📚 Related Documentation

- [System Architecture](../architecture/ARCHITECTURE.md)
- [Infrastructure Operations](../operations/INFRASTRUCTURE_OPERATIONS.md)
- [Troubleshooting Guide](../operations/TROUBLESHOOTING_GUIDE.md)
- [Instagram Cookie Management](../operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

---

## 📝 Changelog

### Version 1.0 (December 5, 2025)
- Initial API documentation
- Video Transcoder endpoints
- Instagram Downloader endpoints
- Account Manager endpoints
- Leaderboard status endpoint with cookie monitoring
- Rate limiting documentation
- SDK examples

---

**Document Status:** ✅ Complete  
**API Version:** 1.0  
**Last Updated:** December 5, 2025  
**Maintainer:** SkateHive Development Team
