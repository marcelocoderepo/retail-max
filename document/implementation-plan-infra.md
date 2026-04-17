# Plano de Implementacao - Parte 1: Infraestrutura e DevOps

**Versao:** 3.0 | **Data:** 2026-04-17 | **Status:** PARCIALMENTE CONCLUIDO
**Referencia:** `document/architecture-plan.md` v2.1
**Complemento:** `document/implementation-plan-dev.md` (Parte 2: Desenvolvimento)

**Changelog v3.0 (2026-04-15):**
- Status atualizado: TODOS os 144 recursos Azure provisionados (48 por ambiente, zero diff)
- Pre-requisitos atualizados: todos CONCLUIDO
- Unity Catalog: nomenclatura corrigida para `retailmax` (sem sufixo de ambiente)
- Azure DevOps: estrutura real documentada (1 org, 1 projeto, 3 repos)
- CI/CD: 6 pipelines criadas nos repos corretos
- Key Vault: secret `sql-retailmax-source-connection-string` provisionado em dev
- UC Grants: ADF MSI com 9 grants (USE_CATALOG, USE_SCHEMA x4, SELECT+MODIFY x4)
- Cronograma Fase 1: todas as tarefas marcadas como CONCLUIDO
- Subscription ID e Tenant ID reais documentados

**Changelog v2.0:**
- Documento separado da versao unificada (v1.1)
- Conteudo exclusivo: Terraform, Azure DevOps, CI/CD, Rede, Custos
- Pre-requisitos e convencoes compartilhados com Parte 2

---

## 1. Visao Geral

Este documento detalha a infraestrutura e DevOps do projeto RetailMax Lakehouse. Cobre provisionamento Azure (Terraform), configuracao Azure DevOps, pipelines CI/CD para as 3 camadas (IaC, ADF, Databricks), topologia de rede e estimativas de custo.

Para o desenvolvimento de pipelines de dados, aplicacao e testes, consultar `implementation-plan-dev.md`.

### 1.1 Pre-Requisitos

| Item | Responsavel | Status |
|------|-------------|--------|
| Azure Subscription ativa (Pay-as-you-go) | Admin Azure | CONCLUIDO - RetailMax (666333e1-8511-4c47-b1ea-41a23af85487) |
| Azure AD Tenant com permissoes Global Admin ou Owner | Admin Azure | CONCLUIDO - massdatagcpgmail.onmicrosoft.com (ae89487f) |
| SQL Server AdventureWorks acessivel | DBA | CONCLUIDO - sql-retailmax-source.database.windows.net (centralus) |
| Conta Azure DevOps (Basic, 5 usuarios gratuitos) | DevOps Lead | CONCLUIDO - dev.azure.com/massdatagcp |
| Dominio de email para Service Principals | Admin Azure | CONCLUIDO - 3 SPNs criados (dev/hml/prd) |
| Budget aprovado (estimativa mensal) | Gerencia | CONCLUIDO - Pay-as-you-go |
| Licenca Databricks Premium (Unity Catalog requer Premium) | Admin Azure | CONCLUIDO - 3 workspaces Premium |

### 1.2 Convencoes de Nomenclatura

```
PADRAO: {tipo}-{projeto}-{ambiente}
===================================================================

Resource Groups:      rg-retailmax-dev     / rg-retailmax-hml     / rg-retailmax-prd
Storage Account:      stretailmaxdev       / stretailmaxhml       / stretailmaxprd       (sem hifens, max 24 chars)
Data Factory:         adf-retailmax-dev    / adf-retailmax-hml    / adf-retailmax-prd
Databricks:           dbx-retailmax-dev    / dbx-retailmax-hml    / dbx-retailmax-prd
Key Vault:            kv-retailmax-dev     / kv-retailmax-hml     / kv-retailmax-prd
VNet:                 vnet-retailmax-dev   / vnet-retailmax-hml   / vnet-retailmax-prd
Log Analytics:        log-retailmax-dev    / log-retailmax-hml    / log-retailmax-prd
Service Principal:    spn-retailmax-dev    / spn-retailmax-hml    / spn-retailmax-prd
NSG:                  nsg-{subnet}-{env}

Ambientes:
  dev = Desenvolvimento (deploy automatico, testes rapidos)
  hml = Homologacao (validacao com stakeholders, testes de aceite, dados reais anonimizados)
  prd = Producao (approval gate obrigatorio, dados reais)

Subnets:
  snet-dbx-public-{env}       10.0.1.0/24 (dev) / 10.2.1.0/24 (hml) / 10.1.1.0/24 (prd)
  snet-dbx-private-{env}      10.0.2.0/24 (dev) / 10.2.2.0/24 (hml) / 10.1.2.0/24 (prd)
  snet-private-endpoints-{env} 10.0.3.0/24 (dev) / 10.2.3.0/24 (hml) / 10.1.3.0/24 (prd)

Unity Catalog:
  Catalogo:   retailmax (mesmo nome em todos workspaces - workspace identifica o env)
  Schemas:    bronze, silver, gold, parametros

Tags obrigatorias:
  project     = "retailmax"
  environment = "dev" | "hml" | "prd"
  managed_by  = "terraform"
  cost_center = "data-engineering"
```

