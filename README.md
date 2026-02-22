# OCI Cost Reports → AWS S3 Sync

Syncs Oracle Cloud (OCI) cost and usage reports to an AWS S3 bucket. Runs automatically every 6 hours on a VM in OCI.

## What You Need Before Starting

| Requirement | Purpose |
|-------------|---------|
| **OpenTofu** | `brew install opentofu` (Mac) or [opentofu.org](https://opentofu.org/docs/intro/install/) |
| **OCI account** | API key in `~/.oci/config` (for `tofu apply` only; create via OCI Console → Profile → API Keys) |
| **AWS IAM user** | Access Key + Secret Key with S3 write permission |
| **S3 bucket** | Created in AWS; the sync will create a folder inside it |

## Quick Start (3 Steps)

### 1. Copy and edit the config file

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and fill in:

- `region`, `tenancy_ocid`, `existing_compartment_id` — from your OCI console
- `aws_s3_bucket_name`, `aws_region` — your S3 bucket and its region
- `aws_access_key`, `aws_secret_key` — AWS IAM user credentials (they go into OCI Vault, not on the VM)
- `alert_email_address` — get email when bootstrap, sync, or cron run fails

### 2. Run the setup

```bash
tofu init
tofu apply
```

Type `yes` when prompted. Wait a few minutes for the VM to start.

### 3. Verify

After apply, logs appear at `bastion_ssh_command`. SSH in and run:

```bash
sudo tail /var/log/rclone-sync.log
```

## How It Works

1. **OCI**: A VM runs in your compartment. No OCI API keys on the VM—it uses Instance Principal.
2. **Vault**: Your AWS keys are stored in OCI Vault. The VM retrieves them at sync time.
3. **Cron**: Every 6 hours, the VM syncs OCI cost reports (bling namespace) to your S3 bucket.

## Security (Financial Data)

- **VM**: No AWS keys on disk; keys are fetched from OCI Vault at sync time (memory only). OCI uses Instance Principal—no API keys on the VM.
- **Transit**: rclone uses HTTPS for OCI Object Storage and S3.
- **OCI Vault**: AWS keys are encrypted at rest with KMS.

**Important:** Terraform state and `terraform.tfvars` can contain plaintext AWS credentials. Use a remote encrypted backend for state and restrict access. See [ARCHITECTURE.md](ARCHITECTURE.md#8-security-details) for details.

## Common Tasks

| Task | Command / Location |
|------|--------------------|
| Check sync log | `sudo tail /var/log/rclone-sync.log` (on the VM) |
| SSH to VM | Use the `bastion_ssh_command` output after apply |
| See cron schedule | `sudo grep rclone /etc/crontab` |
| Run sync manually | `sudo /usr/local/bin/sync.sh` |

## Alerts

When `enable_monitoring = true` and `alert_email_address` is set, you get email alerts for:

- **Bootstrap failure** — dnf, rclone install, or first sync failed at VM boot. Check `/var/log/cloud-init-bootstrap.log`.
- **Sync failure** — credential fetch, rclone, or cron run failed. Check `/var/log/rclone-sync.log`.

**First-time setup:** OCI sends a confirmation email for the subscription. Click the link to activate alerts.

**Test alert** (on VM): `oci ons message publish --topic-id <topic_ocid> --body "Test" --auth instance_principal`

## AWS IAM Policy

Your IAM user needs S3 access. Example policy (replace `YOUR_BUCKET`):

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

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `directory not found` (bling) | Ensure `no_check_bucket = true` in rclone config; policy includes `read buckets` |
| `404` (Vault) | Policy needs `use secret-bundles` (not `secrets`) on the compartment |
| `invalid header` (S3) | Secret may have whitespace; trim on VM or re-store in Vault |
| No reports yet | Cost reports can take 24–48 hours; check correct OCI region |

---

## Architecture Recap

- **OCI**: Instance Principal (no API keys on VM). Dynamic group `rclone-dg` matches instances in your compartment. A-Team policy grants access to bling (usage-report) namespace.
- **AWS**: Keys stored in OCI Vault, fetched at sync time. No credentials in instance metadata.
- **Cron**: Every 6 hours (`0 */6 * * *`). Logs append to `/var/log/rclone-sync.log`.

**Maintainers:** See [ARCHITECTURE.md](ARCHITECTURE.md) for a file-by-file breakdown of components, maintenance tasks, and security details.
