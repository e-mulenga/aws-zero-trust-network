#!/usr/bin/env bash
# Builds, pushes and deploys the five payment services onto the cluster created by infra/baseline.
# Usage: workloads/deploy.sh [--skip-build]
# Account-specific values (ECR URLs, IRSA role ARNs, queue URLs) are read from Terraform outputs,
# never stored in the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISTIO_TAG="${ISTIO_TAG:-1.30.2}"
NS="payment-app"
IMAGE_VERSION="${IMAGE_VERSION:-latest}"
SERVICES=(wallet transaction fraud-detection notification reconciliation)
CLUSTER_DIR="$ROOT/infra/baseline/cluster"
DATA_DIR="$ROOT/infra/baseline/data"

app_repo="$(terraform -chdir="$CLUSTER_DIR" output -raw image_repository)"   # Landing Zone shared-applications
platform_repo="$(terraform -chdir="$CLUSTER_DIR" output -raw platform_image_repository)"
REGION="$(terraform -chdir="$ROOT/infra/zerotrust" output -raw primary_region)"
NAME_PREFIX="$(terraform -chdir="$CLUSTER_DIR" output -raw name_prefix)"
irsa_json="$(terraform -chdir="$CLUSTER_DIR" output -json irsa_role_arns)"
cluster="$(terraform -chdir="$CLUSTER_DIR" output -raw cluster_name)"
notification_queue="$(terraform -chdir="$DATA_DIR" output -raw notification_queue_url)"
reconciliation_queue="$(terraform -chdir="$DATA_DIR" output -raw reconciliation_queue_url)"
# After the zero trust retrofit, DynamoDB Streams is reached through its interface endpoint,
# which has no private DNS name, so the endpoint URL is passed to the fraud detection service.
streams_url="$(terraform -chdir="$ROOT/infra/zerotrust" output -raw dynamodb_streams_endpoint_url 2>/dev/null || true)"

aws eks update-kubeconfig --region "$REGION" --name "$cluster" >/dev/null

if [ "${1:-}" != "--skip-build" ]; then
  registry="${app_repo%%/*}"
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$registry" >/dev/null
  for svc in "${SERVICES[@]}"; do
    # One Landing Zone repository, one tag per service: <svc>-<version>
    docker build --platform linux/amd64 -t "$app_repo:$svc-$IMAGE_VERSION" "$ROOT/workloads/services/$svc"
    docker push "$app_repo:$svc-$IMAGE_VERSION"
  done
fi

render() { sed -e "s|__REGION__|$REGION|g" -e "s|__NAME_PREFIX__|$NAME_PREFIX|g" \
  -e "s|__PLATFORM_REPO__|$platform_repo|g" -e "s|__ISTIO_TAG__|$ISTIO_TAG|g" "$1"; }

# Istio images come from the Landing Zone ECR (no NAT in the Landing Zone): see scripts/mirror_istio_images.sh
render "$ROOT/workloads/istio/operator.yaml" | istioctl install -f - -y
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" istio-injection=enabled --overwrite

for svc in "${SERVICES[@]}"; do
  extra=()
  case "$svc" in
    notification)   extra=(--set "env[1].value=$notification_queue") ;;
    reconciliation) extra=(--set "env[2].value=$reconciliation_queue") ;;
    fraud-detection)
      if [[ "$streams_url" == https://* ]]; then
        extra=(--set "extraEnv[0].name=AWS_ENDPOINT_URL_DYNAMODB_STREAMS" --set "extraEnv[0].value=$streams_url")
      fi ;;
  esac
  helm upgrade --install "$svc" "$ROOT/workloads/helm/microservice" -n "$NS" \
    -f <(render "$ROOT/workloads/helm/values/values-$svc.yaml") \
    --set "image.repository=$app_repo" --set "image.tag=$svc-$IMAGE_VERSION" \
    --set "serviceAccount.irsaRoleArn=$(jq -r --arg s "$svc" '.[$s]' <<<"$irsa_json")" \
    "${extra[@]}"
done

kubectl apply -f "$ROOT/workloads/istio/gateway.yaml"
kubectl -n "$NS" rollout status deployment --timeout=300s
kubectl -n istio-system get svc istio-ingressgateway
