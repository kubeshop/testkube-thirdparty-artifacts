# SeaweedFS Dockerfile - Testkube Edition
# Based on official chrislusf/seaweedfs image
# SEAWEEDFS_VERSION is updated by scripts/check-version.sh

FROM chrislusf/seaweedfs:4.52

LABEL maintainer="Testkube Team" \
      description="SeaweedFS - Testkube Edition"

# Apply Alpine security updates published after the upstream image was built.
RUN apk upgrade --no-cache
