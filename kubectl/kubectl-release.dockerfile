# kubectl Dockerfile - Testkube Edition
# Based on official alpine/kubectl image

ARG KUBECTL_VERSION=1.35.0

FROM alpine/kubectl:${KUBECTL_VERSION}

LABEL maintainer="Testkube Team" \
      version="${KUBECTL_VERSION}" \
      description="kubectl - Testkube Edition"

# Add any custom configurations here if needed

