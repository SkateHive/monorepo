# 🎬 SkateHive Video Compression & Processing Dossier
**Generated:** December 5, 2025  
**Purpose:** Complete technical documentation of video processing pipeline

---

## 📊 Executive Summary

SkateHive processes user-uploaded videos through a multi-tier transcoding system with **zero client-side compression**. All videos are uploaded raw to server endpoints that handle H.264 encoding and IPFS distribution.

**Key Characteristics:**
- **No Client Compression**: Videos uploaded at original quality
- **Server-Side Processing**: FFmpeg transcoding on dedicated workers
- **Multi-Tier Fallback**: Mac Mini M4 → Oracle Cloud → Raspberry Pi
- **Target Format**: H.264/AAC/yuv420p MP4 with faststart streaming
- **Distribution**: Pinata IPFS pinning with CDN delivery

---

## 🏗️ Architecture Overview

```
User Browser / Mobile App (No Compression)
         ↓
    Raw Video Upload
         ↓
┌────────────────────────────────┐
│  Priority 1: Mac Mini M4       │
│  (minivlad.tail83ea3e.ts.net)  │
│  - skatehive-video-transcoder   │
│  - Fast M4 chip processing      │
│  - Primary production server    │
└────────────────────────────────┘
         ↓ (if fails)
┌────────────────────────────────┐
│  Priority 2: Oracle Cloud      │
│  (transcode.skatehive.app)     │
│  - skatehive-video-transcoder   │
│  - Cloud VPS fallback           │
└────────────────────────────────┘
         ↓ (if fails)
┌────────────────────────────────┐
│  Priority 3: Raspberry Pi      │
│  (vladsberry.tail83ea3e.ts.net)│
│  - skatehive-video-transcoder   │
│  - Last-resort fallback         │
│  - Lower performance (ARM)      │
└────────────────────────────────┘
         ↓
    FFmpeg Transcoding
         ↓
┌────────────────────────────────┐
│      Pinata IPFS Upload        │
│   - Content pinning             │
│   - Gateway distribution        │
│   - CDN acceleration            │
└────────────────────────────────┘
         ↓
  Final IPFS URL returned to user
```

> **Note:** All three servers run the same `skatehive-video-transcoder` service.
> Service discovery is handled by `skatehive-api` at `GET /api/transcode/status`,
> which health-checks all nodes and returns the best available URL.

---

## 🎥 Video Transcoding Details

### FFmpeg Configuration (All Servers)

**Location:** `skatehive-video-transcoder/src/server.js` (lines 221-231)

```javascript
const ffArgs = [
  '-y',                                          // Overwrite output
  '-i', inputPath,                               // Input file
  '-c:v', 'libx264',                            // Video codec: H.264
  '-preset', process.env.X264_PRESET || 'medium',   // Encoding speed (default: medium)
  '-crf', crf,                                  // Adaptive: 20 (short) / 22 (default) / 24 (long/large)
  '-vf', 'scale=min(iw\\,1920):min(ih\\,1080):force_original_aspect_ratio=decrease', // Cap to 1080p
  '-maxrate', '5M',                             // Peak bitrate cap
  '-bufsize', '10M',                            // VBV buffer
  '-pix_fmt', 'yuv420p',                        // 8-bit 4:2:0 — required for mobile hardware decode
  '-c:a', 'aac',                                // Audio codec: AAC
  '-b:a', process.env.AAC_BITRATE || '128k',    // Audio bitrate
  '-movflags', '+faststart',                     // Enable streaming before download complete
  outputPath
];
```

### Codec Specifications

#### Video Codec: **H.264 (libx264)**
- **Standard**: MPEG-4 AVC (Advanced Video Coding)
- **Profile**: Auto-selected by FFmpeg (typically High Profile)
- **Level**: Auto-selected based on resolution
- **Compatibility**: Universal playback on all devices
- **Patent Status**: Royalty-free for end users

#### Encoding Parameters

**Preset: `medium` (default)**
- **Options**: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
- **Current Setting**: `medium` (configurable via `X264_PRESET` env var)
- **Characteristics**:
  - Balanced encoding speed vs file size
  - Good compression efficiency
  - Suitable for server-side transcoding where speed is less critical than output quality
- **Trade-off**: Slower than `veryfast` but produces smaller, better-compressed files

