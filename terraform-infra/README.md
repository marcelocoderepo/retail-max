# RetailMax - Terraform Infrastructure

Infrastructure as Code (Terraform) for the RetailMax Lakehouse Analytics Platform on Azure.

## Architecture

Provisions a complete data platform per environment (dev/hml/prd):

| Resource | Naming | Purpose |
|----------|--------|---------|
| Resource Group | `rg-retailmax-{env}` | Container for all resources |
| VNet | `vnet-retailmax-{env}` | Network isolation with 3 subnets |
| ADLS Gen2 | `stretailmax{env}` | Data Lake (bronze/silver/gold/landing) |
| Key Vault | `kv-retailmax-{env}` | Secrets management |
| Databricks | `dbx-retailmax-{env}` | Data processing (VNet injected, Premium) |
| Data Factory | `adf-retailmax-{env}` | Orchestration (Managed Identity) |
| Log Analytics | `log-retailmax-{env}` | Monitoring and diagnostics |

## Network Topology

```
VNet CIDR: dev=10.0.0.0/16 | hml=10.2.0.0/16 | prd=10.1.0.0/16

snet-dbx-public-{env}       x.x.1.0/24  (Databricks public hosts)
snet-dbx-private-{env}      x.x.2.0/24  (Databricks private hosts)
snet-private-endpoints-{env} x.x.3.0/24  (PE: ADLS, KV, SQL Server)
```

## Prerequisites

1. Azure CLI authenticated: `az login`
2. Terraform >= 1.5.0 installed
3. Credentials filled in `../.secrets/` (see `../.secrets/README.md`)

## Quick Start

### 1. Create Terraform State Backend (one-time)

```bash
chmod +x scripts/init-backend.sh
./scripts/init-backend.sh
```

Save the access key to `../.secrets/terraform-backend.env`.

### 2. Deploy Dev Environment

```bash
# Load credentials
source ../.secrets/azure-tenant.env
source ../.secrets/dev/azure.env
source ../.secrets/terraform-backend.env

# Initialize and deploy
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Deploy Other Environments

```bash
# HML
source ../.secrets/hml/azure.env
cd environments/hml
terraform init && terraform plan && terraform apply

# PRD (review plan carefully)
source ../.secrets/prd/azure.env
cd environments/prd
terraform init && terraform plan
# Review the plan, then:
terraform apply
```

## Validation

```bash
chmod +x scripts/validate-all.sh
./scripts/validate-all.sh
```

## Module Reference

| Module | Description |
|--------|-------------|
| `resource-group` | Resource Group creation |
| `networking` | VNet, Subnets, NSGs |
| `storage` | ADLS Gen2 + containers + Private Endpoint |
| `keyvault` | Key Vault + Private Endpoint |
| `databricks` | Workspace with VNet injection (Premium) |
| `data-factory` | ADF with Managed Identity |
| `identity` | AD Groups + RBAC role assignments |
| `monitoring` | Log Analytics + diagnostic settings + budget alerts |
| `dns-zones` | Private DNS Zones + VNet Links |
| `policy` | Azure Policy (tags, allowed locations) |

## Provisioning Order

Terraform handles dependencies automatically. Logical order:

1. Resource Group
2. Networking (VNet, Subnets, NSGs)
3. Key Vault
4. Storage (ADLS Gen2 + PE)
5. Databricks (VNet injection)
6. Data Factory (Managed Identity)
7. Identity (AD Groups, RBAC)
8. Monitoring (Log Analytics, Diagnostics, Budget)
9. DNS Zones (Private DNS + VNet Links)
10. Policy (Tag enforcement, Location restriction)

## CI/CD

Azure DevOps pipelines in `azure-pipelines/`:

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| `ci-terraform-validate.yml` | PR to main | Validate + plan |
| `cd-terraform-deploy.yml` | Merge to main | Deploy dev -> hml -> prd |
| `ci-adf-validate.yml` | PR to main | Validate ADF ARM templates |
| `cd-adf-deploy.yml` | ADF publish | Deploy ADF hml -> prd |
| `ci-databricks-test.yml` | PR to main | pytest + lint |
| `cd-databricks-deploy.yml` | Merge to main | Deploy bundles dev -> hml -> prd |

## Tags

All resources are tagged with:

```hcl
project     = "retailmax"
environment = "dev" | "hml" | "prd"
managed_by  = "terraform"
cost_center = "data-engineering"
```
