#!/usr/bin/env bash
# Install Docker and Fn CLI for OCI-AWS Firehose (macOS)
# Run: ./scripts/install-fn-docker.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installing Docker & Fn for OCI Functions ===${NC}"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${YELLOW}Note: This script is optimized for macOS. On Linux, use package manager.${NC}"
fi

# 1. Docker
echo -e "${BLUE}--- Docker ---${NC}"
if command -v docker &>/dev/null; then
  echo -e "${GREEN}✓ Docker already installed:$(docker --version 2>/dev/null || true)${NC}"
  if docker info &>/dev/null 2>&1; then
    echo -e "${GREEN}  Docker daemon is running${NC}"
  else
    echo -e "${YELLOW}! Docker installed but daemon not running.${NC}"
    echo "  Start Docker Desktop: open -a Docker"
  fi
else
  echo "Installing Docker..."
  if command -v brew &>/dev/null; then
    brew install --cask docker
    echo -e "${GREEN}✓ Docker Desktop installed. Start it from Applications.${NC}"
    echo "  Then rerun this script or: open -a Docker"
  else
    echo -e "${YELLOW}Install Docker manually:${NC}"
    echo "  https://docs.docker.com/desktop/install/mac-install/"
    echo "  Or: brew install --cask docker (then open -a Docker)"
    exit 1
  fi
fi
echo ""

# 2. Fn CLI
echo -e "${BLUE}--- Fn CLI ---${NC}"
if command -v fn &>/dev/null; then
  echo -e "${GREEN}✓ Fn already installed: $(fn version 2>/dev/null | head -1 || fn version 2>/dev/null)${NC}"
else
  echo "Installing Fn CLI..."
  if command -v brew &>/dev/null; then
    brew update && brew install fn
    echo -e "${GREEN}✓ Fn CLI installed${NC}"
  else
    echo "Installing via curl..."
    curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
    echo -e "${GREEN}✓ Fn CLI installed to /usr/local/bin (or ~/bin)${NC}"
  fi
fi
echo ""

# 3. Verify
echo -e "${BLUE}--- Verification ---${NC}"
fn version
echo ""
echo -e "${GREEN}=== Install complete ===${NC}"
echo ""
echo "Next: Configure Fn for OCI (see scripts/configure-fn-oci.sh)"
echo "  Or run: ./scripts/configure-fn-oci.sh"
