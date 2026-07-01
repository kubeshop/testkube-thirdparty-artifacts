group "default" {
  targets = [ "minio", "mongodb", "postgresql", "kubectl", "seaweed", "dex", "nats" ]
}

target "minio-meta" {}
target "minio" {
  inherits = ["minio-meta"]
  context= "./minio"
  dockerfile = "minio-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "mongodb-meta" {}
target "mongodb" {
  inherits = ["mongodb-meta"]
  context= "./mongodb"
  dockerfile = "mongo-8.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "postgresql-meta" {}
target "postgresql" {
  inherits = ["postgresql-meta"]
  context= "./postgresql"
  dockerfile = "postgresql-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "kubectl-meta" {}
target "kubectl" {
  inherits = ["kubectl-meta"]
  context= "./kubectl"
  dockerfile = "kubectl-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "seaweed-meta" {}
target "seaweed" {
  inherits = ["seaweed-meta"]
  context= "./seaweed"
  dockerfile = "seaweedfs-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "dex-meta" {}
target "dex" {
  inherits = ["dex-meta"]
  context= "./dex"
  dockerfile = "dex-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}

target "nats-meta" {}
target "nats" {
  inherits = ["nats-meta"]
  context= "./nats"
  dockerfile = "nats-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}
