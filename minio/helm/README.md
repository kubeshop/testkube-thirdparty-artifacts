# minio

![Version: 2025.10-0](https://img.shields.io/badge/Version-2025.10--0-informational?style=flat-square) ![AppVersion: 2025.10](https://img.shields.io/badge/AppVersion-2025.10-informational?style=flat-square)

Testkube helm chart to deploy Minio instance needed to store artifacts generated on Testkube platform (based on Minio Bitnami helm chart).

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Testkube | <support@testkube.io> | <https://github.com/kubeshop/testkube-thirdparty-artifacts> |

## Source Code

* <https://github.com/kubeshop/testkube-thirdparty-artifacts/tree/main/minio>
* <https://min.io>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../../common | common | 2.26.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| apiIngress.annotations | object | `{}` |  |
| apiIngress.apiVersion | string | `""` |  |
| apiIngress.enabled | bool | `false` |  |
| apiIngress.extraHosts | list | `[]` |  |
| apiIngress.extraPaths | list | `[]` |  |
| apiIngress.extraRules | list | `[]` |  |
| apiIngress.extraTls | list | `[]` |  |
| apiIngress.hostname | string | `"minio.local"` |  |
| apiIngress.ingressClassName | string | `""` |  |
| apiIngress.path | string | `"/"` |  |
| apiIngress.pathType | string | `"ImplementationSpecific"` |  |
| apiIngress.secrets | list | `[]` |  |
| apiIngress.selfSigned | bool | `false` |  |
| apiIngress.servicePort | string | `"minio-api"` |  |
| apiIngress.tls | bool | `false` |  |
| args | list | `[]` |  |
| auth.existingSecret | string | `""` |  |
| auth.forceNewKeys | bool | `false` |  |
| auth.forcePassword | bool | `false` |  |
| auth.rootPassword | string | `""` |  |
| auth.rootPasswordSecretKey | string | `""` |  |
| auth.rootUser | string | `"admin"` |  |
| auth.rootUserSecretKey | string | `""` |  |
| auth.useCredentialsFiles | bool | `false` |  |
| auth.useSecret | bool | `true` |  |
| automountServiceAccountToken | bool | `false` |  |
| clientImage.digest | string | `""` |  |
| clientImage.registry | string | `"us-east1-docker.pkg.dev"` |  |
| clientImage.repository | string | `"testkube-cloud-372110/testkube/minio"` |  |
| clientImage.tag | float | `2025.1` |  |
| clusterDomain | string | `"cluster.local"` |  |
| command | list | `[]` |  |
| commonAnnotations | object | `{}` |  |
| commonLabels | object | `{}` |  |
| containerPorts.api | int | `9000` |  |
| containerPorts.console | int | `9001` |  |
| containerSecurityContext.allowPrivilegeEscalation | bool | `false` |  |
| containerSecurityContext.capabilities.drop[0] | string | `"ALL"` |  |
| containerSecurityContext.enabled | bool | `true` |  |
| containerSecurityContext.privileged | bool | `false` |  |
| containerSecurityContext.readOnlyRootFilesystem | bool | `true` |  |
| containerSecurityContext.runAsGroup | int | `1001` |  |
| containerSecurityContext.runAsNonRoot | bool | `true` |  |
| containerSecurityContext.runAsUser | int | `1001` |  |
| containerSecurityContext.seLinuxOptions | object | `{}` |  |
| containerSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| customLivenessProbe | object | `{}` |  |
| customReadinessProbe | object | `{}` |  |
| customStartupProbe | object | `{}` |  |
| defaultBuckets | string | `""` |  |
| deployment.updateStrategy.type | string | `"Recreate"` |  |
| disableWebUI | bool | `false` |  |
| extraDeploy | list | `[]` |  |
| extraEnvVars | list | `[]` |  |
| extraEnvVarsCM | string | `""` |  |
| extraEnvVarsSecret | string | `""` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| global.compatibility.openshift.adaptSecurityContext | string | `"auto"` |  |
| global.containerSecurityContext | object | `{}` |  |
| global.defaultStorageClass | string | `""` |  |
| global.imagePullSecrets | list | `[]` |  |
| global.imageRegistry | string | `""` |  |
| global.podDisruptionBudget | object | `{"enabled":false}` | Global PodDisruptionBudget |
| global.podSecurityContext | object | `{}` |  |
| global.storageClass | string | `""` |  |
| hostAliases | list | `[]` |  |
| image.debug | bool | `false` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.pullSecrets | list | `[]` |  |
| image.registry | string | `"us-east1-docker.pkg.dev"` |  |
| image.repository | string | `"testkube-cloud-372110/testkube/minio"` |  |
| image.tag | float | `2025.1` |  |
| ingress.annotations | object | `{}` |  |
| ingress.apiVersion | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.extraHosts | list | `[]` |  |
| ingress.extraPaths | list | `[]` |  |
| ingress.extraRules | list | `[]` |  |
| ingress.extraTls | list | `[]` |  |
| ingress.hostname | string | `"minio.local"` |  |
| ingress.ingressClassName | string | `""` |  |
| ingress.path | string | `"/"` |  |
| ingress.pathType | string | `"ImplementationSpecific"` |  |
| ingress.secrets | list | `[]` |  |
| ingress.selfSigned | bool | `false` |  |
| ingress.servicePort | string | `"minio-console"` |  |
| ingress.tls | bool | `false` |  |
| initContainers | list | `[]` |  |
| kubeVersion | string | `""` |  |
| lifecycleHooks | object | `{}` |  |
| livenessProbe.enabled | bool | `true` |  |
| livenessProbe.failureThreshold | int | `5` |  |
| livenessProbe.initialDelaySeconds | int | `5` |  |
| livenessProbe.periodSeconds | int | `5` |  |
| livenessProbe.successThreshold | int | `1` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| metrics.enabled | bool | `false` |  |
| metrics.prometheusAuthType | string | `"public"` |  |
| metrics.prometheusRule.additionalLabels | object | `{}` |  |
| metrics.prometheusRule.enabled | bool | `false` |  |
| metrics.prometheusRule.namespace | string | `""` |  |
| metrics.prometheusRule.rules | list | `[]` |  |
| metrics.serviceMonitor.apiVersion | string | `""` |  |
| metrics.serviceMonitor.enabled | bool | `false` |  |
| metrics.serviceMonitor.honorLabels | bool | `false` |  |
| metrics.serviceMonitor.interval | string | `"30s"` |  |
| metrics.serviceMonitor.jobLabel | string | `""` |  |
| metrics.serviceMonitor.labels | object | `{}` |  |
| metrics.serviceMonitor.metricRelabelings | list | `[]` |  |
| metrics.serviceMonitor.namespace | string | `""` |  |
| metrics.serviceMonitor.paths[0] | string | `"/minio/v2/metrics/cluster"` |  |
| metrics.serviceMonitor.paths[1] | string | `"/minio/v2/metrics/node"` |  |
| metrics.serviceMonitor.relabelings | list | `[]` |  |
| metrics.serviceMonitor.scrapeTimeout | string | `""` |  |
| metrics.serviceMonitor.selector | object | `{}` |  |
| metrics.serviceMonitor.tlsConfig | object | `{}` |  |
| mode | string | `"standalone"` |  |
| nameOverride | string | `""` |  |
| namespaceOverride | string | `""` |  |
| networkPolicy.allowExternal | bool | `true` |  |
| networkPolicy.allowExternalEgress | bool | `true` |  |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.extraEgress | list | `[]` |  |
| networkPolicy.extraIngress | list | `[]` |  |
| networkPolicy.ingressNSMatchLabels | object | `{}` |  |
| networkPolicy.ingressNSPodMatchLabels | object | `{}` |  |
| nodeAffinityPreset.key | string | `""` |  |
| nodeAffinityPreset.type | string | `""` |  |
| nodeAffinityPreset.values | list | `[]` |  |
| nodeSelector | object | `{}` |  |
| pdb.create | bool | `true` |  |
| pdb.maxUnavailable | string | `""` |  |
| pdb.minAvailable | string | `""` |  |
| persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `true` |  |
| persistence.existingClaim | string | `""` |  |
| persistence.mountPath | string | `"/home/minio-user/data"` |  |
| persistence.selector | object | `{}` |  |
| persistence.size | string | `"8Gi"` |  |
| persistence.storageClass | string | `""` |  |
| podAffinityPreset | string | `""` |  |
| podAnnotations | object | `{}` |  |
| podAntiAffinityPreset | string | `"soft"` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.enabled | bool | `true` |  |
| podSecurityContext.fsGroup | int | `1001` |  |
| podSecurityContext.fsGroupChangePolicy | string | `"OnRootMismatch"` |  |
| podSecurityContext.supplementalGroups | list | `[]` |  |
| podSecurityContext.sysctls | list | `[]` |  |
| priorityClassName | string | `""` |  |
| provisioning.args | list | `[]` |  |
| provisioning.buckets | list | `[]` |  |
| provisioning.cleanupAfterFinished.enabled | bool | `false` |  |
| provisioning.cleanupAfterFinished.seconds | int | `600` |  |
| provisioning.command | list | `[]` |  |
| provisioning.config | list | `[]` |  |
| provisioning.containerSecurityContext.allowPrivilegeEscalation | bool | `false` |  |
| provisioning.containerSecurityContext.capabilities.drop[0] | string | `"ALL"` |  |
| provisioning.containerSecurityContext.enabled | bool | `true` |  |
| provisioning.containerSecurityContext.privileged | bool | `false` |  |
| provisioning.containerSecurityContext.readOnlyRootFilesystem | bool | `true` |  |
| provisioning.containerSecurityContext.runAsGroup | int | `1001` |  |
| provisioning.containerSecurityContext.runAsNonRoot | bool | `true` |  |
| provisioning.containerSecurityContext.runAsUser | int | `1001` |  |
| provisioning.containerSecurityContext.seLinuxOptions | object | `{}` |  |
| provisioning.containerSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| provisioning.enabled | bool | `false` |  |
| provisioning.extraCommands | list | `[]` |  |
| provisioning.extraVolumeMounts | list | `[]` |  |
| provisioning.extraVolumes | list | `[]` |  |
| provisioning.groups | list | `[]` |  |
| provisioning.networkPolicy.allowExternalEgress | bool | `true` |  |
| provisioning.networkPolicy.enabled | bool | `true` |  |
| provisioning.networkPolicy.extraEgress | list | `[]` |  |
| provisioning.networkPolicy.extraIngress | list | `[]` |  |
| provisioning.nodeSelector | object | `{}` |  |
| provisioning.podAnnotations | object | `{}` |  |
| provisioning.podLabels | object | `{}` |  |
| provisioning.podSecurityContext.enabled | bool | `true` |  |
| provisioning.podSecurityContext.fsGroup | int | `1001` |  |
| provisioning.podSecurityContext.fsGroupChangePolicy | string | `"Always"` |  |
| provisioning.podSecurityContext.supplementalGroups | list | `[]` |  |
| provisioning.podSecurityContext.sysctls | list | `[]` |  |
| provisioning.policies | list | `[]` |  |
| provisioning.resources | object | `{}` |  |
| provisioning.resourcesPreset | string | `"nano"` |  |
| provisioning.schedulerName | string | `""` |  |
| provisioning.users | list | `[]` |  |
| provisioning.usersExistingSecrets | list | `[]` |  |
| readinessProbe.enabled | bool | `true` |  |
| readinessProbe.failureThreshold | int | `5` |  |
| readinessProbe.initialDelaySeconds | int | `5` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| readinessProbe.successThreshold | int | `1` |  |
| readinessProbe.timeoutSeconds | int | `1` |  |
| resources | object | `{}` |  |
| resourcesPreset | string | `"micro"` |  |
| runtimeClassName | string | `""` |  |
| schedulerName | string | `""` |  |
| service.annotations | object | `{}` |  |
| service.clusterIP | string | `""` |  |
| service.externalTrafficPolicy | string | `"Cluster"` |  |
| service.extraPorts | list | `[]` |  |
| service.headless.annotations | object | `{}` |  |
| service.loadBalancerIP | string | `""` |  |
| service.loadBalancerSourceRanges | list | `[]` |  |
| service.nodePorts.api | string | `""` |  |
| service.nodePorts.console | string | `""` |  |
| service.ports.api | int | `9000` |  |
| service.ports.console | int | `9001` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automountServiceAccountToken | bool | `false` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| sidecars | list | `[]` |  |
| startupProbe.enabled | bool | `false` |  |
| startupProbe.failureThreshold | int | `60` |  |
| startupProbe.initialDelaySeconds | int | `0` |  |
| startupProbe.periodSeconds | int | `10` |  |
| startupProbe.successThreshold | int | `1` |  |
| startupProbe.timeoutSeconds | int | `5` |  |
| statefulset.drivesPerNode | int | `1` |  |
| statefulset.podManagementPolicy | string | `"Parallel"` |  |
| statefulset.replicaCount | int | `4` |  |
| statefulset.updateStrategy.type | string | `"RollingUpdate"` |  |
| statefulset.zones | int | `1` |  |
| terminationGracePeriodSeconds | string | `""` |  |
| tls.autoGenerated | bool | `false` |  |
| tls.enabled | bool | `false` |  |
| tls.existingSecret | string | `""` |  |
| tls.mountPath | string | `""` |  |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` |  |
| volumePermissions.containerSecurityContext.runAsUser | int | `0` |  |
| volumePermissions.containerSecurityContext.seLinuxOptions | object | `{}` |  |
| volumePermissions.enabled | bool | `false` |  |
| volumePermissions.image.digest | string | `""` |  |
| volumePermissions.image.pullPolicy | string | `"IfNotPresent"` |  |
| volumePermissions.image.pullSecrets | list | `[]` |  |
| volumePermissions.image.registry | string | `"docker.io"` |  |
| volumePermissions.image.repository | string | `"bitnami/os-shell"` |  |
| volumePermissions.image.tag | string | `"12-debian-12-r32"` |  |
| volumePermissions.resources | object | `{}` |  |
| volumePermissions.resourcesPreset | string | `"nano"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
