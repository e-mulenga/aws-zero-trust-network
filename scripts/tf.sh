#!/usr/bin/env bash
# Runs Terraform for one stack in one environment.
# Usage: scripts/tf.sh <dev|test|prod> <cluster|data|zerotrust> <init|plan|apply|destroy|output|...> [args]
# Apply order: cluster -> data -> zerotrust. Destroy in the reverse order.
# State lives in the Landing Zone state bucket named in environments/<env>/backend.hcl (git-ignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:?env: dev|test|prod}"
STACK="${2:?stack: cluster|data|zerotrust}"
CMD="${3:?command}"
shift 3

TF="${TF_BIN:-terraform}"
case "$STACK" in
  cluster)   DIR="$ROOT/infra/cluster" ;;
  data)      DIR="$ROOT/infra/data" ;;
  zerotrust) DIR="$ROOT/infra/zerotrust" ;;
  *) echo "unknown stack: $STACK" >&2; exit 2 ;;
esac
ENVDIR="$ROOT/environments/$ENV"
[ -f "$ENVDIR/backend.hcl" ] || { echo "missing $ENVDIR/backend.hcl (copy backend.hcl.example)" >&2; exit 2; }

VARS=(-var-file="$ENVDIR/common.tfvars")
[ -f "$ENVDIR/$STACK.tfvars" ] && VARS+=(-var-file="$ENVDIR/$STACK.tfvars")

case "$CMD" in
  init)
    exec "$TF" -chdir="$DIR" init -reconfigure -backend-config="$ENVDIR/backend.hcl" \
      -backend-config="key=aws-zero-trust-network/$ENV/$STACK.tfstate" "$@" ;;
  plan|apply|destroy|import|refresh)
    exec "$TF" -chdir="$DIR" "$CMD" "${VARS[@]}" "$@" ;;
  *)
    exec "$TF" -chdir="$DIR" "$CMD" "$@" ;;
esac
