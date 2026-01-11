# PostgreSQL Dockerfile - Testkube Edition
# Based on official postgres image

ARG POSTGRESQL_VERSION=18.1

FROM postgres:${POSTGRESQL_VERSION}

LABEL maintainer="Testkube Team" \
      version="${POSTGRESQL_VERSION}" \
      description="PostgreSQL - Testkube Edition"

# Add any custom configurations here if needed

