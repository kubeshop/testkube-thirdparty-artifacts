# Testkube third-party artifacts

This repository contains the container images and Helm charts that Testkube
maintains for its bundled third-party dependencies. These artifacts are built,
tested, and published independently of the main Testkube repository so that
Testkube installations can use known, maintained versions of each dependency.

## Maintained artifacts

| Artifact | Source |
| --- | --- |
| MinIO | [minio/](./minio/) |
| MongoDB | [mongodb/](./mongodb/) |
| PostgreSQL | [postgresql/](./postgresql/) |
| kubectl | [kubectl/](./kubectl/) |
| SeaweedFS | [seaweed/](./seaweed/) |
| Dex | [dex/](./dex/) |
| NATS | [nats/](./nats/) |

Each directory contains the image build files and, where applicable, the Helm
chart used to package that dependency.

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
