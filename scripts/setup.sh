#!/usr/bin/env bash
# Setup for OCI-to-AWS cost report sync

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

echo "=== OCI Cost Reports → AWS S3 Setup ==="
"$SCRIPT_DIR/check-prereqs.sh" || { echo "Fix prerequisites and rerun."; exit 1; }

if [[ ! -f "$INFRA_DIR/terraform.tfvars" ]]; then
  cp "$INFRA_DIR/terraform.tfvars.example" "$INFRA_DIR/terraform.tfvars"
  echo "Created $INFRA_DIR/terraform.tfvars — edit with your values."
fi

cd "$INFRA_DIR"
tofu init 2>/dev/null || terraform init 2>/dev/null || true

echo ""
echo "Next: edit infra/terraform.tfvars, then run tofu apply"