**CRF (Constant Rate Factor): `22` (default)**
- **Range**: 0-51
  - 0 = Lossless (huge files)
  - 18 = Visually lossless
  - 23 = Default H.264 standard
  - 28 = Acceptable quality
  - 51 = Worst quality
- **Current Setting**: `22`
- **Quality Level**: Excellent - Nearly visually lossless
- **File Size Impact**: ~10-15% larger than CRF 23
- **Use Case**: High-quality skating videos with detail preservation

#### Audio Codec: **AAC (Advanced Audio Codec)**
- **Bitrate**: `128k` (default, configurable)
- **Channels**: Stereo (preserved from source)
- **Sample Rate**: Auto-detected from source
- **Compatibility**: Universal (iOS, Android, Web)

#### Container: **MP4 (MPEG-4 Part 14)**
- **Features**:
  - `+faststart` flag enabled
  - Moves moov atom to beginning of file
  - Enables progressive streaming (playback before full download)
  - Essential for web video players

---

## 📐 Compression Characteristics

### Quality vs. File Size Trade-offs

**Current Settings (adaptive CRF 20/22/24, medium preset):**

| Original Format | Resolution | Original Size | Transcoded Size | Compression Ratio |
|----------------|------------|---------------|-----------------|-------------------|
| iPhone HEVC    | 1080p      | 50 MB         | ~35-40 MB       | ~25% reduction    |
| Android H.264  | 1080p      | 80 MB         | ~45-50 MB       | ~40% reduction    |
| GoPro HEVC     | 4K         | 200 MB        | ~120-140 MB     | ~35% reduction    |
| Webcam H.264   | 720p       | 30 MB         | ~20-25 MB       | ~20% reduction    |

**Compression Behavior:**
- ✅ Heavily compressed source videos (iPhone, modern Android): Minimal additional compression
- ✅ Poorly compressed source videos (webcams, older phones): Significant size reduction
- ✅ Already H.264 videos: Re-encodes for consistency (slight quality loss acceptable)
- ✅ Non-H.264 videos (HEVC, VP9, AV1): Transcodes to universal H.264

### Performance Metrics

**Processing Speed (Mac Mini M4 - M4 Chip):**
- 720p video: ~0.5-1x realtime (30s video = 30-60s processing)
- 1080p video: ~1-2x realtime (60s video = 60-120s processing)
- 4K video: ~2-4x realtime (120s video = 240-480s processing)

**Processing Speed (Raspberry Pi - ARM Cortex):**
- 720p video: ~3-5x realtime (slower processing)
- 1080p video: ~5-10x realtime
- 4K video: ~10-20x realtime (very slow)
- **Use Case**: Emergency fallback only

---

## 🚀 Upload Pipeline

### Client-Side (No Compression)

**File:** `skatehive3.0/lib/utils/videoProcessing.ts` (web) · `mobileapp/lib/upload/video-upload.ts` (mobile)

Both clients upload the raw file without any client-side compression. The web app uses `EventSource` for SSE progress; the mobile app polls `/progress/:correlationId` every 1.5s (React Native cannot use `EventSource`).

```typescript
// NO CLIENT-SIDE COMPRESSION OCCURS
const formData = new FormData();
formData.append('video', file);         // Raw file, no processing
formData.append('creator', username);
formData.append('correlationId', id);   // For SSE progress tracking
formData.append('source_app', 'webapp'); // or 'mobile'
// Upload directly to transcoder (bypasses Vercel size limit)
return fetch(transcoderUrl + '/transcode', { method: 'POST', body: formData });
```

**Key Points:**
- ✅ **Zero client-side compression**
- ✅ Upload size limits: 512MB default (configurable via `MAX_UPLOAD_MB`)
- ✅ All compression happens on server
- ✅ Health-checked 3-node fallback: Mac Mini M4 → Oracle Cloud → Raspberry Pi

### Server-Side Processing

**File:** `skatehive-video-transcoder/src/server.js`

**Flow:**
1. **Receive multipart/form-data upload** (multer middleware)
2. **Write to temp directory** (`/tmp` on macOS/Linux)
3. **FFmpeg transcoding** (H.264/AAC conversion)
4. **Pinata IPFS upload** (permanent storage)
5. **Return CID and gateway URL** to client
6. **Cleanup temp files** (both input and output)

