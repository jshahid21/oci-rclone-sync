# Deployment Guide: OCI-AWS Firehose

This guide walks through installing prerequisites, configuring OCI and Terraform, and deploying the infrastructure.

---

## 1. Prerequisites

Install the following on your machine:

| Tool | Purpose | Install |
|------|---------|---------|
| **Terraform** >= 1.0 | Infrastructure as code | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| **OCI CLI** | OCI authentication & Object Storage | [OCI CLI Install](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) |
| **Fn CLI** | Deploy OCI Functions | [fnproject.io](https://fnproject.io/tutorials/local/install/) |
| **Docker** | Build function container images | [docker.com](https://docs.docker.com/get-docker/) |

### Install Docker & Fn (macOS)

```bash
./scripts/install-fn-docker.sh
```

This installs Docker Desktop (via Homebrew) and Fn CLI. Start Docker Desktop after install.

### Configure Fn for OCI

After Terraform has created the Functions app:

```bash
# With compartment from terraform output
cd infra && terraform output compartment_id
OCI_COMPARTMENT_ID=$(terraform output -raw compartment_id) ./scripts/configure-fn-oci.sh

# Or interactive (script will prompt)
./scripts/configure-fn-oci.sh
```

### Quick check

```bash
./scripts/check-prereqs.sh
```

---

## 2. OCI Config

The Terraform OCI provider and OCI CLI use the same config file at `~/.oci/config`.

### Create API Key (one-time)

1. **OCI Console** → Profile (top-right) → **User Settings**
2. **API Keys** → **Add API Key**
3. **Generate API Key Pair** → Download private key
4. Save private key as `~/.oci/oci_api_key.pem`
5. Copy the Configuration (tenancy OCID, user OCID, fingerprint)

### Create config file

```bash
mkdir -p ~/.oci
cp config/oci-config.template ~/.oci/config
chmod 600 ~/.oci/config
```

Edit `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=aa:bb:cc:dd:...
tenancy=ocid1.tenancy.oc1..aaaa...
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

### Or use `oci setup config` (interactive)

```bash
oci setup config
```

### Verify OCI auth

```bash
oci iam region list
```

---

## 3. Terraform Variables

Create `terraform.tfvars` from the example:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values. Key variables:

| Variable | Description |
|----------|-------------|
| `tenancy_ocid` | Your OCI tenancy OCID |
| `region` | OCI region (e.g. `us-ashburn-1`) |
| `aws_access_key` / `aws_secret_key` | AWS IAM user with `s3:PutObject` (when `create_aws_secrets = true`) |
| `aws_s3_bucket_name` | Destination S3 bucket name |
| `aws_region` | AWS region for S3 |
| `existing_bucket_namespace` | From `oci os ns get` (when using existing bucket) |
| `source_bucket_name` | OCI source bucket (e.g. `oci-cost-reports`) |

**Greenfield** (create everything): Set `create_* = true` for VCN, subnet, vault, key, etc.

**Brownfield** (use existing): Set `create_* = false` and provide `existing_*_id` for each.

---

## 4. Run Setup Script

```bash
./scripts/setup.sh
```

This will:

- Check prerequisites
- Create `terraform.tfvars` from example (if missing)
- Run `terraform init`

---

## 5. Deploy Infrastructure

```bash
cd infra

# Review plan
terraform plan

# Apply (creates VCN, subnet, vault, function app, events rule, etc.)
terraform apply
```

---

## 6. Deploy the Function

The function runs as a container in OCI Functions. You need to build and push it to OCI Container Registry (OCIR).

### Configure Fn for OCI

```bash
# Create Fn context for OCI
fn create context oci --provider oracle
fn use context oci

# Set compartment (from terraform output or your compartment OCID)
fn update context oracle.compartment-id <your_compartment_ocid>

# Set registry: <region>.ocir.io/<tenancy_namespace>/oci-aws-firehose
# Get tenancy namespace: oci os ns get
fn update context oracle.registry us-ashburn-1.ocir.io/<tenancy_namespace>/oci-aws-firehose
```

### OCIR Auth (Fn needs to push images)

Option A: **Auth Token**

1. OCI Console → Profile → Auth Tokens → Generate Token
2. `fn update context oracle.registry us-ashburn-1.ocir.io/<namespace>/oci-aws-firehose`
3. When prompted, use: `<tenancy_namespace>/<oci_username>` and the auth token as password

Option B: **Docker login**

```bash
docker login us-ashburn-1.ocir.io
# Username: <tenancy_namespace>/<oci_username>
# Password: <auth_token>
```

### Deploy function

```bash
cd functions
fn deploy --app oci-aws-firehose
```

---

## 7. Sync Terraform with Function Image (if needed)

If Terraform created the function with an empty/placeholder image, update the image after `fn deploy`:

1. Get the image URI from `fn deploy` output (e.g. `us-ashburn-1.ocir.io/namespace/oci-aws-firehose/firehose-handler:0.0.1`)
2. Add to `terraform.tfvars`:

   ```hcl
   function_image = "us-ashburn-1.ocir.io/<namespace>/oci-aws-firehose/firehose-handler:0.0.1"
   ```

3. `terraform apply` to sync

---

## 8. Test

Upload an object to the OCI source bucket:

```bash
echo "test" > test.csv
oci os object put -bn oci-cost-reports --file test.csv --name reports/test.csv
```

Check that it appears in the AWS S3 bucket (with optional prefix).

---

## Environment Variables (Alternative to OCI Config)

You can use environment variables instead of a config file:

```bash
export OCI_CLI_USER=<user_ocid>
export OCI_CLI_FINGERPRINT=<fingerprint>
export OCI_CLI_TENANCY=<tenancy_ocid>
export OCI_CLI_REGION=us-ashburn-1
export OCI_CLI_KEY_FILE=~/.oci/oci_api_key.pem
```

Terraform OCI provider picks these up automatically.

---

## Project-Local OCI Config

To use a config file in the project (not `~/.oci/config`):

```bash
export OCI_CLI_CONFIG_FILE="$(pwd)/config/oci-config"
# Then copy and edit config/oci-config
```
