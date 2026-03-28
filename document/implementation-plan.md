# Plano de Implementacao - Infraestrutura e Desenvolvimento

**Versao:** 1.1 | **Data:** 2026-03-28 | **Status:** Proposto
**Referencia:** `document/architecture-plan.md` v2.1

**Changelog v1.1:**
- Inclusao do ambiente de homologacao (hml) em toda a stack
- Fluxo de deploy: dev (auto) -> hml (auto) -> prd (approval gate)
- 3 ambientes completos: dev, hml, prd

---

## 1. Visao Geral

Este documento traduz a arquitetura definida no `architecture-plan.md` em tarefas executaveis, estruturas de codigo, e configuracoes concretas. Cobre infraestrutura (Terraform), DevOps (Azure DevOps), desenvolvimento (ADF, Databricks, DLT) e aplicacao (Databricks App).

### 1.1 Pre-Requisitos

| Item | Responsavel | Status |
|------|-------------|--------|
| Azure Subscription ativa (Pay-as-you-go ou EA) | Admin Azure | PENDENTE |
| Azure AD Tenant com permissoes Global Admin ou Owner | Admin Azure | PENDENTE |
| SQL Server AdventureWorks acessivel (IP/VPN/ER) | DBA | PENDENTE |
| Conta Azure DevOps (Basic, 5 usuarios gratuitos) | DevOps Lead | PENDENTE |
| Dominio de email para Service Principals | Admin Azure | PENDENTE |
| Budget aprovado (estimativa mensal) | Gerencia | PENDENTE |
| Licenca Databricks Premium (Unity Catalog requer Premium) | Admin Azure | PENDENTE |

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
  Catalogo:   retailmax_dev / retailmax_hml / retailmax_prd
  Schemas:    bronze, silver, gold

Tags obrigatorias:
  project     = "retailmax"
  environment = "dev" | "hml" | "prd"
  managed_by  = "terraform"
  cost_center = "data-engineering"
```

---

## 2. Infraestrutura - Terraform

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
│   └── monitoring/
│       ├── main.tf              # Log Analytics, Diagnostic Settings, Alerts
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
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT
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
  tags                = local.tags
}
```

### 2.4 Variaveis por Ambiente

```hcl
# environments/dev/terraform.tfvars
location        = "eastus2"
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# environments/hml/terraform.tfvars
location        = "eastus2"
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # pode ser a mesma subscription ou diferente

# environments/prd/terraform.tfvars
location        = "eastus2"
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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

## 3. DevOps - Azure DevOps

### 3.1 Setup Inicial da Organizacao

```
TAREFAS MANUAIS (Portal Azure DevOps - unica vez)
===================================================================

1. Criar Organization: dev.azure.com/retailmax
2. Criar 3 projetos:
   - retailmax-iac        (Terraform)
   - retailmax-adf        (Data Factory)
   - retailmax-databricks  (Notebooks + App)
3. Em cada projeto:
   - Criar repos conforme secao 2.3 do architecture-plan
   - Configurar branch policies:
     - main: require PR, require 1 reviewer
     - No direct push to main
   - Criar Environments:
     - dev (auto-deploy em merge para main)
     - hml (auto-deploy apos dev com sucesso)
     - prd (approval gate: 1 aprovador minimo)
4. Configurar Service Connections:
   - Azure Resource Manager (para Terraform e ADF deploy)
   - Databricks dev/hml/prd (para deploy de notebooks)
5. Configurar Variable Groups:
   - retailmax-dev (subscription_id, resource_group, etc.)
   - retailmax-hml (idem para hml)
   - retailmax-prd (idem para prd)
   - retailmax-secrets (linked to Key Vault)
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

```
# NOTA: cd-terraform-prd.yml foi consolidado em cd-terraform-deploy.yml
# Pipeline unico com stages: DeployDev -> DeployHml -> PlanPrd -> ApplyPrd
# Ver cd-terraform-deploy.yml acima
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

## 4. Desenvolvimento - Azure Data Factory

### 4.1 Estrutura do Repositorio `adf-pipelines`

```
adf-pipelines/
├── README.md
├── pipeline/
│   ├── pl_master_ingestion.json      # Pipeline principal (orquestrador)
│   ├── pl_copy_full_load.json        # Sub-pipeline: copia full
│   └── pl_copy_incremental.json      # Sub-pipeline: copia incremental
├── dataset/
│   ├── ds_sqlserver_table.json        # Dataset parametrizado SQL Server
│   ├── ds_adls_parquet.json           # Dataset parametrizado ADLS Parquet
│   └── ds_databricks_delta.json       # Dataset para ingestion_control
├── linkedService/
│   ├── ls_sqlserver.json              # SQL Server (via IR ou PE)
│   ├── ls_adls.json                   # ADLS Gen2 (Managed Identity)
│   ├── ls_databricks.json             # Databricks (SPN)
│   └── ls_keyvault.json               # Key Vault (Managed Identity)
├── trigger/
│   ├── tr_daily_0200.json             # Trigger diario 02:00 UTC
│   └── tr_manual.json                 # Trigger manual para testes
├── integrationRuntime/
│   └── ir_self_hosted.json            # Self-Hosted IR (se SQL on-prem)
└── factory/
    └── adf-retailmax-dev.json
```

### 4.2 Pipeline Master - Logica Metadata-Driven

```
pl_master_ingestion
===================================================================

[Lookup: Get Active Tables]
  |  Source: retailmax_{env}.bronze.ingestion_control
  |  Query: SELECT * WHERE is_active = true
  |  Output: array of table configs
  |
  v
[ForEach: table_config] (sequential=false, batch=5)
  |
  |--[If: load_type == 'full']
  |    |
  |    +--[Execute: pl_copy_full_load]
  |         Parameters:
  |           source_schema = @item().source_schema
  |           source_table  = @item().source_table
  |           landing_path  = @item().landing_path
  |
  |--[If: load_type == 'incremental']
  |    |
  |    +--[Execute: pl_copy_incremental]
  |         Parameters:
  |           source_schema        = @item().source_schema
  |           source_table         = @item().source_table
  |           watermark_column     = @item().watermark_column
  |           last_watermark_value = @item().last_watermark_value
  |           landing_path         = @item().landing_path
  |
  |--[Stored Procedure / Notebook: Update Control Table]
  |    SET last_watermark_value = @activity('Copy').output.maxWatermark
  |    SET last_load_status     = 'SUCCESS'
  |    SET last_load_timestamp  = @utcnow()
  |    SET row_count_last_load  = @activity('Copy').output.rowsCopied
  |    SET updated_at           = @utcnow()
  |
  v (apos ForEach completo)
