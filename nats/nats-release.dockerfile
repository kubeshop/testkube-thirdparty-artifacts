# NATS Dockerfile - Testkube Edition
# Based on the official library/nats alpine image
# NATS_VERSION is updated by scripts/check-version.sh
#
# The upstream alpine release is already free of known CRITICAL/HIGH CVEs, so we
# simply re-publish the latest version under the Testkube namespace.

FROM nats:2.14.3-alpine

LABEL maintainer="Testkube Team" \
      description="NATS - Testkube Edition"
