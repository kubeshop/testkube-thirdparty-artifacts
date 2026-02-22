# kubectl Dockerfile - Testkube Edition
# Based on official alpine/kubectl image
# KUBECTL_VERSION is updated by scripts/check-version.sh

FROM alpine/kubectl:1.35.1

LABEL maintainer="Testkube Team" \
      description="kubectl - Testkube Edition"

# Ensure /bin/bash exists (some jobs invoke bash explicitly)
RUN apk add --no-cache bash
