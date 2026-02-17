#!/usr/bin/env bash
# Check prerequisites for OCI-to-AWS Sync

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
  local name=$1
  local cmd=$2
  local install_hint=$3

  if command -v "$cmd" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $name: $(command -v "$cmd")"
    return 0
  else
    echo -e "${RED}✗${NC} $name not found. $install_hint"
    return 1
  fi
}

failed=0

echo "=== Checking prerequisites ==="
if command -v tofu &>/dev/null; then
  echo -e "${GREEN}✓${NC} OpenTofu: $(command -v tofu)"
elif command -v terraform &>/dev/null; then
  echo -e "${GREEN}✓${NC} Terraform: $(command -v terraform)"
else
  echo -e "${RED}✗${NC} OpenTofu or Terraform not found. Install: https://opentofu.org/docs/intro/install/"
  failed=1
fi
check oci "oci" "Install: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm" || failed=1

echo ""
echo "=== OCI Config ==="
OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
if [[ -f "$OCI_CONFIG" ]]; then
  echo -e "${GREEN}✓${NC} OCI config exists: $OCI_CONFIG"
  if oci iam region list &>/dev/null; then
    echo -e "${GREEN}✓${NC} OCI authentication works"
  else
    echo -e "${YELLOW}!${NC} OCI config exists but auth failed. Run: oci setup repair-file-permissions"
  fi
else
  echo -e "${RED}✗${NC} OCI config not found at $OCI_CONFIG"
  echo "  Copy config/oci-config.template and configure your API keys"
  failed=1
fi

echo ""
if [[ $failed -eq 0 ]]; then
  echo -e "${GREEN}All prerequisites met.${NC}"
  exit 0
else
  echo -e "${RED}Some prerequisites missing. Install them and rerun.${NC}"
  exit 1
fi