---

## 2. Terraform - Infraestrutura como Codigo

### 2.1 Estrutura do Repositorio `terraform-infra`

```
terraform-infra/
├── README.md
├── environments/
│   ├── dev/
│   │   ├── main.tf              # Chama os modulos com variaveis de dev
│   │   ├── variables.tf
│   │   ├── terraform.tfvars     # Valores para dev
│   │   ├── backend.tf           # State no Azure Storage (dev)
│   │   └── outputs.tf
│   ├── hml/
│   │   ├── main.tf              # Chama os modulos com variaveis de hml
│   │   ├── variables.tf
│   │   ├── terraform.tfvars     # Valores para hml
│   │   ├── backend.tf           # State no Azure Storage (hml)
│   │   └── outputs.tf
│   └── prd/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── backend.tf           # State no Azure Storage (prd)
│       └── outputs.tf
├── modules/
│   ├── resource-group/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── main.tf              # VNet, Subnets, NSGs, Private Endpoints
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf              # ADLS Gen2 + containers
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── keyvault/
│   │   ├── main.tf              # Key Vault + access policies
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── databricks/
│   │   ├── main.tf              # Workspace + VNet injection
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── data-factory/
│   │   ├── main.tf              # ADF + Managed Identity
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── identity/
│   │   ├── main.tf              # Service Principals, Managed Identities, AD Groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── monitoring/
│   │   ├── main.tf              # Log Analytics, Diagnostic Settings, Alerts, Budgets
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dns-zones/
│   │   ├── main.tf              # Private DNS Zones + VNet Links
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── policy/
│       ├── main.tf              # Azure Policy Definitions + Assignments
│       ├── variables.tf
│       └── outputs.tf
└── scripts/
    ├── init-backend.sh          # Cria Storage Account para Terraform state
    └── validate-all.sh          # Valida todos os environments
```

### 2.2 Terraform State Backend

Antes de qualquer `terraform init`, criar o Storage Account para o state:

```bash
# scripts/init-backend.sh
RESOURCE_GROUP="rg-retailmax-tfstate"
STORAGE_ACCOUNT="stretailmaxtfstate"
CONTAINER="tfstate"
LOCATION="eastus2"

az group create --name $RESOURCE_GROUP --location $LOCATION

# Storage com GRS, versionamento, soft-delete e encryption
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_GRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --require-infrastructure-encryption true \
  --min-tls-version TLS1_2

# Habilitar versionamento e soft-delete (90 dias)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 90 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 90

az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

# Lock para impedir exclusao acidental
az lock create \
  --name "tfstate-lock" \
  --resource-group $RESOURCE_GROUP \
  --resource-type Microsoft.Storage/storageAccounts \
  --resource $STORAGE_ACCOUNT \
  --lock-type CanNotDelete \
  --notes "Protege Terraform state - NAO remover"
```

```hcl
# environments/dev/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-retailmax-tfstate"
    storage_account_name = "stretailmaxtfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

# environments/hml/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-retailmax-tfstate"
    storage_account_name = "stretailmaxtfstate"
    container_name       = "tfstate"
    key                  = "hml.terraform.tfstate"
  }
}

# environments/prd/backend.tf -> key = "prd.terraform.tfstate"
```

### 2.3 Modulo Principal - Dev (exemplo)

