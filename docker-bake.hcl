group "default" {
  targets = [ "minio", "mongodb", "postgresql", "kubectl", "seaweed" ]
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