**Timeouts:**
- Upload timeout: No hard limit (handles large files)
- Transcoding timeout: No hard limit (long videos supported)
- Total request timeout: ~15 minutes (Vercel timeout on proxy)

**Error Handling:**
- ✅ Automatic retry on next server in chain
- ✅ Detailed error logging with correlation IDs
- ✅ User-friendly error messages
- ✅ Cleanup of temp files even on failure

---

## 🔄 Fallback Chain Logic

**File:** `skatehive3.0/lib/utils/videoProcessing.ts`

```typescript
// Priority 1: Mac Mini M4 (Primary)
const r1 = await tryServer('https://minivlad.tail83ea3e.ts.net/video/transcode', ...);
if (r1.success) return r1;

// Priority 2: Oracle Cloud (Secondary)
const r2 = await tryServer('https://transcode.skatehive.app/transcode', ...);
if (r2.success) return r2;

// Priority 3: Raspberry Pi (Last resort)
const r3 = await tryServer('https://vladsberry.tail83ea3e.ts.net/video/transcode', ...);
if (r3.success) return r3;

throw new Error('All transcoding servers unavailable');
```

**Timeout per server:** 30s + 10s per MB of file size, capped at 3 minutes.  
**Service discovery:** Mobile app queries `GET https://api.skatehive.app/api/transcode/status` at startup to get the current best node URL (30s health-check cache).

---

## 🏅 Server Comparison

All servers run the same `skatehive-video-transcoder` codebase.

| Feature | Mac Mini M4 | Oracle Cloud | Raspberry Pi |
|---------|-------------|--------------|--------------|
| **Priority** | 1st (Primary) | 2nd (Secondary) | 3rd (Last resort) |
| **URL** | `minivlad.tail83ea3e.ts.net` | `transcode.skatehive.app` | `vladsberry.tail83ea3e.ts.net` |
| **Network** | Tailscale (private) | Public internet | Tailscale (private) |
| **Performance** | ⭐⭐⭐⭐ Fast (M4) | ⭐⭐⭐ Good (cloud VPS) | ⭐⭐ Slow (ARM) |
| **Reliability** | ✅ Stable | ✅ Stable | ⚠️ Lower uptime |
| **Use Case** | Primary production | Auto-failover | Emergency only |
| **Typical Speed** | ~1-2x realtime | ~2-4x realtime | ~5-10x realtime |
| **Cost** | On-prem (Mac Mini) | Oracle free tier | On-prem (RPi) |

---

## 📊 Monitoring & Analytics

### Structured Logging

**File:** `skatehive-video-transcoder/src/logger.js`

**Captured Metrics:**
- Request ID (UUID)
- User/Creator name
- File size and original filename
- Client IP and User-Agent
- Origin and Referer
- Platform (mobile/desktop/tablet)
- Device info (OS, browser)
- User Hive Power (HP)
- Correlation ID (for cross-service tracking)
- Viewport resolution
- Connection type (4G, WiFi, etc.)
- Processing duration
- IPFS CID and gateway URL
- Success/failure status
- FFmpeg progress (time elapsed)

**Log Storage:**
- JSON format in `logs/transcode.log`
- Rotating log with max 100 entries
- Accessible via `/logs` and `/stats` endpoints

### Dashboard Endpoints

**Health Check:**
```bash
GET /healthz
Response: { "ok": true, "service": "video-worker", "timestamp": "..." }
```

**Statistics:**
```bash
GET /stats
Response: {
  "total": 100,
  "successful": 43,
  "failed": 7,
  "inProgress": 50,
  "avgDuration": 48610,
  "successRate": 43
}
```

**Recent Logs:**
```bash
GET /logs?limit=10
Response: {
  "logs": [...],
  "stats": { ... }
}
```

---

## 🎯 Quality Optimization Recommendations

### Current Settings Analysis

**Strengths:**
- ✅ High quality (adaptive CRF 20/22/24)
- ✅ Balanced encoding (medium preset)
- ✅ Universal mobile compatibility (H.264/AAC/yuv420p)
- ✅ Streaming-optimized (`+faststart`, maxrate 5M)
- ✅ No client-side compression (preserves quality)
- ✅ Smart passthrough: already-optimized files skip transcoding