[Databricks Notebook Activity: Trigger DLT Refresh]
  |  Notebook: /Shared/retailmax/trigger_dlt_refresh
  |  Cluster: job cluster (serverless)
  |  Parameters: { "pipeline_name": "retailmax_dlt_pipeline" }
  |
  v
[On Failure: Web Activity -> Azure Monitor Alert]
```

### 4.3 Sub-Pipeline: Copy Full Load

```
pl_copy_full_load
===================================================================
Parameters: source_schema, source_table, landing_path

[Copy Activity]
  Source:
    Type: SqlServerSource
    Query: SELECT * FROM @{pipeline().parameters.source_schema}.@{pipeline().parameters.source_table}
  Sink:
    Type: ParquetSink
    Path: @{pipeline().parameters.landing_path}/@{formatDateTime(utcnow(), 'yyyy/MM/dd/HHmmss')}/
  Settings:
    Data Integration Units: 4
    Degree of Copy Parallelism: 4
```

### 4.4 Sub-Pipeline: Copy Incremental

```
pl_copy_incremental
===================================================================
Parameters: source_schema, source_table, watermark_column,
            last_watermark_value, landing_path

[Lookup: Get Max Watermark]
  Query: SELECT MAX(@{pipeline().parameters.watermark_column}) as maxWatermark
         FROM @{pipeline().parameters.source_schema}.@{pipeline().parameters.source_table}

[Copy Activity]
  Source:
    Type: SqlServerSource
    Query: SELECT * FROM @{pipeline().parameters.source_schema}.@{pipeline().parameters.source_table}
           WHERE @{pipeline().parameters.watermark_column}
                 > '@{pipeline().parameters.last_watermark_value}'
             AND @{pipeline().parameters.watermark_column}
                 <= '@{activity('Get Max Watermark').output.firstRow.maxWatermark}'
  Sink:
    Type: ParquetSink
    Path: @{pipeline().parameters.landing_path}/@{formatDateTime(utcnow(), 'yyyy/MM/dd/HHmmss')}/

Output: maxWatermark = @{activity('Get Max Watermark').output.firstRow.maxWatermark}
```

### 4.5 Linked Services - Configuracao

| Linked Service | Tipo | Autenticacao | Detalhes |
|----------------|------|-------------|----------|
| `ls_sqlserver` | SQL Server | Key Vault Secret | Connection string no KV. Self-Hosted IR se on-prem |
| `ls_adls` | ADLS Gen2 | Managed Identity | URL: `https://stretailmax{env}.dfs.core.windows.net` |
| `ls_databricks` | Azure Databricks | SPN (Key Vault) | Token ou SPN via KV. Existing cluster ou job cluster |
| `ls_keyvault` | Azure Key Vault | Managed Identity | URL: `https://kv-retailmax-{env}.vault.azure.net` |

---

## 5. Desenvolvimento - Databricks

### 5.1 Estrutura do Repositorio `databricks-pipelines`

```
databricks-pipelines/
├── README.md
├── databricks.yml                     # Databricks Asset Bundle config
├── requirements.txt                   # Runtime dependencies
├── requirements-dev.txt               # Dev/test dependencies
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── pipelines/
│   │   ├── __init__.py
│   │   ├── bronze/
│   │   │   ├── __init__.py
│   │   │   └── ingest_bronze.py       # DLT Bronze (Auto Loader, 5 tabelas)
│   │   ├── silver/
│   │   │   ├── __init__.py
│   │   │   └── transform_silver.py    # DLT Silver (limpeza, expectations DROP)
│   │   └── gold/
│   │       ├── __init__.py
│   │       ├── model_gold.py          # DLT Gold (fact + dims)
│   │       └── kpis_gold.py           # DLT Gold (KPIs: receita, churn, etc.)
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── expectations.py            # Expectations reutilizaveis
│   │   └── schema_definitions.py      # Schemas tipados por tabela
│   └── setup/
│       ├── create_ingestion_control.py # DDL da tabela de controle
│       └── trigger_dlt_refresh.py      # Notebook chamado pelo ADF
├── tests/
│   ├── __init__.py
│   ├── conftest.py                    # Fixtures (SparkSession, dados mock)
│   ├── test_bronze.py
│   ├── test_silver.py
│   ├── test_gold.py
│   └── test_expectations.py
└── resources/
    ├── dlt_pipeline_config.json       # Config do DLT pipeline
    └── cluster_config.json            # Config de clusters
```

### 5.2 Databricks Asset Bundle

```yaml
# databricks.yml
bundle:
  name: retailmax-pipelines

workspace:
  root_path: /Shared/retailmax

targets:
  dev:
    workspace:
      host: https://dbx-retailmax-dev.azuredatabricks.net
    default: true

  hml:
    workspace:
      host: https://dbx-retailmax-hml.azuredatabricks.net

  prd:
    workspace:
      host: https://dbx-retailmax-prd.azuredatabricks.net

resources:
  pipelines:
    retailmax_dlt_pipeline:
      name: "retailmax_medallion_pipeline"
      target: "retailmax_${bundle.target}"
      catalog: "retailmax_${bundle.target}"
      libraries:
        - notebook:
            path: src/pipelines/bronze/ingest_bronze.py
        - notebook:
            path: src/pipelines/silver/transform_silver.py
        - notebook:
            path: src/pipelines/gold/model_gold.py
        - notebook:
            path: src/pipelines/gold/kpis_gold.py
      configuration:
        "spark.databricks.delta.preview.enabled": "true"
      photon: true
      serverless: true
      channel: "PREVIEW"
      edition: "ADVANCED"
      continuous: false

  jobs:
    retailmax_dlt_job:
      name: "retailmax_dlt_refresh"
      tasks:
        - task_key: "run_dlt"
          pipeline_task:
            pipeline_id: ${resources.pipelines.retailmax_dlt_pipeline.id}
            full_refresh: false
```

### 5.3 Unity Catalog - Setup

