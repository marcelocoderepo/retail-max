# Plano de Implementacao - Parte 2: Desenvolvimento

**Versao:** 3.0 | **Data:** 2026-04-17 | **Status:** PARCIALMENTE CONCLUIDO
**Referencia:** `document/architecture-plan.md` v2.1
**Complemento:** `document/implementation-plan-infra.md` (Parte 1: Infraestrutura e DevOps)

**Changelog v3.0 (2026-04-17):**
- Status atualizado para refletir estado real do projeto (abril 2026)
- **Databricks: CONCLUIDO** - 3 workspaces Premium, Unity Catalog, DLT Bronze/Silver/Gold, KPIs, todas 19 tabelas criadas em dev
- **ADF: CONCLUIDO** - Linked Services, Datasets, Pipelines (master, full, incremental), execucao bem-sucedida, dados no ADLS
- ADF MSI com permissoes UC concedidas (USE_CATALOG, USE_SCHEMA, SELECT, MODIFY)
- Unity Catalog: nomenclatura corrigida para `retailmax` (sem sufixo de ambiente)
- DLT: split em 3 pipelines separados (bronze/silver/gold) - UC exige 1 target por pipeline
- Nomes de tabelas: sem sufixo de layer (ex: `SalesOrderHeader`, NAO `SalesOrderHeader_bronze`)
- Refs cross-pipeline: `spark.readStream.table("retailmax.bronze.X")` em vez de `dlt.read_stream()`
- Refs intra-pipeline: `spark.read.table("LIVE.X")` (sem schema prefix)
- `delta.feature.timestampNtz: supported` adicionado a todas table_properties
- `databricks.yml`: 3 pipelines + job orquestrador `retailmax_medallion_refresh`
- `ingestion_control`: movida para schema `parametros`, landing_path sem `/landing/` prefix
- ADF pipeline: catalog default corrigido de `retailmax_dev` para `retailmax`
- Testes: 18 testes unitarios (11 silver + 7 gold) passando
- PRs: retailmax-databricks (#1, #2) e retailmax-data-factory (#3) mergeados
- Cronograma atualizado: Fases 2-4 CONCLUIDO com checkboxes, Fases 5-6 PENDENTE
- **Pendente:** testes integracao E2E, testes KPI Gold, Databricks App, deploy hml/prd, dashboards

**Changelog v2.1:**
- Schemas corrigidos: todas as tabelas usam `SalesLT` (validado contra AdventureWorksLT real)
- `ProductInventory` removida (nao existe no AdventureWorksLT)
- Adicionadas 3 tabelas: `Address`, `CustomerAddress`, `ProductCategory` (7 total)
- `dim_customer` corrigida: colunas alinhadas com schema real de `SalesLT.Customer`
- `dim_product` corrigida: JOIN com `ProductCategory` para nomes de categoria
- Formula de Revenue inclui `UnitPriceDiscount`
- Logica de churn usa data relativa ao dataset (`MAX(OrderDate)`) em vez de `current_date()`
- `kpi_estoque_critico` substituido por `kpi_produtos_descontinuados` (sem dados de inventario)
- URLs de workspace Databricks corrigidas para valores reais
- Instalacao do Databricks CLI v2 corrigida
- `trigger_dlt_refresh.py` usa `databricks-sdk`
- Testes atualizados para schema corrigido

**Changelog v2.0:**
- Documento separado da versao unificada (v1.1)
- Conteudo exclusivo: ADF pipelines, Databricks (DLT, App), testes, cronograma dev
- Pre-requisitos de infra: Fase 1 do plano de infraestrutura concluida

---

## 1. Visao Geral

Este documento detalha o desenvolvimento de pipelines de dados, aplicacao e testes do projeto RetailMax Lakehouse. Cobre Azure Data Factory (ingestao metadata-driven), Databricks (DLT Bronze/Silver/Gold, Unity Catalog), Databricks App (master data validation) e estrategia de testes.

**Dependencia:** Requer infraestrutura provisionada conforme `implementation-plan-infra.md` (Fase 1 concluida).

Para convencoes de nomenclatura, topologia de rede, CI/CD pipelines e custos, consultar `implementation-plan-infra.md`.

### 1.1 Pre-Requisitos de Desenvolvimento

| Item | Fonte | Status |
|------|-------|--------|
| Todos os recursos Azure provisionados (dev) | Fase 1 - Infra | CONCLUIDO - 48 recursos, zero diff |
| CI/CD operacional nos 3 projetos DevOps | Fase 1 - Infra | CONCLUIDO - 6 pipelines ativas |
| Unity Catalog com schemas bronze/silver/gold/parametros | Fase 1 - Infra | CONCLUIDO - catalog `retailmax` |
| ADF Linked Services configurados | Fase 1 - Infra | CONCLUIDO - SQL, ADLS, Databricks, KV |
| SQL Server AdventureWorksLT acessivel | DBA | CONCLUIDO - sql-retailmax-source.database.windows.net |
| Python 3.10+ no ambiente local | Data Eng | CONCLUIDO |
| Acesso ao workspace Databricks (dev) | Admin | CONCLUIDO - adb-7405613595594457.17 |

### 1.2 Tabelas Fonte - AdventureWorksLT (Validado)

Schema unico: `SalesLT`. Validado via conexao direta ao banco `sql-retailmax-source.database.windows.net`.

| Tabela | Rows | Uso | Tipo Carga |
|--------|------|-----|------------|
| `SalesLT.SalesOrderHeader` | 32 | Fato (pedidos) | Incremental (ModifiedDate) |
| `SalesLT.SalesOrderDetail` | 542 | Fato (itens) | Incremental (ModifiedDate) |
| `SalesLT.Customer` | 847 | Dimensao (clientes) | Full |
| `SalesLT.Product` | 295 | Dimensao (produtos) | Full |
| `SalesLT.Address` | 450 | Dimensao (geografia) | Full |
| `SalesLT.CustomerAddress` | 417 | Bridge (cliente-endereco) | Full |
| `SalesLT.ProductCategory` | 41 | Lookup (categorias) | Full |

**Nota:** `ProductInventory` nao existe no AdventureWorksLT (apenas no AdventureWorks full). O KPI "Estoque Critico" do BRD foi substituido por "Produtos Descontinuados" usando `SellEndDate`/`DiscontinuedDate` da tabela `Product`.

---

## 2. Azure Data Factory - Pipelines de Ingestao

**Status: CONCLUIDO (Abril 2026)**

- [x] Linked Services configurados (SQL Server, ADLS, Key Vault, Databricks)
- [x] Datasets parametrizados (ds_sqlserver_table, ds_adls_parquet)
- [x] Pipeline master ingestion (metadata-driven)
- [x] Pipeline full load (SQL Server -> ADLS)
- [x] Pipeline incremental load (com watermark)
- [x] ADF executado com sucesso, dados landing no ADLS
- [x] ADF MSI com permissoes UC concedidas (USE_CATALOG, USE_SCHEMA, SELECT, MODIFY)

### 2.1 Estrutura do Repositorio `adf-pipelines`

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

### 2.2 Pipeline Master - Logica Metadata-Driven

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

### 2.3 Sub-Pipeline: Copy Full Load

```
pl_copy_full_load
===================================================================
Parameters: source_schema, source_table, landing_path

[Copy Activity]
  Source:
    Type: SqlServerSource
    Query: SELECT * FROM @{pipeline().parameters.source_schema}.[@{pipeline().parameters.source_table}]
  Sink:
    Type: ParquetSink
    Path: @{pipeline().parameters.landing_path}/@{formatDateTime(utcnow(), 'yyyy/MM/dd/HHmmss')}/
  Settings:
    Data Integration Units: 4
    Degree of Copy Parallelism: 4
```

### 2.4 Sub-Pipeline: Copy Incremental

```
pl_copy_incremental
===================================================================
Parameters: source_schema, source_table, watermark_column,
            last_watermark_value, landing_path

[Lookup: Get Max Watermark]
  Query: SELECT MAX(@{pipeline().parameters.watermark_column}) as maxWatermark
         FROM @{pipeline().parameters.source_schema}.[@{pipeline().parameters.source_table}]

[Copy Activity]
  Source:
    Type: SqlServerSource
    Query: SELECT * FROM @{pipeline().parameters.source_schema}.[@{pipeline().parameters.source_table}]
           WHERE @{pipeline().parameters.watermark_column}
                 > '@{pipeline().parameters.last_watermark_value}'
             AND @{pipeline().parameters.watermark_column}
                 <= '@{activity('Get Max Watermark').output.firstRow.maxWatermark}'
  Sink:
    Type: ParquetSink
    Path: @{pipeline().parameters.landing_path}/@{formatDateTime(utcnow(), 'yyyy/MM/dd/HHmmss')}/

Output: maxWatermark = @{activity('Get Max Watermark').output.firstRow.maxWatermark}
```

### 2.5 Linked Services - Configuracao

| Linked Service | Tipo | Autenticacao | Detalhes |
|----------------|------|-------------|----------|
| `ls_sqlserver` | SQL Server | Key Vault Secret | Connection string no KV. Self-Hosted IR se on-prem |
| `ls_adls` | ADLS Gen2 | Managed Identity | URL: `https://stretailmax{env}.dfs.core.windows.net` |
| `ls_databricks` | Azure Databricks | SPN (Key Vault) | Token ou SPN via KV. Existing cluster ou job cluster |
| `ls_keyvault` | Azure Key Vault | Managed Identity | URL: `https://kv-retailmax-{env}.vault.azure.net` |

---

## 3. Databricks - Pipelines DLT

**Status: CONCLUIDO (Abril 2026)**

- [x] 3 Workspaces Premium com Unity Catalog (dev/hml/prd)
- [x] Unity Catalog: catalogo `retailmax`, schemas bronze/silver/gold/parametros
- [x] Cluster Policy: ADF Single Node UC (ID: `001C9EDA0B8C62D0`)
- [x] Tabela de controle: `retailmax.parametros.ingestion_control` (7 tabelas seeded)
- [x] Asset Bundle (`databricks.yml`): 3 pipelines (bronze/silver/gold) + orchestration job
- [x] DLT Bronze: 7 streaming tables via Auto Loader (cloudFiles)
- [x] DLT Silver: 7 tabelas com dedup, validacao (`expect_all_or_drop`), business rules
- [x] DLT Gold Model: `dim_date`, `dim_customer`, `dim_product`, `fact_sales`
- [x] DLT Gold KPIs: `kpi_receita_total`, `kpi_ticket_medio`, `kpi_churn`, `kpi_produtos_descontinuados`, `kpi_top_produtos`
- [x] Todas as 19 tabelas criadas com sucesso no workspace dev
- [x] 18 testes unitarios escritos (test_silver + test_gold)
- [x] ADF MSI com permissoes UC (USE_CATALOG, USE_SCHEMA, SELECT, MODIFY)

### 3.1 Estrutura do Repositorio `databricks-pipelines`

```
databricks-pipelines/
├── README.md
├── databricks.yml                     # Databricks Asset Bundle config
├── requirements.txt                   # Runtime dependencies
├── requirements-dev.txt               # Dev/test dependencies (delta-spark, pytest, ruff)
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── pipelines/
│   │   ├── __init__.py
│   │   ├── bronze/
│   │   │   ├── __init__.py
│   │   │   └── ingest_bronze.py       # DLT Bronze (Auto Loader, 7 tabelas)
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

### 3.2 Databricks Asset Bundle

```yaml
# databricks.yml (v3.0 - configuracao real em producao)
# NOTA: DLT com Unity Catalog exige 1 target (schema) por pipeline.
#       Por isso sao 3 pipelines separados + 1 job orquestrador.
bundle:
  name: retailmax-databricks

workspace:
  root_path: /Workspace/Users/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}

