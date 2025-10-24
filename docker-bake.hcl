target "minio-meta" {}
target "minio" {
  inherits = ["minio-meta"]
  context= "minio/"
  dockerfile = "minio/minio-release.dockerfile"
  platforms = ["linux/arm64", "linux/amd64"]
}