```sql
-- setup/create_catalog.sql (executar manualmente ou via notebook)

-- Criar catalogos (3 ambientes)
CREATE CATALOG IF NOT EXISTS retailmax_dev;
CREATE CATALOG IF NOT EXISTS retailmax_hml;
CREATE CATALOG IF NOT EXISTS retailmax_prd;

-- Schemas em dev
USE CATALOG retailmax_dev;
CREATE SCHEMA IF NOT EXISTS bronze COMMENT 'Raw ingested data';
CREATE SCHEMA IF NOT EXISTS silver COMMENT 'Cleaned and validated data';
CREATE SCHEMA IF NOT EXISTS gold   COMMENT 'Dimensional model and KPIs';

-- Schemas em hml (mesma estrutura)
USE CATALOG retailmax_hml;
CREATE SCHEMA IF NOT EXISTS bronze COMMENT 'Raw ingested data';
CREATE SCHEMA IF NOT EXISTS silver COMMENT 'Cleaned and validated data';
CREATE SCHEMA IF NOT EXISTS gold   COMMENT 'Dimensional model and KPIs';

-- Schemas em prd (mesma estrutura)
USE CATALOG retailmax_prd;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
```

### 5.4 Tabela ingestion_control - DDL

```python
# src/setup/create_ingestion_control.py
import dlt  # noqa: F401 (para contexto do notebook)

# Executar como notebook normal (nao DLT)
# NOTA: substituir retailmax_dev por retailmax_hml ou retailmax_prd conforme ambiente
catalog = spark.conf.get("spark.databricks.unityCatalog.catalog", "retailmax_dev")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {catalog}.bronze.ingestion_control (
    source_schema        STRING    NOT NULL COMMENT 'Schema de origem no SQL Server',
    source_table         STRING    NOT NULL COMMENT 'Tabela de origem',
    target_schema        STRING    NOT NULL COMMENT 'Schema destino no Lakehouse',
    target_table         STRING    NOT NULL COMMENT 'Tabela destino',
    load_type            STRING    NOT NULL COMMENT 'full ou incremental',
    watermark_column     STRING             COMMENT 'Coluna para carga incremental',
    last_watermark_value TIMESTAMP          COMMENT 'Ultimo valor processado',
    primary_key          STRING    NOT NULL COMMENT 'Chave primaria para dedup',
    is_active            BOOLEAN   NOT NULL DEFAULT true COMMENT 'Ativar/desativar',
    landing_path         STRING    NOT NULL COMMENT 'Caminho ADLS Gen2',
    schedule_frequency   STRING    NOT NULL DEFAULT 'daily' COMMENT 'daily/hourly/weekly',
    last_load_status     STRING             COMMENT 'SUCCESS/FAILED/RUNNING',
    last_load_timestamp  TIMESTAMP          COMMENT 'Quando foi a ultima carga',
    row_count_last_load  BIGINT             COMMENT 'Registros ultima carga',
    created_at           TIMESTAMP NOT NULL DEFAULT current_timestamp(),
    updated_at           TIMESTAMP NOT NULL DEFAULT current_timestamp()
)
USING DELTA
COMMENT 'Tabela de controle metadata-driven para ingestao ADF'
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality' = 'system'
)
""")

# Dados iniciais
spark.sql(f"""
INSERT INTO {catalog}.bronze.ingestion_control
(source_schema, source_table, target_schema, target_table, load_type,
 watermark_column, primary_key, is_active, landing_path, schedule_frequency)
VALUES
('Sales',      'SalesOrderHeader',  'bronze', 'SalesOrderHeader_bronze',  'incremental', 'ModifiedDate', 'SalesOrderID',    true, '/landing/SalesOrderHeader/',  'daily'),
('Sales',      'SalesOrderDetail',  'bronze', 'SalesOrderDetail_bronze',  'incremental', 'ModifiedDate', 'SalesOrderDetailID', true, '/landing/SalesOrderDetail/',  'daily'),
('Sales',      'Customer',          'bronze', 'Customer_bronze',          'full',         NULL,          'CustomerID',      true, '/landing/Customer/',           'daily'),
('Production', 'Product',           'bronze', 'Product_bronze',           'full',         NULL,          'ProductID',       true, '/landing/Product/',            'daily'),
('Production', 'ProductInventory',  'bronze', 'ProductInventory_bronze',  'incremental', 'ModifiedDate', 'ProductID',       true, '/landing/ProductInventory/',   'daily')
""")
```

### 5.5 DLT Pipeline - Bronze

```python
# src/pipelines/bronze/ingest_bronze.py
import dlt
from pyspark.sql import functions as F

# Storage account varia por ambiente: stretailmaxdev / stretailmaxhml / stretailmaxprd
# Configurado via pipeline settings ou spark.conf
LANDING_BASE = spark.conf.get(
    "retailmax.landing_base",
    "abfss://landing@stretailmaxdev.dfs.core.windows.net"
)

# -------------------------------------------------------------------
# Helper: cria uma streaming table bronze genérica
# -------------------------------------------------------------------
def create_bronze_table(table_name: str, landing_path: str, comment: str):
    @dlt.expect("rescued_data_null", "_rescued_data IS NULL")
    @dlt.table(
        name=f"{table_name}_bronze",
        comment=comment,
        table_properties={"quality": "bronze"},
    )
    def _inner():
        return (
            spark.readStream
            .format("cloudFiles")
            .option("cloudFiles.format", "parquet")
            .option("cloudFiles.inferColumnTypes", "true")
            .option("cloudFiles.schemaLocation", f"{LANDING_BASE}/_schemas/{table_name}")
            .load(f"{LANDING_BASE}/{landing_path}")
            .withColumn("_ingested_at", F.current_timestamp())
            .withColumn("_source_file", F.input_file_name())
        )
    return _inner

# -------------------------------------------------------------------
# Bronze Tables
# -------------------------------------------------------------------
sales_order_header_bronze = create_bronze_table(
    "SalesOrderHeader",
    "SalesOrderHeader/",
    "Cabecalho de pedidos - ingestao bruta"
)

sales_order_detail_bronze = create_bronze_table(
    "SalesOrderDetail",
    "SalesOrderDetail/",
    "Detalhes de pedidos - ingestao bruta"
)

customer_bronze = create_bronze_table(
    "Customer",
    "Customer/",
    "Clientes - ingestao bruta"
)

product_bronze = create_bronze_table(
    "Product",
    "Product/",
    "Produtos - ingestao bruta"
)

product_inventory_bronze = create_bronze_table(
    "ProductInventory",
    "ProductInventory/",
    "Estoque de produtos - ingestao bruta"
)
```

### 5.6 DLT Pipeline - Silver

