# Motor Desk Infrastructure

Infrastructure as Code and deployment automation for the [Motor Desk application](https://github.com/1ChristianAlex/motordesk). This repository owns the AWS Terraform configuration, Kubernetes workloads, Helm installers, and reusable GitHub Actions workflows. Application source code and the API Dockerfile remain in the application repository.

> **Operational warning:** Terraform plans and applies can create or modify billable AWS resources. Always review the plan, target account, region, environment, and recovery requirements before applying changes. A successful validation workflow does not provision infrastructure or confirm a live deployment.

## Architecture at a glance

Terraform provisions the AWS foundations for `dev`, `qa`, and `prod`, including VPC networking, EKS, ECR, PostgreSQL, Redis, EFS for MongoDB, IAM, Secrets Manager, Systems Manager Parameter Store, and the API's AWS integrations. ACM, Route 53, and ExternalDNS are used for a custom API domain when configured. The API is exposed through an AWS Load Balancer Controller-managed ALB and AWS WAF.

Kubernetes YAML deploys the Motor Desk API and a single-replica MongoDB StatefulSet. Helm installs the EKS add-ons, including External Secrets Operator, Metrics Server, AWS Load Balancer Controller, Cluster Autoscaler, and New Relic Kubernetes observability. PostgreSQL is the transactional database; Redis Streams is transport for asynchronous work; MongoDB stores Service Order history. MongoDB uses EFS and is **not highly available**.

```text
GitHub Actions
├── Application repository (motordesk)
│   ├── Kotlin/Ktor source and Gradle build
│   └── infra/docker/Dockerfile
└── Infrastructure repository (this repository)
    ├── terraform/aws/       AWS resources and per-environment state roots
    ├── kubernetes/          Kubernetes manifests and Helm installers
    └── .github/workflows/   CI and reusable infrastructure workflows
```

## Repository layout

| Path | Purpose |
|---|---|
| `terraform/aws/backend/` | One-time S3 Terraform state bucket bootstrap. |
| `terraform/aws/envs/dev/` | Development Terraform root and state. The root currently labels its module resources `dev-cli`. |
| `terraform/aws/envs/qa/` | QA Terraform root and state. |
| `terraform/aws/envs/prod/` | Production Terraform root and state. |
| `terraform/aws/modules/application/` | Shared AWS networking, EKS, databases, storage, IAM, secrets, and API edge resources. |
| `terraform/secret-cookbook.md` | Notes and examples for application secret configuration. |
| `kubernetes/base/` | API, MongoDB, ingress, storage, configuration, and environment-specific workload manifests. |
| `kubernetes/helm/` | Helm installers and pinned chart versions. |
| `kubernetes/newrelic/` | New Relic Helm values and operational notes. |
| `.github/scripts/` | Kubernetes YAML validation script. |
| `.github/workflows/` | CI, Terraform/Kubernetes validation, and reusable EKS deployment workflows. |

## Prerequisites

For local Terraform validation or planning:

- Terraform CLI `1.10.0` or later;
- Bun and Helm when running the complete Kubernetes/New Relic validation locally;
- AWS credentials for the intended account and permissions to read the selected state and inspect the planned resources;
- an existing Terraform state S3 bucket for the selected environment;
- a verified SES sender address when planning an environment;
- Bash for the Kubernetes script syntax checks.

The GitHub Actions workflows install or use their own tools. The validation workflow uses Terraform `1.10.0`, Bun, and Helm `v3.16.4`; the deployment workflow also uses AWS CLI, Docker, `kubectl` `v1.35.0`, `envsubst`, and `curl` on an Ubuntu runner.

## Terraform state and local workflow

Each environment uses a separate key in the remote S3 state bucket and native S3 state locking. The bucket must exist before an environment root can be initialized. Bootstrap it once with the backend root, using a globally unique bucket name and AWS credentials for the intended account:

```bash
export AWS_REGION=us-east-2
export STATE_BUCKET=replace-with-a-globally-unique-bucket-name

terraform -chdir=terraform/aws/backend init -backend=false -input=false
terraform -chdir=terraform/aws/backend plan -input=false \
  -var="aws_region=$AWS_REGION" \
  -var="state_bucket_name=$STATE_BUCKET"
terraform -chdir=terraform/aws/backend apply -input=false \
  -var="aws_region=$AWS_REGION" \
  -var="state_bucket_name=$STATE_BUCKET"
```

The bucket configuration enables versioning, server-side encryption, public-access blocking, and a TLS-only bucket policy. Keep Terraform state private: it can contain sensitive infrastructure data. Do not commit state, plans, credentials, or `.tfvars` files.

After the bucket exists, initialize and plan an environment. Set `SES_FROM_ADDRESS` to an identity verified in SES in the selected account and region:

```bash
export AWS_REGION=us-east-2
export STATE_BUCKET=replace-with-your-state-bucket
export SES_FROM_ADDRESS=verified-sender@example.com

terraform -chdir=terraform/aws/envs/dev init -input=false \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="region=$AWS_REGION"
terraform -chdir=terraform/aws/envs/dev plan -input=false \
  -var="aws_region=$AWS_REGION" \
  -var="terraform_state_bucket=$STATE_BUCKET" \
  -var="ses_from_address=$SES_FROM_ADDRESS"
```

Replace `dev` with `qa` or `prod` to select another root. Optional custom-domain variables are `api_domain_name` and `route53_zone_id`; the automated deployment currently expects these values to be supplied as GitHub variables. Review and apply Terraform only from an authorized account and environment. Production changes require particular care: inspect the plan, backup/recovery status, and database impact before proceeding.

## Validation

The `Terraform AWS Validation` workflow runs on infrastructure pull requests and pushes to `dev` or `main`, and can also be called by another workflow. It checks Terraform formatting and validates all three environment roots, parses Kubernetes YAML, checks deployment script syntax, and lints/renders the pinned New Relic chart.

Run the local checks that do not require AWS credentials with:

```bash
terraform -chdir=terraform/aws fmt -check -recursive
bun .github/scripts/validate-kubernetes-yaml.js
bash -n kubernetes/deploy-workloads.sh
bash -n kubernetes/helm/install-addons.sh
bash -n kubernetes/helm/install-newrelic.sh
```

To validate Terraform configuration locally without accessing the remote backend, initialize each root with `-backend=false` and run `terraform validate`:

```bash
for environment in dev qa prod; do
  root="terraform/aws/envs/$environment"
  terraform -chdir="$root" init -backend=false -input=false
  terraform -chdir="$root" validate -no-color
done
```

The GitHub workflow additionally downloads the New Relic chart to run `helm lint` and `helm template`. These checks validate configuration, not AWS account quotas, permissions, a Terraform apply, or the readiness of a live cluster.

## CI and deployment workflows

### CI Tests

`ci-tests.yml` is reusable by the application repository. When called, the caller's checkout is used for the Gradle test and build steps; those commands run against the Kotlin project, not this repository's infrastructure files.

### Deploy EKS Runtime

The application repository manually dispatches the deployment workflow and calls `deploy-eks.yml` from this repository. The reusable workflow checks out the application source into the workspace and this infrastructure repository into `infrastructure/`. It always creates and displays a Terraform plan. When `confirm_apply` is enabled, it applies that plan, builds and pushes an immutable API image from the application repository, installs Helm add-ons, and applies Kubernetes workloads.

`confirm_data_cutover` must also be enabled before an apply can proceed. Treat it as an explicit operator confirmation of the required EFS recovery point and maintenance window, not as an automated backup or restore verification. Deployment runs are serialized per environment by the concurrency group in the reusable workflow; callers must not declare the same group, which can deadlock a reusable workflow.

### GitHub configuration

The caller's GitHub Environments (`dev`, `qa`, `prod`) must provide the values and secrets expected by the deployment workflow. Configure them in GitHub; never put credentials in this README, workflow files, Terraform variables committed to the repository, or Kubernetes manifests.

| Type | Name | Used for |
|---|---|---|
| Environment variable | `AWS_REGION` | AWS region for Terraform and deployment. |
| Environment variable | `AWS_TF_BACKEND_BUCKET` | Existing S3 bucket holding Terraform state. |
| Environment variable | `API_DOMAIN_NAME` | API DNS name passed to the environment deployment. |
| Environment variable | `ROUTE53_ZONE_ID` | Route 53 hosted zone ID passed to the environment deployment. |
| Environment variable | `SES_FROM_ADDRESS` | Verified sender identity for SES. |
| Secret | `AWS_ACCESS_KEY_ID` | AWS deployment credentials expected by the current workflow. |
| Secret | `AWS_SECRET_ACCESS_KEY` | AWS deployment credentials expected by the current workflow. |
| Secret | `NEW_RELIC_LICENSE_KEY` | Application observability credential. |
| Secret | `NEW_RELIC_EKS_LICENSE_KEY` | New Relic Kubernetes integration credential. |

The reusable deployment workflow validates that the AWS region, state bucket, domain, hosted-zone ID, and both New Relic secrets are non-empty. Its inputs also require a verified SES sender. Configure these values for every GitHub Environment used by a deployment. The exact IAM policy attached to the AWS credentials must permit the plan/apply and deployment operations required for that environment.

## Security and operations

- Never commit AWS access keys, New Relic license keys, application credentials, Terraform state, plan files, or environment-specific `.tfvars` files.
- Terraform generates application secrets and stores them in AWS Secrets Manager or Parameter Store. External Secrets Operator synchronizes the required values into Kubernetes; manifests should reference Secrets, not embed credential values.
- Keep AWS permissions scoped to the intended environment and resources. The current workflow accepts AWS access keys through GitHub Secrets; protect those secrets with GitHub Environment access controls and rotate them according to the organization's policy.
- MongoDB runs as one Kubernetes replica on EFS. A persistent volume is not a substitute for a tested backup and recovery procedure; never start two MongoDB writers against the same EFS data directory.
- Review resource costs and service quotas before provisioning. EKS nodes, NAT gateways, ALBs, RDS, ElastiCache, EFS, and observability ingestion can incur ongoing charges.
- Helm chart versions are pinned in `kubernetes/helm/versions.env`; review upstream release notes and validate compatibility before changing them.

## Related documentation

- [New Relic Kubernetes observability](kubernetes/newrelic/README.md)
- [Terraform secret cookbook](terraform/secret-cookbook.md)
- [Motor Desk application and domain documentation](https://github.com/1ChristianAlex/motordesk)
- [ADR-011 — Separating application and infrastructure repositories](https://github.com/1ChristianAlex/motordesk/blob/main/docs/ADR/ADR-011-GitHub-Actions-Infrastructure-Repository.md)