```hcl
# environments/dev/main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  env  = "dev"
  tags = {
    project     = "retailmax"
    environment = local.env
    managed_by  = "terraform"
    cost_center = "data-engineering"
  }
}

module "resource_group" {
  source   = "../../modules/resource-group"
  name     = "rg-retailmax-${local.env}"
  location = var.location
  tags     = local.tags
}

module "networking" {
  source              = "../../modules/networking"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  vnet_address_space  = ["10.0.0.0/16"]  # dev=10.0, hml=10.2, prd=10.1
  tags                = local.tags
}

module "storage" {
  source              = "../../modules/storage"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  subnet_id           = module.networking.private_endpoints_subnet_id
  tags                = local.tags
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  subnet_id           = module.networking.private_endpoints_subnet_id
  tags                = local.tags
}

module "databricks" {
  source              = "../../modules/databricks"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  vnet_id             = module.networking.vnet_id
  public_subnet_name  = module.networking.dbx_public_subnet_name
  private_subnet_name = module.networking.dbx_private_subnet_name
  public_subnet_nsg   = module.networking.dbx_public_nsg_id
  private_subnet_nsg  = module.networking.dbx_private_nsg_id
  tags                = local.tags
}

module "data_factory" {
  source              = "../../modules/data-factory"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  tags                = local.tags
}

module "identity" {
  source              = "../../modules/identity"
  resource_group_name = module.resource_group.name
  env                 = local.env
  keyvault_id         = module.keyvault.id
  storage_account_id  = module.storage.id
  databricks_id       = module.databricks.workspace_id
  data_factory_id     = module.data_factory.id
}

module "monitoring" {
  source              = "../../modules/monitoring"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  data_factory_id     = module.data_factory.id
  databricks_id       = module.databricks.workspace_id
  monthly_budget      = var.monthly_budget  # ex: 700 (dev), 500 (hml), 1000 (prd)
  tags                = local.tags
}

module "dns_zones" {
  source              = "../../modules/dns-zones"
  resource_group_name = module.resource_group.name
  vnet_id             = module.networking.vnet_id
  env                 = local.env
  tags                = local.tags
  # Cria Private DNS Zones e VNet links para:
  # - privatelink.blob.core.windows.net
  # - privatelink.dfs.core.windows.net
  # - privatelink.vaultcore.azure.net
  # - privatelink.database.windows.net
  # - privatelink.azuredatabricks.net
}

module "policy" {
  source              = "../../modules/policy"
  subscription_id     = var.subscription_id
  env                 = local.env
  required_tags       = ["project", "environment", "managed_by", "cost_center"]
  allowed_locations   = [var.location]
  # Policies: deny public IP, require tags, require encryption,
  #           enforce diagnostic settings, deny non-approved SKUs
}
```

### 2.4 Variaveis por Ambiente

```hcl
# Todos os ambientes usam a mesma subscription
# environments/*/terraform.tfvars
location        = "eastus2"
subscription_id = "666333e1-8511-4c47-b1ea-41a23af85487"  # RetailMax subscription

# VNETs por ambiente (sem overlap):
# dev: 10.0.0.0/16
# prd: 10.1.0.0/16
# hml: 10.2.0.0/16
```

### 2.5 Topologia de Rede

```
VNet: 10.0.0.0/16 (dev) | 10.2.0.0/16 (hml) | 10.1.0.0/16 (prd)
===================================================================

+---------------------------------------------------------------+
|  vnet-retailmax-{env}                                         |
|                                                               |
|  +----------------------------+                               |
|  | snet-dbx-public-{env}      |  10.0.1.0/24                |
|  | Databricks public hosts    |  NSG: allow Databricks ctrl  |
|  +----------------------------+                               |
|                                                               |
|  +----------------------------+                               |
|  | snet-dbx-private-{env}     |  10.0.2.0/24                |
|  | Databricks private hosts   |  NSG: allow Databricks ctrl  |
|  +----------------------------+                               |
|                                                               |
|  +----------------------------+                               |
|  | snet-private-endpoints     |  10.0.3.0/24                |
|  | PE: ADLS, KV, SQL Server   |  NSG: deny all inbound       |
|  +----------------------------+                               |
|                                                               |
+---------------------------------------------------------------+
         |
         | Private Endpoints
         |
    +----+--------+--------+--------+
    |    ADLS     |   KV   |  SQL   |
    | Gen2        | Vault  | Server |
    +-------------+--------+--------+
```

### 2.6 Ordem de Provisionamento

O Terraform gerencia dependencias automaticamente, mas a ordem logica e:

