#!/usr/bin/env bash
# Setup Terraform, OCI config, and tfvars for OCI-AWS Firehose deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"
CONFIG_DIR="$PROJECT_ROOT/config"

echo "=== OCI-AWS Firehose Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# 1. Check prerequisites
echo "--- Checking prerequisites ---"
"$SCRIPT_DIR/check-prereqs.sh" || {
  echo "Fix prerequisites and rerun."
  exit 1
}
echo ""

# 2. OCI config (informational - don't overwrite)
OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
if [[ ! -f "$OCI_CONFIG" ]]; then
  echo "--- OCI config ---"
  echo "OCI config not found at $OCI_CONFIG"
  echo ""
  echo "To create it:"
  echo "  1. mkdir -p ~/.oci"
  echo "  2. cp $CONFIG_DIR/oci-config.template ~/.oci/config"
  echo "  3. Generate API key: OCI Console → Profile → User Settings → API Keys → Add"
  echo "  4. Download private key, save as ~/.oci/oci_api_key.pem"
  echo "  5. Edit ~/.oci/config with tenancy OCID, user OCID, fingerprint, key_file path"
  echo ""
  read -p "Create config from template now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$(dirname "$OCI_CONFIG")"
    cp "$CONFIG_DIR/oci-config.template" "$OCI_CONFIG"
    chmod 600 "$OCI_CONFIG"
    echo "Created $OCI_CONFIG - edit with your OCI credentials"
    echo "For key: openssl genrsa -out ~/.oci/oci_api_key.pem 2048"
  fi
else
  echo "--- OCI config ---"
  echo "Using existing OCI config: $OCI_CONFIG"
fi
echo ""

# 3. terraform.tfvars
echo "--- Terraform variables ---"
TFVARS="$INFRA_DIR/terraform.tfvars"
if [[ ! -f "$TFVARS" ]]; then
  cp "$INFRA_DIR/terraform.tfvars.example" "$TFVARS"
  echo "Created $TFVARS from example"
  echo "  Edit with your: tenancy_ocid, AWS credentials, bucket names, etc."
else
  echo "terraform.tfvars already exists: $TFVARS"
fi
echo ""

# 4. Terraform init
echo "--- Terraform init ---"
cd "$INFRA_DIR"
terraform init
echo ""
echo "Done. Next steps:"
echo "  1. Edit infra/terraform.tfvars with your values"
echo "  2. terraform plan"
echo "  3. terraform apply"
echo "  4. fn deploy (see DEPLOY.md for OCI Registry auth)"
