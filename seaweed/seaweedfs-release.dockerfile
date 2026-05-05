# SeaweedFS Dockerfile - Testkube Edition
# Based on official chrislusf/seaweedfs image
# SEAWEEDFS_VERSION is updated by scripts/check-version.sh

FROM chrislusf/seaweedfs:4.23

LABEL maintainer="Testkube Team" \
      description="SeaweedFS - Testkube Edition"