```
1. Resource Group
2. Networking (VNet, Subnets, NSGs)
3. Key Vault (com access policies iniciais)
4. Storage (ADLS Gen2 + Private Endpoint)
5. Databricks (Workspace + VNet injection)
6. Data Factory (+ Managed Identity)
7. Identity (SPNs, AD Groups, RBAC assignments)
8. Monitoring (Log Analytics, Diagnostics, Alerts)
```

---

## 3. Azure DevOps - Configuracao e CI/CD

### 3.1 Setup Inicial da Organizacao

```
CONFIGURACAO REAL (CONCLUIDO)
===================================================================

Organizacao: dev.azure.com/massdatagcp
Projeto unico: retail-max (3 repos dentro do mesmo projeto)

Repos:
  retailmax-infra       -> Terraform IaC (10 modulos, 3 envs, 51 arquivos)
  retailmax-databricks  -> Notebooks DLT, testes, Asset Bundles (15 arquivos)
  retailmax-data-factory -> ADF pipelines, datasets, linked services (8 arquivos)

Nota: Repo default "retail-max" foi deletado (nao necessario no DevOps).
      GitHub (retail-max) = monorepo do projeto (docs, agents, KB, planejamento).

CI/CD Pipelines (6 total, 2 por repo):
  retailmax-infra:
    - ci-terraform-validate (trigger: PR para main)
    - cd-terraform-deploy (trigger: merge em main)
  retailmax-databricks:
    - ci-databricks-test (trigger: PR para main)
    - cd-databricks-deploy (trigger: merge em main)
  retailmax-data-factory:
    - ci-adf-validate (trigger: PR para main)
    - cd-adf-deploy (trigger: merge em main)

Branch Policies: main protegida (require PR)
```

### 3.2 Pipeline CI/CD - Terraform (retailmax-iac)

```yaml
# azure-pipelines/ci-terraform-validate.yml
# Trigger: PR para main
trigger: none
pr:
  branches:
    include:
      - main
  paths:
    include:
      - 'environments/**'
      - 'modules/**'

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Validate
    jobs:
      - job: TerraformValidate
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'

          - script: |
              cd environments/dev
              terraform init -backend=false
              terraform validate
              terraform fmt -check -recursive
            displayName: 'Validate Dev'

          - script: |
              cd environments/hml
              terraform init -backend=false
              terraform validate
            displayName: 'Validate Hml'

          - script: |
              cd environments/prd
              terraform init -backend=false
              terraform validate
            displayName: 'Validate Prd'

      - job: TerraformPlanDev
        dependsOn: TerraformValidate
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'

          - task: AzureCLI@2
            inputs:
              azureSubscription: 'retailmax-azure-connection'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                cd environments/dev
                terraform init
                terraform plan -out=tfplan
            displayName: 'Terraform Plan Dev'

          - publish: environments/dev/tfplan
            artifact: tfplan-dev
```

```yaml
# azure-pipelines/cd-terraform-deploy.yml
# Trigger: merge em main -> deploy dev (auto) -> hml (auto) -> prd (approval)
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - 'environments/**'
      - 'modules/**'

pool:
  vmImage: 'ubuntu-latest'

stages:
  # ---- DEV: deploy automatico ----
  - stage: DeployDev
    jobs:
      - deployment: TerraformApplyDev
        environment: 'dev'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: 'latest'
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'retailmax-azure-connection'
                    scriptType: 'bash'
                    inlineScript: |
                      cd environments/dev
                      terraform init
                      terraform apply -auto-approve
                  displayName: 'Terraform Apply Dev'

  # ---- HML: deploy automatico apos dev ----
  - stage: DeployHml
    dependsOn: DeployDev
    jobs:
      - deployment: TerraformApplyHml
        environment: 'hml'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: 'latest'
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'retailmax-azure-connection'
                    scriptType: 'bash'
                    inlineScript: |
                      cd environments/hml
                      terraform init
                      terraform apply -auto-approve
                  displayName: 'Terraform Apply Hml'

  # ---- PRD: requer aprovacao manual ----
  - stage: PlanPrd
    dependsOn: DeployHml
    jobs:
      - job: TerraformPlanPrd
        steps:
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: 'latest'
          - task: AzureCLI@2
            inputs:
              azureSubscription: 'retailmax-azure-connection'
              scriptType: 'bash'
              inlineScript: |
                cd environments/prd
                terraform init
                terraform plan -out=tfplan
            displayName: 'Terraform Plan Prd'
          - publish: environments/prd/tfplan
            artifact: tfplan-prd

  - stage: ApplyPrd
    dependsOn: PlanPrd
    jobs:
      - deployment: TerraformApplyPrd
        environment: 'prd'  # Requer aprovacao manual
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - download: current
                  artifact: tfplan-prd
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'retailmax-azure-connection'
                    scriptType: 'bash'
                    inlineScript: |
                      cd environments/prd
                      terraform init
                      terraform apply $(Pipeline.Workspace)/tfplan-prd/tfplan
                  displayName: 'Terraform Apply Prd'
```

