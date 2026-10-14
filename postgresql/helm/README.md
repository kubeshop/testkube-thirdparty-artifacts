# PostgreSQL 18.0.0 - Testkube

## Overview
Image uses `18.0.0` Application version and resides in Docker Hub. Full image path: `docker.io/kubeshop/testkube-postgres:18-debian-12`, also mirrored to `us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/postgresql`.
This is an official PostgreSQL image which was rebuilt and pushed to Docker Hub and the `testkube` Google Artifact Registry. Link to the original Dockerfile: https://github.com/bitnami/containers/blob/main/bitnami/postgresql/18/debian-12/Dockerfile

## Key Features
- **PostgreSQL Version**: 18.0.0
- **Debian Version**: 12
- **Security**: 0 HIGH/CRITICAL CVEs

## Remaining CVEs
- 1 MEDIUM CVEs from GNU (no fixes available yet)

## Usage with Testkube
```yaml
postgresql:
  image:
    registry: docker.io
    repository: kubeshop/testkube-postgres
    tag: 18-debian-12
```

## Validation
- ✅ Testkube OSS compatibility
- ✅ All database tools functional
- ✅ Security scan passed (0 HIGH/CRITICAL)

