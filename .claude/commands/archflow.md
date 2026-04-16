# /archflow - Visualizacao HTML Interativa da Arquitetura Azure

Voce e um engenheiro de documentacao que gera uma pagina HTML auto-contida com a visualizacao completa da arquitetura Azure do projeto RetailMax. Siga TODOS os steps abaixo em ordem. NAO pule nenhum step.

## Step 1: Coletar Dados da Infraestrutura

Tente obter dados em tempo real via Azure CLI. Execute os comandos abaixo em paralelo:

### 1.1 Verificar autenticacao

```bash
az account show -o json 2>/dev/null
```

Se o comando falhar ou retornar erro, defina `DATA_SOURCE = "referencia"` e use os valores hardcoded do Step 1.3. Se funcionar, defina `DATA_SOURCE = "tempo-real"`.

### 1.2 Dados em tempo real (se autenticado)

Execute em paralelo:

```bash
# Contagem de recursos por ambiente
az resource list -g rg-retailmax-dev --query "length(@)" -o tsv 2>/dev/null
az resource list -g rg-retailmax-hml --query "length(@)" -o tsv 2>/dev/null
az resource list -g rg-retailmax-prd --query "length(@)" -o tsv 2>/dev/null
az resource list -g rg-retailmax-source --query "length(@)" -o tsv 2>/dev/null

# Databricks workspaces
az databricks workspace list --query "[?contains(name,'retailmax')].{name:name,url:workspaceUrl,sku:sku.name}" -o json 2>/dev/null

# Storage accounts
az storage account list --query "[?contains(name,'retailmax')].{name:name,sku:sku.name,kind:kind}" -o json 2>/dev/null

# Key Vaults
az keyvault list --query "[?contains(name,'retailmax')].{name:name}" -o json 2>/dev/null

# Data Factories
az datafactory list --query "[?contains(name,'retailmax')].{name:name}" -o json 2>/dev/null

# SQL Servers
az sql server list --query "[?contains(name,'retailmax')].{name:name,state:state,fqdn:fullyQualifiedDomainName}" -o json 2>/dev/null

# VNets
az network vnet list --query "[?contains(name,'retailmax')].{name:name,addressSpace:addressSpace.addressPrefixes[0],subnets:subnets[].name}" -o json 2>/dev/null
```

### 1.3 Valores de referencia (fallback)

Se `az` nao estiver autenticado, use estes valores do projeto:

```
SUBSCRIPTION_NAME = "RetailMax"
SUBSCRIPTION_ID = "666333e1-8511-4c47-b1ea-41a23af85487"
TENANT_ID = "ae89487f-ce4c-4ff1-819c-3b6c8b463f70"
LOCATION = "eastus2"

RESOURCES_DEV = 48
RESOURCES_HML = 48
RESOURCES_PRD = 48
RESOURCES_SHARED = 3
RESOURCES_TOTAL = 147

VNET_DEV_CIDR = "10.0.0.0/16"
VNET_HML_CIDR = "10.2.0.0/16"
VNET_PRD_CIDR = "10.1.0.0/16"

DBX_DEV_URL = "adb-7405613595594457.17.azuredatabricks.net"
DBX_HML_URL = "adb-7405619649239054.14.azuredatabricks.net"
DBX_PRD_URL = "adb-7405605251477436.16.azuredatabricks.net"

SPN_DEV = "spn-retailmax-dev (5023f79a)"
SPN_HML = "spn-retailmax-hml (d07a4ef7)"
SPN_PRD = "spn-retailmax-prd (1ebb42d1)"

SQL_SERVER = "sql-retailmax-source.database.windows.net"
SQL_DB = "AdventureWorksLT"
SQL_LOCATION = "centralus"

COST_MONTHLY = "~R$ 2,78"
```

## Step 2: Gerar HTML

Gere o arquivo `document/archflow.html` usando o template abaixo. Substitua TODOS os placeholders `{{VAR}}` pelos valores coletados no Step 1.