### 3.3 Pipeline CI/CD - ADF (retailmax-adf)

```yaml
# azure-pipelines/ci-adf-validate.yml
trigger: none
pr:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: NodeTool@0
    inputs:
      versionSpec: '18.x'

  - script: |
      npm install -g @microsoft/azure-data-factory-utilities
    displayName: 'Install ADF Utilities'

  - script: |
      validate \
        "$(Build.Repository.LocalPath)" \
        /subscriptions/$(subscriptionId)/resourceGroups/$(resourceGroup)/providers/Microsoft.DataFactory/factories/adf-retailmax-dev
    displayName: 'Validate ADF ARM Templates'
```

```yaml
# azure-pipelines/cd-adf-deploy.yml
# Fluxo: hml (auto apos publish) -> prd (approval gate)
trigger: none

pool:
  vmImage: 'ubuntu-latest'

stages:
  # ---- HML: deploy automatico apos ADF publish ----
  - stage: DeployAdfHml
    jobs:
      - deployment: AdfDeployHml
        environment: 'hml'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureResourceManagerTemplateDeployment@3
                  inputs:
                    azureResourceManagerConnection: 'retailmax-azure-connection'
                    subscriptionId: '$(hml_subscription_id)'
                    resourceGroupName: 'rg-retailmax-hml'
                    location: 'eastus2'
                    templateLocation: 'Linked artifact'
                    csmFile: '$(Pipeline.Workspace)/adf-arm/ARMTemplateForFactory.json'
                    csmParametersFile: '$(Pipeline.Workspace)/adf-arm/ARMTemplateParametersForFactory.json'
                    overrideParameters: >
                      -factoryName "adf-retailmax-hml"
                      -ls_adls_properties_typeProperties_url "https://stretailmaxhml.dfs.core.windows.net"
                      -ls_databricks_properties_typeProperties_domain "https://dbx-retailmax-hml.azuredatabricks.net"
                  displayName: 'Deploy ADF to Hml'

  # ---- PRD: requer aprovacao manual ----
  - stage: DeployAdfPrd
    dependsOn: DeployAdfHml
    jobs:
      - deployment: AdfDeployPrd
        environment: 'prd'  # Requer aprovacao manual
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureResourceManagerTemplateDeployment@3
                  inputs:
                    azureResourceManagerConnection: 'retailmax-azure-connection'
                    subscriptionId: '$(prd_subscription_id)'
                    resourceGroupName: 'rg-retailmax-prd'
                    location: 'eastus2'
                    templateLocation: 'Linked artifact'
                    csmFile: '$(Pipeline.Workspace)/adf-arm/ARMTemplateForFactory.json'
                    csmParametersFile: '$(Pipeline.Workspace)/adf-arm/ARMTemplateParametersForFactory.json'
                    overrideParameters: >
                      -factoryName "adf-retailmax-prd"
                      -ls_adls_properties_typeProperties_url "https://stretailmaxprd.dfs.core.windows.net"
                      -ls_databricks_properties_typeProperties_domain "https://dbx-retailmax-prd.azuredatabricks.net"
                  displayName: 'Deploy ADF to Prd'
```

### 3.4 Pipeline CI/CD - Databricks (retailmax-databricks)

```yaml
# azure-pipelines/ci-databricks-test.yml
trigger: none
pr:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.10'

  - script: |
      pip install -r requirements-dev.txt
    displayName: 'Install Dependencies'

  - script: |
      python -m pytest tests/ -v --cov=src --cov-report=xml
    displayName: 'Run Tests'

  - script: |
      python -m ruff check src/
    displayName: 'Lint Check'

  - task: PublishTestResults@2
    inputs:
      testResultsFiles: '**/test-results.xml'

  - task: PublishCodeCoverageResults@1
    inputs:
      codeCoverageTool: 'Cobertura'
      summaryFileLocation: 'coverage.xml'
```

