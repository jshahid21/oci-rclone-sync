#!/usr/bin/env bash
# Check prerequisites for OCI-to-AWS sync setup

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

failed=0
command -v tofu &>/dev/null || command -v terraform &>/dev/null || { echo -e "${RED}✗${NC} Install OpenTofu: brew install opentofu"; failed=1; }
command -v oci &>/dev/null || { echo -e "${RED}✗${NC} Install OCI CLI: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"; failed=1; }

OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
if [[ -f "$OCI_CONFIG" ]]; then
  oci iam region list &>/dev/null || { echo -e "${RED}✗${NC} OCI auth failed. Check $OCI_CONFIG"; failed=1; }
else
  echo -e "${RED}✗${NC} OCI config missing at $OCI_CONFIG"
  echo "  Create API key in OCI Console → Profile → User Settings → API Keys"
  echo "  Copy config/oci-config.template to ~/.oci/config and fill in values"
  failed=1
fi

[[ $failed -eq 0 ]] && echo -e "${GREEN}Prerequisites OK${NC}" || exit 1
