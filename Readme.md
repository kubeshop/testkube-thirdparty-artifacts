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

## Processes to manage artifacts into this repository

[TO DO]