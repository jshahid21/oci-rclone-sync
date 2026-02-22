# OCI-to-AWS Sync - Outputs

output "instance_id" {
  description = "Compute instance OCID"
  value       = oci_core_instance.rclone_sync.id
}

output "instance_private_ip" {
  description = "Private IP of the sync VM"
  value       = oci_core_instance.rclone_sync.private_ip
}

output "worker_private_ip" {
  description = "Private IP of the rclone worker VM (alias for SSH)"
  value       = oci_core_instance.rclone_sync.private_ip
}

output "bastion_public_ip" {
  description = "Public IP of bastion host (for SSH proxy)"
  value       = var.create_bastion && var.create_vcn ? data.oci_core_vnic.bastion[0].public_ip_address : null
}

output "bastion_ssh_command" {
  description = "Example SSH command to reach rclone instance via bastion"
  value       = var.create_bastion && var.create_vcn ? "ssh -J opc@${data.oci_core_vnic.bastion[0].public_ip_address} opc@${oci_core_instance.rclone_sync.private_ip}" : null
}

output "dynamic_group_name" {
  description = "Dynamic Group name (Vault secret read via instance principal)"
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

output "alert_notification_topic_id" {
  description = "OCI Notification Topic OCID for rclone sync alerts"
  value       = var.enable_monitoring ? oci_ons_notification_topic.rclone_alerts[0].topic_id : null
}
