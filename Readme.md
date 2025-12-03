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
* [PostgreSQL](./postgres/).
* [Kubectl](./kubectl/).

## Automation overview

Every change starts in a feature branch where `.github/workflows/checks.yaml` builds candidate images with Depot and runs `helm lint` to validate the charts. Once merged to `main`, the trunk-based workflows take over: `.github/workflows/build-images.yaml` authenticates to Google Artifact Registry, generates Docker metadata, and publishes the Minio/MongoDB release images, while `.github/workflows/build-helm-charts.yaml` packages the corresponding Helm charts and pushes them to the OCI registry. Tag pushes (for example `minio-2025.10`) reuse the same pipelines but only build the target that matches the tag prefix and reuse the literal tag in the published image and chart versions. This keeps feature branch validation and trunk releases fully automated and consistent.

Allowed tags prefixes:

* minio-
* mongodb-

## Processes to manage artifacts into this repository

[TODO]

