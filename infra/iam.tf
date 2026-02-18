# Dynamic Group (Vault secret read only - instance principal for fetching creds at runtime)
resource "oci_identity_dynamic_group" "rclone_dg" {
  compartment_id = var.tenancy_ocid
  name          = "rclone-dg"
  description   = "Dynamic group for OCI-to-AWS rclone sync VM (Vault secret read)"
  matching_rule = "ALL {tag.Role.value = 'rclone-worker', instance.compartment.id = '${local.compartment_id}'}"
}

# IAM User + Group for API key auth (bling cost reports - instance principal does not work for bling)
resource "oci_identity_group" "rclone_group" {
  compartment_id = var.tenancy_ocid
  name           = var.oci_rclone_group_name
  description    = "Group for rclone sync user (API key auth for cost reports)"
}

resource "oci_identity_user" "rclone_user" {
  compartment_id = var.tenancy_ocid
  name           = var.oci_rclone_user_name
  description    = "OCI user for rclone sync (API key auth)"
  email          = var.oci_rclone_user_email
}

resource "oci_identity_user_group_membership" "rclone_user_in_group" {
  user_id  = oci_identity_user.rclone_user.id
  group_id = oci_identity_group.rclone_group.id
}

# Policy: Vault secret read (instance principal) + Cost report read (group / API key)
resource "oci_identity_policy" "rclone_policy" {
  compartment_id = var.tenancy_ocid
  name           = "rclone-cross-tenancy-policy"
  description    = "Vault secret read (dynamic group) + Cost report read (rclone group)"
  statements = [
    # Define must be first (OCI policy rule)
    "Define tenancy reporting as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "Endorse group ${var.oci_rclone_group_name} to read objects in tenancy reporting",
    "Endorse group ${var.oci_rclone_group_name} to read buckets in tenancy reporting",
    "Allow dynamic-group rclone-dg to read secret-bundles in compartment id ${local.compartment_id}"
  ]
}
