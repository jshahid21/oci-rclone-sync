# =============================================================================
# OCI AWS Firehose - Main Infrastructure
# Hybrid Create vs Use Existing pattern for all major resources
# =============================================================================

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "oci_identity_tenancy" "root" {
  tenancy_id = var.tenancy_ocid
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = local.compartment_id
}

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

  # Single lookup - resolves to created or existing vault (avoids conditional data source eval)
  vault_management_endpoint = data.oci_kms_vault.vault_lookup.management_endpoint

  aws_access_key_secret_id = var.create_aws_secrets ? oci_vault_secret.aws_access_key[0].id : var.existing_aws_access_key_secret_id
  aws_secret_key_secret_id = var.create_aws_secrets ? oci_vault_secret.aws_secret_key[0].id : var.existing_aws_secret_key_secret_id

  function_app_id  = var.create_function_app ? oci_functions_application.this[0].id : var.existing_function_app_id
  function_id      = var.create_function_app ? oci_functions_function.this[0].id : var.existing_function_id
  bucket_namespace = var.create_bucket ? data.oci_objectstorage_namespace.ns.namespace : var.existing_bucket_namespace
  source_bucket    = var.create_bucket ? oci_objectstorage_bucket.this[0].name : var.source_bucket_name

  # OCIR image: region.ocir.io/tenancy_namespace/repo/image:tag
  function_image = var.function_image != "" ? var.function_image : "${var.region}.ocir.io/${data.oci_identity_tenancy.root.object_storage_namespace}/oci-aws-firehose/firehose-handler:latest"
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
  display_name   = "firehose-vcn"
  dns_label      = var.vcn_dns_label
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------
resource "oci_core_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "firehose-nat"
}

# -----------------------------------------------------------------------------
# Service Gateway
# -----------------------------------------------------------------------------
resource "oci_core_service_gateway" "this" {
  count = var.create_service_gateway ? 1 : 0

  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "firehose-sgw"
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
  display_name   = "firehose-private-rt"

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
  display_name   = "firehose-private-sl"

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
  display_name               = "firehose-private-subnet"
  dns_label                  = var.subnet_dns_label
  prohibit_public_ip_on_vnic  = true
  route_table_id             = (local.nat_gateway_id != "" || local.sgw_id != "") ? oci_core_route_table.private[0].id : null
  security_list_ids          = [oci_core_security_list.private[0].id]
}

# -----------------------------------------------------------------------------
# Vault
# -----------------------------------------------------------------------------
resource "oci_kms_vault" "this" {
  count = var.create_vault ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = "firehose-vault"
  vault_type     = var.vault_type
}

# -----------------------------------------------------------------------------
# KMS Key (for secret encryption)
# -----------------------------------------------------------------------------
resource "oci_kms_key" "this" {
  count = var.create_key ? 1 : 0

  compartment_id      = local.compartment_id
  display_name        = "firehose-key"
  management_endpoint = local.vault_management_endpoint
  key_shape {
    algorithm = "AES"
    length    = 32
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
  secret_name    = "firehose-aws-access-key"
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
  secret_name    = "firehose-aws-secret-key"
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.aws_secret_key)
  }
}

# -----------------------------------------------------------------------------
# Object Storage Bucket
# -----------------------------------------------------------------------------
resource "oci_objectstorage_bucket" "this" {
  count = var.create_bucket ? 1 : 0

  compartment_id = local.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.source_bucket_name
  access_type    = "ObjectRead"
}

# -----------------------------------------------------------------------------
# Dynamic Group (for Resource Principals)
# -----------------------------------------------------------------------------
resource "oci_identity_dynamic_group" "firehose" {
  compartment_id = var.tenancy_ocid
  name           = "firehose-function-dg"
  description    = "Dynamic group for OCI-to-AWS Firehose function"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${local.compartment_id}'}"
}

# -----------------------------------------------------------------------------
# Policies
# -----------------------------------------------------------------------------
resource "oci_identity_policy" "firehose" {
  compartment_id = local.compartment_id
  name           = "firehose-policy"
  description    = "Policy for Firehose function: Object Storage read, Vault secret read"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.firehose.name} to read objectstorage-namespace in compartment id ${local.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.firehose.name} to read buckets in compartment id ${local.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.firehose.name} to read objectstorage-objects in compartment id ${local.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.firehose.name} to manage vault-secrets in compartment id ${local.compartment_id} where target.vault.id = '${local.vault_id}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.firehose.name} to use keys in compartment id ${local.compartment_id} where target.key.id = '${local.key_id}'"
  ]
}

# -----------------------------------------------------------------------------
# Functions Application
# -----------------------------------------------------------------------------
resource "oci_functions_application" "this" {
  count = var.create_function_app ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = var.function_app_display_name
  subnet_ids     = [local.subnet_id]
}

# -----------------------------------------------------------------------------
# Function (deployed via OCI deploy - image referenced)
# Note: Actual function code is deployed via 'fn deploy'. Terraform creates the
# function resource; fn deploy pushes the image and updates the function.
# -----------------------------------------------------------------------------
resource "oci_functions_function" "this" {
  count = var.create_function_app ? 1 : 0

  application_id                     = oci_functions_application.this[0].id
  display_name                       = var.function_display_name
  image                              = local.function_image
  memory_in_mbs                      = var.function_memory_mb
  timeout_in_seconds                 = var.function_timeout_seconds
  provisioned_concurrency_config {
    strategy = "NONE"
  }
  trace_config {
    is_enabled = false
  }

  config = {
    OCI_SOURCE_BUCKET       = local.source_bucket
    OCI_SOURCE_NAMESPACE    = var.create_bucket ? data.oci_objectstorage_namespace.ns.namespace : var.existing_bucket_namespace
    AWS_S3_BUCKET           = var.aws_s3_bucket_name
    AWS_S3_PREFIX           = var.aws_s3_prefix
    AWS_REGION              = var.aws_region
    AWS_ACCESS_KEY_SECRET_ID = local.aws_access_key_secret_id
    AWS_SECRET_KEY_SECRET_ID = local.aws_secret_key_secret_id
  }
}

# -----------------------------------------------------------------------------
# Events Rule - Trigger on Object Create
# -----------------------------------------------------------------------------
resource "oci_events_rule" "object_create" {
  count = var.create_event_rule ? 1 : 0

  compartment_id = local.compartment_id
  display_name   = var.event_rule_display_name
  description    = "Trigger Firehose function when object is created in source bucket"
  is_enabled     = true

  condition = jsonencode({
    eventType = ["com.oraclecloud.objectstorage.createobject"]
    data = {
      resourceName = [local.source_bucket]
    }
  })

  actions {
    action_type = "FAAS"
    is_enabled  = true
    description = "Invoke Firehose function"
    function_id = local.function_id
  }
}
