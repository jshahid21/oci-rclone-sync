#!/usr/bin/env bash
# Configure Fn CLI for OCI Functions (OCI-AWS Firehose project)
# Prerequisites: fn, docker, OCI CLI configured (~/.oci/config)
#
# Run: ./scripts/configure-fn-oci.sh
# Or with values: OCI_REGION=us-ashburn-1 OCI_COMPARTMENT_ID=ocid1... ./scripts/configure-fn-oci.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults (override with env vars)
OCI_REGION="${OCI_REGION:-us-ashburn-1}"
OCI_COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-}"
OCI_NAMESPACE="${OCI_NAMESPACE:-}"
OCI_REGISTRY_REPO="${OCI_REGISTRY_REPO:-oci-aws-firehose}"

echo -e "${BLUE}=== Configure Fn for OCI Functions ===${NC}"
echo ""

# Check fn
if ! command -v fn &>/dev/null; then
  echo -e "${RED}Fn CLI not found. Run: ./scripts/install-fn-docker.sh${NC}"
  exit 1
fi

# Get namespace from OCI CLI if not set
if [[ -z "$OCI_NAMESPACE" ]] && command -v oci &>/dev/null; then
  echo "Fetching OCI tenancy namespace..."
  OCI_NAMESPACE=$(oci os ns get --query 'data' --raw-output 2>/dev/null || echo "")
fi

if [[ -z "$OCI_NAMESPACE" ]]; then
  echo -e "${YELLOW}Could not get OCI namespace. Run: oci os ns get${NC}"
  read -p "Enter your tenancy namespace (e.g. axabcdefghij): " OCI_NAMESPACE
fi

# Get compartment if not set
if [[ -z "$OCI_COMPARTMENT_ID" ]]; then
  echo ""
  echo "Compartment OCID is required (where the Functions app lives)."
  echo "Get it from: Terraform output, or OCI Console → Identity → Compartments"
  read -p "Enter compartment OCID: " OCI_COMPARTMENT_ID
fi

if [[ -z "$OCI_COMPARTMENT_ID" ]] || [[ -z "$OCI_NAMESPACE" ]]; then
  echo -e "${RED}Compartment OCID and namespace are required.${NC}"
  exit 1
fi

REGISTRY="${OCI_REGION}.ocir.io/${OCI_NAMESPACE}/${OCI_REGISTRY_REPO}"

echo ""
echo "Configuration:"
echo "  Region:      $OCI_REGION"
echo "  Compartment: $OCI_COMPARTMENT_ID"
echo "  Registry:    $REGISTRY"
echo ""

# Create or use OCI context
if fn list contexts 2>/dev/null | grep -q "oci"; then
  echo "Using existing OCI context..."
  fn use context oci
else
  echo "Creating OCI context..."
  fn create context oci --provider oracle
  fn use context oci
fi

fn update context oracle.compartment-id "$OCI_COMPARTMENT_ID"
fn update context oracle.registry "$REGISTRY"

echo ""
echo -e "${GREEN}✓ Fn configured for OCI${NC}"
echo ""
echo "Registry: $REGISTRY"
echo ""
echo "OCIR authentication (needed for 'fn deploy'):"
echo "  1. Create Auth Token: OCI Console → Profile → Auth Tokens → Generate"
echo "  2. Docker login:"
echo "     docker login ${OCI_REGION}.ocir.io"
echo "     Username: ${OCI_NAMESPACE}/<your-oci-username>"
echo "     Password: <auth-token>"
echo ""
echo "To deploy the function:"
echo "  cd functions && fn deploy --app oci-aws-firehose"
echo ""
