# Replacing Minio image and helm chart

## Testkube Enterprise

Steps used to test:

1. Pull latest published Testkube Enteprise helm chart:

   ```bash
   export VERSION="2.325.0"
   helm pull oci://us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/testkube-enterprise --version $VERSION --untar -d charts/tke-$VERSION
   ```

2. Prepare `values.demo.yaml` [file](https://github.com/kubeshop/testkube-cloud-api/blob/main/helm/values.demo.yaml) with Minio image version:

   ```bash
   curl https://raw.githubusercontent.com/kubeshop/testkube-cloud-api/refs/heads/main/helm/values.demo.yaml?token=[YOUR_TOKEN] -o minio/values.demo.yaml
   ```

   Lines to change into the `minio/values.demo.yaml`:

   ```yaml
    minio:
      enabled: false
   ```

   Copy from the Testkube Enterprise helm chart, from the file `values.yaml`, 2 main properties: `global` (as global) and `minio` (in the root) into a new file `minio.values.yaml`. Finally ensure property `image` is like in this example:

   ```yaml
   global:
     enterpriseMode: true
     (...)
   fullnameOverride: &minioFullnameOverride testkube-enterprise-minio
   (...)
   image:
     registry: null
     repository: testkube/minio
     tag: latest
   (...)
   ```

3. Deploy and test:

   ```bash
   cd minio
   tilt up -f enterprise.tiltfile
   ```

   Navigate to <http://localhost:8080> and run Testkube regression test.

To clean up run the following commands:

```bash
tilt down -f enterprise.tiltfile
tilt docker-prune -f enterprise.tiltfile
```

To test Minio in cluster change in the `minio.values.yaml` the property:

```yaml
mode: distributed # By default is: standalone
```

## Testkube OSS

Steps used to test:

1. Pull latest published Testkube Enteprise helm chart:

   ```bash
   for version in 2.4.0; do
   helm pull oci://us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/testkube --version $version --untar -d charts/tkoss-$version
   done
   ```

2. Start tilt to deploy local Minio image and chart with each selected Testkube version:

   ```bash
   tilt up -f oss.tiltfile
   ```

To clean up run the following commands:

```bash
tilt down -f oss.tiltfile
tilt docker-prune -f oss.tiltfile
```