```yaml
# azure-pipelines/cd-databricks-deploy.yml
# Fluxo: dev (auto) -> hml (auto) -> prd (approval gate)
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - 'src/**'
      - 'databricks.yml'

pool:
  vmImage: 'ubuntu-latest'

stages:
  # ---- DEV: deploy automatico ----
  - stage: DeployDev
    jobs:
      - job: DeployDatabricksDev
        steps:
          - task: UsePythonVersion@0
            inputs:
              versionSpec: '3.10'
          - script: pip install databricks-cli
            displayName: 'Install Databricks CLI'
          - script: databricks bundle deploy --target dev
            displayName: 'Deploy to Dev'
            env:
              DATABRICKS_HOST: $(DATABRICKS_HOST_DEV)
              DATABRICKS_TOKEN: $(DATABRICKS_TOKEN_DEV)

  # ---- HML: deploy automatico apos dev ----
  - stage: DeployHml
    dependsOn: DeployDev
    jobs:
      - deployment: DeployDatabricksHml
        environment: 'hml'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: UsePythonVersion@0
                  inputs:
                    versionSpec: '3.10'
                - script: pip install databricks-cli
                  displayName: 'Install Databricks CLI'
                - script: databricks bundle deploy --target hml
                  displayName: 'Deploy to Hml'
                  env:
                    DATABRICKS_HOST: $(DATABRICKS_HOST_HML)
                    DATABRICKS_TOKEN: $(DATABRICKS_TOKEN_HML)

  # ---- PRD: requer aprovacao manual ----
  - stage: DeployPrd
    dependsOn: DeployHml
    jobs:
      - deployment: DeployDatabricksPrd
        environment: 'prd'  # Requer aprovacao manual
        strategy:
          runOnce:
            deploy:
              steps:
                - task: UsePythonVersion@0
                  inputs:
                    versionSpec: '3.10'
                - script: pip install databricks-cli
                  displayName: 'Install Databricks CLI'
                - script: databricks bundle deploy --target prd
                  displayName: 'Deploy to Prd'
                  env:
                    DATABRICKS_HOST: $(DATABRICKS_HOST_PRD)
                    DATABRICKS_TOKEN: $(DATABRICKS_TOKEN_PRD)
```

### 3.5 Estrategia de Branching

```
main (protegida - require PR)
  |
  +-- feature/TASK-123-terraform-networking
  +-- feature/TASK-456-adf-metadata-pipeline
  +-- feature/TASK-789-dlt-bronze-tables
  +-- fix/TASK-321-watermark-bug
  +-- hotfix/TASK-999-prd-emergency

Regras:
- Toda alteracao via PR para main
- CI roda em toda PR (validate/test/lint)
- Merge em main -> deploy automatico em dev -> auto em hml -> approval gate prd
- Fluxo de promocao: dev (auto) -> hml (auto apos dev) -> prd (manual)
- Commits seguem Conventional Commits:
    feat: nova funcionalidade
    fix: correcao de bug
    infra: mudanca de infraestrutura
    docs: documentacao
    test: testes
    ci: mudanca de pipeline
```

---

## 4. Cronograma de Infraestrutura

### FASE 1: Fundacao, Infraestrutura e DevOps (S1-S4) — CONCLUIDO

