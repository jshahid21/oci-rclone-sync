# =============================================================================
# OCI-to-AWS Sync - Outputs
# Final resolved IDs for reference and downstream use
# =============================================================================

output "instance_id" {
  description = "Compute instance OCID"
  value       = oci_core_instance.rclone_sync.id
}

output "instance_private_ip" {
  description = "Private IP of the sync VM"
  value       = oci_core_instance.rclone_sync.private_ip
}

output "dynamic_group_name" {
  description = "Dynamic Group name for Instance Principals"
  value       = oci_identity_dynamic_group.rclone_dg.name
}

output "compartment_id" {
  description = "Compartment OCID in use"
  value       = local.compartment_id
}

output "vcn_id" {
  description = "VCN OCID in use"
  value       = local.vcn_id
}

output "subnet_id" {
  description = "Subnet OCID in use"
  value       = local.subnet_id
}

output "nat_gateway_id" {
  description = "NAT Gateway OCID in use"
  value       = local.nat_gateway_id
}

output "service_gateway_id" {
  description = "Service Gateway OCID in use"
  value       = local.sgw_id
}

output "vault_id" {
  description = "Vault OCID in use"
  value       = local.vault_id
}

output "key_id" {
  description = "KMS Key OCID in use"
  value       = local.key_id
}

output "aws_access_key_secret_id" {
  description = "OCI Vault Secret OCID for AWS Access Key"
  value       = local.aws_access_key_secret_id
  sensitive   = true
}

output "aws_secret_key_secret_id" {
  description = "OCI Vault Secret OCID for AWS Secret Key"
  value       = local.aws_secret_key_secret_id
  sensitive   = true
}

