#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${EKS_KUBERNETES_VERSION:?EKS_KUBERNETES_VERSION is required}"
: "${EKS_VPC_ID:?EKS_VPC_ID is required}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.env"

helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

helm upgrade --install external-secrets external-secrets/external-secrets \
  --version "$EXTERNAL_SECRETS_CHART_VERSION" \
  --namespace external-secrets \
  --create-namespace \
  --set replicaCount=1 \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-secrets \
  --wait \
  --timeout 10m

if ! kubectl wait \
  --for=jsonpath='{.subsets[0].addresses[0].ip}' \
  endpoints/external-secrets-webhook \
  --namespace external-secrets \
  --timeout=5m; then
  echo "::error::External Secrets webhook has no ready endpoints; collecting diagnostics."
  kubectl get deployments,pods,services,endpoints -n external-secrets -o wide || true
  kubectl describe deployment external-secrets-webhook -n external-secrets || true
  kubectl logs deployment/external-secrets-webhook -n external-secrets --all-containers=true --tail=100 || true
  kubectl get events -n external-secrets --sort-by=.lastTimestamp | tail -n 40 || true
  exit 1
fi

helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "$METRICS_SERVER_CHART_VERSION" \
  --namespace kube-system \
  --wait \
  --timeout 10m

webhook_cert_hash=""
webhook_cert_data="$(
  kubectl get secret aws-load-balancer-tls --namespace kube-system \
    --ignore-not-found --output=jsonpath='{.data.ca\.crt}{.data.tls\.crt}'
)"
if [[ -n "$webhook_cert_data" ]]; then
  webhook_cert_hash="$(printf '%s' "$webhook_cert_data" | sha256sum | cut -d ' ' -f 1)"
fi
unset webhook_cert_data

lbc_helm_args=(
  --version "$AWS_LOAD_BALANCER_CONTROLLER_CHART_VERSION"
  --namespace kube-system
  --set "clusterName=$EKS_CLUSTER_NAME"
  --set "region=$AWS_REGION"
  --set "vpcId=$EKS_VPC_ID"
  --set serviceAccount.create=true
  --set serviceAccount.name=aws-load-balancer-controller
  --set keepTLSSecret=true
  --wait
  --timeout 10m
)
if [[ -n "$webhook_cert_hash" ]]; then
  lbc_helm_args+=(--set-string "podAnnotations.webhook-cert-sha256=$webhook_cert_hash")
fi
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  "${lbc_helm_args[@]}"

if ! kubectl wait \
  --for=jsonpath='{.subsets[0].addresses[0].ip}' \
  endpoints/aws-load-balancer-webhook-service \
  --namespace kube-system --timeout=5m; then
  echo "::error::AWS Load Balancer Controller webhook has no ready endpoints; collecting diagnostics."
  kubectl get deployment,pods,services,endpoints -n kube-system -o wide || true
  kubectl describe mutatingwebhookconfiguration aws-load-balancer-webhook || true
  kubectl logs deployment/aws-load-balancer-controller -n kube-system --all-containers=true --tail=100 || true
  kubectl get events -n kube-system --sort-by=.lastTimestamp | tail -n 40 || true
  exit 1
fi

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --version "$CLUSTER_AUTOSCALER_CHART_VERSION" \
  --namespace kube-system \
  --set autoDiscovery.clusterName="$EKS_CLUSTER_NAME" \
  --set awsRegion="$AWS_REGION" \
  --set image.tag="v${EKS_KUBERNETES_VERSION}.0" \
  --set rbac.create=true \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --wait \
  --timeout 10m

if [[ -n "${ROUTE53_ZONE_ID:-}" && -n "${API_DOMAIN_NAME:-}" ]]; then
  helm upgrade --install external-dns external-dns/external-dns \
    --version "$EXTERNAL_DNS_CHART_VERSION" \
    --namespace kube-system \
    --set provider.name=aws \
    --set serviceAccount.create=true \
    --set serviceAccount.name=external-dns \
    --set "domainFilters={$API_DOMAIN_NAME}" \
    --set "extraArgs={--aws-zone-type=public,--zone-id-filter=$ROUTE53_ZONE_ID,--policy=upsert-only}" \
    --wait \
    --timeout 10m
fi
