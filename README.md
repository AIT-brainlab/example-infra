# Infrastructure Foundation & Project Management

Automated, idempotent scaffolding and Terraform management plane for Google Cloud Platform (GCP). Designed for personal accounts and standalone setups **without requiring a GCP Organization or Folder hierarchy**.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Tool Installation](#-tool-installation)
- [GCP Authentication](#-gcp-authentication)
- [Quick Start Guide](#-quick-start-guide)
  - [Step 1: Configure Environment](#step-1-configure-environment)
  - [Step 2: Validate Environment](#step-2-validate-environment)
  - [Step 3: Bootstrap the Foundation](#step-3-bootstrap-the-foundation)
  - [Step 4: Deploy with Terraform](#step-4-deploy-with-terraform)
  - [Step 5: Launch Workloads (VMs / Child Projects)](#step-5-launch-workloads-vms--child-projects)
- [Repository Structure](#-repository-structure)
- [Troubleshooting & FAQ](#-troubleshooting--faq)

---

## 🛠️ Prerequisites

Before getting started, make sure you have:

1. **Google Cloud Account**:
   - A personal Google Account (e.g., `@gmail.com` or custom Google Workspace).
   - Access to the [Google Cloud Console](https://console.cloud.google.com).
2. **Active GCP Billing Account**:
   - An active billing account is required to create and link projects.
   - **How to find your Billing Account ID**:
     1. Open [GCP Console Billing](https://console.cloud.google.com/billing).
     2. Select your billing account.
     3. Look for **Billing account ID** (format: `01XXXX-XXXXXX-XXXXXX`).
3. **Billing IAM Permissions**:
   - Your account must have the **Billing Account User** (`roles/billing.user`) or **Billing Account Administrator** (`roles/billing.admin`) role on that billing account.

---

## 💻 Tool Installation

Install the two required command-line tools: the **Google Cloud SDK (`gcloud`)** and **Terraform**.

### 1. Google Cloud SDK (`gcloud`)

#### macOS (Homebrew)
```bash
brew install --cask google-cloud-sdk
```

#### Linux (Debian / Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install -y google-cloud-cli
```

> For other operating systems or standalone tarballs, see the [official Google Cloud SDK install guide](https://cloud.google.com/sdk/docs/install).

Verify the installation:
```bash
gcloud version
```

---

### 2. HashiCorp Terraform

Requires Terraform `>= 1.5.0`.

#### macOS (Homebrew)
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Linux (Debian / Ubuntu)
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Verify the installation:
```bash
terraform version
```

---

## 🔑 GCP Authentication

Because this repository uses both `gcloud` CLI scripts and Terraform, authenticate **both**:

```bash
# 1. Log in to gcloud CLI (used by bootstrap scripts)
gcloud auth login

# 2. Log in to Application Default Credentials / ADC (used by Terraform)
gcloud auth application-default login

# 3. Confirm your active logged-in account
gcloud config get-value account
```

---

## 🚀 Quick Start Guide

### Step 1: Configure Environment

Copy the example configuration to `.env` in the repository root:

```bash
cp .env.example .env
```

Open `.env` in your editor and update the required values:

```bash
# Project & domain prefix (will create <DOMAIN_NAME>-mgmt project)
DOMAIN_NAME="my-project"

# Your GCP Billing Account ID (from GCP Console -> Billing)
BILLING_ACCOUNT_ID="01XXXX-XXXXXX-XXXXXX"

# Optional: Leave empty if you do not have/want custom Cloud DNS subzones
PARENT_DOMAIN=""

# Optional: Target GCP Region for remote state storage (Default: Singapore)
REGION="asia-southeast1"

# Optional: Collaborator emails to grant Editor / Viewer roles
PROJECT_ADMINS=""
PROJECT_MEMBERS=""
```

---

### Step 2: Validate Environment

Run the pre-flight verification script to ensure your `.env` settings, CLI authentication, and billing account permissions are valid:

```bash
# Live validation against GCP:
./scripts/check_env.sh

# Or offline static syntax validation only:
./scripts/check_env.sh --skip-gcp
```

---

### Step 3: Bootstrap the Foundation

The bootstrap script scaffolds the management directory, provisions the management GCP project, links your billing account, enables essential APIs, and provisions a secure GCS remote state bucket.

```bash
# 1. Preview changes (Dry-Run / Plan Mode):
./scripts/bootstrap_domain.sh --plan

# 2. Provision and apply:
./scripts/bootstrap_domain.sh
```

**What happens behind the scenes:**
1. Scaffolds `<domain>-mgmt/` from the template.
2. Creates the GCP management project: `<domain>-mgmt`.
3. Links the project to your `BILLING_ACCOUNT_ID`.
4. Enables foundational APIs (`serviceusage`, `cloudresourcemanager`, `secretmanager`, `iam`, etc.).
5. Creates a versioned Google Cloud Storage bucket (`gs://<domain>-mgmt-tfstate`) for Terraform remote state.
6. Automatically populates `<domain>-mgmt/terraform/terraform.tfvars`.

---

### Step 4: Deploy with Terraform

Navigate into the generated management directory and apply the Terraform configuration:

```bash
cd <domain>-mgmt/terraform

# 1. Initialize remote GCS backend
terraform init

# 2. Preview infrastructure changes
terraform plan

# 3. Apply baseline configuration
terraform apply
```

This deploys:
- **Project Deletion Protection Lien** (prevents accidental deletion of the management project).
- **Project IAM Bindings** (for any configured `project_admins` and `project_members`).
- **Secret Manager Baseline** (secure vault with billing ID metadata).
- **Authoritative Cloud DNS Zone** (only if `DOMAIN_NAME` and `PARENT_DOMAIN` are set; skipped if empty).

---

### Step 5: Launch Workloads (VMs / Child Projects)

You can launch workloads in two ways depending on your needs:

#### Option A: Directly in the Management Project
For simple setups, deploy VMs, containers, or databases directly inside `<domain>-mgmt`.

#### Option B: Dedicated Child Workload Projects
For zero blast radius and isolation, instantiate dedicated workload projects using the included example:

```bash
cd <domain>-mgmt/terraform

# Copy the workload project template
cp prj-workload.tf.example prj-workload.tf

# Review prj-workload.tf and apply
terraform plan
terraform apply
```

This creates a dedicated child project (`<domain>-workload`) linked to your billing account, with its own APIs and service accounts, managed cleanly by Terraform.

---

## 📁 Repository Structure

```text
.
├── .env.example                   # Environment configuration template
├── README.md                      # Quick start and runbook (this file)
├── scripts/
│   ├── check_env.sh               # Environment and pre-flight validation
│   ├── scaffold_domain.sh         # Scaffolding tool (template -> <domain>-mgmt)
│   └── bootstrap_domain.sh        # Idempotent GCP project & storage bootstrapper
└── template-mgmt/                 # Baseline template for management plane
    └── terraform/
        ├── main.tf                # GCS backend & deletion protection lien
        ├── dns.tf                 # Cloud DNS managed subzone (conditional)
        ├── iam.tf                 # Project IAM roles (Editor, Viewer)
        ├── secrets.tf             # Secret Manager vault
        ├── variables.tf           # Terraform input variables
        ├── outputs.tf             # Outputs (DNS, nameservers, etc.)
        ├── prj-workload.tf.example# Starter template for child projects
        └── terraform.tfvars.example
```

---

## ❓ Troubleshooting & FAQ

<details>
<summary><b>1. Error: "The caller does not have permission" or Billing link failure</b></summary>

Ensure your authenticated account has `roles/billing.user` or `roles/billing.admin` on the billing account:
```bash
gcloud billing accounts get-iam-policy YOUR_BILLING_ACCOUNT_ID
```
Also verify you logged into the correct account:
```bash
gcloud config get-value account
```
</details>

<details>
<summary><b>2. Error: "google: could not find default credentials" when running Terraform</b></summary>

Terraform uses Application Default Credentials (ADC), which is separate from `gcloud auth login`. Run:
```bash
gcloud auth application-default login
```
</details>

<details>
<summary><b>3. Do I need a domain name or DNS delegation?</b></summary>

No. If you leave `PARENT_DOMAIN=""` in `.env`, Cloud DNS is automatically skipped in Terraform, and you can use the GCP project without any custom domain.
</details>

<details>
<summary><b>4. How to tear down or clean up resources?</b></summary>

To destroy resources managed by Terraform:
```bash
cd <domain>-mgmt/terraform
terraform destroy
```
*(Note: If deletion protection liens were enabled, remove or comment out the lien in `main.tf` first before destroying the project).*
</details>