```python
# src/pipelines/silver/transform_silver.py
import dlt
from pyspark.sql import functions as F

# -------------------------------------------------------------------
# Silver: SalesOrderHeader
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_order_id": "SalesOrderID IS NOT NULL",
    "valid_customer": "CustomerID IS NOT NULL",
    "valid_date": "OrderDate IS NOT NULL",
    "valid_total": "TotalDue >= 0",
})
@dlt.table(
    name="SalesOrderHeader_silver",
    comment="Cabecalho de pedidos - limpo e validado",
    table_properties={"quality": "silver"},
)
def sales_order_header_silver():
    return (
        dlt.read_stream("SalesOrderHeader_bronze")
        .dropDuplicates(["SalesOrderID"])
        .withColumn("OrderDate", F.to_date("OrderDate"))
        .withColumn("ShipDate", F.to_date("ShipDate"))
        .withColumn("DueDate", F.to_date("DueDate"))
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: SalesOrderDetail
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_detail_id": "SalesOrderDetailID IS NOT NULL",
    "valid_order_ref": "SalesOrderID IS NOT NULL",
    "valid_product": "ProductID IS NOT NULL",
    "positive_qty": "OrderQty > 0",
    "positive_price": "UnitPrice >= 0",
})
@dlt.table(
    name="SalesOrderDetail_silver",
    comment="Detalhes de pedidos - limpo e validado",
    table_properties={"quality": "silver"},
)
def sales_order_detail_silver():
    return (
        dlt.read_stream("SalesOrderDetail_bronze")
        .dropDuplicates(["SalesOrderDetailID"])
        .withColumn("LineTotal", F.col("OrderQty") * F.col("UnitPrice"))
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: Customer
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_customer_id": "CustomerID IS NOT NULL",
    "valid_account": "AccountNumber IS NOT NULL",
})
@dlt.table(
    name="Customer_silver",
    comment="Clientes - limpo e validado",
    table_properties={"quality": "silver"},
)
def customer_silver():
    return (
        dlt.read_stream("Customer_bronze")
        .dropDuplicates(["CustomerID"])
        .withColumn("AccountNumber", F.trim(F.upper(F.col("AccountNumber"))))
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: Product
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_product_id": "ProductID IS NOT NULL",
    "valid_name": "Name IS NOT NULL",
    "valid_price": "ListPrice >= 0",
})
@dlt.table(
    name="Product_silver",
    comment="Produtos - limpo e validado",
    table_properties={"quality": "silver"},
)
def product_silver():
    return (
        dlt.read_stream("Product_bronze")
        .dropDuplicates(["ProductID"])
        .withColumn("Name", F.trim(F.col("Name")))
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: ProductInventory
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_product_id": "ProductID IS NOT NULL",
    "valid_location": "LocationID IS NOT NULL",
    "valid_quantity": "Quantity >= 0",
})
@dlt.table(
    name="ProductInventory_silver",
    comment="Estoque - limpo e validado",
    table_properties={"quality": "silver"},
)
def product_inventory_silver():
    return (
        dlt.read_stream("ProductInventory_bronze")
        .dropDuplicates(["ProductID", "LocationID"])
        .withColumn("_processed_at", F.current_timestamp())
    )
```

### 5.7 DLT Pipeline - Gold (Modelo Dimensional)

```python
# src/pipelines/gold/model_gold.py
import dlt
from pyspark.sql import functions as F

# -------------------------------------------------------------------
# dim_date (gerada, nao depende de fonte)
# -------------------------------------------------------------------
@dlt.table(
    name="dim_date",
    comment="Dimensao de data",
    table_properties={"quality": "gold"},
)
def dim_date():
    # Gerar range de datas: 2010-01-01 a 2030-12-31
    return (
        spark.sql("""
            SELECT
                CAST(date_format(d, 'yyyyMMdd') AS INT) AS DateKey,
                d AS FullDate,
                YEAR(d) AS Year,
                QUARTER(d) AS Quarter,
                MONTH(d) AS Month,
                DAY(d) AS Day,
                dayofweek(d) AS DayOfWeek,
                date_format(d, 'EEEE') AS DayName,
                CASE WHEN dayofweek(d) IN (1, 7) THEN true ELSE false END AS IsWeekend
            FROM (
                SELECT explode(sequence(
                    to_date('2010-01-01'),
                    to_date('2030-12-31'),
                    interval 1 day
                )) AS d
            )
        """)
    )


# -------------------------------------------------------------------
# dim_customer
# -------------------------------------------------------------------
@dlt.table(
    name="dim_customer",
    comment="Dimensao de clientes",
    table_properties={"quality": "gold"},
)
def dim_customer():
    customer = spark.read.table("LIVE.Customer_silver")
    orders = spark.read.table("LIVE.SalesOrderHeader_silver")

    customer_metrics = (
        orders
        .groupBy("CustomerID")
        .agg(
            F.min("OrderDate").alias("FirstPurchase"),
            F.max("OrderDate").alias("LastPurchase"),
            F.countDistinct("SalesOrderID").alias("TotalOrders"),
        )
    )

    return (
        customer
        .join(customer_metrics, "CustomerID", "left")
        .withColumn("CustomerKey", F.monotonically_increasing_id())
        .withColumn(
            "IsChurned",
            F.when(
                F.col("LastPurchase") < F.date_sub(F.current_date(), 90), True
            ).otherwise(False)
        )
        .select(
            "CustomerKey", "CustomerID", "AccountNumber",
            "CustomerType", "TerritoryID",
            "FirstPurchase", "LastPurchase", "TotalOrders", "IsChurned",
        )
    )


# -------------------------------------------------------------------
# dim_product
# -------------------------------------------------------------------
@dlt.table(
    name="dim_product",
    comment="Dimensao de produtos",
    table_properties={"quality": "gold"},
)
def dim_product():
    return (
        spark.read.table("LIVE.Product_silver")
        .withColumn("ProductKey", F.monotonically_increasing_id())
        .select(
            "ProductKey", "ProductID", "Name", "ProductNumber",
            "Color", "ListPrice", "StandardCost",
            "ProductSubcategoryID",
        )
    )


# -------------------------------------------------------------------
# fact_sales
# -------------------------------------------------------------------
@dlt.expect_or_fail("revenue_positive", "Revenue >= 0")
@dlt.expect_or_fail("valid_customer_key", "CustomerKey IS NOT NULL")
@dlt.expect_or_fail("valid_product_key", "ProductKey IS NOT NULL")
@dlt.table(
    name="fact_sales",
    comment="Fato de vendas - modelo dimensional",
    table_properties={"quality": "gold"},
)
def fact_sales():
    header = spark.read.table("LIVE.SalesOrderHeader_silver")
    detail = spark.read.table("LIVE.SalesOrderDetail_silver")
    dim_cust = spark.read.table("LIVE.dim_customer").select("CustomerKey", "CustomerID")
    dim_prod = spark.read.table("LIVE.dim_product").select("ProductKey", "ProductID")

    return (
        detail
        .join(header, "SalesOrderID")
        .join(dim_cust, "CustomerID")
        .join(dim_prod, "ProductID")
        .select(
            F.monotonically_increasing_id().alias("SalesKey"),
            "SalesOrderID",
            F.date_format("OrderDate", "yyyyMMdd").cast("int").alias("OrderDateKey"),
            "CustomerKey",
            "ProductKey",
            "OrderQty",
            "UnitPrice",
            (F.col("OrderQty") * F.col("UnitPrice")).alias("Revenue"),
            "LineTotal",
            F.col("Status").alias("OrderStatus"),
        )
    )
```