targets:
  dev:
    default: true
    presets:
      pipelines_development: true
      trigger_pause_status: PAUSED
    workspace:
      host: https://adb-7405613595594457.17.azuredatabricks.net

  hml:
    workspace:
      host: https://adb-7405619649239054.14.azuredatabricks.net

  prd:
    mode: production
    workspace:
      host: https://adb-7405605251477436.16.azuredatabricks.net
    permissions:
      - group_name: grp-retailmax-prd-data-engineers
        level: CAN_MANAGE

resources:
  pipelines:
    # Pipeline por schema - DLT com UC exige target unico por pipeline
    bronze_pipeline:
      name: "retailmax_bronze"
      catalog: "retailmax"
      target: "bronze"
      libraries:
        - notebook:
            path: src/pipelines/bronze/ingest_bronze.py
      configuration:
        "spark.databricks.delta.preview.enabled": "true"
        "spark.sql.parquet.inferTimestampNTZ.enabled": "false"
        "pipelines.applyTimestampWithoutTimezoneInParquet": "false"
      photon: true
      serverless: true
      channel: "PREVIEW"
      edition: "ADVANCED"
      continuous: false

    silver_pipeline:
      name: "retailmax_silver"
      catalog: "retailmax"
      target: "silver"
      libraries:
        - notebook:
            path: src/pipelines/silver/transform_silver.py
      configuration:
        "spark.databricks.delta.preview.enabled": "true"
        "spark.sql.parquet.inferTimestampNTZ.enabled": "false"
        "pipelines.applyTimestampWithoutTimezoneInParquet": "false"
      photon: true
      serverless: true
      channel: "PREVIEW"
      edition: "ADVANCED"
      continuous: false

    gold_pipeline:
      name: "retailmax_gold"
      catalog: "retailmax"
      target: "gold"
      libraries:
        - notebook:
            path: src/pipelines/gold/model_gold.py
        - notebook:
            path: src/pipelines/gold/kpis_gold.py
      configuration:
        "spark.databricks.delta.preview.enabled": "true"
        "spark.sql.parquet.inferTimestampNTZ.enabled": "false"
        "pipelines.applyTimestampWithoutTimezoneInParquet": "false"
      photon: true
      serverless: true
      channel: "PREVIEW"
      edition: "ADVANCED"
      continuous: false

  jobs:
    retailmax_medallion_job:
      name: "retailmax_medallion_refresh"
      tasks:
        - task_key: "run_bronze"
          pipeline_task:
            pipeline_id: ${resources.pipelines.bronze_pipeline.id}
            full_refresh: false
        - task_key: "run_silver"
          depends_on:
            - task_key: "run_bronze"
          pipeline_task:
            pipeline_id: ${resources.pipelines.silver_pipeline.id}
            full_refresh: false
        - task_key: "run_gold"
          depends_on:
            - task_key: "run_silver"
          pipeline_task:
            pipeline_id: ${resources.pipelines.gold_pipeline.id}
            full_refresh: false
