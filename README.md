# OCI-to-AWS Firehose

Streams files from OCI Object Storage to AWS S3 on object creation. OCI Events triggers an OCI Function that streams directly (zero-disk) via `boto3.upload_fileobj`.

## Architecture

```
OCI Object Storage     →  Events  →  OCI Function  →  AWS S3
(oci-cost-reports)         │      (Resource Principals,
                            │       AWS creds from Vault)
```

## Why OpenTofu?

OpenTofu is the preferred IaC tool for OCI due to licensing alignment. Oracle recommends OpenTofu for Oracle Cloud deployments; it is fully compatible with Terraform configuration and the OCI provider.

## Prerequisites

| Tool | Purpose |
|------|---------|
| OpenTofu >= 1.5 | Infrastructure |
| OCI CLI | Auth & Object Storage |
| Docker | Build function images |
| Fn CLI | Deploy OCI Functions |
| AWS | S3 bucket; IAM user with `s3:PutObject` |

---

## Implementation Steps

### 1. Install Tools

```bash
# macOS
brew install opentofu
brew install oci-cli
brew install --cask docker    # Then: open -a Docker
brew install fn
```

OpenTofu: [Installation Guide](https://opentofu.org/docs/intro/install/)

### 2. Configure OCI

- **OCI Console** → Profile → User Settings → API Keys → Add API Key
- Download private key → save as `~/.oci/oci_api_key.pem`
- Create `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=aa:bb:cc:dd:...
tenancy=ocid1.tenancy.oc1..aaaa...
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

Verify: `oci iam region list`

### 3. Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with:
#   tenancy_ocid, region
#   aws_access_key, aws_secret_key (if create_aws_secrets = true)
#   aws_s3_bucket_name, aws_region
#   existing_bucket_namespace (oci os ns get), source_bucket_name
```

Or run: `./scripts/setup.sh` (creates tfvars, runs `tofu init`)

### 4. Apply Infrastructure

```bash
cd infra
tofu init
tofu plan
tofu apply
```

Note compartment OCID from output for Step 6.

### 5. Authenticate to OCIR

- **OCI Console** → Profile → Auth Tokens → Generate Token
- Docker login:

```bash
oci os ns get --query 'data' --raw-output   # Get namespace
docker login us-ashburn-1.ocir.io
# Username: <namespace>/<oci_username>
# Password: <auth_token>
```

### 6. Configure Fn and Deploy Function

```bash
# From project root
OCI_COMPARTMENT_ID=$(cd infra && tofu output -raw compartment_id) ./scripts/configure-fn-oci.sh

cd functions
fn deploy --app oci-aws-firehose
```

### 7. Sync Function Image (if needed)

If OpenTofu created the function with a placeholder image, add the deployed image to `infra/terraform.tfvars` and re-apply:

```hcl
function_image = "us-ashburn-1.ocir.io/<namespace>/oci-aws-firehose/firehose-handler:0.0.1"
```

```bash
cd infra && tofu apply
```

### 8. Test

```bash
echo "test" > test.csv
oci os object put -bn oci-cost-reports --file test.csv --name reports/test.csv
```

Verify the file appears in the AWS S3 bucket.

---

## Create vs Use Existing

Each resource can be created by OpenTofu or use an existing one. Set `create_X = true` to create, or `create_X = false` with `existing_X_id` to use existing.

| Resource | Create | Use Existing |
|----------|--------|---------------|
| Compartment | `create_compartment` | `existing_compartment_id` |
| VCN / Subnet | `create_vcn`, `create_subnet` | `existing_vcn_id`, `existing_subnet_id` |
| Vault / Key | `create_vault`, `create_key` | `existing_vault_id`, `existing_key_id` |
| AWS Secrets | `create_aws_secrets` | `existing_aws_access_key_secret_id`, `existing_aws_secret_key_secret_id` |
| Bucket | `create_bucket` | `existing_bucket_namespace`, `source_bucket_name` |
| Function App | `create_function_app` | `existing_function_app_id`, `existing_function_id` |

See `infra/terraform.tfvars.example` for full examples (greenfield and brownfield).

---

## Project Structure

```
oci-aws-firehose/
├── infra/           # OpenTofu (main.tf, variables.tf, outputs.tf)
├── functions/       # Python handler (func.py, func.yaml)
├── config/          # OCI config template
├── scripts/         # setup.sh, configure-fn-oci.sh, check-prereqs.sh
└── docs/            # DEPLOY.md, FN-DOCKER-SETUP.md
```

---

## Security

- **OCI:** Resource Principals (Dynamic Group) — no API keys in code
- **AWS:** Credentials in OCI Vault, fetched at runtime
- **Network:** Function in private subnet (NAT → AWS, Service Gateway → OCI)
- **Data:** Streamed OCI → S3; nothing written to disk

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| Auth failed | Dynamic Group policy includes `fnfunc` in compartment |
| Vault access | Policy allows `manage vault-secrets` and `use keys` |
| No AWS egress | Route table: `0.0.0.0/0` → NAT Gateway |
| No OCI Object Storage | Service Gateway route for Object Storage CIDR |
| Event not firing | Events rule `resourceName` matches bucket; rule enabled |
| `fn deploy` fails | Run `docker login <region>.ocir.io` |
