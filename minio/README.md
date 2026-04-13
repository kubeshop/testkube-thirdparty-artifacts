# MinIO - Testkube Edition

Custom MinIO image optimized for Testkube artifact storage.

## 📁 Structure

```
minio/
├── README.md                    # This file
├── minio-release.dockerfile     # Dockerfile for building the image
├── service.yaml                 # Service configuration for automation
├── oss.tiltfile                 # Tilt configuration (local & CI)
├── minio.values.yaml            # Helm values for testing
├── helm/                        # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── scripts/
    ├── generate-pr-description.sh  # AI-powered PR descriptions
    └── lib/                         # Helper scripts
```

## 🔄 Automated Update Pipeline

The system automatically checks for new MinIO versions and creates PRs when updates are available.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SUNDAY 00:00 UTC (or manual trigger)                                   │
│                                                                         │
│  1. CHECK FOR UPDATES                                                   │
│     └── Query Docker Hub: minio/minio                                  │
│     └── Compare with current version in Dockerfile                     │
│     └── If newer version exists → continue                             │
│                                                                         │
│  2. RUN REGRESSION TESTS                                                │
│     └── Create Kind cluster                                            │
│     └── Build image with new version                                   │
│     └── Deploy Testkube + MinIO with Tilt                              │
│     └── Run smoke tests (k6, artifacts)                                │
│                                                                         │
│  3. CREATE PR (only if tests pass)                                      │
│     └── Update Dockerfile with new version                             │
│     └── Update Chart.yaml                                              │
│     └── Generate PR description with OpenAI                            │
│     └── Create PR with labels: [minio, automated, tests-passed]        │
│                                                                         │
│  4. PUSH TO DOCKER HUB (when PR is merged)                              │
│     └── Build final image                                              │
│     └── Push to docker.io/kubeshop/testkube-minio                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### Version Detection

The script reads the current version from:
```dockerfile
# minio-release.dockerfile
ARG MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z
```

And compares it with Docker Hub's latest tag matching:
```
RELEASE.YYYY-MM-DDTHH-MM-SSZ
```

## 🧪 Testing

### Local Development

```bash
# Start Tilt (builds image automatically)
cd minio
tilt up -f oss.tiltfile

# Access Testkube
kubectl port-forward svc/testkube-api-server 8088:8088 -n testkube
testkube config api-uri http://localhost:8088

# Run tests
kubectl apply -f ../test/
testkube run tw oss-smoke-test --watch
testkube run tw minio-artifact-test --watch
```

### CI Testing

In GitHub Actions, the workflow:
1. Pre-builds the Docker image
2. Loads it into Kind cluster
3. Runs Tilt in CI mode (skips docker_build)
4. Executes regression tests

```yaml
# Workflow runs:
docker build -t testkube/minio:latest -f minio-release.dockerfile .
kind load docker-image testkube/minio:latest --name test-cluster
tilt ci -f oss.tiltfile --timeout 10m
```

## 📝 Configuration Files

### service.yaml
```yaml
name: minio
display_name: MinIO
source: dockerhub
source_image: minio/minio
version_pattern: "RELEASE\\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z"
dockerfile: minio-release.dockerfile
dockerhub_image: docker.io/kubeshop/testkube-minio
```

### minio.values.yaml (for testing)
```yaml
mode: standalone
image:
  repository: testkube/minio
  tag: latest
  pullPolicy: Never  # Use local image
auth:
  rootUser: "minio"
  rootPassword: "minio123"
persistence:
  enabled: false
defaultBuckets: "testkube-artifacts"
```

## 🔑 Required Secrets

| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Avoid Docker Hub rate limits |
| `DOCKERHUB_TOKEN` | Avoid Docker Hub rate limits |
| `OPENAI_API_KEY` | Generate PR descriptions |
| `GKE_SA_KEY_PROD` | Push to Google Artifact Registry |

## 🏗️ Building Manually

```bash
# Build image
docker build -t testkube/minio:latest -f minio-release.dockerfile .

# Tag for Docker Hub
docker tag testkube/minio:latest \
  docker.io/kubeshop/testkube-minio:2025.10

# Push (requires Docker Hub auth)
docker login
docker push docker.io/kubeshop/testkube-minio:2025.10
```

## 📊 Helm Chart

The Helm chart is based on Bitnami's MinIO chart with custom configurations for Testkube.

### Key Values

| Value | Default | Description |
|-------|---------|-------------|
| `mode` | `standalone` | Deployment mode |
| `auth.rootUser` | `minio` | Root username |
| `auth.rootPassword` | `minio123` | Root password |
| `defaultBuckets` | `testkube-artifacts` | Buckets to create |
| `persistence.enabled` | `true` | Enable persistent storage |

### Usage with Testkube

```yaml
# In Testkube values
testkube-api:
  minio:
    enabled: false  # Disable built-in MinIO
  storage:
    endpoint: testkube-minio:9000
    accessKeyId: minio
    accessKey: minio123
    SSL: false
```

## 🔗 Related Files

- **Workflow**: `.github/workflows/thirdparty-updates.yaml`
- **GAR Push**: `.github/workflows/push-to-gar.yaml`
- **Version Check Script**: `scripts/check-version.sh`
- **Tests**: `test/oss-smoke-test.yaml`, `test/minio-artifact-test.yaml`

## 📚 Additional Resources

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [Testkube Documentation](https://docs.testkube.io/)
- [Bitnami MinIO Chart](https://github.com/bitnami/charts/tree/main/bitnami/minio)