**Placeholders a substituir:**
- `{{GENERATED_AT}}` — Timestamp ISO 8601 da geracao (ex: `2026-03-30T14:30:00-03:00`)
- `{{DATA_SOURCE}}` — `"tempo-real"` ou `"referencia"`
- `{{DATA_SOURCE_BADGE}}` — `"AZ CLI"` ou `"Referencia"`
- `{{DATA_SOURCE_COLOR}}` — `"#22c55e"` (tempo-real) ou `"#f59e0b"` (referencia)
- `{{SUBSCRIPTION_NAME}}` — Nome da subscription
- `{{SUBSCRIPTION_ID}}` — ID da subscription
- `{{LOCATION}}` — Regiao Azure principal
- `{{RESOURCES_TOTAL}}` — Total de recursos
- `{{RESOURCES_DEV}}` — Recursos no dev
- `{{RESOURCES_HML}}` — Recursos no hml
- `{{RESOURCES_PRD}}` — Recursos no prd
- `{{RESOURCES_SHARED}}` — Recursos compartilhados
- `{{VNET_DEV_CIDR}}` — CIDR da VNet dev
- `{{VNET_HML_CIDR}}` — CIDR da VNet hml
- `{{VNET_PRD_CIDR}}` — CIDR da VNet prd
- `{{DBX_DEV_URL}}` — URL do workspace Databricks dev
- `{{DBX_HML_URL}}` — URL do workspace Databricks hml
- `{{DBX_PRD_URL}}` — URL do workspace Databricks prd
- `{{SPN_DEV}}` — Service Principal dev
- `{{SPN_HML}}` — Service Principal hml
- `{{SPN_PRD}}` — Service Principal prd
- `{{SQL_SERVER}}` — FQDN do SQL Server
- `{{SQL_DB}}` — Nome do banco
- `{{SQL_LOCATION}}` — Regiao do SQL Server
- `{{COST_MONTHLY}}` — Custo mensal estimado

Use a ferramenta Write para escrever o arquivo `document/archflow.html` com o conteudo abaixo (com placeholders substituidos):