### 5.8 DLT Pipeline - Gold (KPIs)

```python
# src/pipelines/gold/kpis_gold.py
import dlt
from pyspark.sql import functions as F

# -------------------------------------------------------------------
# KPI: Receita Total por periodo
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_receita_total",
    comment="KPI: Receita total agregada por periodo",
    table_properties={"quality": "gold"},
)
def kpi_receita_total():
    return (
        spark.read.table("LIVE.fact_sales")
        .join(spark.read.table("LIVE.dim_date"), "OrderDateKey")
        .groupBy("Year", "Quarter", "Month")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.countDistinct("SalesOrderID").alias("TotalPedidos"),
            (F.sum("Revenue") / F.countDistinct("SalesOrderID")).alias("TicketMedio"),
        )
    )


# -------------------------------------------------------------------
# KPI: Ticket Medio por periodo e segmento
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_ticket_medio",
    comment="KPI: Ticket medio por periodo",
    table_properties={"quality": "gold"},
)
def kpi_ticket_medio():
    return (
        spark.read.table("LIVE.fact_sales")
        .join(spark.read.table("LIVE.dim_date"), "OrderDateKey")
        .join(spark.read.table("LIVE.dim_customer"), "CustomerKey")
        .groupBy("Year", "Month", "CustomerType")
        .agg(
            F.sum("Revenue").alias("Receita"),
            F.countDistinct("SalesOrderID").alias("Pedidos"),
            (F.sum("Revenue") / F.countDistinct("SalesOrderID")).alias("TicketMedio"),
        )
    )


# -------------------------------------------------------------------
# KPI: Churn (clientes sem compra > 90 dias)
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_churn",
    comment="KPI: Clientes em churn (sem compra > 90 dias)",
    table_properties={"quality": "gold"},
)
def kpi_churn():
    return (
        spark.read.table("LIVE.dim_customer")
        .select(
            "CustomerKey", "CustomerID", "AccountNumber",
            "LastPurchase", "TotalOrders", "IsChurned",
            F.datediff(F.current_date(), "LastPurchase").alias("DaysSinceLastPurchase"),
        )
        .where("IsChurned = true")
    )


# -------------------------------------------------------------------
# KPI: Estoque Critico (qty < 10)
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_estoque_critico",
    comment="KPI: Produtos com estoque critico (< 10 unidades)",
    table_properties={"quality": "gold"},
)
def kpi_estoque_critico():
    inventory = spark.read.table("LIVE.ProductInventory_silver")
    product = spark.read.table("LIVE.dim_product")

    return (
        inventory
        .where("Quantity < 10")
        .join(product, "ProductID")
        .select(
            "ProductKey", "ProductID", "Name", "Quantity",
            "LocationID", "ListPrice",
        )
    )


# -------------------------------------------------------------------
# KPI: Top Produtos por receita
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_top_produtos",
    comment="KPI: Ranking de produtos por receita",
    table_properties={"quality": "gold"},
)
def kpi_top_produtos():
    return (
        spark.read.table("LIVE.fact_sales")
        .join(spark.read.table("LIVE.dim_product"), "ProductKey")
        .groupBy("ProductKey", "ProductID", "Name")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.sum("OrderQty").alias("QtdTotal"),
            F.countDistinct("SalesOrderID").alias("TotalPedidos"),
        )
        .orderBy(F.desc("ReceitaTotal"))
    )
```

### 5.9 Trigger DLT Refresh (chamado pelo ADF)

```python
# src/setup/trigger_dlt_refresh.py
# Notebook Databricks chamado pelo ADF via Notebook Activity

dbutils.widgets.text("pipeline_name", "retailmax_dlt_pipeline")
pipeline_name = dbutils.widgets.get("pipeline_name")

# Buscar pipeline ID pelo nome
import json
import requests

host = dbutils.notebook.entry_point.getDbutils().notebook().getContext().apiUrl().getOrElse(None)
token = dbutils.notebook.entry_point.getDbutils().notebook().getContext().apiToken().getOrElse(None)

# Listar pipelines
response = requests.get(
    f"{host}/api/2.0/pipelines",
    headers={"Authorization": f"Bearer {token}"},
    params={"filter": f"name LIKE '{pipeline_name}'"},
)
pipelines = response.json().get("statuses", [])

if not pipelines:
    dbutils.notebook.exit(json.dumps({"status": "ERROR", "message": f"Pipeline '{pipeline_name}' not found"}))

pipeline_id = pipelines[0]["pipeline_id"]

# Trigger update (incremental)
response = requests.post(
    f"{host}/api/2.0/pipelines/{pipeline_id}/updates",
    headers={"Authorization": f"Bearer {token}"},
    json={"full_refresh": False},
)

result = response.json()
dbutils.notebook.exit(json.dumps({"status": "TRIGGERED", "update_id": result.get("update_id")}))
```

---

## 6. Desenvolvimento - Databricks App (Master Data)

### 6.1 Estrutura do Repositorio `databricks-app`

```
databricks-app/
├── README.md
├── app.py                             # Entry point Streamlit
├── requirements.txt
├── pages/
│   ├── 1_visao_geral.py               # Metricas de qualidade
│   ├── 2_registros_anomalos.py         # Registros com problemas
│   ├── 3_historico_cargas.py           # Dados da ingestion_control
│   └── 4_master_data_review.py         # Validacao manual
├── utils/
│   ├── __init__.py
│   ├── db_connection.py               # Conexao Databricks SQL
│   └── queries.py                     # SQL queries parametrizadas
├── app.yaml                           # Config Databricks App
└── tests/
    └── test_queries.py
```

### 6.2 App Entry Point

```python
# app.py
import streamlit as st

st.set_page_config(
    page_title="RetailMax - Master Data Validation",
    page_icon="📊",
    layout="wide",
)

st.title("RetailMax - Master Data Validation")
st.markdown("""
Aplicacao para monitoramento e validacao de dados mestres.
Use o menu lateral para navegar entre as telas.
""")

st.sidebar.success("Selecione uma pagina acima.")

# Metricas resumo na home
col1, col2, col3, col4 = st.columns(4)
# Populados via queries ao Unity Catalog
```

