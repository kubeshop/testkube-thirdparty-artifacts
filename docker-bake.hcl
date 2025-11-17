group "default" {
  targets = [ "minio", "mongodb" ]
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
