# =============================================================================
# OCI-to-AWS Sync - Hybrid Create vs Use Existing Variables
# =============================================================================

variable "region" {
  description = "OCI region (e.g., us-ashburn-1)"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

# -----------------------------------------------------------------------------
# Compartment
# -----------------------------------------------------------------------------
variable "create_compartment" {
  description = "Create a new compartment for OCI-to-AWS sync resources"
  type        = bool
  default     = false
}

variable "existing_compartment_id" {
  description = "Existing compartment OCID when create_compartment is false"
  type        = string
  default     = ""
}

variable "compartment_name" {
  description = "Name for the compartment when create_compartment is true"
  type        = string
  default     = "oci-aws-sync"
}

variable "compartment_description" {
  description = "Description for the compartment"
  type        = string
  default     = "Compartment for OCI-to-AWS sync"
}

# -----------------------------------------------------------------------------
# VCN & Networking
# -----------------------------------------------------------------------------
variable "create_vcn" {
  description = "Create a new VCN"
  type        = bool
  default     = false
}

variable "existing_vcn_id" {
  description = "Existing VCN OCID when create_vcn is false"
  type        = string
  default     = ""
}

variable "vcn_cidr" {
  description = "CIDR block for VCN when creating new"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  description = "DNS label for VCN"
  type        = string
  default     = "ociawssync"
}

variable "create_subnet" {
  description = "Create a new private subnet"
  type        = bool
  default     = false
}

variable "existing_subnet_id" {
  description = "Existing subnet OCID when create_subnet is false"
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "CIDR for private subnet when creating new"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_dns_label" {
  description = "DNS label for subnet"
  type        = string
  default     = "ociawssyncsub"
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------
variable "create_nat_gateway" {
  description = "Create a new NAT Gateway (for AWS/internet egress)"
  type        = bool
  default     = false
}

variable "existing_nat_gateway_id" {
  description = "Existing NAT Gateway OCID when create_nat_gateway is false"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Service Gateway
# -----------------------------------------------------------------------------
variable "create_service_gateway" {
  description = "Create a new Service Gateway (for OCI Object Storage)"
  type        = bool
  default     = false
}

variable "existing_service_gateway_id" {
  description = "Existing Service Gateway OCID when create_service_gateway is false"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Vault & Keys
# -----------------------------------------------------------------------------
variable "create_vault" {
  description = "Create a new Vault for storing AWS credentials"
  type        = bool
  default     = false
}

variable "existing_vault_id" {
  description = "Existing Vault OCID when create_vault is false"
  type        = string
  default     = ""
}

variable "create_key" {
  description = "Create a new KMS key for secret encryption"
  type        = bool
  default     = false
}

variable "existing_key_id" {
  description = "Existing KMS Key OCID when create_key is false"
  type        = string
  default     = ""
}

variable "vault_type" {
  description = "Vault type: DEFAULT or VIRTUAL_PRIVATE"
  type        = string
  default     = "DEFAULT"
}

# -----------------------------------------------------------------------------
# Secrets (AWS Credentials)
# -----------------------------------------------------------------------------
variable "create_aws_secrets" {
  description = "Create AWS Access Key and Secret Key secrets in Vault"
  type        = bool
  default     = false
}

variable "existing_aws_access_key_secret_id" {
  description = "Existing secret OCID for AWS Access Key when create_aws_secrets is false"
  type        = string
  default     = ""
}

variable "existing_aws_secret_key_secret_id" {
  description = "Existing secret OCID for AWS Secret Key when create_aws_secrets is false"
  type        = string
  default     = ""
}

variable "aws_access_key" {
  description = "AWS Access Key ID (used when create_aws_secrets is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key (used when create_aws_secrets is true)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# OCI Source (Usage Report bucket in cross-tenancy)
# -----------------------------------------------------------------------------
variable "source_bucket_name" {
  description = "OCI Usage Report bucket name (in cross-tenancy, namespace=bling)"
  type        = string
}

# -----------------------------------------------------------------------------
# Compute (Always Free Ampere A1)
# -----------------------------------------------------------------------------
variable "instance_shape" {
  description = "Compute shape (Always Free: VM.Standard.A1.Flex)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs for A1.Flex"
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memory in GB for A1.Flex"
  type        = number
  default     = 1
}

variable "instance_display_name" {
  description = "Display name for the compute instance"
  type        = string
  default     = "oci-aws-rclone-sync"
}

# -----------------------------------------------------------------------------
# AWS Destination
# -----------------------------------------------------------------------------
variable "aws_s3_bucket_name" {
  description = "AWS S3 bucket name for destination"
  type        = string
}

variable "aws_s3_prefix" {
  description = "Optional prefix/folder in S3 bucket"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for S3 bucket"
  type        = string
}
