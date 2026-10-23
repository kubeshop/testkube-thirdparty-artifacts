# Third-party service validation workflows

These TestWorkflows are Git-based production-scenario validations for the
third-party images maintained in this repository. They run through the
Testkube HTTP API; they do not merely probe a service port.

## MongoDB upgrade validation

`mongodb-upgrade-validation` validates the MongoDB operations used by
Testkube's TestWorkflow execution repository:

| Testkube operation | Validation action |
| --- | --- |
| TestWorkflow read | Create the fixture CR and retrieve it through `GET /v1/test-workflows/{name}`. |
| Execution create | Start it through `POST /v1/test-workflows/{name}/executions`. |
| Execution read | Poll `GET /v1/test-workflow-executions/{id}` until it passes. |
| Execution list/aggregation | Query `GET /v1/test-workflows/{name}/executions` and locate the pre-upgrade execution. |
| Persistence | Upgrade the MongoDB workload in place, retaining its PVC, then read the original execution and create/complete another one. |

The underlying repository performs inserts, replacements/updates, deletes,
finds, and aggregation pipelines for TestWorkflow executions. The validation
focuses on the production API paths that exercise those operations rather than
writing directly to MongoDB.

The candidate image must already exist in GAR. The workflow intentionally
requires its full location as separate Helm image registry and repository
values, so it cannot silently validate a Docker Hub image instead.

Apply and run the workflow in each target installation, supplying the actual
release/workload shape:

```sh
kubectl apply -f test/mongodb-upgrade-validation.yaml -n testkube

# OSS example (the MongoDB chart defaults to a Deployment).
testkube run tw mongodb-upgrade-validation \
  --config namespace=testkube \
  --config apiURL=http://testkube-api-server.testkube.svc.cluster.local:8088 \
  --config mongodbRelease=testkube-mongodb \
  --config mongodbWorkloadKind=deployment \
  --config mongodbWorkloadName=testkube-mongodb \
  --config gitRevision=COMMIT_SHA_BEING_VALIDATED \
  --config imageRegistry=us-east1-docker.pkg.dev \
  --config imageRepository=testkube-cloud-372110/testkube/mongodb \
  --config baselineTag=9.0.2 \
  --config candidateTag=REPLACED_BY_PR_VERSION
```

For Enterprise, run the same workflow against that installation's API service
and set `mongodbRelease`/`mongodbWorkloadName` to
`testkube-enterprise-mongodb`. Use `statefulset` only when the installed chart
uses `useStatefulSet=true`; otherwise use `deployment`.

## PR gating

An upgrade PR must build and publish its immutable candidate tag to GAR before
this workflow is dispatched for both an OSS and an Enterprise validation
installation. The PR is eligible to merge only when both executions pass.
This ordering is essential: a candidate that exists only on Docker Hub does not
validate the GAR artifact that production pulls.

`mongodb-gar-upgrade-validation.yaml` runs this PR gate on dev GKE. Configure
these repository/environment secrets before enabling it:

| Secret | Purpose |
| --- | --- |
| `DEV_GKE_CLUSTER_NAME`, `DEV_GKE_LOCATION`, `GKE_PROJECT` | The dev GKE cluster connection. |

The job requires `GAR_LOCATION`, `GCP_PROJECT_ID_PROD`, `GKE_SA_KEY_PROD`,
`GKE_WORKLOAD_IDENTITY_PROVIDER`, `GKE_SERVICE_ACCOUNT_EMAIL`,
`DEV_GKE_CLUSTER_NAME`, `DEV_GKE_LOCATION`, and `GKE_PROJECT` secrets. It
installs the latest published OSS Testkube chart and runs the TestWorkflow from
that same isolated namespace. The workload-identity service account must
create namespaces and install Helm releases; the TestWorkflow service account
must upgrade MongoDB in its own isolated namespace.

For OSS, the job creates one namespace per run, installs `testkube-mongodb` at
the baseline GAR tag, and installs the Testkube chart with its bundled MongoDB
disabled and `testkube-api.mongodb.dsn` set to the external service. The
TestWorkflow is applied and executed by that same Testkube installation. It
deletes the namespace after the validation regardless of the result.

The Testkube Helm release name is unique per run. This prevents the chart's
required cluster-scoped `crd-reader-<release>` RBAC object from colliding with
an existing Testkube or Enterprise installation. No CRDs are installed by this
validation job.

To test an open PR manually, open **Actions → MongoDB GAR Upgrade
Validation → Run workflow**, choose the PR branch, set `baseline_ref` to the
branch it targets (normally `main`), and provide its `pr_number`. This builds
the selected branch and compares it with the specified baseline.

The remaining services need equivalent API-level scenarios before they can be
added to this gate. Each must document the actual Testkube operation it covers,
the API assertion, and its OSS/Enterprise release-specific inputs:

| Service | Testkube-facing scenario to validate |
| --- | --- |
| MinIO / SeaweedFS | Upload, list, download, and persist TestWorkflow artifacts. |
| PostgreSQL | Create, read, list, and persist TestWorkflow executions when PostgreSQL is selected. |
| NATS | Submit an execution and verify it is scheduled and reaches a terminal state. |
| Dex | Complete the Enterprise login/token refresh path used by the API/UI. |
| kubectl | Run a Kubernetes executor workflow that creates, reads, and removes its fixture resource. |
