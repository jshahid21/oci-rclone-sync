# OCI-to-AWS Sync (VM + Rclone)

Syncs **OCI Cost and Usage Reports** from Oracle's cross-tenancy bucket to **AWS S3** using a Compute VM running Rclone on a schedule. Supports cross-tenancy access where Event Rules are not available.

## Architecture

- **Compute:** Always Free Ampere A1 (`VM.Standard.A1.Flex`) in a private subnet
- **Rclone:** Syncs from OCI Object Storage (Usage Report tenancy, namespace `bling`) to AWS S3
- **Auth:** Instance Principals for OCI; AWS credentials stored in OCI Vault, retrieved at sync time
- **Schedule:** Cron every 6 hours (`0 */6 * * *`)

## Prerequisites

- **OpenTofu** (or Terraform) >= 1.5
- **OCI CLI** configured (`~/.oci/config`) for provisioning
- OCI tenancy with permissions to create VCN, Compute, Vault, IAM policies
- AWS S3 bucket for the destination

## Quick Start

1. **Configure variables**
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Apply**
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

3. **Post-apply**
   - If `create_aws_secrets = true`, paste your AWS keys into the secrets in OCI Console, or re-apply with `aws_access_key` and `aws_secret_key` set
   - Cross-tenancy policies must exist in the Usage Report tenancy (or be created manually there) to endorse your dynamic group

See [DEPLOY.md](DEPLOY.md) for detailed deployment steps.

## Variables

| Variable | Description |
|----------|-------------|
| `source_bucket_name` | OCI Usage Report bucket name (cross-tenancy, namespace=bling) |
| `aws_s3_bucket_name` | AWS S3 bucket name for destination |
| `aws_s3_prefix` | Optional S3 prefix/folder |
| `aws_region` | AWS region (e.g., us-east-1) |
| `create_*` / `existing_*_id` | Hybrid create vs use existing for VCN, subnet, NAT, SGW, Vault, secrets |

## Outputs

- `instance_id` - Compute instance OCID
- `instance_private_ip` - Private IP of the sync VM
- `dynamic_group_name` - Dynamic group for Instance Principals
- `compartment_id`, `vcn_id`, `subnet_id`, `vault_id`, etc.

## Cross-Tenancy

The policy in `iam.tf` references Oracle's Usage Report tenancy. **Define** and **Endorse** policies are typically created in the tenancy that owns the resources. If your tenancy cannot create cross-tenancy policies, you may need to request Oracle to add the endorsement in the Usage Report tenancy.
