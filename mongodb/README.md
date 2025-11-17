# MongoDB 8.0.15 - Testkube Custom Edition

## Overview
Custom MongoDB image based on official `mongo:8.0.15` with enhanced security, recompiled database tools, and full Bitnami Helm chart compatibility.

## Key Features
- **Base Image**: `mongo:8.0.15` (official)
- **MongoDB Version**: 8.0.15
- **Go Version**: 1.24 (for compilation)
- **Security**: 0 HIGH/CRITICAL CVEs (vs 8 in official image)
- **Bitnami Compatibility**: Full compatibility with existing Helm charts
- **Custom Entrypoint**: Handles permissions and configuration like Bitnami

## Security Improvements
- **Vulnerability Reduction**: From 8 HIGH vulnerabilities to 0 HIGH/CRITICAL
- **Updated Dependencies**: `golang.org/x/crypto@v0.35.0`
- **Security Patches**: Ubuntu 24.04 LTS with latest patches
- **Package Updates**: Updated vulnerable packages (coreutils, libssl3t64, openssl, tar)

## CVEs Eliminated
- ✅ **CVE-2025-47906** (HIGH) - Go stdlib
- ✅ **CVE-2025-47907** (CRITICAL) - golang.org/x/crypto
- ✅ **8 HIGH vulnerabilities** from official MongoDB image

## Remaining CVEs
- 5 MEDIUM CVEs from Ubuntu base (system libraries)
- 11 LOW CVEs (minimal risk)

## What Was Done
1. **Recompiled MongoDB Database Tools** with updated Go dependencies:
   - `golang.org/x/crypto@v0.35.0`
   - Go 1.24 toolchain

2. **Updated Binaries**:
   - bsondump, mongodump, mongoexport, mongofiles
   - mongoimport, mongorestore, mongostat, mongotop

3. **Applied Ubuntu Security Patches**: `apt-get upgrade -y`

4. **Custom Entrypoint Script**: Handles permissions and configuration
   - UID/GID 1001:1001 (Bitnami compatible)
   - Network configuration (`--bind_ip_all`)
   - Directory creation and permissions

## Build
```bash
docker build -t testkube/mongodb:8.0.15 .
```

## Usage with Testkube
```yaml
# Helm values (mongo.values.yaml)
image:
  repository: testkube/mongodb
  tag: 8.0.15

# Security context is handled by the custom image
# No need for manual podSecurityContext configuration
containerSecurityContext:
  runAsUser: 1001
  runAsGroup: 1001

podSecurityContext:
  fsGroup: 1001
```

## Architecture
- **Custom Dockerfile**: `mongo-8.dockerfile` with security enhancements
- **Entrypoint Script**: `entrypoint.sh` following Bitnami approach
- **Helm Values**: `mongo.values.yaml` for deployment configuration
- **Tilt Integration**: `tiltfile` for local development

## Validation
- ✅ MongoDB operations (CRUD, ping, export/import)
- ✅ Testkube Enterprise compatibility
- ✅ All database tools functional
- ✅ Security scan passed (0 HIGH/CRITICAL)
- ✅ Bitnami Helm chart compatibility
- ✅ Kubernetes probes working
- ✅ Network configuration correct