```html
<!DOCTYPE html>
<html lang="pt-BR" data-theme="light">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RetailMax - Arquitetura Azure</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<style>
:root{--bg:#ffffff;--bg-card:#f8fafc;--bg-hover:#f1f5f9;--text:#0f172a;--text-secondary:#475569;--border:#e2e8f0;--accent:#2563eb;--accent-light:#dbeafe;--shadow:0 1px 3px rgba(0,0,0,.1);--radius:8px}
[data-theme="dark"]{--bg:#0f172a;--bg-card:#1e293b;--bg-hover:#334155;--text:#f1f5f9;--text-secondary:#94a3b8;--border:#334155;--accent:#60a5fa;--accent-light:#1e3a5f;--shadow:0 1px 3px rgba(0,0,0,.4)}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);line-height:1.6;transition:background .3s,color .3s}
.container{max-width:1200px;margin:0 auto;padding:16px}
header{text-align:center;padding:32px 0 16px;border-bottom:2px solid var(--border);margin-bottom:24px}
header h1{font-size:1.8rem;font-weight:700;margin-bottom:8px}
header p{color:var(--text-secondary);font-size:.9rem}
.badges{display:flex;gap:8px;justify-content:center;flex-wrap:wrap;margin-top:12px}
.badge{padding:3px 10px;border-radius:12px;font-size:.75rem;font-weight:600;color:#fff}
.badge-dev{background:#3b82f6}.badge-hml{background:#f59e0b}.badge-prd{background:#22c55e}
.badge-source{background:{{DATA_SOURCE_COLOR}}}
.badge-count{background:var(--accent)}
.stats-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin:20px 0}
.stat-card{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:16px;text-align:center}
.stat-card .num{font-size:1.6rem;font-weight:700;color:var(--accent)}
.stat-card .label{font-size:.8rem;color:var(--text-secondary);margin-top:4px}
.section{margin-bottom:16px;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.section-header{display:flex;align-items:center;justify-content:space-between;padding:14px 18px;background:var(--bg-card);cursor:pointer;user-select:none;transition:background .2s}
.section-header:hover{background:var(--bg-hover)}
.section-header h2{font-size:1.1rem;font-weight:600}
.chevron{transition:transform .3s;font-size:1.2rem;color:var(--text-secondary)}
.section.open .chevron{transform:rotate(90deg)}
.section-body{max-height:0;overflow:hidden;transition:max-height .4s ease}
.section.open .section-body{max-height:5000px}
.section-content{padding:18px}
.mermaid{display:flex;justify-content:center;overflow-x:auto;padding:8px 0}
table{width:100%;border-collapse:collapse;margin:12px 0;font-size:.88rem}
th,td{padding:10px 14px;text-align:left;border-bottom:1px solid var(--border)}
th{background:var(--bg-card);font-weight:600;color:var(--text-secondary);font-size:.78rem;text-transform:uppercase;letter-spacing:.5px}
tr:hover{background:var(--bg-hover)}
.env-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px;margin:12px 0}
.env-card{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:16px}
.env-card h3{font-size:1rem;font-weight:600;margin-bottom:10px;display:flex;align-items:center;gap:8px}
.env-card .dot{width:10px;height:10px;border-radius:50%;display:inline-block}
.dot-dev{background:#3b82f6}.dot-hml{background:#f59e0b}.dot-prd{background:#22c55e}
.env-card dl{display:grid;grid-template-columns:auto 1fr;gap:4px 12px;font-size:.85rem}
.env-card dt{color:var(--text-secondary);font-weight:500}
.env-card dd{word-break:break-all}
.inv-module{margin-bottom:12px}
.inv-module summary{cursor:pointer;font-weight:600;font-size:.9rem;padding:6px 0;color:var(--accent)}
.inv-module ul{list-style:none;padding-left:20px;margin-top:4px}
.inv-module li{font-size:.83rem;padding:2px 0;color:var(--text-secondary)}
.inv-module li::before{content:"";display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--border);margin-right:8px;vertical-align:middle}
.finding{display:flex;align-items:flex-start;gap:10px;padding:10px 0;border-bottom:1px solid var(--border)}
.finding:last-child{border-bottom:none}
.sev{padding:2px 8px;border-radius:4px;font-size:.7rem;font-weight:700;color:#fff;white-space:nowrap}
.sev-critico{background:#ef4444}.sev-alerta{background:#f97316}.sev-info{background:#3b82f6}.sev-ok{background:#22c55e}
.finding-text{font-size:.85rem}
.finding-text strong{display:block;margin-bottom:2px}
.cost-table td:last-child{text-align:right;font-weight:600}
.cost-table tr:last-child{border-top:2px solid var(--border);font-weight:700}
.theme-toggle{position:fixed;top:16px;right:16px;width:44px;height:44px;border-radius:50%;border:1px solid var(--border);background:var(--bg-card);cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:1.2rem;z-index:100;box-shadow:var(--shadow);transition:background .2s}
.theme-toggle:hover{background:var(--bg-hover)}
footer{text-align:center;padding:24px 0 16px;border-top:1px solid var(--border);margin-top:24px;color:var(--text-secondary);font-size:.8rem}
footer a{color:var(--accent);text-decoration:none}
footer a:hover{text-decoration:underline}
@media(max-width:768px){.container{padding:12px}.env-grid{grid-template-columns:1fr}.stats-row{grid-template-columns:repeat(2,1fr)}header h1{font-size:1.4rem}}
</style>
</head>
<body>

<button class="theme-toggle" onclick="toggleTheme()" title="Alternar tema" aria-label="Alternar tema claro/escuro">
<span id="theme-icon">&#9790;</span>
</button>

<div class="container">

<!-- HEADER -->
<header>
<h1>RetailMax &mdash; Arquitetura Azure</h1>
<p>Plataforma Analitica Lakehouse &bull; {{SUBSCRIPTION_NAME}} &bull; {{LOCATION}}</p>
<div class="badges">
<span class="badge badge-source">{{DATA_SOURCE_BADGE}}</span>
<span class="badge badge-dev">DEV</span>
<span class="badge badge-hml">HML</span>
<span class="badge badge-prd">PRD</span>
<span class="badge badge-count">{{RESOURCES_TOTAL}} recursos</span>
</div>
<div class="stats-row">
<div class="stat-card"><div class="num">{{RESOURCES_DEV}}</div><div class="label">Recursos DEV</div></div>
<div class="stat-card"><div class="num">{{RESOURCES_HML}}</div><div class="label">Recursos HML</div></div>
<div class="stat-card"><div class="num">{{RESOURCES_PRD}}</div><div class="label">Recursos PRD</div></div>
<div class="stat-card"><div class="num">{{RESOURCES_SHARED}}</div><div class="label">Compartilhados</div></div>
</div>
<p style="font-size:.75rem;color:var(--text-secondary);margin-top:8px">Gerado em {{GENERATED_AT}} &bull; Subscription: <code>{{SUBSCRIPTION_ID}}</code></p>
</header>

<!-- SECTION A: VISAO GERAL -->
<div class="section open" id="sec-overview">
<div class="section-header" onclick="toggleSection('sec-overview')">
<h2>Visao Geral da Plataforma</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<div class="mermaid">
graph LR
    SQL["SQL Server\nAdventureWorksLT\n(centralus)"]
    ADF["Azure Data Factory\nOrquestrador Unico\nMetadata-Driven"]
    ADLS["ADLS Gen2\nLanding Zone\n(Parquet)"]
    DBX["Databricks Lakehouse\nLakeflow DLT + Photon"]
    BRONZE["Bronze\nStreaming Tables\n5 tabelas"]
    SILVER["Silver\nStreaming Tables\nDQ: DROP"]
    GOLD["Gold\nMaterialized Views\nStar Schema"]
    DASH["Databricks\nAI/BI Dashboards"]
    GENIE["Databricks Genie\nNL-to-SQL"]
    APP["Databricks App\nMaster Data"]

    SQL -->|"Copy Activity\nFull + Incremental"| ADF
    ADF -->|"Parquet files"| ADLS
    ADF -->|"Trigger Job"| DBX
    ADLS -->|"Auto Loader\ncloudFiles"| BRONZE
    BRONZE -->|"Expectations WARN"| SILVER
    SILVER -->|"Expectations DROP"| GOLD
    GOLD --> DASH
    GOLD --> GENIE
    GOLD --> APP

    style SQL fill:#ef4444,stroke:#dc2626,color:#fff
    style ADF fill:#f59e0b,stroke:#d97706,color:#fff
    style ADLS fill:#3b82f6,stroke:#2563eb,color:#fff
    style DBX fill:#6366f1,stroke:#4f46e5,color:#fff
    style BRONZE fill:#78716c,stroke:#57534e,color:#fff
    style SILVER fill:#64748b,stroke:#475569,color:#fff
    style GOLD fill:#eab308,stroke:#ca8a04,color:#fff
    style DASH fill:#22c55e,stroke:#16a34a,color:#fff
    style GENIE fill:#22c55e,stroke:#16a34a,color:#fff
    style APP fill:#22c55e,stroke:#16a34a,color:#fff
</div>
</div></div>
</div>

<!-- SECTION B: TOPOLOGIA DE REDE -->
<div class="section" id="sec-network">
<div class="section-header" onclick="toggleSection('sec-network')">
<h2>Topologia de Rede</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<div class="mermaid">
graph TB
    subgraph DEV ["VNet DEV — {{VNET_DEV_CIDR}}"]
        D1["snet-dbx-public-dev\n10.0.1.0/24"]
        D2["snet-dbx-private-dev\n10.0.2.0/24"]
        D3["snet-private-endpoints-dev\n10.0.3.0/24"]
    end
    subgraph HML ["VNet HML — {{VNET_HML_CIDR}}"]
        H1["snet-dbx-public-hml\n10.2.1.0/24"]
        H2["snet-dbx-private-hml\n10.2.2.0/24"]
        H3["snet-private-endpoints-hml\n10.2.3.0/24"]
    end
    subgraph PRD ["VNet PRD — {{VNET_PRD_CIDR}}"]
        P1["snet-dbx-public-prd\n10.1.1.0/24"]
        P2["snet-dbx-private-prd\n10.1.2.0/24"]
        P3["snet-private-endpoints-prd\n10.1.3.0/24"]
    end
    NSG["NSGs\nRegras por Subnet"]
    DNS["Private DNS Zones\nblob / dfs / vault / databricks"]
    PE["Private Endpoints\nADLS + KV + SQL"]

    D3 --- PE
    H3 --- PE
    P3 --- PE
    PE --- DNS
    D1 --- NSG
    H1 --- NSG
    P1 --- NSG

    style DEV fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
    style HML fill:#fef3c7,stroke:#f59e0b,color:#78350f
    style PRD fill:#dcfce7,stroke:#22c55e,color:#14532d
</div>
</div></div>
</div>

<!-- SECTION C: COMPARACAO DE AMBIENTES -->
<div class="section" id="sec-envs">
<div class="section-header" onclick="toggleSection('sec-envs')">
<h2>Comparacao de Ambientes</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<div class="env-grid">
<div class="env-card">
<h3><span class="dot dot-dev"></span> DEV</h3>
<dl>
<dt>Resource Group</dt><dd>rg-retailmax-dev</dd>
<dt>VNet CIDR</dt><dd>{{VNET_DEV_CIDR}}</dd>
<dt>Databricks</dt><dd>{{DBX_DEV_URL}}</dd>
<dt>SPN</dt><dd>{{SPN_DEV}}</dd>
<dt>Storage</dt><dd>stretailmaxdev</dd>
<dt>Key Vault</dt><dd>kv-retailmax-dev</dd>
<dt>Data Factory</dt><dd>adf-retailmax-dev</dd>
<dt>Recursos</dt><dd>{{RESOURCES_DEV}}</dd>
</dl>
</div>
<div class="env-card">
<h3><span class="dot dot-hml"></span> HML</h3>
<dl>
<dt>Resource Group</dt><dd>rg-retailmax-hml</dd>
<dt>VNet CIDR</dt><dd>{{VNET_HML_CIDR}}</dd>
<dt>Databricks</dt><dd>{{DBX_HML_URL}}</dd>
<dt>SPN</dt><dd>{{SPN_HML}}</dd>
<dt>Storage</dt><dd>stretailmaxhml</dd>
<dt>Key Vault</dt><dd>kv-retailmax-hml</dd>
<dt>Data Factory</dt><dd>adf-retailmax-hml</dd>
<dt>Recursos</dt><dd>{{RESOURCES_HML}}</dd>
</dl>
</div>
<div class="env-card">
<h3><span class="dot dot-prd"></span> PRD</h3>
<dl>
<dt>Resource Group</dt><dd>rg-retailmax-prd</dd>
<dt>VNet CIDR</dt><dd>{{VNET_PRD_CIDR}}</dd>
<dt>Databricks</dt><dd>{{DBX_PRD_URL}}</dd>
<dt>SPN</dt><dd>{{SPN_PRD}}</dd>
<dt>Storage</dt><dd>stretailmaxprd</dd>
<dt>Key Vault</dt><dd>kv-retailmax-prd</dd>
<dt>Data Factory</dt><dd>adf-retailmax-prd</dd>
<dt>Recursos</dt><dd>{{RESOURCES_PRD}}</dd>
</dl>
</div>
</div>
</div></div>
</div>

<!-- SECTION D: INVENTARIO DE RECURSOS -->
<div class="section" id="sec-inventory">
<div class="section-header" onclick="toggleSection('sec-inventory')">
<h2>Inventario de Recursos por Modulo Terraform</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<p style="font-size:.85rem;color:var(--text-secondary);margin-bottom:12px">10 modulos Terraform &bull; 48 recursos por ambiente &bull; Provisionados com zero diff</p>

<details class="inv-module"><summary>resource-group</summary>
<ul><li>azurerm_resource_group &mdash; rg-retailmax-{env}</li></ul>
</details>

<details class="inv-module"><summary>networking</summary>
<ul>
<li>azurerm_virtual_network &mdash; vnet-retailmax-{env}</li>
<li>azurerm_subnet &mdash; snet-dbx-public-{env}</li>
<li>azurerm_subnet &mdash; snet-dbx-private-{env}</li>
<li>azurerm_subnet &mdash; snet-private-endpoints-{env}</li>
<li>azurerm_network_security_group &mdash; nsg-dbx-public-{env}</li>
<li>azurerm_network_security_group &mdash; nsg-dbx-private-{env}</li>
<li>azurerm_network_security_group &mdash; nsg-private-endpoints-{env}</li>
<li>azurerm_subnet_network_security_group_association (x3)</li>
<li>azurerm_network_security_rule (multiplas regras por NSG)</li>
</ul>
</details>

<details class="inv-module"><summary>storage</summary>
<ul>
<li>azurerm_storage_account &mdash; stretailmax{env}</li>
<li>azurerm_storage_data_lake_gen2_filesystem &mdash; landing</li>
<li>azurerm_storage_data_lake_gen2_filesystem &mdash; bronze</li>
<li>azurerm_storage_data_lake_gen2_filesystem &mdash; silver</li>
<li>azurerm_storage_data_lake_gen2_filesystem &mdash; gold</li>
<li>azurerm_private_endpoint &mdash; pe-adls-blob-{env}</li>
<li>azurerm_private_endpoint &mdash; pe-adls-dfs-{env}</li>
</ul>
</details>

<details class="inv-module"><summary>keyvault</summary>
<ul>
<li>azurerm_key_vault &mdash; kv-retailmax-{env}</li>
<li>azurerm_private_endpoint &mdash; pe-kv-{env}</li>
<li>azurerm_key_vault_access_policy (SPN + ADF + Databricks)</li>
</ul>
</details>

<details class="inv-module"><summary>databricks</summary>
<ul>
<li>azurerm_databricks_workspace &mdash; dbx-retailmax-{env}</li>
<li>Workspace URL: {DBX_URL}</li>
<li>SKU: Premium (Unity Catalog)</li>
<li>VNet Injection: snet-dbx-public + snet-dbx-private</li>
</ul>
</details>

<details class="inv-module"><summary>data-factory</summary>
<ul>
<li>azurerm_data_factory &mdash; adf-retailmax-{env}</li>
<li>azurerm_data_factory_managed_private_endpoint (ADLS, KV)</li>
<li>Managed Identity habilitada</li>
</ul>
</details>

<details class="inv-module"><summary>identity</summary>
<ul>
<li>azuread_application &mdash; spn-retailmax-{env}</li>
<li>azuread_service_principal</li>
<li>azuread_service_principal_password</li>
<li>azurerm_role_assignment &mdash; Contributor (RG)</li>
<li>azurerm_role_assignment &mdash; Storage Blob Data Contributor</li>
</ul>
</details>

<details class="inv-module"><summary>dns-zones</summary>
<ul>
<li>azurerm_private_dns_zone &mdash; privatelink.blob.core.windows.net</li>
<li>azurerm_private_dns_zone &mdash; privatelink.dfs.core.windows.net</li>
<li>azurerm_private_dns_zone &mdash; privatelink.vaultcore.azure.net</li>
<li>azurerm_private_dns_zone &mdash; privatelink.azuredatabricks.net</li>
<li>azurerm_private_dns_zone_virtual_network_link (x4)</li>
<li>azurerm_private_dns_a_record (por Private Endpoint)</li>
</ul>
</details>

<details class="inv-module"><summary>monitoring</summary>
<ul>
<li>azurerm_log_analytics_workspace &mdash; log-retailmax-{env}</li>
<li>azurerm_monitor_diagnostic_setting (ADF)</li>
<li>azurerm_monitor_diagnostic_setting (Databricks)</li>
<li>azurerm_monitor_action_group</li>
</ul>
</details>

<details class="inv-module"><summary>policy</summary>
<ul>
<li>azurerm_resource_group_policy_assignment &mdash; Tags obrigatorias</li>
<li>azurerm_resource_group_policy_assignment &mdash; Allowed locations</li>
</ul>
</details>

<h4 style="margin-top:16px;font-size:.9rem">Recursos Compartilhados (rg-retailmax-source)</h4>
<table>
<tr><th>Recurso</th><th>Nome</th><th>Regiao</th></tr>
<tr><td>SQL Server</td><td>{{SQL_SERVER}}</td><td>{{SQL_LOCATION}}</td></tr>
<tr><td>SQL Database</td><td>{{SQL_DB}}</td><td>{{SQL_LOCATION}}</td></tr>
<tr><td>Terraform State</td><td>stretailmaxtfstate</td><td>eastus2</td></tr>
</table>
</div></div>
</div>

<!-- SECTION E: SEGURANCA -->
<div class="section" id="sec-security">
<div class="section-header" onclick="toggleSection('sec-security')">
<h2>Status de Seguranca</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<p style="font-size:.85rem;color:var(--text-secondary);margin-bottom:12px">Auditoria de seguranca baseada nas configuracoes Terraform e boas praticas Azure.</p>

<div class="finding">
<span class="sev sev-ok">OK</span>
<div class="finding-text"><strong>Private Endpoints configurados</strong>ADLS Gen2, Key Vault e Databricks acessiveis apenas via Private Endpoint em todas os ambientes.</div>
</div>
<div class="finding">
<span class="sev sev-ok">OK</span>
<div class="finding-text"><strong>VNet Injection no Databricks</strong>Workspaces Databricks com VNet injection em subnets dedicadas (public + private).</div>
</div>
<div class="finding">
<span class="sev sev-ok">OK</span>
<div class="finding-text"><strong>NSGs por subnet</strong>Network Security Groups aplicados em todas as subnets com regras de seguranca.</div>
</div>
<div class="finding">
<span class="sev sev-ok">OK</span>
<div class="finding-text"><strong>Managed Identity no ADF</strong>Data Factory usando Managed Identity para autenticacao com ADLS e Key Vault.</div>
</div>
<div class="finding">
<span class="sev sev-info">INFO</span>
<div class="finding-text"><strong>Unity Catalog requer Premium SKU</strong>Todos os workspaces usam SKU Premium, habilitando Unity Catalog para RBAC e governanca.</div>
</div>
<div class="finding">
<span class="sev sev-info">INFO</span>
<div class="finding-text"><strong>Tags obrigatorias via Azure Policy</strong>Policies de tags (project, environment, managed_by, cost_center) aplicadas em todos os Resource Groups.</div>
</div>
<div class="finding">
<span class="sev sev-info">INFO</span>
<div class="finding-text"><strong>Terraform state protegido</strong>State armazenado em Storage Account dedicado (stretailmaxtfstate) com acesso restrito.</div>
</div>
<div class="finding">
<span class="sev sev-info">INFO</span>
<div class="finding-text"><strong>Ambientes isolados</strong>VNets separadas sem peering. Cada ambiente tem seus proprios recursos e Service Principals.</div>
</div>
<div class="finding">
<span class="sev sev-alerta">ALERTA</span>
<div class="finding-text"><strong>SQL Server com acesso publico</strong>sql-retailmax-source esta em centralus com firewall rules. Considerar migrar para Private Endpoint quando ingestao estiver em producao.</div>
</div>
<div class="finding">
<span class="sev sev-alerta">ALERTA</span>
<div class="finding-text"><strong>Key Vault soft-delete e purge protection</strong>Verificar se soft-delete (90 dias) e purge protection estao habilitados em todos os Key Vaults.</div>
</div>
<div class="finding">
<span class="sev sev-alerta">ALERTA</span>
<div class="finding-text"><strong>Diagnostic settings parciais</strong>Configurar diagnostic settings para ADLS e Key Vault alem de ADF e Databricks.</div>
</div>
<div class="finding">
<span class="sev sev-alerta">ALERTA</span>
<div class="finding-text"><strong>Rotacao de secrets dos SPNs</strong>Secrets dos Service Principals devem ter politica de rotacao (recomendado: 90 dias).</div>
</div>
<div class="finding">
<span class="sev sev-critico">CRITICO</span>
<div class="finding-text"><strong>Row Filters e Column Masks pendentes</strong>Unity Catalog RBAC configurado, mas Row Filters e Column Masks para dados sensiveis (AccountNumber, email) ainda nao implementados. Previsto para Fase 5.</div>
</div>
<div class="finding">
<span class="sev sev-critico">CRITICO</span>
<div class="finding-text"><strong>Backup e disaster recovery</strong>Nenhuma estrategia de backup/DR definida para Delta Lake tables e configuracoes Databricks. Considerar geo-replication do ADLS.</div>
</div>
<div class="finding">
<span class="sev sev-critico">CRITICO</span>
<div class="finding-text"><strong>Approval gates de producao</strong>CI/CD com approval gates definidos no plano, mas ainda nao implementados nas pipelines Azure DevOps.</div>
</div>
<div class="finding">
<span class="sev sev-critico">CRITICO</span>
<div class="finding-text"><strong>Auditoria de acesso nao centralizada</strong>Azure AD audit logs e Databricks audit logs nao integrados em um SIEM ou Log Analytics centralizado.</div>
</div>
</div></div>
</div>

<!-- SECTION F: CUSTO MENSAL -->
<div class="section" id="sec-cost">
<div class="section-header" onclick="toggleSection('sec-cost')">
<h2>Custo Mensal Estimado</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<p style="font-size:.85rem;color:var(--text-secondary);margin-bottom:12px">Estimativa baseada em recursos provisionados (idle). Custos de compute Databricks e ADF sao pay-per-use e aparecem apenas durante execucao.</p>
<table class="cost-table">
<tr><th>Servico</th><th>Detalhe</th><th>Custo (3 envs)</th></tr>
<tr><td>ADLS Gen2</td><td>3 Storage Accounts (LRS, idle)</td><td>~R$ 0,30</td></tr>
<tr><td>Key Vault</td><td>3 Key Vaults (secrets armazenados)</td><td>~R$ 0,10</td></tr>
<tr><td>Log Analytics</td><td>3 Workspaces (ingestion minima)</td><td>~R$ 0,50</td></tr>
<tr><td>Private DNS Zones</td><td>12 zones (4 por env)</td><td>~R$ 0,60</td></tr>
<tr><td>Databricks</td><td>3 Workspaces (idle, sem clusters)</td><td>~R$ 0,00</td></tr>
<tr><td>Data Factory</td><td>3 Factories (idle, sem pipelines)</td><td>~R$ 0,00</td></tr>
<tr><td>SQL Server</td><td>Free tier (auto-pause 60min)</td><td>~R$ 0,00</td></tr>
<tr><td>VNet / NSG / Subnets</td><td>Networking (sem gateway)</td><td>~R$ 0,00</td></tr>
<tr><td>Terraform State</td><td>1 Storage Account</td><td>~R$ 0,08</td></tr>
<tr><td colspan="2"><strong>TOTAL MENSAL (idle)</strong></td><td><strong>{{COST_MONTHLY}}</strong></td></tr>
</table>
<p style="font-size:.8rem;color:var(--text-secondary);margin-top:10px">Nota: Custos de execucao (DBU Databricks, DIU Data Factory, queries SQL) sao adicionais e dependem do volume de processamento.</p>
</div></div>
</div>

<!-- SECTION G: FLUXO DE DADOS -->
<div class="section" id="sec-dataflow">
<div class="section-header" onclick="toggleSection('sec-dataflow')">
<h2>Fluxo de Dados (Pipeline ETL)</h2>
<span class="chevron">&#9654;</span>
</div>
<div class="section-body"><div class="section-content">
<div class="mermaid">
graph LR
    subgraph SOURCE ["Origem"]
        S1["SalesOrderHeader\n(32 registros)"]
        S2["SalesOrderDetail\n(542 registros)"]
        S3["Customer\n(847 registros)"]
        S4["Product\n(295 registros)"]
        S5["Address\n(450 registros)"]
    end

    subgraph INGESTION ["Ingestao ADF"]
        IC["ingestion_control\nMetadata-Driven"]
        LOOKUP["Lookup\nis_active = true"]
        FOREACH["ForEach\nCopy Activity"]
    end

    subgraph BRONZE ["Bronze - Streaming Tables"]
        B1["SalesOrderHeader_bronze"]
        B2["SalesOrderDetail_bronze"]
        B3["Customer_bronze"]
        B4["Product_bronze"]
        B5["Address_bronze"]
    end

    subgraph SILVER ["Silver - DQ: DROP"]
        SV1["SalesOrderHeader_silver"]
        SV2["SalesOrderDetail_silver"]
        SV3["Customer_silver"]
        SV4["Product_silver"]
    end

    subgraph GOLD ["Gold - Star Schema"]
        FS["fact_sales"]
        DC["dim_customer"]
        DP["dim_product"]
        DD["dim_date"]
        KPI["KPIs\nReceita | Ticket\nChurn | Estoque"]
    end

    S1 & S2 & S3 & S4 & S5 --> LOOKUP
    IC --> LOOKUP
    LOOKUP --> FOREACH
    FOREACH -->|"Parquet → ADLS"| B1 & B2 & B3 & B4 & B5
    B1 --> SV1
    B2 --> SV2
    B3 --> SV3
    B4 --> SV4
    SV1 & SV2 --> FS
    SV3 --> DC
    SV4 --> DP
    FS --> KPI
    DD --> KPI

    style SOURCE fill:#ef4444,stroke:#dc2626,color:#fff
    style INGESTION fill:#f59e0b,stroke:#d97706,color:#fff
    style BRONZE fill:#78716c,stroke:#57534e,color:#fff
    style SILVER fill:#64748b,stroke:#475569,color:#fff
    style GOLD fill:#eab308,stroke:#ca8a04,color:#fff
</div>
</div></div>
</div>

<!-- FOOTER -->
<footer>
<p>RetailMax Lakehouse Platform &bull; Gerado automaticamente por <code>/archflow</code></p>
<p><a href="https://github.com/marcelocoderepo/retail-max">github.com/marcelocoderepo/retail-max</a> &bull; Subscription: {{SUBSCRIPTION_NAME}} ({{SUBSCRIPTION_ID}})</p>
<p style="margin-top:4px">Fonte dos dados: {{DATA_SOURCE_BADGE}} &bull; {{GENERATED_AT}}</p>
</footer>

</div>

<script>
function toggleTheme(){
  const html=document.documentElement;
  const curr=html.getAttribute('data-theme');
  const next=curr==='dark'?'light':'dark';
  html.setAttribute('data-theme',next);
  localStorage.setItem('archflow-theme',next);
  document.getElementById('theme-icon').innerHTML=next==='dark'?'&#9788;':'&#9790;';
  reRenderMermaid(next);
}
function toggleSection(id){
  document.getElementById(id).classList.toggle('open');
}
function reRenderMermaid(theme){
  mermaid.initialize({startOnLoad:false,theme:theme==='dark'?'dark':'default',securityLevel:'loose',flowchart:{useMaxWidth:true,htmlLabels:true,curve:'basis'}});
  document.querySelectorAll('.mermaid').forEach(function(el){
    const code=el.getAttribute('data-mermaid-src');
    if(code){el.removeAttribute('data-processed');el.innerHTML=code;mermaid.run({nodes:[el]});}
  });
}
document.addEventListener('DOMContentLoaded',function(){
  const saved=localStorage.getItem('archflow-theme');
  if(saved){document.documentElement.setAttribute('data-theme',saved);document.getElementById('theme-icon').innerHTML=saved==='dark'?'&#9788;':'&#9790;';}
  const mermaidTheme=(saved||'light')==='dark'?'dark':'default';
  mermaid.initialize({startOnLoad:false,theme:mermaidTheme,securityLevel:'loose',flowchart:{useMaxWidth:true,htmlLabels:true,curve:'basis'}});
  document.querySelectorAll('.mermaid').forEach(function(el){
    el.setAttribute('data-mermaid-src',el.textContent.trim());
  });
  mermaid.run();
});
</script>
</body>
</html>
```

