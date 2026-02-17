# Fn & Docker Setup for OCI-AWS Firehose

Install and configure Docker and Fn CLI to deploy the OCI Function.

---

## 1. Install Docker (macOS)

**Option A: Docker Desktop (recommended)**

1. Download: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
2. Install the `.dmg` and open Docker from Applications
3. Wait for Docker to start (whale icon in menu bar)

**Option B: Homebrew**

```bash
brew install --cask docker
# Then: Open Docker from Applications
open -a Docker
```

Verify:

```bash
docker --version
docker info   # Should show "Server Version" if daemon is running
```

---

## 2. Install Fn CLI (macOS)

**Option A: Homebrew**

```bash
brew update
brew install fn
```

**Option B: Install script**

```bash
curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
```

Verify:

```bash
fn version
```

---

## 3. Configure Fn for OCI

Run after **Terraform has created the Functions app** (you need the compartment OCID):

```bash
./scripts/configure-fn-oci.sh
```

Or with values pre-set:

```bash
cd infra
export OCI_COMPARTMENT_ID=$(terraform output -raw compartment_id)
export OCI_REGION="us-ashburn-1"   # or your region
cd ..
./scripts/configure-fn-oci.sh
```

The script will:
- Create Fn context `oci` with Oracle provider
- Set compartment ID (where Functions app lives)
- Set registry: `us-ashburn-1.ocir.io/<namespace>/oci-aws-firehose`

---

## 4. OCIR Authentication (required for `fn deploy`)

Fn pushes images to OCI Container Registry (OCIR). You must authenticate.

### Create Auth Token

1. **OCI Console** → Profile (top-right) → **User Settings**
2. **Auth Tokens** → **Generate Token**
3. Copy and save the token (shown only once)

### Docker login to OCIR

```bash
# Get your tenancy namespace
oci os ns get --query 'data' --raw-output

# Login (replace with your values)
docker login us-ashburn-1.ocir.io
# Username: <tenancy_namespace>/<oci_username>
#           e.g. axabcdefghij/john.doe@example.com
# Password: <auth_token>
```

---

## 5. Deploy the Function

Once Docker is running, Fn is configured, and you're logged into OCIR:

```bash
cd functions
fn deploy --app oci-aws-firehose
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `docker: command not found` | Install Docker Desktop, ensure it's running |
| `fn: command not found` | Add `fn` to PATH; or `brew install fn` |
| `permission denied` on brew | `sudo chown -R $(whoami) /opt/homebrew` |
| `fn deploy` fails to push | Run `docker login us-ashburn-1.ocir.io` |
| `oci` auth fails in configure script | Verify `~/.oci/config` and `oci iam region list` |