```

### 3.3 Unity Catalog - Setup

```sql
-- setup/create_catalog.sql (executar manualmente ou via notebook)
-- NOTA: Catalog unico "retailmax" em todos os workspaces.
--       O workspace identifica o ambiente (dev/hml/prd).

CREATE CATALOG IF NOT EXISTS retailmax;

USE CATALOG retailmax;
CREATE SCHEMA IF NOT EXISTS bronze     COMMENT 'Raw ingested data (Auto Loader)';
CREATE SCHEMA IF NOT EXISTS silver     COMMENT 'Cleaned and validated data (DLT expectations)';
CREATE SCHEMA IF NOT EXISTS gold       COMMENT 'Dimensional model and KPIs (Star Schema)';
CREATE SCHEMA IF NOT EXISTS parametros COMMENT 'Control tables (ingestion_control)';
```

### 3.4 Tabela ingestion_control - DDL

```python
# src/setup/create_ingestion_control.py

# Executar como notebook normal (nao DLT)
# NOTA: catalog "retailmax" e o mesmo em todos workspaces
catalog = dbutils.widgets.get("catalog") if "dbutils" in dir() else "retailmax"

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {catalog}.parametros.ingestion_control (
    source_schema        STRING    NOT NULL COMMENT 'Schema de origem no SQL Server',
    source_table         STRING    NOT NULL COMMENT 'Tabela de origem',
    target_schema        STRING    NOT NULL COMMENT 'Schema destino no Lakehouse',
    target_table         STRING    NOT NULL COMMENT 'Tabela destino',
    load_type            STRING    NOT NULL COMMENT 'full ou incremental',
    watermark_column     STRING             COMMENT 'Coluna para carga incremental',
    last_watermark_value STRING             COMMENT 'Ultimo valor processado',
    primary_key          STRING    NOT NULL COMMENT 'Chave primaria para dedup',
    is_active            BOOLEAN   NOT NULL COMMENT 'Ativar/desativar',
    landing_path         STRING    NOT NULL COMMENT 'Caminho ADLS Gen2 (relativo ao container landing)',
    schedule_frequency   STRING    NOT NULL COMMENT 'daily/hourly/weekly',
    last_load_status     STRING             COMMENT 'SUCCESS/FAILED/RUNNING',
    last_load_timestamp  TIMESTAMP          COMMENT 'Quando foi a ultima carga',
    row_count_last_load  BIGINT             COMMENT 'Registros ultima carga',
    created_at           TIMESTAMP NOT NULL,
    updated_at           TIMESTAMP NOT NULL
)
USING DELTA
COMMENT 'Tabela de controle metadata-driven para ingestao ADF'
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality' = 'system'
)
""")

# Dados iniciais (7 tabelas - schema SalesLT validado)
# NOTA: Nomes de tabela sem sufixo de layer (ex: SalesOrderHeader, NAO SalesOrderHeader_bronze)
#       Landing path relativo ao container (ex: SalesOrderHeader/, sem /landing/ prefix)
spark.sql(f"""
INSERT INTO {catalog}.parametros.ingestion_control
(source_schema, source_table, target_schema, target_table, load_type,
 watermark_column, primary_key, is_active, landing_path, schedule_frequency,
 created_at, updated_at)
