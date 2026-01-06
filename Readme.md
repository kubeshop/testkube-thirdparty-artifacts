# Testkube 3rd-party artifacts

Testkube has 6 external technologies in use which are part of any installation by default:

* Minio.
* MongoDB or PostgreSQL.
* NATS.
* Dex.
* Kubectl.

For all of them it's required a container image and helm chart to be part of the Testkube installations out of the box,
in this repository we managed all those artifacts that are not continuously maintained and patched by it's community
ensuring that Testkube provides secure and reliable versions of these platforms for all installations.

## Currently Maintained here

* [Minio](./minio/).
* [MongoDB](./mongodb/).
* [PostgreSQL](./postgresql/).
* [Kubectl](./kubectl/).

## Automation overview

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `checks.yaml` | Push to feature branches | Builds candidate images with Depot and runs `helm lint` |
| `thirdparty-updates.yaml` | Daily cron | Checks for new versions, runs tests, creates PRs |
| `create-version-tag.yaml` | PR merge with `automated` label | Creates version tags (e.g., `minio-RELEASE.xxx`) |
| `build-images.yaml` | Push to `main` or tags | Builds and publishes Docker images to GAR |

### Update Flow

```
Daily Cron
    │
    ▼
Check for new versions (Docker Hub)
    │
    ▼
Run tests in Kind cluster
    │
    ▼
Create PR with AI-generated description
    │
    ▼
Review & Merge
    │
    ├──► build-images.yaml (temp-main tag)
    │
    └──► create-version-tag.yaml
              │
              ▼
         Creates tag: minio-RELEASE.xxx
              │
              ▼
         build-images.yaml (production tag)
```

### Supported Tag Prefixes

* `minio-`
* `mongodb-`
* `postgresql-`
* `kubectl-`

## Processes to manage artifacts into this repository

[TODO]
