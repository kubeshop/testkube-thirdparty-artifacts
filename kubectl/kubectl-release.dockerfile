# kubectl Dockerfile - Testkube Edition
# Based on official alpine/kubectl image
# KUBECTL_VERSION is updated by scripts/check-version.sh

FROM alpine/kubectl:1.35.0

LABEL maintainer="Testkube Team" \
      description="kubectl - Testkube Edition"

# Add any custom configurations here if needed
