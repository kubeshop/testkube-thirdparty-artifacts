# PostgreSQL Dockerfile - Testkube Edition
# Based on official postgres image
# POSTGRESQL_VERSION is updated by scripts/check-version.sh

FROM postgres:18.3

LABEL maintainer="Testkube Team" \
      description="PostgreSQL - Testkube Edition"

COPY initdb/ /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

