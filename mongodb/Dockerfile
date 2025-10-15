# Stage 1: Build MongoDB tools with Go 1.24 and updated dependencies
FROM golang:1.24 AS builder

WORKDIR /build

# Install required dependencies
RUN apt-get update && apt-get install -y git

# Clone MongoDB database tools
RUN git clone --depth 1 --branch 100.10.0 https://github.com/mongodb/mongo-tools.git

WORKDIR /build/mongo-tools

# Update dependencies and regenerate vendor directory
RUN go get golang.org/x/crypto@v0.35.0 && \
    go mod tidy && \
    go mod vendor

# Build each tool using updated vendor directory
RUN go build -mod=vendor -o /usr/local/bin/bsondump ./bsondump/main/bsondump.go
RUN go build -mod=vendor -o /usr/local/bin/mongodump ./mongodump/main/mongodump.go
RUN go build -mod=vendor -o /usr/local/bin/mongoexport ./mongoexport/main/mongoexport.go
RUN go build -mod=vendor -o /usr/local/bin/mongofiles ./mongofiles/main/mongofiles.go
RUN go build -mod=vendor -o /usr/local/bin/mongoimport ./mongoimport/main/mongoimport.go
RUN go build -mod=vendor -o /usr/local/bin/mongorestore ./mongorestore/main/mongorestore.go
RUN go build -mod=vendor -o /usr/local/bin/mongostat ./mongostat/main/mongostat.go
RUN go build -mod=vendor -o /usr/local/bin/mongotop ./mongotop/main/mongotop.go

# Stage 2: Final image based on official mongo:8.0.15
FROM mongo:8.0.15

# Metadata
LABEL maintainer="Testkube Team"
LABEL version="8.0.15-testkube"
LABEL description="MongoDB 8.0.15 - Testkube Edition - Recompiled binaries"

USER root

# Copy recompiled binaries with updated dependencies
COPY --from=builder /usr/local/bin/bsondump /usr/bin/bsondump
COPY --from=builder /usr/local/bin/mongodump /usr/bin/mongodump
COPY --from=builder /usr/local/bin/mongoexport /usr/bin/mongoexport
COPY --from=builder /usr/local/bin/mongofiles /usr/bin/mongofiles
COPY --from=builder /usr/local/bin/mongoimport /usr/bin/mongoimport
COPY --from=builder /usr/local/bin/mongorestore /usr/bin/mongorestore
COPY --from=builder /usr/local/bin/mongostat /usr/bin/mongostat
COPY --from=builder /usr/local/bin/mongotop /usr/bin/mongotop

# Apply Ubuntu security patches
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER mongodb

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD mongosh --eval "db.adminCommand('ping')" || exit 1

EXPOSE 27017
CMD ["mongod"]
