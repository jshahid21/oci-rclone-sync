# OCI-to-AWS Cost Report Sync

A "Set and Forget" utility that syncs Oracle Cloud Usage Reports (Cross-Tenancy) to AWS S3 using a lightweight VM and Rclone.

## Architecture

- **Compute:** Always Free Ampere A1 VM (runs `rclone` via cron every 6 hours).
- **Security:** OCI Instance Principals (Identity) + OCI Vault (AWS Keys).
- **Infrastructure:** OpenTofu with **Hybrid** logic: create new resources (Greenfield) or use existing ones (Brownfield).

## Prerequisites

1. **OpenTofu:** `brew install opentofu`
2. **AWS:** An IAM User with `s3:PutObject` permission. Keep Access Key and Secret Key ready.
3. **OCI:** Permissions to manage Compute, Network, and Vault.

## Greenfield vs Brownfield

| Mode | Use Case | Variables |
|------|----------|-----------|
| **Greenfield** | Create everything from scratch | `create_vcn = true`, `create_vault = true`, etc. |
| **Brownfield** | Use existing VCN, Subnet, Vault | `create_* = false`, `existing_*_id = "ocid1..."` |

## Quick Start

### 1. Configure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. See examples below for both modes.

**Greenfield (Create All):**

```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaa..."
region       = "us-ashburn-1"

create_vcn            = true
create_subnet         = true
create_nat_gateway    = true
create_service_gateway = true
create_vault          = true
create_key            = true
create_aws_secrets    = true

source_bucket_name   = "your-usage-report-bucket"
aws_s3_bucket_name   = "my-target-bucket"
aws_s3_prefix        = "oci-sync"
aws_region           = "us-east-1"
```

**Brownfield (Use Existing):**

```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaa..."
region       = "us-ashburn-1"

create_vcn           = false
existing_vcn_id      = "ocid1.vcn..."
create_subnet        = false
existing_subnet_id   = "ocid1.subnet..."
create_nat_gateway   = false
existing_nat_gateway_id = "ocid1.natgateway..."
create_service_gateway = false
existing_service_gateway_id = "ocid1.servicegateway..."
create_vault         = false
existing_vault_id    = "ocid1.vault..."
create_key           = false
existing_key_id      = "ocid1.key..."
create_aws_secrets   = false
existing_aws_access_key_secret_id = "ocid1.vaultsecret..."
existing_aws_secret_key_secret_id = "ocid1.vaultsecret..."

source_bucket_name   = "your-usage-report-bucket"
aws_s3_bucket_name   = "my-target-bucket"
aws_s3_prefix        = "oci-sync"
aws_region           = "us-east-1"
```

### 2. Deploy

```bash
tofu init
tofu apply
```

### 3. Add Secrets (Required Step)

OpenTofu creates a Vault and **placeholder** secrets so your AWS keys never touch disk. You must update them manually after `tofu apply`:

1. Go to **OCI Console → Identity & Security → Vault**.
2. Open **oci-aws-sync-vault**.
3. Under **Secrets**, click **oci-aws-sync-aws-access-key** → **Create New Version** → paste your AWS Access Key.
4. Repeat for **oci-aws-sync-aws-secret-key** with your AWS Secret Key.

### 4. Verify

The VM syncs automatically every 6 hours. To test immediately, force a new instance (picks up the keys):

```bash
tofu taint oci_core_instance.rclone_sync
tofu apply
```

Check logs on the VM:

```bash
tail -f /var/log/rclone-sync.log
```

## Important: tenancy_ocid and Source Sync

- **`tenancy_ocid`** is used as the `compartment` in the OCI rclone remote. This gives Instance Principals the correct auth context when accessing the cross-tenancy Usage Report bucket.
- **`source_bucket_name`** is the actual bucket name (in Oracle's `bling` namespace) where your Cost Reports are stored.

## Troubleshooting

| Issue | Action |
|-------|--------|
| Sync failed | Check `/var/log/rclone-sync.log` on the VM. |
| Permission denied on OCI | Ensure `rclone-cross-tenancy-policy` has the `Define tenancy UsageReport` and `Endorse` statements. |
| AWS permission denied | Verify IAM user has `s3:PutObject` on the destination bucket. |
