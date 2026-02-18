# oci-rclone-sync

OCI-to-AWS Cost Report Sync — syncs Oracle Cloud Usage Reports to AWS S3 via a VM running rclone (cron every 6h).

**Stack:** OpenTofu · OCI (VCN, NAT, Service Gateway, Vault, Compute) · Instance Principals · Rclone

**Compute:** VM.Standard.E6.Flex (AMD) by default; configurable OCPUs and memory. Use VM.Standard.A1.Flex for free tier.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         OCI Object Storage (Cross-Tenancy)                        │
│  Usage Reports in namespace "bling", bucket = tenancy OCID (Oracle-managed)      │
└────────────────────────────────────────────────┬────────────────────────────────┘
                                                  │
                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    VM (Private Subnet · rclone-worker)                            │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────────────┐   │
│  │ Rclone          │  │ OCI Unified      │  │ Monitoring/Email Alerting     │   │
│  │ Cron every 6h   │──│ Agent            │  │ On sync failure → publish to  │   │
│  │ Instance        │  │ /var/log/        │  │ OCI Notification Topic →      │   │
│  │ Principal auth  │  │ rclone-sync.log  │  │ email to alert_email_address  │   │
│  └────────┬────────┘  └────────┬─────────┘  └──────────────────────────────┘   │
└───────────┼────────────────────┼────────────────────────────────────────────────┘
            │                    │
            │ (via NAT/SGW)      │ (stream to OCI Logging)
            ▼                    ▼
┌───────────────────────┐  ┌─────────────────────┐
│ AWS S3                │  │ OCI Logging Service   │
│ Your cost reports     │  │ rclone-execution-log  │
│ bucket/prefix         │  │ (view in Console)     │
└───────────────────────┘  └─────────────────────┘
```

**Flow:** OCI Object Storage (Usage Reports) → VM (Rclone + Agent) → AWS S3. Logs stream to OCI Logging; sync failures trigger email alerts via the Notification Topic.

## Setup Flow

```
1. Prerequisites     → OpenTofu, OCI config (~/.oci/config), AWS IAM keys, email for alerts
2. Configure        → Copy tfvars.example, set region, tenancy, compartment, S3 bucket, alert_email_address
3. Deploy           → tofu init && tofu apply
4. Add secrets      → OCI Console: paste AWS keys into Vault secrets
5. Confirm alerts   → Check inbox and confirm OCI Subscription to receive alerts
6. Replace VM      → tofu taint instance && tofu apply (picks up keys)
7. Done             → Sync runs every 6h; logs in OCI Console or /var/log/rclone-sync.log
```

## Prerequisites

- **OpenTofu:** `brew install opentofu`
- **OCI:** `~/.oci/config` (DEFAULT profile). Set `region` and `tenancy_ocid` in tfvars.
- **AWS:** IAM user with `s3:PutObject`. Access key and secret key required.
- **Email address for alerts:** Used for sync-failure notifications via OCI Notification Service.

## Quick Start

### 1. Configure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: region, tenancy_ocid, compartment, aws_s3_*, aws_region, alert_email_address
```

Example `terraform.tfvars`:

```hcl
region       = "us-ashburn-1"
tenancy_ocid = "ocid1.tenancy.oc1..aaaa..."

create_compartment      = false
existing_compartment_id = "ocid1.compartment.oc1..aaaa..."
create_vcn              = true
create_subnet           = true
create_nat_gateway      = true
create_service_gateway  = true
create_vault            = true
create_key              = true
create_aws_secrets      = true

aws_access_key = "AKIA..."
aws_secret_key = "your-secret"
aws_s3_bucket_name = "my-aws-cost-reports"
aws_s3_prefix      = "oci-sync"
aws_region         = "us-east-1"

# Email alerts when sync fails
enable_monitoring   = true
alert_email_address = "you@example.com"
```

**Greenfield** (create all): `create_vcn = true`, `create_vault = true`, etc.  
**Brownfield** (use existing): `create_* = false`, set `existing_*_id` for each resource.

### 2. Deploy

```bash
tofu init
tofu apply
```

### 3. Add AWS secrets (required)

OpenTofu creates placeholder secrets. After apply:

1. **OCI Console → Identity & Security → Vault** → open `oci-aws-sync-vault`
2. **Secrets** → `oci-aws-sync-aws-access-key` → Create New Version → paste AWS Access Key
3. Repeat for `oci-aws-sync-aws-secret-key` with AWS Secret Key

### 4. Post-deployment: Confirm email subscription

**Check your inbox and confirm the OCI Subscription to receive alerts.** OCI sends a confirmation email for new notification topic subscriptions. Click the confirmation link so sync-failure alerts are delivered.

### 5. Replace VM (pick up secrets)

The VM fetches AWS keys from Vault at boot (cloud-init). After you add the secret versions, force a replace so it reboots with the real keys:

```bash
tofu taint oci_core_instance.rclone_sync && tofu apply
```

Check logs on VM: `tail -f /var/log/rclone-sync.log` — or in **OCI Console → Logging → Logs** when `enable_monitoring = true`.

### 6. Access via bastion (optional)

By default a bastion host is created for SSH access to the private rclone instance. Ensure your public key is at `~/.ssh/id_rsa.pub` (or set `bastion_ssh_public_key_path`).

After apply, use the output:

```bash
# One-liner (use bastion_ssh_command output):
ssh -J opc@<bastion_public_ip> opc@<instance_private_ip>

# Or set in ~/.ssh/config:
# Host oci-rclone-bastion
#   HostName <bastion_public_ip>
#   User opc
# Host oci-rclone
#   HostName <instance_private_ip>
#   User opc
#   ProxyJump oci-rclone-bastion
```

Set `create_bastion = false` in tfvars if you do not need bastion access. Bastion requires `create_vcn = true`.

---

**Note:** Cost Reports use bucket = Tenancy OCID in Oracle's `bling` namespace. No extra config needed.

## Troubleshooting

| Issue | Action |
|-------|--------|
| `cloud-init status: error` | Expected with older config — setup runs in background. Check `tail -f /var/log/cloud-init-bootstrap.log` |
| Bootstrap "Killed" in log | OOM — increase `instance_memory_gb` to 2+ in tfvars |
| sync.sh not found | Wait for bootstrap; `cloud-init status: done` is not required. Verify with `grep sync /etc/crontab` and `ls /usr/local/bin/sync.sh` |
| Sync failed | Check `/var/log/rclone-sync.log` on VM or OCI Logging |
| No email alerts | Confirm OCI Subscription in your inbox; verify `alert_email_address` in tfvars |
| OCI permission denied | Ensure `rclone-cross-tenancy-policy` has UsageReport Define + Endorse |
| AWS permission denied | Verify IAM has `s3:PutObject` on bucket |
| Image lookup empty | Try `instance_shape = "VM.Standard.E5.Flex"` (better availability in some regions) |
| TLS error (macOS) | `export SSL_CERT_FILE=$(brew --prefix)/etc/ca-certificates/cert.pem` |
