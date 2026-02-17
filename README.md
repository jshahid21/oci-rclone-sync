# OCI-to-AWS Sync (Deprecated)

> **Deprecated:** Use **[oci-rclone-sync](../oci-rclone-sync)** for syncing OCI Cost and Usage Reports to AWS S3 (VM + Rclone, supports cross-tenancy).

This project contains **shared infrastructure only** (VCN, Vault, secrets) with no consumer. The event-driven approach (OCI Functions + Python) was removed.

---

## Implementation: Use oci-rclone-sync

For OCI Usage Reports → AWS S3:

```bash
cd ../oci-rclone-sync
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars with: compartment_id, usage_report_tenancy_ocid,
# source_bucket_name, source_namespace, aws_s3_bucket_name, aws_region
cd infra
tofu init
tofu plan
tofu apply
```

See **[oci-rclone-sync/README.md](../oci-rclone-sync/README.md)** for full instructions.

---

## This Project: Tear Down

If you have existing state from the old event-driven setup:

1. **Update terraform.tfvars** – Remove any vars for: `create_bucket`, `source_bucket_name`, `existing_bucket_namespace`, `create_function_app`, `existing_function_app_id`, `existing_function_id`, `function_image`, `create_event_rule`, `event_rule_display_name`.

2. **Destroy resources:**

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars  # Or update your existing one
# Edit terraform.tfvars - remove deprecated variables
tofu init
tofu plan    # Will show deletions for Function, Events, Bucket, DG, Policy
tofu apply   # Confirm to destroy
```

---

## What Was Removed

- Python function (`functions/`)
- OCI Function, Events rule, Dynamic Group, Policy
- OCI source bucket
- Fn CLI and Docker setup scripts
