# Replacing Minio image and helm chart

## Using official image and helm chart

Artifacts to test:

* Official image: https://hub.docker.com/r/minio/minio
* Official helm chart: https://github.com/minio/operator/tree/master/helm

### Testkube Enterprise

Versions tested:

* [2.325.0](https://console.cloud.google.com/artifacts/docker/testkube-cloud-372110/us-east1/testkube/testkube-enterprise/sha256:269069768a5d38ad8fa4f431d32d1cd37379a45eacbe6dfa3d37e0f0d8c7e8fa?inv=1&invt=Abp0OQ&project=testkube-cloud-372110&supportedpurview=project).
* [2.324.9](https://console.cloud.google.com/artifacts/docker/testkube-cloud-372110/us-east1/testkube/testkube-enterprise/sha256:1b100d4779503afc4a93c89cbc74809b56b48d4022fbe7325f3db4cd90bf4c93?inv=1&invt=Abp0OQ&project=testkube-cloud-372110&supportedpurview=project).

Steps used to test:

1. Pull latest published Testkube Enteprise helm chart:

   ```bash
   for version in 2.325.0 2.324.9; do
   helm pull oci://us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/testkube-enterprise --version $version --untar -d charts/tke-$version
   done
   ```

2. Prepare `values.demo.yaml` [file](https://github.com/kubeshop/testkube-cloud-api/blob/main/helm/values.demo.yaml) with Minio image version:

   ```bash
   curl https://raw.githubusercontent.com/kubeshop/testkube-cloud-api/refs/heads/main/helm/values.demo.yaml?token=[YOUR_TOKEN] -o values.demo.yaml
   ```

   Lines to change into the `values.demo.yaml`:

   ```yaml
    minio:
      enabled: false
   ```

   Copy from the Testkube Enterprise helm chart, from the file `values.yaml`, 2 main properties: `global` and `minio` into a new file `minio.values.yaml`.

3. Deploy and test:

   ```bash
   tilt up
   ```

   Navigate to <http://localhost:8080> and run Testkube regression test.

### Testkube OSS

Versions tested:

* [2.3.0](https://console.cloud.google.com/artifacts/docker/testkube-cloud-372110/us-east1/testkube/testkube/sha256:ae338a5125b9f5791652360be1602207203b3bd0fea41c7bf937fe2b13f80111?inv=1&invt=Abp0OQ&project=testkube-cloud-372110&supportedpurview=project).
* [2.2.13](https://console.cloud.google.com/artifacts/docker/testkube-cloud-372110/us-east1/testkube/testkube/sha256:9154e9dd8e92b6cf5a3e1dc31bdd7168dd36895e9884737b41ecf851773f0da4?inv=1&invt=Abp0OQ&project=testkube-cloud-372110&supportedpurview=project).

Steps used to test:

1. Pull latest published Testkube Enteprise helm chart:

   ```bash
   for version in 2.3.0 2.2.13; do
   helm pull oci://us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/testkube --version $version --untar -d charts/tkoss-$version
   done
   ```
