# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Oracle Database learning repository running Oracle Database Express Edition (XE) in Docker, configured for Korean language support (ko_KR.UTF-8) with Asia/Seoul timezone. Also includes Netdata and Uptime Kuma for monitoring.

## Common Commands

### Initial Setup
```bash
cp .env.example .env
# Edit .env: set ORACLE_PWD and HOSTNAME

docker-compose -f docker/docker-compose.yml --env-file .env up -d

# First-time initialization takes ~15 minutes
docker logs oracle-xe -f
# Wait for "DATABASE IS READY TO USE" message

# Uptime Kuma requires manual UI setup after first start
# See docs/setup-uptime-kuma.md
```

### Container Management
```bash
docker-compose -f docker/docker-compose.yml --env-file .env down              # Stop all services
docker-compose -f docker/docker-compose.yml --env-file .env restart           # Restart all services
docker-compose -f docker/docker-compose.yml --env-file .env ps                # View container status
docker inspect oracle-xe --format='{{.State.Health.Status}}'  # Health check
```

### Database Access
```bash
# SQLPlus as SYSDBA
docker exec -it oracle-xe sqlplus sys/${ORACLE_PWD}@XE as sysdba

# As SYSTEM user
docker exec -it oracle-xe sqlplus system/${ORACLE_PWD}@XE

# Pluggable database (XEPDB1)
docker exec -it oracle-xe sqlplus system/${ORACLE_PWD}@XEPDB1
```

### Troubleshooting
```bash
docker exec oracle-xe env | grep ORACLE   # Verify env vars reached container
docker-compose -f docker/docker-compose.yml --env-file .env down -v   # Nuclear reset: removes all volumes and data
docker builder prune                       # Free ~4GB of build cache
```

## Architecture

### Services (docker/docker-compose.yml)
| Service | Container | Ports | Purpose |
|---------|-----------|-------|---------|
| oracle-db | oracle-xe | 1521, 5500 | Oracle XE database (custom Dockerfile with Korean locale) |
| netdata | netdata | 19999 | Real-time system monitoring dashboard |
| uptime-kuma | uptime-kuma | 3001 | Uptime monitoring (manual setup required, see `docs/setup-uptime-kuma.md`) |

### Dockerfile (docker/Dockerfile)
Extends `container-registry.oracle.com/database/express:latest` with Korean locale (`ko_KR.UTF-8`) and Seoul timezone.

### Data Persistence
All data uses **Docker named volumes** (not bind mounts). This is intentional — bind mounts cause permission failures on Windows due to NTFS/Linux permission mismatch, which manifests as a misleading "Password cannot be null" error. See `docs/setup-oracle-xe-troubleshooting.md` for details.

### Environment Variables (.env)
- `ORACLE_PWD`: SYS/SYSTEM password (required; avoid `!` in password — causes bash history expansion issues)
- `ORACLE_SID`: Database SID (default: XE)
- `ORACLE_PDB`: Pluggable database name (default: XEPDB1)
- `ORACLE_CHARACTERSET`: Character set (default: AL32UTF8)
- `HOSTNAME`: Netdata hostname (default: home-server)

### Database Connection Info (SQL Developer/DBeaver)
- Hostname: localhost, Port: 1521, SID: XE, Username: system, Password: ORACLE_PWD value

## Important Notes
- Oracle XE image is ~15GB; empty database adds ~5GB of data files (~24GB total with cache)
- Health check has 20-minute start period to accommodate initial database creation
- Logs: oracle-xe limited to 50MB/file x 30 files; monitoring services limited to 10MB/file x 3 files