### 6.3 Databricks App Config

```yaml
# app.yaml
command:
  - "streamlit"
  - "run"
  - "app.py"
  - "--server.port=8080"
  - "--server.headless=true"
env:
  - name: DATABRICKS_WAREHOUSE_ID
    value: "${WAREHOUSE_ID}"
```

---

## 7. Estrategia de Testes

### 7.1 Piramide de Testes

```
                    /\
                   /  \    E2E (manual)
                  / E2E\   Pipeline completo: SQL Server -> Gold -> Dashboard
                 /------\
                /        \  Integracao
               / Integr.  \ DLT expectations + Unity Catalog em workspace dev
              /------------\
             /              \ Unitarios
            /   Unitarios    \ Transformacoes PySpark com dados mock (pytest)
           /------------------\
```

### 7.2 Testes Unitarios (pytest)

```python
# tests/conftest.py
import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    return (
        SparkSession.builder
        .master("local[*]")
        .appName("retailmax-tests")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
        .getOrCreate()
    )

@pytest.fixture
def sample_sales_header(spark):
    data = [
        (1, 101, "2026-01-15", 150.00, 1),
        (2, 102, "2026-01-16", 200.00, 1),
        (3, None, "2026-01-17", 100.00, 1),  # customer nulo - deve ser dropado
        (4, 103, None, 50.00, 1),              # data nula - deve ser dropada
    ]
    return spark.createDataFrame(data, ["SalesOrderID", "CustomerID", "OrderDate", "TotalDue", "Status"])
```

```python
# tests/test_silver.py
def test_sales_header_dedup(spark, sample_sales_header):
    """Deduplicacao deve remover registros com mesmo SalesOrderID."""
    from pyspark.sql import functions as F

    # Simular duplicata
    duped = sample_sales_header.union(sample_sales_header.limit(1))
    result = duped.dropDuplicates(["SalesOrderID"])
    assert result.count() == sample_sales_header.count()


def test_sales_header_null_filter(spark, sample_sales_header):
    """Registros com CustomerID ou OrderDate nulos devem ser removidos."""
    result = (
        sample_sales_header
        .where("CustomerID IS NOT NULL AND OrderDate IS NOT NULL")
    )
    assert result.count() == 2  # apenas os 2 validos


def test_revenue_calculation(spark):
    """Revenue = OrderQty * UnitPrice."""
    from pyspark.sql import functions as F

    data = [(1, 5, 10.00), (2, 3, 25.50)]
    df = spark.createDataFrame(data, ["DetailID", "OrderQty", "UnitPrice"])
    result = df.withColumn("Revenue", F.col("OrderQty") * F.col("UnitPrice"))

    revenues = [row.Revenue for row in result.collect()]
    assert revenues == [50.00, 76.50]
```

### 7.3 Testes de Integracao (Databricks dev)

```
CHECKLIST DE INTEGRACAO (executar no workspace dev)
===================================================================

[ ] DLT Pipeline executa sem erro (full refresh)
[ ] Bronze: 5 streaming tables criadas com dados
[ ] Silver: expectations DROP removendo registros invalidos
[ ] Gold: fact_sales com foreign keys validas
[ ] Gold: KPIs calculados corretamente
[ ] Unity Catalog: linhagem visivel ate a origem
[ ] ingestion_control: watermark atualizado apos execucao
[ ] ADF -> Databricks: trigger funcionando end-to-end
[ ] Row Filters: usuarios restritos nao veem dados de outros territorios
[ ] Genie: responde "Qual a receita total?" com dado correto
[ ] App: carrega metricas de qualidade sem erro
```

---

## 8. Cronograma Detalhado - Tarefas por Semana

### FASE 1: Fundacao, Infraestrutura e DevOps (S1-S4)

```
SEMANA 1: Azure DevOps + Terraform Base
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S1-1 | Criar Azure DevOps Org + 3 projetos             | DevOps
S1-1 | Configurar repos, branch policies               | DevOps
S1-2 | Criar Terraform state backend (Storage Account)  | Infra
S1-2 | Implementar modulo: resource-group               | Infra
S1-3 | Implementar modulo: networking (VNet, Subnets)   | Infra
S1-3 | Implementar modulo: keyvault                     | Infra
S1-4 | Implementar modulo: storage (ADLS Gen2)          | Infra
S1-4 | Configurar CI pipeline Terraform (validate/plan) | DevOps
S1-5 | Code review + merge -> terraform apply dev       | Infra

ENTREGAVEIS:
[x] DevOps Organization + 3 projetos
[x] Terraform: RG + VNet + ADLS + Key Vault em dev
[x] CI pipeline rodando em PRs


SEMANA 2: Databricks + ADF + Identidade
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S2-1 | Implementar modulo: databricks (VNet injection)  | Infra
S2-2 | Implementar modulo: data-factory                 | Infra
S2-2 | Implementar modulo: identity (SPNs, MI, Groups)  | Infra
S2-3 | Implementar modulo: monitoring (Log Analytics)    | Infra
S2-3 | Terraform apply dev (todos os modulos)            | Infra
S2-4 | Configurar Service Connections no DevOps          | DevOps
S2-4 | Configurar Variable Groups (dev/hml/prd/secrets)   | DevOps
S2-5 | Validar acesso a todos os recursos em dev         | Infra

ENTREGAVEIS:
[x] TODOS os recursos Azure provisionados em dev
[x] Service Connections e Variable Groups configurados
[x] Acesso validado (ADF -> ADLS, ADF -> DBX, DBX -> ADLS)


SEMANA 3: Unity Catalog + ADF Linked Services + CI/CD
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S3-1 | Criar Unity Catalog: retailmax_dev (catalogos)   | Data Eng
S3-1 | Criar schemas: bronze, silver, gold               | Data Eng
S3-2 | Configurar RBAC: groups + grants                  | Data Eng
S3-2 | ADF: criar Linked Services (SQL, ADLS, DBX, KV)  | Data Eng
S3-3 | ADF: configurar Git integration (adf repo)       | DevOps
S3-3 | Criar CI/CD pipeline para ADF (validate + deploy) | DevOps
S3-4 | Criar CI/CD pipeline para Databricks (test + deploy)| DevOps
S3-5 | Validar CI/CD end-to-end (PR -> merge -> deploy)  | DevOps

ENTREGAVEIS:
[x] Unity Catalog operacional com schemas
[x] ADF com Linked Services configurados
[x] CI/CD operacional para os 3 projetos


SEMANA 4: Tabela de Controle + Pipeline Template + Hello World
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S4-1 | Criar ingestion_control DDL no Unity Catalog     | Data Eng
S4-1 | Inserir dados iniciais (5 tabelas)               | Data Eng
S4-2 | Criar pipeline ADF pl_master_ingestion (Lookup)   | Data Eng
S4-2 | Criar sub-pipelines (full + incremental)          | Data Eng
S4-3 | Criar DLT template "hello world" (1 tabela)      | Data Eng
S4-3 | Testar ADF -> ADLS -> DLT flow completo           | Data Eng
S4-4 | Documentar onboarding (README de cada repo)       | Data Eng
S4-5 | Demo + validacao com equipe                       | Todos

ENTREGAVEIS:
[x] ingestion_control populada e funcional
[x] Pipeline ADF master testado (Lookup + ForEach)
[x] DLT template executando no workspace
[x] Flow ADF -> DLT validado end-to-end
[x] Documentacao de onboarding

>>> MILESTONE M1: INFRA READY <<<
```

