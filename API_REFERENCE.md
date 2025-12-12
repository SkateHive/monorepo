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
| Video Transcoder | `https://minivlad.tail9656d3.ts.net/video` | `http://localhost:8081` | 8081:8080 |
| Instagram Downloader | `https://vladsberry.tail83ea3e.ts.net/instagram` | `http://localhost:8000` | 443(`/instagram`):8000 |
| Account Manager | `https://minivlad.tail9656d3.ts.net` | `http://localhost:3001` | 3001:3000 |
| Leaderboard API | `https://your-domain.vercel.app` | `http://localhost:3000` | 3000 |

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
- **Management:** See [Cookie Management Guide](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

---

## 🎬 Video Transcoder API

**Base URL (Production):** `https://minivlad.tail9656d3.ts.net/video`  
**Base URL (Development):** `http://localhost:8081`

---

### Health Check

Get service health status.

**Endpoint:** `GET /video/healthz`

**Response:**
```json
{
  "status": "healthy",
  "uptime": 172800,
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `500 Internal Server Error` - Service unhealthy

**Example:**
```bash
curl https://minivlad.tail9656d3.ts.net/video/healthz
```

---

### Get Statistics

Get video processing statistics.

**Endpoint:** `GET /video/stats`

**Response:**
```json
{
  "total_processed": 1247,
  "queue_length": 3,
  "active_jobs": 1,
  "failed_jobs": 12,
  "average_processing_time": 45.2,
  "disk_usage": {
    "total": "500GB",
    "used": "342GB",
    "available": "158GB"
  }
}
```

**Status Codes:**
- `200 OK` - Statistics retrieved
- `500 Internal Server Error` - Failed to get stats

**Example:**
```bash
curl https://minivlad.tail9656d3.ts.net/video/stats
```

---

### Get Recent Logs

Get recent processing logs.

**Endpoint:** `GET /video/logs`

**Query Parameters:**
- `limit` (optional): Number of log entries (default: 100, max: 1000)
- `level` (optional): Filter by log level (`info`, `warning`, `error`)

**Response:**
```json
{
  "logs": [
    {
      "timestamp": "2025-12-05T10:30:00Z",
      "level": "info",
      "message": "Video processing completed",
      "job_id": "abc123",
      "duration": 42.5
    }
  ],
  "total": 1,
  "limit": 100
}
```

**Example:**
```bash
curl "https://minivlad.tail9656d3.ts.net/video/logs?limit=50&level=error"
```

---

### Upload Video for Transcoding

Upload a video file for processing and IPFS upload.

**Endpoint:** `POST /video/upload`

**Content-Type:** `multipart/form-data`

**Parameters:**
- `file` (required): Video file (MP4, MOV, AVI, etc.)
- `title` (optional): Video title
- `description` (optional): Video description
- `formats` (optional): Comma-separated formats (`hls`, `mp4`, default: both)

**Request:**
```bash
curl -X POST https://minivlad.tail9656d3.ts.net/video/upload \
  -F "file=@/path/to/video.mp4" \
  -F "title=My Skate Video" \
  -F "description=Kickflip compilation" \
  -F "formats=hls,mp4"
```

**Response (Success):**
```json
{
  "success": true,
  "job_id": "abc123def456",
  "status": "processing",
  "estimated_time": 120,
  "message": "Video uploaded and queued for processing"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "File too large (max 2GB)",
  "code": "FILE_TOO_LARGE"
}
```

**Status Codes:**
- `202 Accepted` - Video queued for processing
- `400 Bad Request` - Invalid request (missing file, wrong format)
- `413 Payload Too Large` - File exceeds size limit
- `500 Internal Server Error` - Processing failed

---

### Check Job Status

Get status of a transcoding job.

**Endpoint:** `GET /video/job/:jobId`

**Response (Processing):**
```json
{
  "job_id": "abc123def456",
  "status": "processing",
  "progress": 45,
  "current_step": "transcoding",
  "estimated_time_remaining": 60
}
```

**Response (Completed):**
```json
{
  "job_id": "abc123def456",
  "status": "completed",
  "progress": 100,
  "outputs": {
    "hls": {
      "cid": "QmXxx...abc",
      "url": "ipfs://QmXxx...abc/master.m3u8",
      "size": 45678912
    },
    "mp4": {
      "cid": "QmYyy...def",
      "url": "ipfs://QmYyy...def/video.mp4",
      "size": 52341678
    }
  },
  "metadata": {
    "duration": 125.4,
    "resolution": "1920x1080",
    "fps": 30,
    "codec": "h264"
  },
  "processing_time": 142.5
}
```

**Response (Failed):**
```json
{
  "job_id": "abc123def456",
  "status": "failed",
  "error": "FFmpeg encoding failed",
  "details": "Invalid video codec"
}
```

**Status Values:**
- `queued` - Waiting for processing
- `processing` - Currently transcoding
- `uploading` - Uploading to IPFS
- `completed` - Successfully processed
- `failed` - Processing failed

**Example:**
```bash
curl https://minivlad.tail9656d3.ts.net/video/job/abc123def456
```

---

## 📸 Instagram Downloader API

**Base URL (Production):** `https://minivlad.tail9656d3.ts.net/instagram`  
**Base URL (Development):** `http://localhost:8000`

---

### Health Check

Get service health and cookie status.

**Endpoint:** `GET /instagram/health`

**Response:**
```json
{
  "status": "healthy",
  "uptime": 259200,
  "version": "1.0.0",
  "authentication": {
    "cookies_valid": true,
    "cookies_exist": true
  }
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `500 Internal Server Error` - Service unhealthy

**Example:**
```bash
curl https://minivlad.tail9656d3.ts.net/instagram/health
```

---

### Download Instagram Content

Download Instagram post, reel, or story and upload to IPFS.

**Endpoint:** `POST /instagram/download`

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "url": "https://www.instagram.com/p/abc123/",
  "options": {
    "upload_to_ipfs": true,
    "include_metadata": true
  }
}
```

**Parameters:**
- `url` (required): Instagram post/reel/story URL
- `options.upload_to_ipfs` (optional): Upload to IPFS (default: true)
- `options.include_metadata` (optional): Include post metadata (default: true)

**Response (Success):**
```json
{
  "success": true,
  "media": [
    {
      "type": "video",
      "url": "https://instagram.com/...",
      "ipfs_cid": "QmXxx...abc",
      "ipfs_url": "ipfs://QmXxx...abc",
      "size": 12345678,
      "width": 1080,
      "height": 1920,
      "duration": 15.5
    }
  ],
  "metadata": {
    "username": "skater123",
    "caption": "Kickflip down 10 stair! 🛹",
    "likes": 1234,
    "comments": 56,
    "timestamp": "2025-12-05T10:00:00Z",
    "hashtags": ["skateboarding", "kickflip"]
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Invalid Instagram cookies",
  "code": "AUTHENTICATION_FAILED"
}
```

**Status Codes:**
- `200 OK` - Content downloaded successfully
- `400 Bad Request` - Invalid URL
- `401 Unauthorized` - Invalid or expired cookies
- `404 Not Found` - Post not found or private
- `429 Too Many Requests` - Rate limited by Instagram
- `500 Internal Server Error` - Download failed

**Example:**
```bash
curl -X POST https://minivlad.tail9656d3.ts.net/instagram/download \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.instagram.com/p/abc123/",
    "options": {
      "upload_to_ipfs": true,
      "include_metadata": true
    }
  }'
```

---

### Download TikTok Content

Download TikTok video and upload to IPFS.

**Endpoint:** `POST /instagram/download/tiktok`

**Request Body:**
```json
{
  "url": "https://www.tiktok.com/@user/video/123456",
  "options": {
    "upload_to_ipfs": true,
    "no_watermark": true
  }
}
```

**Parameters:**
- `url` (required): TikTok video URL
- `options.upload_to_ipfs` (optional): Upload to IPFS (default: true)
- `options.no_watermark` (optional): Remove TikTok watermark (default: false)

**Response:** Similar to Instagram download

---

### Download YouTube Content

Download YouTube video and upload to IPFS.

**Endpoint:** `POST /instagram/download/youtube`

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=abc123",
  "options": {
    "upload_to_ipfs": true,
    "quality": "1080p"
  }
}
```

**Parameters:**
- `url` (required): YouTube video URL
- `options.upload_to_ipfs` (optional): Upload to IPFS (default: true)
- `options.quality` (optional): Video quality (`360p`, `480p`, `720p`, `1080p`, `best`)

**Response:** Similar to Instagram download

---

### Check Cookie Status

Get Instagram cookie validation status.

**Endpoint:** `GET /instagram/cookies/status`

**Response:**
```json
{
  "cookies_exist": true,
  "cookies_valid": true,
  "expires_at": "2026-01-15T00:00:00Z",
  "days_until_expiry": 41,
  "last_validated": "2025-12-05T09:00:00Z"
}
```

**Status Codes:**
- `200 OK` - Cookie status retrieved

**Example:**
```bash
curl https://minivlad.tail9656d3.ts.net/instagram/cookies/status
```

---

### Validate Cookies

Manually trigger cookie validation.

**Endpoint:** `POST /instagram/cookies/validate`

**Response:**
```json
{
  "valid": true,
  "message": "Cookies are valid and working",
  "tested_at": "2025-12-05T10:30:00Z"
}
```

**Status Codes:**
- `200 OK` - Validation successful (may be valid or invalid)
- `500 Internal Server Error` - Validation failed to run

**Example:**
```bash
curl -X POST https://minivlad.tail9656d3.ts.net/instagram/cookies/validate
```

---

## 👤 Account Manager API

**Base URL (Production):** `https://minivlad.tail9656d3.ts.net`  
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
curl https://minivlad.tail9656d3.ts.net/healthz
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
curl https://minivlad.tail9656d3.ts.net/rc-status
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

