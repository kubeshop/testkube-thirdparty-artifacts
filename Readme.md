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
* [SeaweedFS](./seaweed/).
* [Dex](./dex/).
* [NATS](./nats/).

## Automation overview

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `checks.yaml` | Push to feature branches | Builds candidate images with Depot and runs `helm lint` |
| `thirdparty-updates.yaml` | Daily cron | Checks for new versions, runs tests, creates PRs |
| `create-version-tag.yaml` | PR merge with `automated` label | Creates version tags (e.g., `minio-RELEASE.xxx`) |
| `build-images.yaml` | Push to `main` or tags | Builds and publishes Docker images to GAR |
| `build-helm-charts.yaml` | Push to `main` | Packages and publishes Helm charts to GAR |
| `mongodb-gar-upgrade-validation.yaml` | Pull requests changing MongoDB; manual dispatch | Validates MongoDB upgrades with OSS and Enterprise Testkube |
| `minio-gar-upgrade-validation.yaml` | Pull requests changing MinIO; manual dispatch | Validates persisted artifacts and new executions across MinIO upgrades |
| `postgresql-gar-upgrade-validation.yaml` | Pull requests changing PostgreSQL; manual dispatch | Validates PostgreSQL upgrades with OSS and Enterprise Testkube |
| `dex-gar-upgrade-validation.yaml` | Pull requests changing Dex; manual dispatch | Verifies Enterprise Dex login before and after an upgrade |
| `seaweed-gar-upgrade-validation.yaml` | Pull requests changing SeaweedFS; manual dispatch | Validates persisted artifacts and new executions across SeaweedFS upgrades |
| `kubectl-gar-validation.yaml` | Pull requests changing kubectl; manual dispatch | Validates the candidate kubectl image in Testkube installation hooks |

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
    ├──► build-helm-charts.yaml (publishes charts to GAR)
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
* `seaweed-`
* `dex-`
* `nats-`


# Testkube third-party artifacts
## Automation

The repository workflows build and publish images and charts, check for
upstream releases, and create version tags. Supported tag prefixes are:

`minio-`, `mongodb-`, `postgresql-`, `kubectl-`, `seaweed-`, `dex-`, and
`nats-`.

## GAR upgrade validation

Pull requests that change a supported artifact start its corresponding
validation workflow. The workflow builds a candidate image, publishes it to
Google Artifact Registry (GAR), deploys it to an isolated namespace in the dev
GKE cluster, and verifies that Testkube continues to work after the upgrade.

| Workflow | Services and installations validated |
| --- | --- |
| `mongodb-gar-upgrade-validation.yaml` | MongoDB with OSS and Enterprise Testkube |
| `minio-gar-upgrade-validation.yaml` | MinIO with OSS and Enterprise Testkube |
| `postgresql-gar-upgrade-validation.yaml` | PostgreSQL with OSS and Enterprise Testkube |
| `dex-gar-upgrade-validation.yaml` | Dex with Enterprise Testkube |
| `seaweed-gar-upgrade-validation.yaml` | SeaweedFS with Enterprise Testkube |
| `kubectl-gar-validation.yaml` | kubectl with OSS Testkube |

The validations retain data created before the upgrade and verify that the
upgraded service can accept new data. Namespaces are removed when a run
finishes, including after a failure.

### Run a validation manually

In GitHub, open **Actions**, select the desired validation workflow, choose
**Run workflow**, and enter the branch and required inputs. Upgrade workflows
that compare versions require `baseline_ref` (normally `main`). Set
`pr_number` when the candidate image is associated with a pull request.

Validation workflows require repository or environment configuration for GAR
access and dev-GKE workload identity. See the workflow file for the exact
secrets and permissions required by that validation.

## Contributing an artifact update

1. Update the artifact's image build files and Helm chart as needed.
2. Open a pull request.
3. Wait for the relevant GAR validation workflow to finish successfully.
4. Merge the pull request to publish the updated artifact through the normal
   release automation.

For the TestWorkflow scenarios used by the validation jobs, see
[test/README.md](./test/README.md).