VALUES
('SalesLT', 'SalesOrderHeader',  'bronze', 'SalesOrderHeader',  'incremental', 'ModifiedDate', 'SalesOrderID',       true, 'SalesOrderHeader/',  'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'SalesOrderDetail',  'bronze', 'SalesOrderDetail',  'incremental', 'ModifiedDate', 'SalesOrderDetailID', true, 'SalesOrderDetail/',  'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'Customer',          'bronze', 'Customer',          'full',         NULL,          'CustomerID',         true, 'Customer/',           'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'Product',           'bronze', 'Product',           'full',         NULL,          'ProductID',          true, 'Product/',            'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'Address',           'bronze', 'Address',           'full',         NULL,          'AddressID',          true, 'Address/',            'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'CustomerAddress',   'bronze', 'CustomerAddress',   'full',         NULL,          'CustomerID',         true, 'CustomerAddress/',    'daily', current_timestamp(), current_timestamp()),
('SalesLT', 'ProductCategory',   'bronze', 'ProductCategory',   'full',         NULL,          'ProductCategoryID',  true, 'ProductCategory/',    'daily', current_timestamp(), current_timestamp())
""")
```

### 3.5 DLT Pipeline - Bronze

```python
# src/pipelines/bronze/ingest_bronze.py (v3.0 - codigo real em producao)
# NOTA: Nomes de tabela SEM sufixo "_bronze" (UC schema = target = "bronze" no pipeline)
#       table_properties incluem timestampNtz (necessario para Parquet do ADF)
import dlt
from pyspark.sql import functions as F

LANDING_BASE = spark.conf.get(
    "retailmax.landing_base",
    "abfss://landing@stretailmaxdev.dfs.core.windows.net"
)

def create_bronze_table(table_name: str, landing_path: str, comment: str):
    @dlt.expect("rescued_data_null", "_rescued_data IS NULL")
    @dlt.table(
        name=table_name,  # SEM sufixo _bronze (schema bronze = target do pipeline)
        comment=comment,
        table_properties={
            "quality": "bronze",
            "delta.feature.timestampNtz": "supported",  # necessario para Parquet NTZ
        },
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
        )
    return _inner

# 7 tabelas Bronze (nomes = nomes da fonte, sem sufixo)
sales_order_header_bronze = create_bronze_table("SalesOrderHeader", "SalesOrderHeader/", "...")
sales_order_detail_bronze = create_bronze_table("SalesOrderDetail", "SalesOrderDetail/", "...")
customer_bronze           = create_bronze_table("Customer", "Customer/", "...")
product_bronze            = create_bronze_table("Product", "Product/", "...")
address_bronze            = create_bronze_table("Address", "Address/", "...")
customer_address_bronze   = create_bronze_table("CustomerAddress", "CustomerAddress/", "...")
product_category_bronze   = create_bronze_table("ProductCategory", "ProductCategory/", "...")
```

### 3.6 DLT Pipeline - Silver

```python
# src/pipelines/silver/transform_silver.py (v3.0 - codigo real em producao)
# MUDANCAS v3.0:
#   - Nomes SEM sufixo "_silver" (schema silver = target do pipeline)
#   - Refs CROSS-PIPELINE: spark.readStream.table("retailmax.bronze.X")
#     (NAO dlt.read_stream() - isso so funciona intra-pipeline)
#   - table_properties incluem "delta.feature.timestampNtz": "supported"

import dlt
from pyspark.sql import functions as F

STATUS_MAP = {1: "InProcess", 2: "Approved", 3: "BackOrdered",
              4: "Rejected", 5: "Shipped", 6: "Cancelled"}

# Exemplo: SalesOrderHeader (padrao identico para todas 7 tabelas)
@dlt.expect_all_or_drop({
    "valid_order_id": "SalesOrderID IS NOT NULL",
    "valid_customer": "CustomerID IS NOT NULL",
    "valid_date": "OrderDate IS NOT NULL",
    "valid_total": "TotalDue >= 0",
})
@dlt.table(
    name="SalesOrderHeader",  # SEM sufixo (schema silver = target)
    comment="Cabecalho de pedidos - limpo e validado",
    table_properties={"quality": "silver", "delta.feature.timestampNtz": "supported"},
)
def sales_order_header_silver():
    return (
        spark.readStream.table("retailmax.bronze.SalesOrderHeader")  # UC path cross-pipeline
        .dropDuplicates(["SalesOrderID"])
        .withColumn("OrderDate", F.to_date("OrderDate"))
        .withColumn("ShipDate", F.to_date("ShipDate"))
        .withColumn("DueDate", F.to_date("DueDate"))
        .withColumn("StatusName", F.create_map(
            *[item for k, v in STATUS_MAP.items() for item in (F.lit(k), F.lit(v))]
        )[F.col("Status")])
        .withColumn("_processed_at", F.current_timestamp())
    )

# ... mesma pattern para as 6 tabelas restantes:
# SalesOrderDetail: Revenue = OrderQty * UnitPrice * (1 - UnitPriceDiscount)
# Customer: FullName, EmailAddress lower/trim, CustomerSegment (B2B/B2C)
# Product: IsDiscontinued flag
# Address: City/StateProvince/CountryRegion trim
# CustomerAddress: bridge table (dedup por CustomerID+AddressID)
# ProductCategory: Name trim
```

### 3.7 DLT Pipeline - Gold (Modelo Dimensional)

```python
# src/pipelines/gold/model_gold.py (v3.0 - codigo real em producao)
# MUDANCAS v3.0:
#   - Refs CROSS-PIPELINE para Silver: spark.read.table("retailmax.silver.X")
#     (NAO "LIVE.X_silver" - Silver esta em pipeline separado)
#   - Refs INTRA-PIPELINE para dims: spark.read.table("LIVE.X")
#     (SEM "LIVE.gold.X" - "gold" e o schema default do pipeline)
#   - table_properties incluem "delta.feature.timestampNtz": "supported"

import dlt
from pyspark.sql import functions as F

# dim_date: gerada por range 2000-2030 (sem dependencia de fonte)
@dlt.table(
    name="dim_date",
    comment="Dimensao de data - gerada por range 2000-2030",
    table_properties={"quality": "gold", "delta.feature.timestampNtz": "supported"},
)
def dim_date():
    return spark.sql("""...""")  # sequence 2000-01-01 to 2030-12-31

# dim_customer: Customer + Address + purchase metrics + churn relativo
@dlt.table(
    name="dim_customer",
    comment="Dimensao de clientes - metricas de compra, churn relativo, geografia",
    table_properties={"quality": "gold", "delta.feature.timestampNtz": "supported"},
)
def dim_customer():
    customer = spark.read.table("retailmax.silver.Customer")       # cross-pipeline (UC path)
    orders = spark.read.table("retailmax.silver.SalesOrderHeader") # cross-pipeline
    cust_addr = spark.read.table("retailmax.silver.CustomerAddress")
    address = spark.read.table("retailmax.silver.Address")
    # ... metricas, churn com MAX(OrderDate) - 90 dias, endereco principal
    return (...)

# dim_product: Product + ProductCategory hierarquia (parent/child)
@dlt.table(
    name="dim_product",
    comment="Dimensao de produtos - hierarquia categoria/subcategoria",
    table_properties={"quality": "gold", "delta.feature.timestampNtz": "supported"},
)
def dim_product():
    product = spark.read.table("retailmax.silver.Product")          # cross-pipeline
    category = spark.read.table("retailmax.silver.ProductCategory") # cross-pipeline
    # ... hierarquia CategoryName/SubcategoryName, IsDiscontinued
    return (...)

# fact_sales: Header + Detail + dims, expectations FAIL
@dlt.expect_or_fail("revenue_positive", "Revenue >= 0")
@dlt.expect_or_fail("valid_customer_key", "CustomerKey IS NOT NULL")
@dlt.expect_or_fail("valid_product_key", "ProductKey IS NOT NULL")
@dlt.table(
    name="fact_sales",
    comment="Fato de vendas - modelo dimensional com Revenue incluindo desconto",
    table_properties={"quality": "gold", "delta.feature.timestampNtz": "supported"},
)
def fact_sales():
    header = spark.read.table("retailmax.silver.SalesOrderHeader")  # cross-pipeline
    detail = spark.read.table("retailmax.silver.SalesOrderDetail")  # cross-pipeline
    dim_cust = spark.read.table("LIVE.dim_customer").select("CustomerKey", "CustomerID")  # intra-pipeline
    dim_prod = spark.read.table("LIVE.dim_product").select("ProductKey", "ProductID")     # intra-pipeline
    return (...)
```

### 3.8 DLT Pipeline - Gold (KPIs)

```python
# src/pipelines/gold/kpis_gold.py (v3.0 - codigo real em producao)
# NOTA: Todas refs INTRA-PIPELINE usam "LIVE.X" (sem schema prefix)
#       5 KPIs derivados de fact_sales, dim_date, dim_customer, dim_product
import dlt
from pyspark.sql import functions as F

# kpi_receita_total: Revenue por Year/Quarter/Month
# kpi_ticket_medio: Ticket medio por periodo e CustomerSegment (B2B/B2C)
# kpi_churn: Clientes sem compra >90 dias (relativo a MAX OrderDate do dataset)
# kpi_produtos_descontinuados: Produtos descontinuados com receita historica
# kpi_top_produtos: Ranking de produtos por receita com CategoryName

# Exemplo: kpi_receita_total
@dlt.table(
    name="kpi_receita_total",
    comment="KPI: Receita total agregada por periodo (Year/Quarter/Month)",
    table_properties={"quality": "gold", "delta.feature.timestampNtz": "supported"},
)
def kpi_receita_total():
    return (
        spark.read.table("LIVE.fact_sales")  # intra-pipeline (SEM schema prefix)
        .join(spark.read.table("LIVE.dim_date"),
              F.col("OrderDateKey") == F.col("DateKey"))
        .groupBy("Year", "Quarter", "Month")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.countDistinct("SalesOrderID").alias("TotalPedidos"),
            (F.sum("Revenue") / F.countDistinct("SalesOrderID")).alias("TicketMedio"),
        )
    )
# ... (4 KPIs restantes seguem o mesmo padrao de refs LIVE.X)
```

### 3.9 Trigger DLT Refresh (chamado pelo ADF)

```python
# src/setup/trigger_dlt_refresh.py
# Notebook Databricks chamado pelo ADF via Notebook Activity

dbutils.widgets.text("pipeline_name", "retailmax_medallion_pipeline")
pipeline_name = dbutils.widgets.get("pipeline_name")

from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# Buscar pipeline pelo nome
pipelines = [
    p for p in w.pipelines.list_pipelines()
    if p.name == pipeline_name
]

if not pipelines:
    import json
    dbutils.notebook.exit(json.dumps({
        "status": "ERROR",
        "message": f"Pipeline '{pipeline_name}' not found"
    }))

pipeline_id = pipelines[0].pipeline_id

# Trigger update (incremental)
update = w.pipelines.start_update(pipeline_id=pipeline_id, full_refresh=False)

import json
dbutils.notebook.exit(json.dumps({
    "status": "TRIGGERED",
    "update_id": update.update_id
}))
```

---

## 4. Databricks App - Validacao de Master Data

**Status: PENDENTE**

- [ ] Implementar pagina: Visao Geral de Qualidade
- [ ] Implementar pagina: Registros Anomalos
- [ ] Implementar pagina: Historico de Cargas
- [ ] Implementar pagina: Master Data Review
- [ ] Deploy app no workspace dev

### 4.1 Estrutura do Repositorio `databricks-app`

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

### 4.2 App Entry Point

```python
# app.py
import streamlit as st

st.set_page_config(
    page_title="RetailMax - Master Data Validation",
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

### 4.3 Databricks App Config

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

## 5. Estrategia de Testes

### 5.1 Piramide de Testes

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

### 5.2 Status dos Testes

| Tipo | Arquivo | Quantidade | Status |
|------|---------|------------|--------|
| Unitario | `test_silver.py` | 11 testes | CONCLUIDO |
| Unitario | `test_gold.py` | 7 testes | CONCLUIDO |
| Unitario | `test_expectations.py` | - | PENDENTE |
| Integracao | Checklist (secao 5.4) | 12 itens | PARCIALMENTE CONCLUIDO |
| KPI Gold | Testes especificos KPIs | - | PENDENTE (gap de cobertura) |
| E2E | Pipeline completo end-to-end | - | PENDENTE |

### 5.3 Testes Unitarios (pytest) - CONCLUIDO (18 testes)

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
        (1, 101, "2008-06-01", 150.00, 1, "SO71774"),
        (2, 102, "2008-06-02", 200.00, 5, "SO71776"),
        (3, None, "2008-06-03", 100.00, 1, "SO71780"),  # customer nulo - deve ser dropado
        (4, 103, None, 50.00, 1, "SO71782"),              # data nula - deve ser dropada
    ]
    return spark.createDataFrame(
        data,
        ["SalesOrderID", "CustomerID", "OrderDate", "TotalDue", "Status", "SalesOrderNumber"]
    )

@pytest.fixture
def sample_sales_detail(spark):
    data = [
        (1, 1, 5, 10.00, 0.00),     # Revenue = 5 * 10 * (1 - 0.00) = 50.00
        (2, 2, 3, 25.50, 0.10),     # Revenue = 3 * 25.50 * (1 - 0.10) = 68.85
        (3, 3, 2, 100.00, 0.25),    # Revenue = 2 * 100 * (1 - 0.25) = 150.00
    ]
    return spark.createDataFrame(
        data,
        ["SalesOrderDetailID", "SalesOrderID", "OrderQty", "UnitPrice", "UnitPriceDiscount"]
    )
```

```python
# tests/test_silver.py
def test_sales_header_dedup(spark, sample_sales_header):
    """Deduplicacao deve remover registros com mesmo SalesOrderID."""
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


def test_revenue_calculation_with_discount(spark, sample_sales_detail):
    """Revenue = OrderQty * UnitPrice * (1 - UnitPriceDiscount)."""
    from pyspark.sql import functions as F

    result = (
        sample_sales_detail
        .withColumn(
            "Revenue",
            F.col("OrderQty") * F.col("UnitPrice") * (F.lit(1) - F.col("UnitPriceDiscount"))
        )
    )

    revenues = [round(row.Revenue, 2) for row in result.orderBy("SalesOrderDetailID").collect()]
    assert revenues == [50.00, 68.85, 150.00]


def test_customer_segment(spark):
    """Clientes com CompanyName sao B2B, sem sao B2C."""
    from pyspark.sql import functions as F

    data = [
        (1, "John", "Doe", "ACME Corp"),
        (2, "Jane", "Smith", None),
    ]
    df = spark.createDataFrame(data, ["CustomerID", "FirstName", "LastName", "CompanyName"])
    result = df.withColumn(
        "CustomerSegment",
        F.when(F.col("CompanyName").isNotNull(), F.lit("B2B")).otherwise(F.lit("B2C"))
    )

    segments = {row.CustomerID: row.CustomerSegment for row in result.collect()}
    assert segments == {1: "B2B", 2: "B2C"}
```

### 5.3 Testes de Integracao (Databricks dev)

```
CHECKLIST DE INTEGRACAO (executar no workspace dev)
===================================================================

[x] DLT Pipeline executa sem erro (full refresh)        - CONCLUIDO (3 pipelines)
[x] Bronze: 7 streaming tables criadas com dados         - CONCLUIDO (19 tabelas total)
[x] Silver: expectations DROP removendo registros invalidos - CONCLUIDO
[x] Gold: fact_sales com foreign keys validas             - CONCLUIDO (expectations FAIL)
[x] Gold: KPIs calculados corretamente                    - CONCLUIDO (5 KPIs)
[x] Gold: Revenue inclui desconto                         - CONCLUIDO
[x] Unity Catalog: linhagem visivel ate a origem          - CONCLUIDO
[x] ingestion_control: watermark atualizado apos execucao - CONCLUIDO
[x] ADF -> Databricks: trigger funcionando end-to-end     - CONCLUIDO
[ ] Row Filters: usuarios restritos nao veem dados        - PENDENTE (Fase 5)
[ ] Genie: responde "Qual a receita total?" correto       - PENDENTE (Fase 5)
[ ] App: carrega metricas de qualidade sem erro            - PENDENTE (Fase 5)
```

---

## 6. Cronograma de Desenvolvimento

### FASE 2: Ingestao e Camada Bronze (S5-S7) — CONCLUIDO

```
SEMANA 5-7: ADF + Auto Loader + DLT Bronze              STATUS: CONCLUIDO
===================================================================
[x] Pipeline ADF pl_master_ingestion (Lookup + ForEach)  - Metadata-driven
[x] Sub-pipelines: pl_copy_full_load + pl_copy_incremental
[x] Update de watermark e status na ingestion_control
[x] Auto Loader com cloudFiles + schemaLocation
[x] Carga full inicial: 7 tabelas SalesLT.* na landing zone
[x] DLT Bronze: 7 streaming tables com expectation rescued_data_null
[x] Full refresh executado com sucesso
[x] Linhagem visivel no Unity Catalog
[x] Carga incremental testada (SalesOrderHeader, SalesOrderDetail)

NOTA: timestampNtz required para Parquet do ADF - resolvido via table_properties

>>> MILESTONE M2: DATA LANDING <<< STATUS: CONCLUIDO
```

### FASE 3: Transformacao e Camada Silver (S8-S10) — CONCLUIDO

```
SEMANA 8-10: Silver Layer                                STATUS: CONCLUIDO
===================================================================
[x] SalesOrderHeader: dedup, tipos, StatusName map       - 4 expectations DROP
[x] SalesOrderDetail: dedup, Revenue c/ discount         - 5 expectations DROP
[x] Customer: dedup, FullName, CustomerSegment B2B/B2C   - 3 expectations DROP
[x] Product: dedup, IsDiscontinued flag                  - 3 expectations DROP
[x] Address: dedup, trim City/State/Country              - 2 expectations DROP
[x] CustomerAddress: dedup (CustomerID+AddressID)        - 2 expectations DROP
[x] ProductCategory: dedup, trim Name                    - 2 expectations DROP
[x] 11 testes unitarios (test_silver.py)                 - PASSANDO
[x] Refs cross-pipeline: spark.readStream.table("retailmax.bronze.X")
[x] DLT full refresh (Bronze + Silver) executado com sucesso

>>> MILESTONE M3: CLEAN DATA <<< STATUS: CONCLUIDO
```

### FASE 4: Modelo Dimensional e Camada Gold (S11-S14) — CONCLUIDO

```
SEMANA 11-14: Gold Layer                                 STATUS: CONCLUIDO
===================================================================
[x] dim_date: range 2000-2030 (11,323 registros)
[x] dim_customer: metricas compra, churn relativo (MAX OrderDate - 90d), geografia
[x] dim_product: hierarquia ProductCategory (parent/child), IsDiscontinued
[x] fact_sales: Header+Detail+dims, Revenue c/ discount, expectations FAIL
[x] kpi_receita_total: Year/Quarter/Month
[x] kpi_ticket_medio: por CustomerSegment (B2B/B2C)
[x] kpi_churn: clientes sem compra >90 dias
[x] kpi_produtos_descontinuados: substitui kpi_estoque_critico
[x] kpi_top_produtos: ranking por receita com CategoryName
[x] 7 testes unitarios (test_gold.py) - 3 classes               - PASSANDO
[x] Refs cross-pipeline: spark.read.table("retailmax.silver.X")
[x] Refs intra-pipeline: spark.read.table("LIVE.X")
[x] DLT full refresh (Bronze -> Silver -> Gold) executado com sucesso

Tabelas criadas em dev: 19 total (7 bronze + 7 silver + 4 dims + 5 KPIs + 1 fact)
PRs mergeados: retailmax-databricks #1, #2 | retailmax-data-factory #3

>>> MILESTONE M4: ANALYTICS READY <<< STATUS: CONCLUIDO
```

### FASE 5: Consumo, Dashboards, GenAI e App (S15-S18) — PENDENTE

```
SEMANA 15: SQL Endpoint + Databricks Dashboards
===================================================================
S15-1 | Configurar SQL Endpoint serverless                   | Data Eng
S15-2 | Criar Dashboard: Vendas (receita, ticket, trends)    | Analista
S15-3 | Criar Dashboard: Clientes (churn, segmentacao B2B/B2C, geografia) | Analista
S15-4 | Criar Dashboard: Produtos (categorias, descontinuados, top) | Analista
S15-5 | Configurar refresh automatico dos dashboards          | Data Eng


SEMANA 16: Databricks Genie + Seguranca
===================================================================
S16-1 | Criar Genie Space vinculado ao Gold layer            | Data Eng
S16-2 | Escrever instrucoes de contexto (glossario, KPIs)    | Analista
S16-3 | Testar queries em linguagem natural                  | Analista
S16-4 | Implementar Row Filters (restricao por CountryRegion) | Data Eng
S16-5 | Implementar Column Masks (EmailAddress, Phone)       | Data Eng


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

### FASE 6 (Dev): Validacao Hml, Deploy Prd e Go-Live (S20-S24) — PENDENTE

```
SEMANA 20: Validacao em Homologacao
===================================================================
S20-1 | Configurar Linked Services hml (SQL Server, ADLS)    | Data Eng
S20-2 | Executar carga full inicial em hml                    | Data Eng
S20-3 | Validar pipeline end-to-end em hml                   | Data Eng
S20-4 | Testes de aceite com stakeholders em hml              | Analista
S20-5 | Correcoes pos-validacao hml                          | Data Eng


SEMANA 22: Deploy de Pipelines em Producao
===================================================================
S22-1 | Configurar Linked Services prd (SQL Server, ADLS)    | Data Eng
S22-2 | Executar carga full inicial em prd                    | Data Eng
S22-3 | Configurar RBAC e security em prd                    | Data Eng
S22-4 | Validar pipeline end-to-end em prd                   | Data Eng
S22-5 | Aprovacao final de stakeholders                      | Todos


SEMANA 23: Otimizacao
===================================================================
S23-1 | Habilitar Photon em prd                               | Data Eng
S23-2 | Configurar Enhanced Autoscaling                       | Data Eng


SEMANA 24: Estabilizacao + Go-Live
===================================================================
S24-1 | Monitorar pipeline em prd (2a semana de execucao)     | Data Eng
S24-2 | Escrever guia de troubleshooting                      | Data Eng
S24-3 | Escrever guia de onboarding de novas tabelas          | Data Eng
S24-4 | Validacao final com stakeholders                      | Todos
S24-5 | GO-LIVE oficial                                       | Todos

>>> MILESTONE M6: GO-LIVE <<<
```

**Nota:** As semanas 19, 21 e S23 (monitoramento) sao de responsabilidade do time de Infraestrutura (ver `implementation-plan-infra.md`).

---

## 7. Criterios de Aceite - Desenvolvimento

| Fase | Criterio | Metrica |
|------|----------|---------|
| F2 | Dados no Bronze | 7 tabelas com row count > 0 |
| F2 | Metadata-driven funcional | INSERT na control table -> nova tabela ingerida |
| F3 | Qualidade Silver | Taxa de DROP < 5% |
| F3 | Testes unitarios | Cobertura > 80% |
| F4 | KPIs corretos | Validacao cruzada com SQL Server (diff < 1%) |
| F4 | Revenue com desconto | `SUM(Revenue)` == `SUM(LineTotal)` da fonte |
| F4 | Performance | Gold refresh < 30 min |
| F5 | Dashboards | Carregamento < 5 seg |
| F5 | Genie | Precisao > 85% em 20 perguntas de teste |
| F5 | App | Todas as 4 telas operacionais |
| F6 | Hml validado | Testes de aceite aprovados por stakeholders em hml |
| F6 | Producao estavel | 2 semanas sem falhas em prd |
| F6 | Performance E2E | Refresh end-to-end < 1 hora |

---

## 8. Equipe Minima - Desenvolvimento

| Papel | Quantidade | Dedicacao | Fases Principais |
|-------|-----------|-----------|------------------|
| Data Engineer (Senior) | 1 | 100% | F1-F6 (todo o projeto) |
| Data Engineer (Pleno) | 1 | 100% | F2-F5 (pipelines e app) |
| Analista de Dados | 1 | 50% | F4-F5 (KPIs, dashboards, Genie) |

---

## 9. Limitacoes Conhecidas (AdventureWorksLT)

| Limitacao | Impacto | Mitigacao |
|-----------|---------|-----------|
| `ProductInventory` nao existe no LT | KPI "Estoque Critico" do BRD nao implementavel | Substituido por `kpi_produtos_descontinuados` |
| Dados historicos (~2008) | Churn com `current_date()` marcaria 100% | Usa `MAX(OrderDate)` como data de referencia |
| Apenas 32 pedidos | Volume insuficiente para analises estatisticas | Suficiente para validacao funcional do pipeline |
| Sem `TerritoryID` no Customer | Segmentacao geografica indireta | Usa `Address` via `CustomerAddress` para geografia |
| Sem `AccountNumber` no Customer | Campo referenciado no FRD nao existe | `EmailAddress` usado como identificador alternativo |
| Sem subcategorias hierarquicas ricas | `ProductCategory` tem apenas 2 niveis | Suficiente para demo (categoria + subcategoria) |

---

## Fontes e Referencias

| Documento | Conteudo |
|-----------|---------|
| `document/architecture-plan.md` | Arquitetura v2.1 (base para este plano) |
| `document/implementation-plan-infra.md` | Parte 1: Infraestrutura e DevOps |
| `document/brd-retail-max.md` | Requisitos de negocio |
| `document/frd-adventure-works.md` | Especificacao funcional |
| `kb/lakeflow/index.md` | Medallion Architecture patterns |
| `kb/lakeflow/06-data-quality/expectations.md` | DLT Expectations |
| `kb/spark/01-performance-tuning.md` | Spark optimization |
| `kb/spark/05-best-practices.md` | PySpark best practices |
| SQL Server real | `sql-retailmax-source.database.windows.net / AdventureWorksLT` (validado 2026-03-30) |
