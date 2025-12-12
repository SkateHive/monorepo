# 🔧 Instagram Service Timeout Fix Prompt

> **✅ RESOLVED - December 5, 2025**  
> **Status:** Issue Fixed in Production  
> **Archived:** This document describes a problem that has been resolved in the codebase.  
> **Location:** Moved to `docs/archive/` for historical reference  
> **Solution:** Environment-aware Instagram server configuration was implemented in `app/api/instagram-download/route.ts`
>
> See current implementation:
> - Development: Uses `localhost:6666` (correct port)
> - Production: Uses `minivlad.tail9656d3.ts.net/instagram/download` (Mac Mini M4 primary)
> - All services tested and working as of December 5, 2025

---

## Context (Historical - Issue Already Resolved)
You are working on the SkateHive 3.0 webapp and need to fix Instagram download service timeouts. The webapp currently has a timeout issue when trying to reach the Raspberry Pi Instagram service via Tailscale from localhost.

## Current Problem
The webapp's Instagram health check shows:
```json
{
  "healthy": true,
  "servers": [
    {
      "server": "http://vladsberry.tail83ea3e.ts.net:8000",
      "healthy": false,
      "error": "Server timeout"
    },
    {
      "server": "https://skate-insta.onrender.com",
      "healthy": true,
      "status": 200
    }
  ]
}
```

## Root Cause
The webapp running on `localhost:3000` cannot reach `http://vladsberry.tail83ea3e.ts.net:8000` due to network isolation, but the local Docker service is running perfectly on `localhost:8000`.

## Verified Working Services
✅ **Local Docker service**: `http://localhost:8000` - Working perfectly with Instagram cookies
✅ **Render service**: `https://skate-insta.onrender.com` - Working as backup
❌ **Tailscale from localhost**: `http://vladsberry.tail83ea3e.ts.net:8000` - Timeout (network isolation)

## Task: Fix Instagram Service Configuration

### Objective
Update the webapp to use the correct Instagram service URLs based on the environment to eliminate timeouts and ensure reliable Instagram downloads.

### Required Changes

#### Option 1: Environment-Based Configuration (Recommended)
```typescript
// In your Instagram service configuration file
const getInstagramAPIs = () => {
  const isDevelopment = process.env.NODE_ENV === 'development' || 
                       process.env.NEXT_PUBLIC_ENVIRONMENT === 'development';
  
  return [
    isDevelopment 
      ? 'http://localhost:8000'                    // Local Docker service
      : 'http://vladsberry.tail83ea3e.ts.net:8000', // Production Tailscale
    'https://skate-insta.onrender.com'             // Always as backup
  ];
};

export const INSTAGRAM_APIS = getInstagramAPIs();
```

#### Option 2: Environment Variables
Create environment-specific configurations:

**`.env.local` (for development):**
```env
NEXT_PUBLIC_INSTAGRAM_API_PRIMARY=http://localhost:8000
NEXT_PUBLIC_INSTAGRAM_API_BACKUP=https://skate-insta.onrender.com
```

**`.env.production` (for production):**
```env
NEXT_PUBLIC_INSTAGRAM_API_PRIMARY=http://vladsberry.tail83ea3e.ts.net:8000
NEXT_PUBLIC_INSTAGRAM_API_BACKUP=https://skate-insta.onrender.com
```

**In your service file:**
```typescript
export const INSTAGRAM_APIS = [
  process.env.NEXT_PUBLIC_INSTAGRAM_API_PRIMARY || 'http://localhost:8000',
  process.env.NEXT_PUBLIC_INSTAGRAM_API_BACKUP || 'https://skate-insta.onrender.com'
];
```

### Files to Modify
Look for these files in your `skatehive3.0` project:
- `services/instagramDownloadService.ts` (or similar)
- `lib/instagram.ts` (or similar) 
- `api/instagram-download/route.ts` (or similar)
- Any file containing Instagram API configurations

### Search Patterns
Use these search patterns to find the configuration:
```bash
# Find Instagram API configurations
grep -r "vladsberry.tail83ea3e.ts.net" .
grep -r "skate-insta.onrender.com" .
grep -r "INSTAGRAM_API" .
grep -r "instagram.*download" . --include="*.ts" --include="*.js"
```

### Expected Result
After the fix, the health check should show:
```json
{
  "healthy": true,
  "servers": [
    {
      "server": "http://localhost:8000",
      "healthy": true,
      "status": 200
    },
    {
      "server": "https://skate-insta.onrender.com", 
      "healthy": true,
      "status": 200
    }
  ],
  "healthyCount": 2
}
```

### Testing Steps
1. **Update the Instagram service configuration** using one of the options above
2. **Restart your development server** (`npm run dev`)
3. **Test the health endpoint**:
   ```bash
   curl -s http://localhost:3000/api/instagram-health | jq .
   ```
4. **Test Instagram download**:
   ```bash
   curl -X POST http://localhost:3000/api/instagram-download \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.instagram.com/skate_dev/reel/DOCCkdVj0Iy/"}'
   ```

### Why This Works
- **Local development**: Uses `localhost:8000` (Docker service on same machine)
- **Production deployment**: Uses `vladsberry.tail83ea3e.ts.net:8000` (Tailscale for remote access)
- **Always has backup**: Render service provides redundancy
- **No network isolation**: localhost can always reach localhost

### Additional Benefits
✅ **Faster local development** (no network latency)
✅ **More reliable** (no dependency on Tailscale for local testing)
✅ **Environment-appropriate** (uses correct service for each context)
✅ **Maintains production functionality** (Tailscale still works in prod)

## Success Criteria
- ✅ Instagram health check shows 2 healthy servers
- ✅ Instagram downloads work without timeouts
- ✅ Local development uses localhost:8000
- ✅ Production deployment ready for Tailscale access

## Context Notes
- The local Docker Instagram service has working Instagram cookies and authentication
- The service is enhanced with cookie-based authentication (v2.0.0)
- Both video transcoding and Instagram downloading are working locally
- The issue is purely network routing between localhost webapp and Tailscale

Fix this configuration and the Instagram downloads will work perfectly! 🚀
