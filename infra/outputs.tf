# =============================================================================
# OCI AWS Firehose - Outputs
# Final resolved IDs for reference and downstream use
# =============================================================================

output "compartment_id" {
  description = "Compartment OCID in use"
  value       = local.compartment_id
}

output "vcn_id" {
  description = "VCN OCID in use"
  value       = local.vcn_id
}

output "subnet_id" {
  description = "Subnet OCID in use (private subnet for Functions)"
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

output "function_app_id" {
  description = "OCI Functions Application OCID"
  value       = local.function_app_id
}

output "function_id" {
  description = "OCI Function OCID"
  value       = local.function_id
}

output "source_bucket_name" {
  description = "OCI Object Storage source bucket name"
  value       = local.source_bucket
}

output "source_bucket_namespace" {
  description = "OCI Object Storage namespace"
  value       = local.bucket_namespace
}

output "dynamic_group_name" {
  description = "Dynamic Group name for Resource Principals"
  value       = oci_identity_dynamic_group.firehose.name
}
