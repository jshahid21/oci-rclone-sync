# oci-rclone-sync

Sync OCI cost reports (bling namespace) to AWS S3. Runs on a VM in OCI with rclone on a 6-hour cron.

**Stack:** OpenTofu · OCI (VCN, NAT, Vault, Compute) · Rclone

## Architecture

```
OCI bling (cost reports)  →  VM (rclone + cron)  →  AWS S3
```

- VM in private subnet, egress via NAT + Service Gateway
- **100% Instance Principal:** OCI auth via dynamic group (A-Team usage-report policy for bling); no API keys
- **AWS credentials:** Stored in OCI Vault, fetched at runtime via instance principal
- Sync every 6h; optional email alerts on failure

## Prerequisites

- **OpenTofu:** `brew install opentofu`
- **OCI:** `~/.oci/config` with DEFAULT profile (for Terraform apply only)
- **AWS:** IAM user with S3 access; keys stored in OCI Vault
- **Email:** For sync-failure alerts (optional)

## Quick Start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: region, tenancy_ocid, compartment, aws_*, existing_*_secret_id (if brownfield)

tofu init
tofu apply
```

**Single apply:** No API keys needed. The VM uses Instance Principal for OCI and fetches AWS keys from Vault at runtime.

## Security

**How credentials are passed to the sync VM:**

| Credential | Method | Where it lives |
|------------|--------|----------------|
| **OCI auth** | Instance Principal (dynamic group) | No keys—VM identity grants access to bling namespace via A-Team cross-tenancy policy |
| **AWS access key + secret** | OCI Vault, fetched at sync time | Stored in Vault; VM fetches via `oci secrets secret-bundle get --auth instance_principal` |

**Implications:**
- No credentials in instance metadata or Terraform state
- Terraform state does not contain AWS keys or OCI private keys
- Vault stores AWS keys; dynamic group needs `read secret-bundles` on compartment

## Configuration

| Variable | Required |
|----------|----------|
| `region`, `tenancy_ocid`, `existing_compartment_id` | ✓ |
| `aws_s3_bucket_name`, `aws_s3_prefix`, `aws_region` | ✓ |
| `aws_access_key`, `aws_secret_key` | ✓ (when create_aws_secrets) |
| `existing_aws_access_key_secret_id`, `existing_aws_secret_key_secret_id` | ✓ (when create_aws_secrets = false) |
| `alert_email_address` | Optional (for sync-failure email alerts) |

## AWS IAM Policy

The IAM user needs S3 access. Example policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::YOUR_BUCKET",
      "arn:aws:s3:::YOUR_BUCKET/*"
    ]
  }]
}
```

## SSH Access (Bastion)

Bastion is created by default. After apply:

```bash
ssh -J opc@<bastion_public_ip> opc@<instance_private_ip>
```

Logs: `/var/log/rclone-sync.log`

## Troubleshooting

| Issue | Action |
|-------|--------|
| `403 Forbidden` (bling) | Ensure A-Team policy is applied: `Define tenancy usage-report` + `Endorse dynamic-group rclone-dg to read objects in tenancy usage-report` |
| `404` (Vault secret fetch) | Policy must use `read secret-bundles` (not `secrets`). Check IAM policy on compartment. |
| `403 Forbidden` (S3) | Add `s3:GetObject` to IAM policy (rclone uses it for HeadObject). |
| No bling data | Reports are in tenancy home region. Set `region` correctly; reports may take 24–48h. |