```
SEMANA 1: Azure DevOps + Terraform Base                    STATUS: CONCLUIDO
===================================================================
DIA  | TAREFA                                          | STATUS
-----+------------------------------------------------+-----------
S1-1 | Criar Azure DevOps Org (massdatagcp) + projeto   | CONCLUIDO
S1-1 | Configurar 3 repos, branch policies              | CONCLUIDO
S1-2 | Criar Terraform state backend (stretailmaxtfstate)| CONCLUIDO
S1-2 | Implementar modulo: resource-group               | CONCLUIDO
S1-3 | Implementar modulo: networking (VNet, Subnets)   | CONCLUIDO
S1-3 | Implementar modulo: keyvault                     | CONCLUIDO
S1-4 | Implementar modulo: storage (ADLS Gen2)          | CONCLUIDO
S1-4 | Configurar CI pipeline Terraform (validate/plan) | CONCLUIDO
S1-5 | Code review + merge -> terraform apply dev       | CONCLUIDO

ENTREGAVEIS:
[x] DevOps Organization + 1 projeto com 3 repos
[x] Terraform: RG + VNet + ADLS + Key Vault em dev (zero diff)
[x] CI pipeline rodando em PRs


SEMANA 2: Databricks + ADF + Identidade                    STATUS: CONCLUIDO
===================================================================
DIA  | TAREFA                                          | STATUS
-----+------------------------------------------------+-----------
S2-1 | Implementar modulo: databricks (VNet injection)  | CONCLUIDO
S2-2 | Implementar modulo: data-factory                 | CONCLUIDO
S2-2 | Implementar modulo: identity (SPNs, MI, Groups)  | CONCLUIDO
S2-3 | Implementar modulo: monitoring (Log Analytics)    | CONCLUIDO
S2-3 | Terraform apply dev (todos os modulos)            | CONCLUIDO - 48 recursos
S2-4 | Terraform apply hml (todos os modulos)            | CONCLUIDO - 48 recursos
S2-4 | Terraform apply prd (todos os modulos)            | CONCLUIDO - 48 recursos
S2-5 | Validar acesso a todos os recursos                | CONCLUIDO

ENTREGAVEIS:
[x] TODOS 144 recursos Azure provisionados (48 x 3 envs, zero diff)
[x] SPNs criados: spn-retailmax-dev/hml/prd
[x] Acesso validado (ADF -> ADLS, ADF -> DBX, DBX -> ADLS)


SEMANA 3: Unity Catalog + ADF Linked Services + CI/CD      STATUS: CONCLUIDO
===================================================================
DIA  | TAREFA                                          | STATUS
-----+------------------------------------------------+-----------
S3-1 | Criar Unity Catalog: retailmax (catalog unico)   | CONCLUIDO
S3-1 | Criar schemas: bronze, silver, gold, parametros   | CONCLUIDO
S3-2 | Configurar UC grants para ADF MSI (9 grants)     | CONCLUIDO
S3-2 | ADF: Linked Services (SQL, ADLS, DBX, KV)        | CONCLUIDO
S3-3 | KV: secret sql-retailmax-source-connection-string | CONCLUIDO
S3-3 | Criar CI/CD pipelines (6 total, 2 por repo)      | CONCLUIDO
S3-4 | Cluster policy ADF Single Node UC                 | CONCLUIDO
S3-5 | Validar CI/CD end-to-end                          | CONCLUIDO

ENTREGAVEIS:
[x] Unity Catalog operacional com 4 schemas (bronze/silver/gold/parametros)
[x] ADF com Linked Services configurados
[x] 6 CI/CD pipelines operacionais nos repos corretos
[x] ADF MSI com grants UC (USE_CATALOG, USE_SCHEMA x4, SELECT+MODIFY x4)


SEMANA 4: Tabela de Controle + Pipeline Completo            STATUS: CONCLUIDO
===================================================================
DIA  | TAREFA                                          | STATUS
-----+------------------------------------------------+-----------
S4-1 | Criar ingestion_control DDL (schema parametros)  | CONCLUIDO
S4-1 | Inserir dados iniciais (7 tabelas)               | CONCLUIDO
S4-2 | Pipeline ADF pl_master_ingestion (Lookup+ForEach) | CONCLUIDO
S4-2 | Sub-pipelines (full + incremental)               | CONCLUIDO
S4-3 | DLT 3 pipelines (bronze/silver/gold) + job       | CONCLUIDO - 19 tabelas
S4-3 | Testar ADF -> ADLS -> DLT flow completo          | CONCLUIDO
S4-4 | Documentar onboarding (README de cada repo)       | CONCLUIDO
S4-5 | Validacao end-to-end                              | CONCLUIDO

ENTREGAVEIS:
[x] ingestion_control com 7 tabelas no schema parametros
[x] Pipeline ADF master testado (Lookup + ForEach + update watermark)
[x] 3 DLT pipelines + job orquestrador executando (19 tabelas criadas)
[x] Flow ADF -> DLT validado end-to-end em dev
[x] Documentacao de onboarding

>>> MILESTONE M1: INFRA READY <<< STATUS: CONCLUIDO (2026-04-15)
```

### FASE 6 (Infra): Deploy Hml e Prd (S19-S23) — PARCIALMENTE CONCLUIDO

