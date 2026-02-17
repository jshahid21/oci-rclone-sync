# =============================================================================
# OCI-to-AWS Sync - VM + Rclone Architecture
# Hybrid: Create VCN/Subnet/NAT/Vault/Secrets OR use existing IDs
# Compute: Always Free Ampere A1, cloud-init, cron every 6 hours
# =============================================================================

# -----------------------------------------------------------------------------
# Locals - Resolved IDs
# -----------------------------------------------------------------------------
locals {
  compartment_id = var.create_compartment ? oci_identity_compartment.this[0].id : var.existing_compartment_id
  vcn_id         = var.create_vcn ? oci_core_vcn.this[0].id : var.existing_vcn_id
  subnet_id      = var.create_subnet ? oci_core_subnet.this[0].id : var.existing_subnet_id
  nat_gateway_id = var.create_nat_gateway ? oci_core_nat_gateway.this[0].id : var.existing_nat_gateway_id
  sgw_id         = var.create_service_gateway ? oci_core_service_gateway.this[0].id : var.existing_service_gateway_id
  vault_id       = var.create_vault ? oci_kms_vault.this[0].id : var.existing_vault_id
  key_id         = var.create_key ? oci_kms_key.this[0].id : var.existing_key_id

  vault_management_endpoint = data.oci_kms_vault.vault_lookup.management_endpoint

  aws_access_key_secret_id = var.create_aws_secrets ? oci_vault_secret.aws_access_key[0].id : var.existing_aws_access_key_secret_id
  aws_secret_key_secret_id = var.create_aws_secrets ? oci_vault_secret.aws_secret_key[0].id : var.existing_aws_secret_key_secret_id
}

# -----------------------------------------------------------------------------
# Compartment
# -----------------------------------------------------------------------------
resource "oci_identity_compartment" "this" {
  count = var.create_compartment ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = var.compartment_description
}

# -----------------------------------------------------------------------------
# VCN
# -----------------------------------------------------------------------------
resource "oci_core_vcn" "this" {
  count = var.create_vcn ? 1 : 0

  compartment_id = local.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "oci-aws-sync-vcn"
  dns_label      = var.vcn_dns_label

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------
resource "oci_core_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "oci-aws-sync-nat"
}

# -----------------------------------------------------------------------------
# Service Gateway
# -----------------------------------------------------------------------------
resource "oci_core_service_gateway" "this" {
  count = var.create_service_gateway ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "oci-aws-sync-sgw"
  services {
    service_id = data.oci_core_services.object_storage.services[0].id
  }
}

data "oci_core_services" "object_storage" {
  filter {
    name   = "name"
    values = ["Object Storage"]
  }
}

# -----------------------------------------------------------------------------
# Route Table for Private Subnet (internet via NAT, OCI services via SGW)
# Create when subnet is new AND we have at least one gateway (created or existing)
# -----------------------------------------------------------------------------
resource "oci_core_route_table" "private" {
  count = var.create_subnet && (local.nat_gateway_id != "" || local.sgw_id != "") ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "oci-aws-sync-private-rt"

  dynamic "route_rules" {
    for_each = local.nat_gateway_id != "" ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = local.nat_gateway_id
    }
  }

  dynamic "route_rules" {
    for_each = local.sgw_id != "" ? [1] : []
    content {
      destination       = data.oci_core_services.object_storage.services[0].cidr_block
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = local.sgw_id
    }
  }
}

# -----------------------------------------------------------------------------
# Security List for Private Subnet
# -----------------------------------------------------------------------------
resource "oci_core_security_list" "private" {
  count = var.create_subnet ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "oci-aws-sync-private-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  egress_security_rules {
    destination = data.oci_core_services.object_storage.services[0].cidr_block
    protocol    = "6"
    stateless   = false
  }
}

# -----------------------------------------------------------------------------
# Private Subnet
# -----------------------------------------------------------------------------
resource "oci_core_subnet" "this" {
  count = var.create_subnet ? 1 : 0

  compartment_id             = local.compartment_id
  vcn_id                     = local.vcn_id
  cidr_block                 = var.subnet_cidr
  display_name               = "oci-aws-sync-private-subnet"
  dns_label                  = var.subnet_dns_label
  prohibit_public_ip_on_vnic  = true
  route_table_id             = (local.nat_gateway_id != "" || local.sgw_id != "") ? oci_core_route_table.private[0].id : null
  security_list_ids          = [oci_core_security_list.private[0].id]

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Vault
# -----------------------------------------------------------------------------
resource "oci_kms_vault" "this" {
  count = var.create_vault ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = "oci-aws-sync-vault"
  vault_type     = var.vault_type

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# KMS Key (for secret encryption)
# -----------------------------------------------------------------------------
resource "oci_kms_key" "this" {
  count = var.create_key ? 1 : 0

  compartment_id      = local.compartment_id
  display_name        = "oci-aws-sync-key"
  management_endpoint = local.vault_management_endpoint
  key_shape {
    algorithm = "AES"
    length    = 32
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Create key version and get the key OCID for secrets (Keys use different endpoint)
resource "oci_kms_key_version" "this" {
  count = var.create_key ? 1 : 0

  key_id              = oci_kms_key.this[0].id
  management_endpoint = local.vault_management_endpoint
}

# -----------------------------------------------------------------------------
# Vault Lookup - Resolves management_endpoint for created or existing vault
# -----------------------------------------------------------------------------
data "oci_kms_vault" "vault_lookup" {
  vault_id = local.vault_id
}

# -----------------------------------------------------------------------------
# AWS Credentials Secrets
# -----------------------------------------------------------------------------
resource "oci_vault_secret" "aws_access_key" {
  count = var.create_aws_secrets ? 1 : 0

  compartment_id = local.compartment_id
  secret_name    = "oci-aws-sync-aws-access-key"
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.aws_access_key)
  }
}

resource "oci_vault_secret" "aws_secret_key" {
  count = var.create_aws_secrets ? 1 : 0

  compartment_id = local.compartment_id
  secret_name    = "oci-aws-sync-aws-secret-key"
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.aws_secret_key)
  }
}

# -----------------------------------------------------------------------------
# Compute Instance (Always Free Ampere A1)
# -----------------------------------------------------------------------------
resource "oci_core_instance" "rclone_sync" {
  compartment_id      = local.compartment_id
  availability_domain  = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = var.instance_shape
  display_name        = var.instance_display_name
  subnet_id           = local.subnet_id
  hostname_label      = "rclone-sync"
  preserve_boot_volume = false

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id              = local.subnet_id
    skip_source_dest_check = false
    assign_public_ip       = false
    nsg_ids                = []
    hostname_label         = "rclone-sync"
  }

  metadata = {
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      tenancy_ocid              = var.tenancy_ocid
      region                    = var.region
      aws_access_key_secret_id  = local.aws_access_key_secret_id
      aws_secret_key_secret_id  = local.aws_secret_key_secret_id
      source_bucket_name        = var.source_bucket_name
      aws_s3_bucket_name        = var.aws_s3_bucket_name
      aws_s3_prefix             = var.aws_s3_prefix
      aws_region                = var.aws_region
    }))
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

