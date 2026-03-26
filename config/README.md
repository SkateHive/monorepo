# Config

Configuration files and operational scripts for SkateHive infrastructure nodes.

## Files

- `skatehive.config.example` — Template for node configuration (copy to `skatehive.config`)
- `load-config.sh` — Configuration loader sourced by all scripts

## Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `health-check.sh` | Comprehensive health check for all services (local + Tailscale) |
| `power-recovery-v2.sh` | Auto-restart services after power outage (runs via launchd) |
| `emergency-recovery.sh` | Manual emergency restart of all services |
| `cookie-health-check.sh` | Instagram cookie expiration monitor with Discord alerts |
| `test-macmini-services.sh` | Quick endpoint accessibility test |

## Usage

```bash
# Run health check
./config/scripts/health-check.sh

# Emergency restart
./config/scripts/emergency-recovery.sh
```

All scripts auto-detect the monorepo root via `load-config.sh`.
