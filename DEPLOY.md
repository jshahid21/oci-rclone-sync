# OCI-to-AWS Sync Deployment

## Prerequisites

- **OpenTofu** (or Terraform) >= 1.5
- **OCI CLI** configured (`~/.oci/config`) with sufficient privileges
- AWS S3 bucket created in the target region

## Steps

### 1. Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `region`, `tenancy_ocid`
- Network: set `create_vcn`, `create_subnet`, `create_nat_gateway`, `create_service_gateway` (or use `existing_*_id`)
- Vault: `create_vault`, `create_key`, `create_aws_secrets` (or existing IDs)
- **`source_bucket_name`** – OCI Usage Report bucket name
- **`aws_s3_bucket_name`**, **`aws_s3_prefix`**, **`aws_region`**
- If `create_aws_secrets = true`, provide `aws_access_key` and `aws_secret_key`

### 2. Apply

```bash
tofu init
tofu plan
tofu apply
```

### 3. Post-Apply

1. **AWS Keys:** If you created secrets but did not provide keys in tfvars, add the secret content via OCI Console (Vault → Secrets).

2. **Cross-Tenancy:** The policy in `iam.tf` uses:
   - `Define tenancy UsageReport as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq`
   - `Endorse dynamic-group rclone-dg to read objects/buckets in tenancy UsageReport`  
   These policies must be effective in the Usage Report tenancy. If provisioning fails due to cross-tenancy policy limitations, create the endorse policies manually in the Usage Report tenancy.

### 4. Verify

- Check instance: `oci compute instance get --instance-id <instance_id>`
- SSH (via bastion) and inspect: `/var/log/rclone-sync.log`, `/usr/local/bin/sync.sh`
