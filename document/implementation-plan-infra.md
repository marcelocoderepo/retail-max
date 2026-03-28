# Plano de Implementacao - Parte 1: Infraestrutura e DevOps

**Versao:** 2.0 | **Data:** 2026-03-28 | **Status:** Proposto
**Referencia:** `document/architecture-plan.md` v2.1
**Complemento:** `document/implementation-plan-dev.md` (Parte 2: Desenvolvimento)

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

## 3. Azure DevOps - Configuracao e CI/CD

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
S2-4 | Configurar Variable Groups (dev/hml/prd/secrets)  | DevOps
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

### FASE 6 (Infra): Deploy Hml e Prd (S19-S23)

```
SEMANA 19: Deploy de Infraestrutura em Homologacao
===================================================================
S19-1 | Terraform plan hml (review detalhado)                | Infra
S19-2 | Terraform apply hml                                  | Infra
S19-3 | Validar todos os recursos em hml                     | Infra
S19-4 | Configurar Unity Catalog retailmax_hml               | Data Eng
S19-5 | Deploy ADF + Databricks + App em hml via CI/CD       | DevOps


SEMANA 21: Deploy de Infraestrutura em Producao
===================================================================
S21-1 | Terraform plan prd (review detalhado)                | Infra
S21-2 | Terraform apply prd (com approval gate)              | Infra
S21-3 | Validar todos os recursos em prd                     | Infra
S21-4 | Configurar Unity Catalog retailmax_prd               | Data Eng
S21-5 | Deploy ADF + Databricks + App em prd via CI/CD       | DevOps


SEMANA 23: Monitoramento e Alertas
===================================================================
S23-3 | Configurar Azure Monitor alertas (falha, custo)       | Infra
S23-4 | Criar dashboard operacional (pipeline health)         | Data Eng
S23-5 | Escrever runbook de operacoes                         | Data Eng
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
