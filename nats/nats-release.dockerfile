# NATS Dockerfile - Testkube Edition
# Based on the official library/nats alpine image
# The FROM version is updated by scripts/check-version.sh
#
# Reuse upstream's patched binary and runtime; scan both architectures on updates.

FROM nats:2.15.2-alpine

LABEL maintainer="Testkube Team" \
      description="NATS - Testkube Edition"
