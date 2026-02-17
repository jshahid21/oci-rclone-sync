# =============================================================================
# IAM: Dynamic Group & Cross-Tenancy Policy
# Instance Principals: No API keys on VM
# =============================================================================

# -----------------------------------------------------------------------------
# Dynamic Group - Match the rclone sync compute instance
# -----------------------------------------------------------------------------
resource "oci_identity_dynamic_group" "rclone_dg" {
  compartment_id = var.tenancy_ocid
  name          = "rclone-dg"
  description   = "Dynamic group for OCI-to-AWS rclone sync VM"
  matching_rule = "ALL {instance.id = '${oci_core_instance.rclone_sync.id}'}"
}

# -----------------------------------------------------------------------------
# Cross-Tenancy Policy
# 1. Allow access to Oracle's Usage Report Tenancy (cross-tenancy read)
# 2. Allow access to OCI Vault for AWS keys
# -----------------------------------------------------------------------------
resource "oci_identity_policy" "rclone_policy" {
  compartment_id = local.compartment_id
  name           = "rclone-cross-tenancy-policy"
  description    = "Cross-tenancy OCI Usage Report read + Vault secret read"
  statements = [
    "Define tenancy UsageReport as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "Endorse dynamic-group rclone-dg to read objects in tenancy UsageReport",
    "Endorse dynamic-group rclone-dg to read buckets in tenancy UsageReport",
    "Allow dynamic-group rclone-dg to read secret-bundles in compartment id ${local.compartment_id}"
  ]
}
