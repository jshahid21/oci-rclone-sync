# oci-rclone-sync

OCI-to-AWS Cost Report Sync — syncs Oracle Cloud Usage Reports to AWS S3 via a VM running rclone (cron every 6h).

**Stack:** OpenTofu · OCI (VCN, NAT, Service Gateway, Vault, Compute) · Instance Principals · Rclone

**Compute:** VM.Standard.E6.Flex (AMD) by default; configurable OCPUs and memory. Use VM.Standard.A1.Flex for free tier.

## Setup Flow

```
1. Prerequisites     → OpenTofu, OCI config (~/.oci/config), AWS IAM keys
2. Configure        → Copy tfvars.example, set region, tenancy, compartment, S3 bucket
3. Deploy            → tofu init && tofu apply
4. Add secrets       → OCI Console: paste AWS keys into Vault secrets
5. Replace VM        → tofu taint instance && tofu apply (picks up keys)
6. Done             → Sync runs every 6h; check /var/log/rclone-sync.log
```

## Prerequisites

- **OpenTofu:** `brew install opentofu`
- **OCI:** `~/.oci/config` (DEFAULT profile). Set `region` and `tenancy_ocid` in tfvars.
- **AWS:** IAM user with `s3:PutObject`. Access key and secret key required.

## Quick Start

### 1. Configure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: region, tenancy_ocid, compartment_id, aws_s3_*, aws_region
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

### 4. Verify

The VM fetches AWS keys from Vault at boot (cloud-init). After you add the secret versions, force a replace so it reboots with the real keys:

```bash
tofu taint oci_core_instance.rclone_sync && tofu apply
```

Check logs on VM: `tail -f /var/log/rclone-sync.log`

---

**Note:** Cost Reports use bucket = Tenancy OCID in Oracle's `bling` namespace. No extra config needed.

## Troubleshooting

| Issue | Action |
|-------|--------|
| Sync failed | Check `/var/log/rclone-sync.log` on VM |
| OCI permission denied | Ensure `rclone-cross-tenancy-policy` has UsageReport Define + Endorse |
| AWS permission denied | Verify IAM has `s3:PutObject` on bucket |
| Image lookup empty | Try `instance_shape = "VM.Standard.E5.Flex"` (better availability in some regions) |
| TLS error (macOS) | `export SSL_CERT_FILE=$(brew --prefix)/etc/ca-certificates/cert.pem` |
