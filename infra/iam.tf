# Dynamic Group (Instance Principal for OCI auth + Vault secret read for AWS keys at runtime)
resource "oci_identity_dynamic_group" "rclone_dg" {
  compartment_id = var.tenancy_ocid
  name          = "rclone-dg"
  description   = "Dynamic group for OCI-to-AWS rclone sync VM (Instance Principal + Vault)"
  matching_rule = "ALL {tag.Role.value = 'rclone-worker', instance.compartment.id = '${local.compartment_id}'}"
}

# A-Team policy: Instance Principal access to restricted billing (usage-report) namespace
# + Vault secret-bundles for AWS credentials (fixes 404 - must be secret-bundles, not secrets)
resource "oci_identity_policy" "rclone_policy" {
  compartment_id = var.tenancy_ocid
  name           = "rclone-cross-tenancy-policy"
  description    = "Instance Principal: usage-report (bling) + Vault secret-bundles"
  statements = [
    # Define must be first (OCI policy rule) - A-Team pattern for billing bucket
    "Define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "Endorse dynamic-group ${oci_identity_dynamic_group.rclone_dg.name} to read objects in tenancy usage-report",
    # Vault: read secret-bundles (not secrets) - required for GetSecretBundle API
    "Allow dynamic-group ${oci_identity_dynamic_group.rclone_dg.name} to read secret-bundles in compartment id ${local.compartment_id}"
  ]
}
