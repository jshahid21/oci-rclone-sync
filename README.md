# oci-rclone-sync

OCI-to-AWS Cost Report Sync — syncs Oracle Cloud Usage Reports to AWS S3 via a VM running rclone (cron every 6h).

**Stack:** OpenTofu · OCI (VCN, NAT, Service Gateway, Vault, Compute) · API Key + Instance Principal · Rclone

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
│  │ API key auth    │  │ rclone-sync.log  │  │ OCI Notification Topic →      │   │
│  │ (Vault: IP)     │  │                  │  │ email to alert_email_address  │   │
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

## Prerequisites

- **OpenTofu:** `brew install opentofu`
- **OCI:** `~/.oci/config` (DEFAULT profile)
- **AWS:** IAM user with `s3:PutObject`; access key + secret key
- **Email:** For sync-failure alerts via OCI Notifications

## Steps

### 1. Configure tfvars

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable | Required |
|----------|----------|
| `region`, `tenancy_ocid` | ✓ |
| `existing_compartment_id` (or `create_compartment`) | ✓ |
| `aws_s3_bucket_name`, `aws_s3_prefix`, `aws_region` | ✓ |
| `aws_access_key`, `aws_secret_key` (if `create_aws_secrets = true`) | ✓ |
| `alert_email_address` | ✓ |
| `oci_rclone_user_email` | ✓ (RFC 5322 format, e.g. `rclone-sync@example.com` or your-domain) |
| `oci_api_key_fingerprint`, `oci_api_private_key` | After step 3 |

### 2. First deploy

```bash
tofu init
tofu apply
```

Creates VM, IAM user `rclone-sync`, vault, and policies. OCI API key can be empty initially.

### 3. Add OCI API key

1. **Console** → Identity → Users → `rclone-sync` → API Keys → Add API Key
2. Generate key pair, download private key, copy fingerprint
3. In `terraform.tfvars`:
   ```hcl
   oci_api_key_fingerprint = "aa:bb:cc:dd:..."
   oci_api_private_key     = "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
   ```
4. Run `tofu apply` to store the key in Vault

### 4. Add AWS secrets (if `create_aws_secrets = true`)

1. **Console** → Identity & Security → Vault → `oci-aws-sync-vault`
2. Secrets → `oci-aws-sync-aws-access-key` → Create New Version → paste key
3. Repeat for `oci-aws-sync-aws-secret-key`

### 5. Replace VM (pick up secrets)

```bash
tofu taint oci_core_instance.rclone_sync && tofu apply
```

VM reboots and fetches AWS + OCI creds from Vault on each sync.

### 6. Confirm email subscription

**Check inbox** — OCI sends a confirmation for the notification subscription. Click the link so alerts are delivered.

### 7. Done

Sync runs every 6h. Logs: `/var/log/rclone-sync.log` on VM, or OCI Console → Logging when `enable_monitoring = true`.

---

**Greenfield:** `create_vcn = true`, `create_vault = true`, etc.  
**Brownfield:** `create_* = false`, set `existing_*_id` for each resource.

### Access via bastion (optional)

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

**Note:** Cost Reports use bucket = Tenancy OCID in Oracle's `bling` namespace. Rclone uses **API key auth** (instance principal does not work for bling); credentials are stored in Vault and fetched at sync time.

## Troubleshooting

| Issue | Action |
|-------|--------|
| `cloud-init status: error` | Expected with older config — setup runs in background. Check `tail -f /var/log/cloud-init-bootstrap.log` |
| Bootstrap "Killed" in log | OOM — increase `instance_memory_gb` to 2+ in tfvars |
| sync.sh not found | Wait for bootstrap; `cloud-init status: done` is not required. Verify with `grep sync /etc/crontab` and `ls /usr/local/bin/sync.sh` |
| Sync failed | Check `/var/log/rclone-sync.log` on VM or OCI Logging |
| "directory not found" (bling) | Cost reports are in tenancy **home region** — ensure `region` in tfvars matches. Reports may take 24–48h to appear. Verify policy in IAM. |
| No email alerts | Confirm OCI Subscription in your inbox; verify `alert_email_address` in tfvars |
| OCI permission denied | Ensure `rclone-cross-tenancy-policy` has Define + Endorse for rclone-sync-readers group; verify OCI API key in Vault |
| "primary email must be specified" | Set `oci_rclone_user_email` in tfvars (e.g. valid email for your identity domain) |
| AWS permission denied | Verify IAM has `s3:PutObject` on bucket |
| Image lookup empty | Try `instance_shape = "VM.Standard.E5.Flex"` (better availability in some regions) |
| TLS error (macOS) | `export SSL_CERT_FILE=$(brew --prefix)/etc/ca-certificates/cert.pem` |
