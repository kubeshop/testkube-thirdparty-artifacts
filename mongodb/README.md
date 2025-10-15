# MongoDB 8.0.15 - Testkube

## Overview
Custom MongoDB image based on official `mongo:8.0.15` with recompiled database tools to eliminate Go stdlib CVEs.

## Key Features
- **Base Image**: `mongo:8.0.15` (official)
- **MongoDB Version**: 8.0.15
- **Go Version**: 1.24 (for compilation)
- **Security**: 0 HIGH/CRITICAL CVEs

## CVEs Eliminated
- ✅ **CVE-2025-47906** (HIGH) - Go stdlib
- ✅ **CVE-2025-47907** (CRITICAL) - golang.org/x/crypto

## Remaining CVEs
- 5 MEDIUM CVEs from Ubuntu base (no fixes available)

## What Was Done
1. **Recompiled MongoDB Database Tools** with updated Go dependencies:
   - `golang.org/x/crypto@v0.35.0`
   - Go 1.24 toolchain
   
2. **Updated Binaries**:
   - bsondump, mongodump, mongoexport, mongofiles
   - mongoimport, mongorestore, mongostat, mongotop

3. **Applied Ubuntu Security Patches**: `apt-get upgrade -y`

## Build
```bash
docker build -t kubeshop/mongo:8.0.15-testkube .
```

## Usage with Testkube
```yaml
mongodb:
  image:
    repository: kubeshop/mongo
    tag: "8.0.15-testkube"
  podSecurityContext:
    fsGroup: 999
    runAsUser: 999
    runAsNonRoot: true
```

## Validation
- ✅ MongoDB operations (CRUD, ping, export/import)
- ✅ Testkube Enterprise compatibility
- ✅ All database tools functional
- ✅ Security scan passed (0 HIGH/CRITICAL)

