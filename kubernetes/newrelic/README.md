# New Relic Kubernetes observability

MotorDesk installs New Relic's official `newrelic/nri-bundle` Helm chart alongside the existing AWS observability
components. Helm release `newrelic-kubernetes` runs in namespace `newrelic`. The chart version is pinned in
`../helm/versions.env` (`8.0.40`); the shared values file is `values.yaml`. The install script obtains the cluster name
from the selected environment's Terraform output, so the same configuration works for `dev`, `qa`, and `prod`.

## Components and telemetry ownership

| Component | Setting | Purpose |
|---|---|---|
| New Relic infrastructure integration | Enabled | Node, kubelet, pod, workload and cluster resource metrics on EC2 nodes |
| Bundled kube-state-metrics | Enabled | Kubernetes object state metrics; no other KSM deployment exists in this repository |
| Kubernetes events integration | Enabled | Sends events only; resource-description scraping is disabled |
| Low-data mode | Enabled | Uses reduced metric volume for the current small 2–4-node cluster |
| Prometheus integration | Disabled | No Prometheus server or scrape targets are configured |
| Metadata injection | Disabled | Avoids mutating application pods; backend telemetry remains OpenTelemetry-first |
| New Relic logging | Disabled | Prevents a second container-log collector |
| Fargate support | Disabled | Terraform defines EC2 managed node groups and no Fargate profile |
| Control-plane scraping | Disabled | EKS control plane is AWS-managed; its existing logs remain in CloudWatch |

Kube-state-metrics exports only the selected Kubernetes name labels, not arbitrary labels or annotations. Component resource
requests and limits are set for the small node group; revisit them if cluster size or workload density increases. No custom
node selector, broad toleration, privileged override, or application instrumentation is added.
New Relic's optional AWS cluster-ID lookup is disabled, so the agents do not need AWS API permissions; the configured EKS
cluster name remains the telemetry cluster identifier.

The responsibilities remain distinct:

- **OpenTelemetry** instruments the Kotlin/Ktor backend and continues exporting its existing OTLP telemetry. This
  installation does not add an APM agent or duplicate application traces.
- **New Relic Kubernetes integration** reports infrastructure metrics and Kubernetes events to New Relic.
- **CloudWatch Observability EKS add-on** remains the Kubernetes/control-plane log collection path to CloudWatch.
- **New Relic platform** is the destination for Kubernetes infrastructure telemetry and existing backend OTLP telemetry.

Do not enable `newrelic-logging` unless a reviewed log-forwarding design prevents duplicate collection, filters sensitive
fields before export and preserves structured JSON plus trace/span correlation. Application secrets and personal data must
not be emitted as telemetry. The Terraform control-plane log group has 30-day retention; this module does not set
retention for CloudWatch container log groups, so verify their retention in each AWS account. New Relic data retention and
ingestion charges depend on the account plan and enabled telemetry.

## GitHub secret and deployment

An authorized repository or GitHub Environment administrator must configure the non-empty
`NEW_RELIC_EKS_LICENSE_KEY` secret. The workflow never retrieves or generates it. For environment-level secrets, configure
it in each of `dev`, `qa`, and `prod`; a repository secret can be used where the organization's policy allows it. The
existing `NEW_RELIC_LICENSE_KEY` for the backend OTLP configuration is separate and is not changed by this integration.

When `Deploy EKS Runtime` is dispatched with `confirm_apply=true`, the workflow:

1. Authenticates with the existing AWS credentials and selects the EKS cluster from the environment's Terraform output.
2. Adds/updates the official `https://helm-charts.newrelic.com` repository.
3. Creates namespace `newrelic` if needed.
4. Creates or updates Secret `newrelic-license`, data key `license-key`, piping the GitHub secret through standard input.
5. Runs `helm upgrade --install` for the fixed release and chart version using the environment's actual EKS cluster name.

The script disables shell tracing before reading the secret, does not pass its value as a command-line argument, and
removes it from the process environment before invoking Helm. The chart values reference the Kubernetes Secret by name and
key; they contain no credentials. Terraform configures KMS encryption for EKS Kubernetes Secrets. The New Relic namespace
keeps this credential separate from application Secrets; do not grant application service accounts access to it.

The release is repeatable and upgrades use Helm's normal `upgrade --install` behavior. If readiness times out, the
installer prints the Helm status, pod/DaemonSet/deployment/job state, events and pod descriptions, then fails without
automatically uninstalling or rolling back the release. This preserves evidence for diagnosis. A subsequent workflow
run can retry the same release; after a failed upgrade of an existing release, inspect the reported state and roll back
to the last known-good Helm revision if needed before retrying. To upgrade intentionally, review the official chart's
release notes and values, change `NEW_RELIC_NRI_BUNDLE_CHART_VERSION`, update this values file only with settings
supported by that version, and run the Terraform AWS validation workflow before deploying through `Deploy EKS Runtime`.

## Validation and operations

The `Terraform AWS Validation` workflow runs Kubernetes YAML validation, shell syntax checks, `helm lint`, and
`helm template` against the pinned chart and values. For a live deployment, inspect the release and workloads without
printing Secret data:

```bash
helm status newrelic-kubernetes --namespace newrelic
kubectl get pods,daemonsets,deployments --namespace newrelic
kubectl get secret newrelic-license --namespace newrelic
kubectl get events --namespace newrelic --sort-by=.lastTimestamp
```

The Secret check confirms only its metadata; do not request or print `.data`. Helm readiness is a deployment check, not
proof that New Relic accepted the license or that telemetry is visible in the account. Confirm Kubernetes cluster/node
entities and events in New Relic after deployment. CloudWatch log ingestion should be checked separately in its existing
log groups.

For pods that fail to start, check `kubectl describe pod` and recent namespace events, then inspect only the affected
agent's logs for configuration or network errors. Do not include license-key fields or Secret output in support logs.
Verify that worker nodes can reach New Relic ingestion endpoints over HTTPS and that the correct account/region license
key was configured. Review agent resource pressure before increasing limits; low-data mode and the explicit label allowlist
are intended to control ingestion volume and metadata exposure.

If a failed install previously used Helm's `--atomic` cleanup and removed the resources, the retained namespace and
license Secret do not identify the readiness failure. Re-run the deployment with this diagnostic-enabled installer or
inspect the EKS cluster events and node capacity using an authorized Kubernetes context.

## Official references

- [Install the Kubernetes integration](https://docs.newrelic.com/install/kubernetes/)
- [Official New Relic Helm charts](https://github.com/newrelic/helm-charts)
- [`nri-bundle` chart documentation](https://github.com/newrelic/helm-charts/tree/master/charts/nri-bundle)
- [`nri-bundle` values](https://github.com/newrelic/helm-charts/blob/master/charts/nri-bundle/values.yaml)