**NOTA:** Terraform apply hml e prd ja foram executados na Fase 1 (144 recursos, 48 por env).
Restam: Unity Catalog setup em hml/prd, deploy ADF/Databricks, monitoramento.

```
SEMANA 19: Deploy de Infraestrutura em Homologacao      STATUS: PARCIAL
===================================================================
S19-1 | Terraform plan hml (review detalhado)                | CONCLUIDO (zero diff)
S19-2 | Terraform apply hml                                  | CONCLUIDO (48 recursos)
S19-3 | Validar todos os recursos em hml                     | CONCLUIDO
S19-4 | Configurar Unity Catalog retailmax (hml workspace)   | PENDENTE
S19-5 | Deploy ADF + Databricks + App em hml via CI/CD       | PENDENTE


SEMANA 21: Deploy de Infraestrutura em Producao         STATUS: PARCIAL
===================================================================
S21-1 | Terraform plan prd (review detalhado)                | CONCLUIDO (zero diff)
S21-2 | Terraform apply prd                                  | CONCLUIDO (48 recursos)
S21-3 | Validar todos os recursos em prd                     | CONCLUIDO
S21-4 | Configurar Unity Catalog retailmax (prd workspace)   | PENDENTE
S21-5 | Deploy ADF + Databricks + App em prd via CI/CD       | PENDENTE


SEMANA 23: Monitoramento e Alertas                      STATUS: PENDENTE
===================================================================
S23-3 | Configurar Azure Monitor alertas (falha, custo)       | PENDENTE
S23-4 | Criar dashboard operacional (pipeline health)         | PENDENTE
S23-5 | Escrever runbook de operacoes                         | PENDENTE
```

**Nota:** As semanas 20, 22 e 24 sao de responsabilidade do time de Desenvolvimento (ver `implementation-plan-dev.md`).

---

## 5. Estimativa de Custo Azure (Mensal - por ambiente)

| Recurso | SKU | Dev/mes | Hml/mes | Prd/mes |
|---------|-----|---------|---------|---------|
| Databricks (Serverless) | Pay-per-use | $200-400 | $150-300 | $300-600 |
| ADLS Gen2 | Standard LRS | $20-50 | $15-30 | $30-80 |
| Azure Data Factory | Pay-per-activity | $50-100 | $30-60 | $50-150 |
| Key Vault | Standard | $5 | $5 | $5 |
| VNet / Private Endpoints | Standard | $30-50 | $30-50 | $30-50 |
| Log Analytics | Pay-per-GB | $20-40 | $15-30 | $30-60 |
| **Total** | | **~$325-645** | **~$245-475** | **~$445-945** |

**Notas:**
- Hml tem custo menor que dev (uso sob demanda, sem desenvolvimento ativo)
- Prd tera custo maior dependendo do volume de dados e frequencia de execucao
- Total estimado dos 3 ambientes: **~$1.015-2.065/mes**

---

## 6. Criterios de Aceite - Infraestrutura

| Fase | Criterio | Metrica |
|------|----------|---------|
| F1 | Todos os recursos via Terraform | `terraform plan` sem diff em dev |
| F1 | CI/CD operacional | PR -> merge -> deploy funcionando nos 3 projetos |
| F1 | Acesso validado | ADF -> ADLS, ADF -> DBX, DBX -> ADLS OK |
| F1 | Unity Catalog | Catalogos e schemas criados (dev/hml/prd) |
| F6 | Hml provisionado | Todos os recursos via Terraform em hml |
| F6 | Prd provisionado | Todos os recursos via Terraform em prd (approval gate) |
| F6 | Monitoramento | Azure Monitor alertas configurados (falha + custo) |
| F6 | Drift zero | `terraform plan` sem diff em todos ambientes |

---

## 7. Equipe Minima - Infraestrutura

| Papel | Quantidade | Dedicacao | Fases Principais |
|-------|-----------|-----------|------------------|
| DevOps / Infra Engineer | 1 | 100% F1, 50% restante | F1 (setup completo), F6 (deploy hml/prd), suporte pontual |

---

## Fontes e Referencias

| Documento | Conteudo |
|-----------|---------|
| `document/architecture-plan.md` | Arquitetura v2.1 (base para este plano) |
| `document/implementation-plan-dev.md` | Parte 2: Desenvolvimento |
| `document/brd-retail-max.md` | Requisitos de negocio |
| `document/frd-adventure-works.md` | Especificacao funcional |