**Potential Improvements:**

#### 1. Adaptive CRF Based on Resolution 🔥 **HIGH IMPACT**
```javascript
// Suggested improvement in server.js
const crf = inputHeight >= 2160 ? '24' :  // 4K: Slightly lower quality acceptable
           inputHeight >= 1080 ? '22' :  // 1080p: Current setting
           '20';                         // 720p and below: Higher quality
```
**Benefits:**
- Smaller 4K files without visible quality loss
- Higher quality on lower resolutions where it matters
- Better quality/size balance

#### 2. Two-Pass Encoding for Large Files 🔥 **MEDIUM IMPACT**
```javascript
// For files > 100MB, use two-pass encoding
if (fileSize > 100 * 1024 * 1024) {
  // Pass 1: Analysis
  await runFfmpeg(['-i', input, '-c:v', 'libx264', '-b:v', '5M', '-pass', '1', '-f', 'null', '/dev/null']);
  // Pass 2: Encoding
  await runFfmpeg(['-i', input, '-c:v', 'libx264', '-b:v', '5M', '-pass', '2', output]);
}
```
**Benefits:**
- Better bitrate allocation
- 10-20% smaller files at same quality
- **Trade-off:** 2x encoding time

#### 3. Resolution-Based Preset Selection 📊 **LOW IMPACT**
```javascript
const preset = inputHeight >= 2160 ? 'faster' :   // 4K: Slightly slower OK
              inputHeight >= 1080 ? 'veryfast' :  // 1080p: Current
              'fast';                             // 720p: Better compression
```
**Benefits:**
- Better compression on smaller files
- Minimal speed impact on 720p

#### 4. Client-Side Pre-compression (Optional) ⚠️ **OPTIONAL**
**Current:** No client compression (good for quality)
**Consideration:** Add optional client-side compression for mobile users on slow connections

**Pros:**
- Faster uploads on slow connections
- Reduced server load

**Cons:**
- Additional quality loss
- Battery drain on mobile
- Complexity in browser compatibility

**Recommendation:** Keep current approach (no client compression) for quality preservation

---

## 🔒 Security & Limits

### File Upload Limits

**Hard Limits:**
- Max upload size: `512 MB` (configurable via `MAX_UPLOAD_MB` env var)
- Supported formats: All FFmpeg-supported video formats
- No file type validation (trusts FFmpeg to reject invalid files)

**Recommendations:**
- ✅ Add file type whitelist (mp4, mov, avi, mkv, etc.)
- ✅ Add virus scanning integration
- ✅ Implement rate limiting (currently absent)

### CORS Configuration

**Current Settings:**
```javascript
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET,POST,OPTIONS,PUT,DELETE
Access-Control-Allow-Headers: Content-Type,Authorization,Accept,X-Requested-With
```

**Status:** ✅ Properly configured for web uploads

---

## 💾 Storage & Distribution

### IPFS Pinning (Pinata)

**Configuration:**
- API: `https://api.pinata.cloud/pinning/pinFileToIPFS`
- Gateway: `https://gateway.pinata.cloud/ipfs/{CID}`
- CID Version: `1` (base32, case-insensitive)
- Authentication: JWT Bearer token (`PINATA_JWT` env var)

**Metadata Stored:**
```json
{
  "name": "transcoded-2025-12-05T12:34:56.789Z.mp4",
  "keyvalues": {
    "creator": "username",
    "requestId": "abc12345",
    "platform": "mobile",
    "deviceInfo": "mobile/iOS/Safari",
    "userHP": "123.456",
    "clientIP": "192.168.1.1",
    "thumbnail": "https://..."
  }
}
```

**Benefits:**
- ✅ Permanent storage (pinned)
- ✅ Global CDN distribution
- ✅ Cryptographic verification (CID)
- ✅ Rich metadata for analytics

---

## 🧪 Testing & Validation

### Manual Testing Commands

**Test Mac Mini M4 Transcoder:**
```bash
curl -X POST https://minivlad.tail83ea3e.ts.net/video/transcode \
  -F "video=@test_video.mp4" \
  -F "creator=testuser" \
  -F "platform=desktop" \
  -F "deviceInfo=desktop/macOS/Chrome"
```

