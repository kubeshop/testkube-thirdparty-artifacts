# kubectl Dockerfile - Testkube Edition
# Based on official alpine/kubectl image
# KUBECTL_VERSION is updated by scripts/check-version.sh

FROM alpine/kubectl:1.37.2

LABEL maintainer="Testkube Team" \
      description="kubectl - Testkube Edition"

# Ensure /bin/bash exists (some jobs invoke bash explicitly), and apply Alpine security
# updates published after the upstream image was built.
RUN apk upgrade --no-cache && apk add --no-cache bash