### FASE 2: Ingestao e Camada Bronze (S5-S7)

```
SEMANA 5: ADF Metadata-Driven + Auto Loader Setup
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S5-1 | Refinar pipeline ADF: error handling, retry      | Data Eng
S5-2 | Implementar update de watermark e status          | Data Eng
S5-3 | Configurar Auto Loader schemas (cloudFiles)       | Data Eng
S5-4 | Carga full inicial: todas 5 tabelas               | Data Eng
S5-5 | Validar dados na landing zone (formato, volume)   | Data Eng


SEMANA 6: DLT Bronze Tables + Expectations WARN
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S6-1 | Implementar ingest_bronze.py (5 streaming tables) | Data Eng
S6-2 | Configurar expectations WARN em cada tabela        | Data Eng
S6-3 | Executar full refresh do DLT pipeline              | Data Eng
S6-4 | Validar linhagem no Unity Catalog                  | Data Eng
S6-5 | Validar metricas de qualidade no DLT dashboard     | Data Eng


SEMANA 7: Carga Incremental + Validacao End-to-End
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S7-1 | Testar carga incremental (inserir dados novos)    | Data Eng
S7-2 | Validar watermark atualizado na ingestion_control | Data Eng
S7-3 | Testar adicionar nova tabela (INSERT na control)  | Data Eng
S7-4 | Configurar trigger diario no ADF (02:00 UTC)      | Data Eng
S7-5 | Demo: flow completo SQL Server -> Bronze           | Todos

>>> MILESTONE M2: DATA LANDING <<<
```

### FASE 3: Transformacao e Camada Silver (S8-S10)

```
SEMANA 8: Silver - SalesOrderHeader + SalesOrderDetail
===================================================================
S8-1 | Implementar SalesOrderHeader_silver (dedup, tipos) | Data Eng
S8-2 | Implementar SalesOrderDetail_silver (dedup, calc)  | Data Eng
S8-3 | Configurar expectations DROP em ambas               | Data Eng
S8-4 | Escrever testes unitarios (pytest)                  | Data Eng
S8-5 | Code review + merge                                 | Data Eng


SEMANA 9: Silver - Customer + Product + Inventory
===================================================================
S9-1 | Implementar Customer_silver (dedup, padronizacao)   | Data Eng
S9-2 | Implementar Product_silver (dedup, validacao preco) | Data Eng
S9-3 | Implementar ProductInventory_silver (dedup, qty)    | Data Eng
S9-4 | Configurar expectations DROP                        | Data Eng
S9-5 | Testes unitarios + code review                      | Data Eng


SEMANA 10: Validacao Silver Layer + Testes Integracao
===================================================================
S10-1 | Executar DLT full refresh (Bronze + Silver)         | Data Eng
S10-2 | Analisar taxa de registros dropados (< 5%?)         | Data Eng
S10-3 | Executar testes de integracao no workspace dev       | Data Eng
S10-4 | Documentar regras de qualidade aplicadas             | Data Eng
S10-5 | Demo: qualidade de dados Bronze vs Silver            | Todos

>>> MILESTONE M3: CLEAN DATA <<<
```

### FASE 4: Modelo Dimensional e Camada Gold (S11-S14)

```
SEMANA 11: dim_date + dim_customer
===================================================================
S11-1 | Implementar dim_date (gerada por range)             | Data Eng
S11-2 | Implementar dim_customer (metricas + churn flag)    | Data Eng
S11-3 | Testes unitarios para logica de churn                | Data Eng
S11-4 | Code review + merge                                  | Data Eng


SEMANA 12: dim_product + fact_sales
===================================================================
S12-1 | Implementar dim_product                              | Data Eng
S12-2 | Implementar fact_sales (joins + revenue calc)        | Data Eng
S12-3 | Configurar expectations FAIL (integridade ref.)      | Data Eng
S12-4 | Testes unitarios para revenue e joins                | Data Eng
S12-5 | Z-ORDER em OrderDateKey e CustomerKey                | Data Eng


SEMANA 13: KPIs
===================================================================
S13-1 | Implementar kpi_receita_total                        | Data Eng
S13-2 | Implementar kpi_ticket_medio                         | Data Eng
S13-3 | Implementar kpi_churn + kpi_estoque_critico          | Data Eng
S13-4 | Implementar kpi_top_produtos                         | Data Eng
S13-5 | Validacao cruzada: KPIs vs SQL Server direto         | Data Eng


SEMANA 14: Validacao Gold Layer + Stakeholders
===================================================================
S14-1 | Executar DLT full refresh (Bronze -> Silver -> Gold) | Data Eng
S14-2 | Validar modelo dimensional com stakeholders          | Data Eng
S14-3 | Correcoes pos-feedback                               | Data Eng
S14-4 | Testes de integracao completos                       | Data Eng
S14-5 | Demo: modelo Gold + KPIs                             | Todos

>>> MILESTONE M4: ANALYTICS READY <<<
```

### FASE 5: Consumo, Dashboards, GenAI e App (S15-S18)