**Check Transcoder Health:**
```bash
curl https://minivlad.tail83ea3e.ts.net/video/healthz
curl https://minivlad.tail83ea3e.ts.net/video/stats
```

### Automated Testing Recommendations

**Unit Tests Needed:**
- ✅ FFmpeg argument construction
- ✅ Fallback chain logic
- ✅ Error handling and retry logic
- ✅ Telemetry data collection

**Integration Tests Needed:**
- ✅ End-to-end upload flow
- ✅ Server fallback chain
- ✅ IPFS pinning
- ✅ Cleanup of temp files

**Load Testing:**
- ✅ Concurrent uploads
- ✅ Large file handling (512MB)
- ✅ Failover under load

---

## 📈 Performance Optimization Opportunities

### High Priority 🔥

1. **Add Explicit Timeouts**
   - Current: No timeout configured
   - Recommendation: 5 minutes per server, 15 minutes total
   - Impact: Prevents hung requests

2. **Implement Request Queuing**
   - Current: All requests processed immediately
   - Recommendation: Queue system with max concurrent transcodes
   - Impact: Prevents server overload

3. **Add Rate Limiting**
   - Current: No rate limiting
   - Recommendation: 5 uploads/hour per user
   - Impact: Prevents abuse

### Medium Priority 📊

4. **Cache Optimization**
   - Add Redis/KV cache for frequently accessed videos
   - Cache IPFS gateway URLs (1 hour TTL)

5. **Compression Optimization**
   - Implement adaptive CRF (resolution-based)
   - Consider two-pass encoding for large files

6. **Error Recovery**
   - Add automatic retry with exponential backoff
   - Implement partial upload resumption

### Low Priority 🎯

7. **Monitoring Enhancement**
   - Integrate with Datadog/Sentry
   - Add real-time alerting
   - Track compression ratios and quality metrics

8. **Storage Optimization**
   - Implement deduplication (check CID before transcoding)
   - Add automatic cleanup of failed uploads

---

## 📝 Configuration Reference

### Environment Variables

**Video Transcoder Service:**
```bash
# Server Configuration
PORT=8080

# FFmpeg Encoding Settings
X264_PRESET=medium       # ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow (default: medium)
X264_CRF=22              # 0-51 (lower = better quality, 18-28 recommended)
AAC_BITRATE=128k         # Audio bitrate (128k recommended)

# Upload Limits
MAX_UPLOAD_MB=512        # Maximum upload size in megabytes

# IPFS/Pinata Configuration
PINATA_JWT=your_jwt_token_here
PINATA_GATEWAY=https://gateway.pinata.cloud/ipfs  # Optional, defaults to this
```

### Docker Configuration

**Current Settings:**
```yaml
services:
  video-worker:
    build: .
    ports:
      - "8081:8080"  # External:Internal
    env_file:
      - .env
    environment:
      - PORT=8080
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:8080/healthz', ...)"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## 🎓 Best Practices

### For Developers

1. **Always handle all server fallbacks** in client code
2. **Include correlation IDs** for cross-service request tracking
3. **Log rich telemetry** (device, browser, network) for analytics
4. **Implement proper error handling** with user-friendly messages
5. **Test with various video formats** and sizes

### For Operations

1. **Monitor all transcoding servers** for health
2. **Set up alerts** for high failure rates
3. **Rotate logs regularly** to prevent disk space issues
4. **Back up Pinata JWT** and rotate periodically
5. **Monitor IPFS gateway performance** and costs

### For Content Creators

1. **Upload original quality videos** - no need to compress first
2. **Supported formats:** MP4, MOV, AVI, MKV, WEBM, and more
3. **Max file size:** 512 MB
4. **Processing time:** 1-5 minutes for typical videos
5. **Result:** Universally compatible H.264/AAC MP4 on IPFS

---

## 🔗 Related Documentation

- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - System architecture overview
- [INFRASTRUCTURE_OPERATIONS.md](../operations/INFRASTRUCTURE_OPERATIONS.md) - Deployment and maintenance
- [TROUBLESHOOTING_GUIDE.md](../operations/TROUBLESHOOTING_GUIDE.md) - Video processing issues
- [API_REFERENCE.md](./API_REFERENCE.md) - API endpoint documentation

---

**Last Updated:** December 5, 2025  
**Maintainer:** SkateHive Development Team  
**Version:** 1.0
