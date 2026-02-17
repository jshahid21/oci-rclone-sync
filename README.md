# OCI-to-AWS Firehose Pipeline

A production-ready **Serverless Firehose** that streams files from OCI Object Storage to AWS S3 immediately upon creation. Uses OCI Events to trigger an OCI Function, which streams data directly (zero-disk) using `boto3.upload_fileobj`.

## Architecture

```
OCI Object Storage (oci-cost-reports)
         │
         │  Object Create Event
         ▼
   OCI Events Service
         │
         │  Triggers
         ▼
   OCI Function (Python)
   - Resource Principals (no API keys)
   - AWS creds from OCI Vault
   - Stream: get_object → upload_fileobj (no disk)
         │
         ▼
   AWS S3 Bucket
```

## Prerequisites

- **OCI:** Terraform, OCI CLI, Fn CLI (`fn`), Docker
- **AWS:** S3 bucket, IAM user with `s3:PutObject` (keys stored in OCI Vault)
- **Terraform:** OCI Provider >= 5.0

## Hybrid Terraform: Create vs Use Existing

Every major resource supports **either** creating new **or** using existing:

| Resource   | Create Variable       | Use Existing Variable       |
|-----------|------------------------|------------------------------|
| Compartment | `create_compartment`  | `existing_compartment_id`    |
| VCN       | `create_vcn`          | `existing_vcn_id`            |
| Subnet    | `create_subnet`       | `existing_subnet_id`         |
| NAT Gateway | `create_nat_gateway` | `existing_nat_gateway_id`   |
| Service Gateway | `create_service_gateway` | `existing_service_gateway_id` |
| Vault     | `create_vault`        | `existing_vault_id`          |
| KMS Key   | `create_key`          | `existing_key_id`            |
| AWS Secrets | `create_aws_secrets` | `existing_aws_access_key_secret_id` / `existing_aws_secret_key_secret_id` |
| Bucket    | `create_bucket`       | `existing_bucket_namespace` + `source_bucket_name` |
| Function App | `create_function_app` | `existing_function_app_id` + `existing_function_id` |

**Pattern:** For each component, set `create_X = true` to create, or `create_X = false` and provide `existing_X_id`.

---

## Example: Greenfield (Create Everything)

Use when you want Terraform to provision the full stack.

**`terraform.tfvars`:**

```hcl
region   = "us-ashburn-1"
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaa..."

# Create new compartment
create_compartment   = true
existing_compartment_id = ""

# Create new network
create_vcn           = true
existing_vcn_id      = ""
create_subnet        = true
existing_subnet_id   = ""
create_nat_gateway   = true
existing_nat_gateway_id = ""
create_service_gateway = true
existing_service_gateway_id = ""

# Create new Vault and Key
create_vault = true
existing_vault_id = ""
create_key   = true
existing_key_id = ""

# Create AWS secrets in Vault (provide keys)
create_aws_secrets = true
existing_aws_access_key_secret_id = ""
existing_aws_secret_key_secret_id = ""
aws_access_key = "AKIA..."
aws_secret_key = "your-secret-key"

# Use existing bucket (or create with create_bucket = true)
create_bucket = false
existing_bucket_namespace = "your-tenancy-namespace"
source_bucket_name = "oci-cost-reports"

# Create Function App
create_function_app = true
existing_function_app_id = ""
existing_function_id = ""

# Events
create_event_rule = true

# AWS destination
aws_s3_bucket_name = "my-aws-cost-reports"
aws_s3_prefix     = "oci-sync"
aws_region        = "us-east-1"
```

---

## Example: Brownfield (Use Existing Resources)

Use when you already have VCN, subnet, Vault, and want to attach the Firehose.

**`terraform.tfvars`:**

