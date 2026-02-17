# -----------------------------------------------------------------------------
# OpenTofu / Terraform compatibility: This configuration works with both
# `tofu` and `terraform` binaries. Providers from registry.terraform.io are
# fully compatible with OpenTofu via the registry shim.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0, < 9.0"
    }
  }
}

provider "oci" {
  # Use credentials from ~/.oci/config (DEFAULT profile)
  # OCI config contains: user, fingerprint, key_file, tenancy, region
  config_file_profile = "DEFAULT"
  region              = var.region
}