IMPORTANTE: Ao substituir os placeholders, mantenha o HTML exatamente como esta, apenas trocando os valores `{{VAR}}` pelos dados reais.

## Step 3: Validar Arquivo

Apos escrever o arquivo, verifique:

```bash
wc -c document/archflow.html
```

O arquivo deve ter entre 15KB e 30KB (~15000 a 30000 bytes). Se estiver fora dessa faixa, algo pode estar errado.

Verifique tambem que nenhum placeholder `{{` restou no arquivo:

```bash
grep -c '{{' document/archflow.html
```

O resultado deve ser `0`. Se houver placeholders restantes, corrija-os.

## Step 4: Relatorio Final

Apresente ao usuario um resumo formatado:

```
============================================================
  ARCHFLOW - Geracao Concluida
============================================================

  Arquivo:    document/archflow.html
  Tamanho:    XX KB
  Fonte:      [AZ CLI / Referencia]
  Timestamp:  YYYY-MM-DDTHH:MM:SS

  SECOES GERADAS:
  ├── Visao Geral da Plataforma (diagrama Mermaid)
  ├── Topologia de Rede (3 VNets, subnets, NSGs)
  ├── Comparacao de Ambientes (dev/hml/prd)
  ├── Inventario de Recursos (10 modulos, 48/env)
  ├── Status de Seguranca (4 OK, 4 INFO, 4 ALERTA, 4 CRITICO)
  ├── Custo Mensal Estimado
  └── Fluxo de Dados (Pipeline ETL completo)

  FEATURES:
  ├── Dark/Light mode (toggle + localStorage)
  ├── Collapsible sections
  ├── Mermaid re-render on theme change
  └── Responsive layout

  Para visualizar: abra document/archflow.html no browser
============================================================
```

## Regras Importantes

- NUNCA commitar o arquivo gerado automaticamente (ele e gerado sob demanda)
- O HTML deve ser auto-contido (unica dependencia externa: Mermaid CDN)
- Se `az` CLI falhar, usar dados de referencia SEM erros ou avisos excessivos
- Manter o HTML limpo e valido (sem warnings no console do browser)
- Todos os textos e labels em PT-BR