```
SEMANA 15: SQL Endpoint + Databricks Dashboards
===================================================================
S15-1 | Configurar SQL Endpoint serverless                   | Data Eng
S15-2 | Criar Dashboard: Vendas (receita, ticket, trends)    | Analista
S15-3 | Criar Dashboard: Clientes (churn, segmentacao)       | Analista
S15-4 | Criar Dashboard: Estoque (niveis, criticos)          | Analista
S15-5 | Configurar refresh automatico dos dashboards          | Data Eng


SEMANA 16: Databricks Genie + Seguranca
===================================================================
S16-1 | Criar Genie Space vinculado ao Gold layer            | Data Eng
S16-2 | Escrever instrucoes de contexto (glossario, KPIs)    | Analista
S16-3 | Testar queries em linguagem natural                  | Analista
S16-4 | Implementar Row Filters (restricao por territorio)   | Data Eng
S16-5 | Implementar Column Masks (AccountNumber)             | Data Eng


SEMANA 17: Databricks App (Master Data)
===================================================================
S17-1 | Implementar pagina: Visao Geral de Qualidade         | Data Eng
S17-2 | Implementar pagina: Registros Anomalos                | Data Eng
S17-3 | Implementar pagina: Historico de Cargas                | Data Eng
S17-4 | Implementar pagina: Master Data Review                | Data Eng
S17-5 | Deploy app no workspace dev + testes                  | Data Eng


SEMANA 18: Validacao + Treinamento Usuarios
===================================================================
S18-1 | Validar dashboards com stakeholders de negocio        | Analista
S18-2 | Validar Genie com perguntas reais                     | Analista
S18-3 | Validar App com equipe de dados mestres               | Data Eng
S18-4 | Criar documentacao de uso para cada ferramenta        | Data Eng
S18-5 | Sessao de treinamento com usuarios finais             | Todos

>>> MILESTONE M5: USER ACCESS <<<
```

### FASE 6: Operacoes, Deploy Hml/Prd e Go-Live (S19-S23)

```
SEMANA 19: Deploy de Infraestrutura em Homologacao
===================================================================
S19-1 | Terraform plan hml (review detalhado)                | Infra
S19-2 | Terraform apply hml                                  | Infra
S19-3 | Validar todos os recursos em hml                     | Infra
S19-4 | Configurar Unity Catalog retailmax_hml               | Data Eng
S19-5 | Deploy ADF + Databricks + App em hml via CI/CD       | DevOps


SEMANA 20: Validacao em Homologacao
===================================================================
S20-1 | Configurar Linked Services hml (SQL Server, ADLS)    | Data Eng
S20-2 | Executar carga full inicial em hml                    | Data Eng
S20-3 | Validar pipeline end-to-end em hml                   | Data Eng
S20-4 | Testes de aceite com stakeholders em hml              | Analista
S20-5 | Correcoes pos-validacao hml                          | Data Eng


SEMANA 21: Deploy de Infraestrutura e Pipelines em Producao
===================================================================
S21-1 | Terraform plan prd (review detalhado)                | Infra
S21-2 | Terraform apply prd (com approval gate)              | Infra
S21-3 | Validar todos os recursos em prd                     | Infra
S21-4 | Configurar Unity Catalog retailmax_prd               | Data Eng
S21-5 | Deploy ADF + Databricks + App em prd via CI/CD       | DevOps


SEMANA 22: Deploy de Pipelines em Producao
===================================================================
S22-1 | Configurar Linked Services prd (SQL Server, ADLS)    | Data Eng
S22-2 | Executar carga full inicial em prd                    | Data Eng
S22-3 | Configurar RBAC e security em prd                    | Data Eng
S22-4 | Validar pipeline end-to-end em prd                   | Data Eng
S22-5 | Aprovacao final de stakeholders                      | Todos


SEMANA 23: Otimizacao + Monitoramento
===================================================================
S23-1 | Habilitar Photon em prd                               | Data Eng
S23-2 | Configurar Enhanced Autoscaling                       | Data Eng
S23-3 | Configurar Azure Monitor alertas (falha, custo)       | Infra
S23-4 | Criar dashboard operacional (pipeline health)         | Data Eng
S23-5 | Escrever runbook de operacoes                         | Data Eng


SEMANA 24: Estabilizacao + Go-Live
===================================================================
S24-1 | Monitorar pipeline em prd (2a semana de execucao)     | Data Eng
S24-2 | Escrever guia de troubleshooting                      | Data Eng
S24-3 | Escrever guia de onboarding de novas tabelas          | Data Eng
S24-4 | Validacao final com stakeholders                      | Todos
S24-5 | GO-LIVE oficial                                       | Todos

>>> MILESTONE M6: GO-LIVE <<<
```

---

## 9. Estimativa de Recursos

### 9.1 Equipe Minima

| Papel | Quantidade | Dedicacao | Fases Principais |
|-------|-----------|-----------|------------------|
| Data Engineer (Senior) | 1 | 100% | F1-F6 (todo o projeto) |
| Data Engineer (Pleno) | 1 | 100% | F2-F5 (pipelines e app) |
| DevOps / Infra Engineer | 1 | 50% | F1 (100%), F6 (50%), suporte pontual |
| Analista de Dados | 1 | 50% | F4-F5 (KPIs, dashboards, Genie) |

### 9.2 Estimativa de Custo Azure (Mensal - por ambiente)

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

## 10. Criterios de Aceite por Fase

| Fase | Criterio | Metrica |
|------|----------|---------|
| F1 | Todos os recursos via Terraform | `terraform plan` sem diff |
| F1 | CI/CD operacional | PR -> merge -> deploy funcionando |
| F2 | Dados no Bronze | 5 tabelas com row count > 0 |
| F2 | Metadata-driven funcional | INSERT na control table -> nova tabela ingerida |
| F3 | Qualidade Silver | Taxa de DROP < 5% |
| F3 | Testes unitarios | Cobertura > 80% |
| F4 | KPIs corretos | Validacao cruzada com SQL Server (diff < 1%) |
| F4 | Performance | Gold refresh < 30 min |
| F5 | Dashboards | Carregamento < 5 seg |
| F5 | Genie | Precisao > 85% em 20 perguntas de teste |
| F5 | App | Todas as 4 telas operacionais |
| F6 | Hml validado | Testes de aceite aprovados por stakeholders em hml |
| F6 | Producao estavel | 2 semanas sem falhas em prd |
| F6 | Performance E2E | Refresh end-to-end < 1 hora |

---

## Fontes e Referencias

| Documento | Conteudo |
|-----------|---------|
| `document/architecture-plan.md` | Arquitetura v2.1 (base para este plano) |
| `document/brd-retail-max.md` | Requisitos de negocio |
| `document/frd-adventure-works.md` | Especificacao funcional |
| `kb/lakeflow/index.md` | Medallion Architecture patterns |
| `kb/lakeflow/06-data-quality/expectations.md` | DLT Expectations |
| `kb/spark/01-performance-tuning.md` | Spark optimization |
| `kb/spark/05-best-practices.md` | PySpark best practices |
