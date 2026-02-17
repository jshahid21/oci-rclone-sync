# OCI-to-AWS Cost Report Sync

A "Set and Forget" utility that syncs Oracle Cloud Usage Reports (Cross-Tenancy) to AWS S3 using a lightweight VM and Rclone.

## Architecture

- **Compute:** Always Free Ampere A1 VM (runs `rclone` via cron every 6 hours).
- **Security:** OCI Instance Principals (Identity) + OCI Vault (AWS Keys).
- **Infrastructure:** OpenTofu (Hybrid: Create New or Use Existing Network).

## Prerequisites

1. **OpenTofu:** `brew install opentofu`
2. **AWS:** An IAM User with `s3:PutObject` permission. (Keep Access/Secret keys ready).
3. **OCI:** Permissions to manage Compute, Network, and Vault.

## Quick Start

### 1. Configure

Copy the example variables:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. You can choose to create new resources or use existing ones:

```hcl
# Example: "Hybrid" Setup
tenancy_ocid = "ocid1.tenancy..."
region       = "us-ashburn-1"

# Network (Use Existing)
create_vcn          = false
existing_subnet_id  = "ocid1.subnet..."

# Vault (Create New for Security)
create_vault = true

# OCI Source & AWS Destination
source_bucket_name   = "your-usage-report-bucket"
aws_s3_bucket_name  = "my-target-bucket"
aws_s3_prefix       = "oci-sync"
aws_region          = "us-east-1"
```

### 2. Deploy

```bash
tofu init
tofu apply
```

### 3. Add Secrets (Secure Step)

OpenTofu created a Vault and "Placeholder" secrets to keep your keys off your disk. You must update them manually:

1. Go to **OCI Console → Identity & Security → Vault**.
2. Click the new **oci-aws-sync-vault**.
3. Under **Secrets**, click **oci-aws-sync-aws-access-key**.
4. Click **Create New Version** → Paste your actual AWS Access Key.
5. Repeat for **oci-aws-sync-aws-secret-key**.

### 4. Verify

The VM will sync automatically every 6 hours. To test immediately:

Reboot the VM (to pick up the new keys you just added):

```bash
tofu taint oci_core_instance.rclone_sync
tofu apply
```

Check the logs:

```bash
# SSH into the VM (if you added an SSH key, otherwise check AWS S3)
tail -f /var/log/rclone-sync.log
```

## Troubleshooting

- **Sync Failed?** Check `/var/log/rclone-sync.log` on the VM.
- **Permission Denied?** Ensure the `rclone-cross-tenancy-policy` in OCI IAM has the `Define tenancy UsageReport` statement.
