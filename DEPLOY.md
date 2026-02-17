# OCI-to-AWS Sync Deployment

**This project is deprecated.** Use **[oci-rclone-sync](../oci-rclone-sync)** for OCI Usage Reports → AWS S3.

---

## Implementation: oci-rclone-sync

1. **Prerequisites:** OpenTofu, OCI CLI, OCI config (`~/.oci/config`)

2. **Configure:**
   ```bash
   cd oci-rclone-sync/infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit: compartment_id, usage_report_tenancy_ocid, source_bucket_name,
   #       source_namespace, aws_s3_bucket_name, aws_region
   ```

3. **Apply:**
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

4. **Post-apply:** Paste AWS keys into Vault secrets (OCI Console). Add Admit/Endorse policy in Usage Report tenancy. See oci-rclone-sync/README.md.
