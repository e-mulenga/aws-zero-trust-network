#!/usr/bin/env bash
# Mirrors the Istio control-plane and proxy images into the Landing Zone shared-platform ECR repo.
# Run from a machine with internet access (the Landing Zone VPC has no NAT gateway).
# Usage: scripts/mirror_istio_images.sh [istio-tag]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-1.30.2}"
REGION="$(terraform -chdir="$ROOT/infra/zerotrust" output -raw primary_region)"
REPO="$(terraform -chdir="$ROOT/infra/baseline/cluster" output -raw platform_image_repository)"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO%%/*}" >/dev/null
for img in pilot proxyv2; do
  docker pull --platform linux/amd64 "docker.io/istio/$img:$TAG"
  docker tag "docker.io/istio/$img:$TAG" "$REPO:$img-$TAG"
  docker push "$REPO:$img-$TAG"
done
echo "Mirrored pilot and proxyv2 $TAG to $REPO"