**Base URL (Production):** `https://your-domain.vercel.app`  
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
      "url": "https://minivlad.tail9656d3.ts.net/video/healthz",
      "isHealthy": true,
      "responseTime": 45,
      "lastChecked": "2025-12-05T10:29:55Z"
    },
    {
      "id": "macmini-insta",
      "name": "Mac Mini IG",
      "category": "Instagram Downloader",
      "url": "https://minivlad.tail9656d3.ts.net/instagram/health",
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
      "url": "https://minivlad.tail9656d3.ts.net/healthz",
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
curl https://your-domain.vercel.app/api/status | jq
```

---

### Filter by Category

Get status for specific service category.

**Query Parameters:**
- `category`: Filter by category (`Video Transcoder`, `Instagram Downloader`, `Account Manager`)

**Example:**
```bash
curl "https://your-domain.vercel.app/api/status?category=Instagram%20Downloader"
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

No explicit rate limits, but resource-constrained:
- Concurrent jobs: 3 max
- Queue limit: 50 pending jobs
- File size limit: 2GB

**Queue Full Response:**
```json
{
  "success": false,
  "error": "Processing queue is full. Please try again later.",
  "code": "QUEUE_FULL",
  "queue_length": 50,
  "estimated_wait": 3600
}
```

---

## 🛠️ SDKs & Libraries

### JavaScript/TypeScript

```typescript
// Example service client
class SkateHiveClient {
  constructor(private baseUrl: string) {}

  async downloadInstagram(url: string) {
    const response = await fetch(`${this.baseUrl}/instagram/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });
    return response.json();
  }

  async uploadVideo(file: File) {
    const formData = new FormData();
    formData.append('file', file);
    
    const response = await fetch(`${this.baseUrl}/video/upload`, {
      method: 'POST',
      body: formData
    });
    return response.json();
  }

  async getServiceStatus() {
    const response = await fetch(`${this.baseUrl}/api/status`);
    return response.json();
  }
}