```hcl
region   = "us-ashburn-1"
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaa..."

# Use existing compartment
create_compartment   = false
existing_compartment_id = "ocid1.compartment.oc1..aaaaaaaa..."

# Use existing network (assume route tables and gateways are configured)
create_vcn           = false
existing_vcn_id      = "ocid1.vcn.oc1.iad.aaaaaaa..."

create_subnet        = false
existing_subnet_id   = "ocid1.subnet.oc1.iad.aaaaaaa..."

create_nat_gateway   = false
existing_nat_gateway_id = ""

create_service_gateway = false
existing_service_gateway_id = ""

# Use existing Vault and Key
create_vault = false
existing_vault_id = "ocid1.vault.oc1.iad.aaaaaaa..."
create_key   = false
existing_key_id = "ocid1.key.oc1.iad.aaaaaaa..."

# Use existing AWS secrets (already in Vault)
create_aws_secrets = false
existing_aws_access_key_secret_id = "ocid1.vaultsecret.oc1.iad.aaaaaaa..."
existing_aws_secret_key_secret_id = "ocid1.vaultsecret.oc1.iad.bbbbbbb..."

# Use existing bucket
create_bucket = false
existing_bucket_namespace = "axabcdefghij"
source_bucket_name = "oci-cost-reports"

# Create new Function App in existing subnet
create_function_app = true
existing_function_app_id = ""
existing_function_id = ""

create_event_rule = true

aws_s3_bucket_name = "my-aws-cost-reports"
aws_s3_prefix     = ""
aws_region        = "us-east-1"
```

---

## Deployment Steps

### 1. Configure Terraform

Copy the example and adjust:

```bash
cd oci-aws-firehose/infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Apply Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Deploy the Function

Configure OCI Registry auth for Fn, then deploy:

```bash
# One-time: create Docker registry secret
# Get your OCI Auth Token: OCI CLI → User Settings → Auth Tokens
fn create context oci --provider oracle
fn use context oci
fn update context oracle.compartment-id <compartment_ocid>
fn update context oracle.registry <region>.ocir.io/<tenancy_namespace>/oci-aws-firehose

cd ../functions
fn deploy --app oci-aws-firehose
```

### 4. Update Terraform with Function Image (if needed)

If Terraform created the function with a placeholder image, `fn deploy` updates it. Otherwise, set `function_image` in tfvars to the actual OCIR image and re-apply to sync config:

```hcl
function_image = "us-ashburn-1.ocir.io/axabcdefghij/oci-aws-firehose/firehose-handler:0.0.1"
```

### 5. Test

Upload an object to the OCI bucket:

```bash
oci os object put -bn oci-cost-reports --file test.csv --name reports/test.csv
```

Verify the object appears in the AWS S3 bucket.

---

## Security

- **Identity:** OCI Resource Principals (Dynamic Group) — no hardcoded OCI API keys
- **AWS Credentials:** Stored in OCI Vault, retrieved at runtime by the function
- **Network:** Function runs in a private subnet with NAT (AWS) and Service Gateway (OCI Object Storage)
- **Zero-Disk:** Data is streamed directly from OCI to S3; nothing is written to the function's filesystem

---

## Project Structure

```
oci-aws-firehose/
├── infra/
│   ├── main.tf        # Resources with create vs existing logic
│   ├── variables.tf   # Booleans and existing IDs
│   ├── outputs.tf     # Resolved IDs
│   └── provider.tf
├── functions/
│   ├── func.py        # Handler with streaming logic
│   ├── func.yaml      # Fn Project config
│   └── requirements.txt
└── README.md
```

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| Auth failed / Dynamic Group | Policy allows `fnfunc` in compartment; Dynamic Group matching rule includes your function |
| Cannot read Vault secret | Policy allows `manage vault-secrets` and `use keys` for the vault/key |
| No internet (AWS) | Private subnet route table routes `0.0.0.0/0` → NAT Gateway |
| No OCI Object Storage | Service Gateway route for Object Storage CIDR |
| Event not firing | Events rule `resourceName` matches bucket name; rule is enabled |