// Usage
const client = new SkateHiveClient('https://minivlad.tail9656d3.ts.net');
const result = await client.downloadInstagram('https://instagram.com/p/abc123');
```

---

### Python

```python
import requests

class SkateHiveClient:
    def __init__(self, base_url: str):
        self.base_url = base_url
    
    def download_instagram(self, url: str):
        response = requests.post(
            f"{self.base_url}/instagram/download",
            json={"url": url}
        )
        return response.json()
    
    def upload_video(self, file_path: str):
        with open(file_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(
                f"{self.base_url}/video/upload",
                files=files
            )
        return response.json()
    
    def get_service_status(self):
        response = requests.get(f"{self.base_url}/api/status")
        return response.json()

# Usage
client = SkateHiveClient("https://minivlad.tail9656d3.ts.net")
result = client.download_instagram("https://instagram.com/p/abc123")
```

---

### cURL Examples Collection

```bash
# Health checks
curl https://minivlad.tail9656d3.ts.net/video/healthz
curl https://minivlad.tail9656d3.ts.net/instagram/health
curl https://minivlad.tail9656d3.ts.net/healthz

# Download Instagram
curl -X POST https://minivlad.tail9656d3.ts.net/instagram/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://instagram.com/p/abc123"}'

# Upload video
curl -X POST https://minivlad.tail9656d3.ts.net/video/upload \
  -F "file=@video.mp4" \
  -F "title=My Video"

# Check job status
curl https://minivlad.tail9656d3.ts.net/video/job/abc123

# Get service status
curl https://your-domain.vercel.app/api/status

# Check cookie status
curl https://minivlad.tail9656d3.ts.net/instagram/cookies/status
```

---

## 📚 Related Documentation

- [System Architecture](./ARCHITECTURE.md)
- [Infrastructure Operations](./INFRASTRUCTURE_OPERATIONS.md)
- [Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)
- [Instagram Cookie Management](./docs/operations/INSTAGRAM_COOKIE_MANAGEMENT.md)

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
