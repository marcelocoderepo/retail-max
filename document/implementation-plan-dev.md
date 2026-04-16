# Plano de Implementacao - Parte 2: Desenvolvimento

**Versao:** 2.1 | **Data:** 2026-03-30 | **Status:** Revisado
**Referencia:** `document/architecture-plan.md` v2.1
**Complemento:** `document/implementation-plan-infra.md` (Parte 1: Infraestrutura e DevOps)

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
| Todos os recursos Azure provisionados (dev) | Fase 1 - Infra | DEPENDENCIA |
| CI/CD operacional nos 3 projetos DevOps | Fase 1 - Infra | DEPENDENCIA |
| Unity Catalog com schemas bronze/silver/gold | Fase 1 - Infra | DEPENDENCIA |
| ADF Linked Services configurados | Fase 1 - Infra | DEPENDENCIA |
| SQL Server AdventureWorksLT acessivel | DBA | PENDENTE |
| Python 3.10+ no ambiente local | Data Eng | PENDENTE |
| Acesso ao workspace Databricks (dev) | Admin | PENDENTE |

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
# databricks.yml
bundle:
  name: retailmax-pipelines

workspace:
  root_path: /Shared/retailmax

targets:
  dev:
    workspace:
      host: https://adb-7405613595594457.17.azuredatabricks.net
    default: true

  hml:
    workspace:
      host: https://adb-7405619649239054.14.azuredatabricks.net

  prd:
    workspace:
      host: https://adb-7405605251477436.16.azuredatabricks.net

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

### 3.3 Unity Catalog - Setup

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

### 3.4 Tabela ingestion_control - DDL

```python
# src/setup/create_ingestion_control.py

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

# Dados iniciais (7 tabelas - schema SalesLT validado)
spark.sql(f"""
INSERT INTO {catalog}.bronze.ingestion_control
(source_schema, source_table, target_schema, target_table, load_type,
 watermark_column, primary_key, is_active, landing_path, schedule_frequency)
VALUES
('SalesLT', 'SalesOrderHeader',  'bronze', 'SalesOrderHeader_bronze',  'incremental', 'ModifiedDate', 'SalesOrderID',       true, '/landing/SalesOrderHeader/',  'daily'),
('SalesLT', 'SalesOrderDetail',  'bronze', 'SalesOrderDetail_bronze',  'incremental', 'ModifiedDate', 'SalesOrderDetailID', true, '/landing/SalesOrderDetail/',  'daily'),
('SalesLT', 'Customer',          'bronze', 'Customer_bronze',          'full',         NULL,          'CustomerID',         true, '/landing/Customer/',           'daily'),
('SalesLT', 'Product',           'bronze', 'Product_bronze',           'full',         NULL,          'ProductID',          true, '/landing/Product/',            'daily'),
('SalesLT', 'Address',           'bronze', 'Address_bronze',           'full',         NULL,          'AddressID',          true, '/landing/Address/',            'daily'),
('SalesLT', 'CustomerAddress',   'bronze', 'CustomerAddress_bronze',   'full',         NULL,          'CustomerID',         true, '/landing/CustomerAddress/',    'daily'),
('SalesLT', 'ProductCategory',   'bronze', 'ProductCategory_bronze',   'full',         NULL,          'ProductCategoryID',  true, '/landing/ProductCategory/',    'daily')
""")
```

### 3.5 DLT Pipeline - Bronze

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
# Helper: cria uma streaming table bronze generica
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
# Bronze Tables (7 tabelas - schema SalesLT)
# -------------------------------------------------------------------
sales_order_header_bronze = create_bronze_table(
    "SalesOrderHeader",
    "SalesOrderHeader/",
    "Cabecalho de pedidos - ingestao bruta (SalesLT.SalesOrderHeader)"
)

sales_order_detail_bronze = create_bronze_table(
    "SalesOrderDetail",
    "SalesOrderDetail/",
    "Detalhes de pedidos - ingestao bruta (SalesLT.SalesOrderDetail)"
)

customer_bronze = create_bronze_table(
    "Customer",
    "Customer/",
    "Clientes - ingestao bruta (SalesLT.Customer)"
)

product_bronze = create_bronze_table(
    "Product",
    "Product/",
    "Produtos - ingestao bruta (SalesLT.Product)"
)

address_bronze = create_bronze_table(
    "Address",
    "Address/",
    "Enderecos - ingestao bruta (SalesLT.Address)"
)

customer_address_bronze = create_bronze_table(
    "CustomerAddress",
    "CustomerAddress/",
    "Relacao cliente-endereco - ingestao bruta (SalesLT.CustomerAddress)"
)

product_category_bronze = create_bronze_table(
    "ProductCategory",
    "ProductCategory/",
    "Categorias de produto - ingestao bruta (SalesLT.ProductCategory)"
)
```

### 3.6 DLT Pipeline - Silver

```python
# src/pipelines/silver/transform_silver.py
import dlt
from pyspark.sql import functions as F

# Mapeamento de Status (tinyint) para nomes legiveis
STATUS_MAP = {
    1: "InProcess", 2: "Approved", 3: "BackOrdered",
    4: "Rejected", 5: "Shipped", 6: "Cancelled"
}

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
        .withColumn("StatusName", F.create_map(
            *[item for k, v in STATUS_MAP.items() for item in (F.lit(k), F.lit(v))]
        )[F.col("Status")])
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
        .withColumn("UnitPriceDiscount", F.coalesce(F.col("UnitPriceDiscount"), F.lit(0)))
        .withColumn(
            "Revenue",
            F.col("OrderQty") * F.col("UnitPrice") * (F.lit(1) - F.col("UnitPriceDiscount"))
        )
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: Customer
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_customer_id": "CustomerID IS NOT NULL",
    "valid_first_name": "FirstName IS NOT NULL",
    "valid_last_name": "LastName IS NOT NULL",
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
        .withColumn("FirstName", F.trim(F.col("FirstName")))
        .withColumn("LastName", F.trim(F.col("LastName")))
        .withColumn("FullName", F.concat_ws(" ", F.col("FirstName"), F.col("LastName")))
        .withColumn("EmailAddress", F.lower(F.trim(F.col("EmailAddress"))))
        .withColumn(
            "CustomerSegment",
            F.when(F.col("CompanyName").isNotNull(), F.lit("B2B"))
             .otherwise(F.lit("B2C"))
        )
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
        .withColumn(
            "IsDiscontinued",
            F.when(F.col("DiscontinuedDate").isNotNull(), F.lit(True))
             .otherwise(F.lit(False))
        )
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: Address
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_address_id": "AddressID IS NOT NULL",
    "valid_city": "City IS NOT NULL",
})
@dlt.table(
    name="Address_silver",
    comment="Enderecos - limpo e validado",
    table_properties={"quality": "silver"},
)
def address_silver():
    return (
        dlt.read_stream("Address_bronze")
        .dropDuplicates(["AddressID"])
        .withColumn("City", F.trim(F.col("City")))
        .withColumn("StateProvince", F.trim(F.col("StateProvince")))
        .withColumn("CountryRegion", F.trim(F.col("CountryRegion")))
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: CustomerAddress (bridge table)
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_customer_id": "CustomerID IS NOT NULL",
    "valid_address_id": "AddressID IS NOT NULL",
})
@dlt.table(
    name="CustomerAddress_silver",
    comment="Relacao cliente-endereco - limpo e validado",
    table_properties={"quality": "silver"},
)
def customer_address_silver():
    return (
        dlt.read_stream("CustomerAddress_bronze")
        .dropDuplicates(["CustomerID", "AddressID"])
        .withColumn("_processed_at", F.current_timestamp())
    )


# -------------------------------------------------------------------
# Silver: ProductCategory
# -------------------------------------------------------------------
@dlt.expect_all_or_drop({
    "valid_category_id": "ProductCategoryID IS NOT NULL",
    "valid_name": "Name IS NOT NULL",
})
@dlt.table(
    name="ProductCategory_silver",
    comment="Categorias de produto - limpo e validado",
    table_properties={"quality": "silver"},
)
def product_category_silver():
    return (
        dlt.read_stream("ProductCategory_bronze")
        .dropDuplicates(["ProductCategoryID"])
        .withColumn("Name", F.trim(F.col("Name")))
        .withColumn("_processed_at", F.current_timestamp())
    )
```

### 3.7 DLT Pipeline - Gold (Modelo Dimensional)

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
                    to_date('2000-01-01'),
                    to_date('2030-12-31'),
                    interval 1 day
                )) AS d
            )
        """)
    )


# -------------------------------------------------------------------
# dim_customer
# Colunas reais do SalesLT.Customer: CustomerID, NameStyle, Title,
# FirstName, MiddleName, LastName, Suffix, CompanyName, SalesPerson,
# EmailAddress, Phone, PasswordHash, PasswordSalt, rowguid, ModifiedDate
# -------------------------------------------------------------------
@dlt.table(
    name="dim_customer",
    comment="Dimensao de clientes",
    table_properties={"quality": "gold"},
)
def dim_customer():
    customer = spark.read.table("LIVE.Customer_silver")
    orders = spark.read.table("LIVE.SalesOrderHeader_silver")
    cust_addr = spark.read.table("LIVE.CustomerAddress_silver")
    address = spark.read.table("LIVE.Address_silver")

    # Metricas de compra por cliente
    customer_metrics = (
        orders
        .groupBy("CustomerID")
        .agg(
            F.min("OrderDate").alias("FirstPurchase"),
            F.max("OrderDate").alias("LastPurchase"),
            F.countDistinct("SalesOrderID").alias("TotalOrders"),
            F.sum("TotalDue").alias("TotalSpent"),
        )
    )

    # Data de referencia para churn: MAX(OrderDate) do dataset inteiro
    # (dados historicos ~2008, usar current_date() marcaria 100% como churned)
    max_order_date = orders.agg(F.max("OrderDate")).collect()[0][0]

    # Endereco principal do cliente (primeiro match)
    primary_address = (
        cust_addr
        .join(address, "AddressID")
        .dropDuplicates(["CustomerID"])
        .select("CustomerID", "City", "StateProvince", "CountryRegion")
    )

    return (
        customer
        .join(customer_metrics, "CustomerID", "left")
        .join(primary_address, "CustomerID", "left")
        .withColumn("CustomerKey", F.monotonically_increasing_id())
        .withColumn(
            "IsChurned",
            F.when(
                F.col("LastPurchase") < F.date_sub(F.lit(max_order_date), 90), True
            ).otherwise(False)
        )
        .select(
            "CustomerKey", "CustomerID", "FullName", "FirstName", "LastName",
            "CompanyName", "CustomerSegment", "EmailAddress", "Phone",
            "City", "StateProvince", "CountryRegion",
            "FirstPurchase", "LastPurchase", "TotalOrders", "TotalSpent",
            "IsChurned",
        )
    )


# -------------------------------------------------------------------
# dim_product
# Colunas reais do SalesLT.Product: ProductID, Name, ProductNumber,
# Color, StandardCost, ListPrice, Size, Weight, ProductCategoryID,
# ProductModelID, SellStartDate, SellEndDate, DiscontinuedDate, ...
# -------------------------------------------------------------------
@dlt.table(
    name="dim_product",
    comment="Dimensao de produtos",
    table_properties={"quality": "gold"},
)
def dim_product():
    product = spark.read.table("LIVE.Product_silver")
    category = spark.read.table("LIVE.ProductCategory_silver")

    # ProductCategory tem hierarquia: ParentProductCategoryID
    # Nivel 1 = categoria pai (Bikes, Components, Clothing, Accessories)
    # Nivel 2 = subcategoria (Mountain Bikes, Road Bikes, etc.)
    parent_cat = category.select(
        F.col("ProductCategoryID").alias("ParentCategoryID"),
        F.col("Name").alias("ParentCategoryName"),
    )
    sub_cat = (
        category
        .join(
            parent_cat,
            category["ParentProductCategoryID"] == parent_cat["ParentCategoryID"],
            "left"
        )
        .select(
            category["ProductCategoryID"],
            category["Name"].alias("SubcategoryName"),
            F.coalesce("ParentCategoryName", category["Name"]).alias("CategoryName"),
        )
    )

    return (
        product
        .join(sub_cat, "ProductCategoryID", "left")
        .withColumn("ProductKey", F.monotonically_increasing_id())
        .select(
            "ProductKey", "ProductID", "Name", "ProductNumber",
            "Color", "Size", "Weight", "ListPrice", "StandardCost",
            "CategoryName", "SubcategoryName",
            "SellStartDate", "SellEndDate", "IsDiscontinued",
        )
    )


# -------------------------------------------------------------------
# fact_sales
# Revenue inclui UnitPriceDiscount (corrigido v2.1)
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
            "UnitPriceDiscount",
            "Revenue",
            "LineTotal",
            "StatusName",
        )
    )
```

### 3.8 DLT Pipeline - Gold (KPIs)

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
# Segmentacao por CustomerSegment (B2B/B2C) derivado de CompanyName
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_ticket_medio",
    comment="KPI: Ticket medio por periodo e segmento de cliente",
    table_properties={"quality": "gold"},
)
def kpi_ticket_medio():
    return (
        spark.read.table("LIVE.fact_sales")
        .join(spark.read.table("LIVE.dim_date"), "OrderDateKey")
        .join(spark.read.table("LIVE.dim_customer"), "CustomerKey")
        .groupBy("Year", "Month", "CustomerSegment")
        .agg(
            F.sum("Revenue").alias("Receita"),
            F.countDistinct("SalesOrderID").alias("Pedidos"),
            (F.sum("Revenue") / F.countDistinct("SalesOrderID")).alias("TicketMedio"),
        )
    )


# -------------------------------------------------------------------
# KPI: Churn (clientes sem compra > 90 dias antes do ultimo pedido)
# Usa data relativa ao dataset (MAX(OrderDate)) como referencia
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_churn",
    comment="KPI: Clientes em churn (sem compra > 90 dias relativo ao dataset)",
    table_properties={"quality": "gold"},
)
def kpi_churn():
    dim_customer = spark.read.table("LIVE.dim_customer")
    max_date = dim_customer.agg(F.max("LastPurchase")).collect()[0][0]

    return (
        dim_customer
        .select(
            "CustomerKey", "CustomerID", "FullName", "EmailAddress",
            "CustomerSegment", "City", "CountryRegion",
            "LastPurchase", "TotalOrders", "TotalSpent", "IsChurned",
            F.datediff(F.lit(max_date), "LastPurchase").alias("DaysSinceLastPurchase"),
        )
        .where("IsChurned = true")
    )


# -------------------------------------------------------------------
# KPI: Produtos Descontinuados
# Substitui kpi_estoque_critico (ProductInventory nao existe no LT)
# Usa SellEndDate e DiscontinuedDate do SalesLT.Product
# -------------------------------------------------------------------
@dlt.table(
    name="kpi_produtos_descontinuados",
    comment="KPI: Produtos descontinuados ou fora de venda",
    table_properties={"quality": "gold"},
)
def kpi_produtos_descontinuados():
    product = spark.read.table("LIVE.dim_product")
    sales = spark.read.table("LIVE.fact_sales")

    # Receita por produto
    product_revenue = (
        sales
        .groupBy("ProductKey")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.sum("OrderQty").alias("QtdVendida"),
        )
    )

    return (
        product
        .where("IsDiscontinued = true")
        .join(product_revenue, "ProductKey", "left")
        .select(
            "ProductKey", "ProductID", "Name", "CategoryName",
            "ListPrice", "SellStartDate", "SellEndDate",
            F.coalesce("ReceitaTotal", F.lit(0)).alias("ReceitaTotal"),
            F.coalesce("QtdVendida", F.lit(0)).alias("QtdVendida"),
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
        .groupBy("ProductKey", "ProductID", "Name", "CategoryName")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.sum("OrderQty").alias("QtdTotal"),
            F.countDistinct("SalesOrderID").alias("TotalPedidos"),
        )
        .orderBy(F.desc("ReceitaTotal"))
    )
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

### 5.2 Testes Unitarios (pytest)

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

[ ] DLT Pipeline executa sem erro (full refresh)
[ ] Bronze: 7 streaming tables criadas com dados
[ ] Silver: expectations DROP removendo registros invalidos
[ ] Gold: fact_sales com foreign keys validas
[ ] Gold: KPIs calculados corretamente
[ ] Gold: Revenue inclui desconto (validar contra LineTotal da fonte)
[ ] Unity Catalog: linhagem visivel ate a origem
[ ] ingestion_control: watermark atualizado apos execucao
[ ] ADF -> Databricks: trigger funcionando end-to-end
[ ] Row Filters: usuarios restritos nao veem dados de outros territorios
[ ] Genie: responde "Qual a receita total?" com dado correto
[ ] App: carrega metricas de qualidade sem erro
```

---

## 6. Cronograma de Desenvolvimento

### FASE 2: Ingestao e Camada Bronze (S5-S7)

```
SEMANA 5: ADF Metadata-Driven + Auto Loader Setup
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S5-1 | Refinar pipeline ADF: error handling, retry      | Data Eng
S5-2 | Implementar update de watermark e status          | Data Eng
S5-3 | Configurar Auto Loader schemas (cloudFiles)       | Data Eng
S5-4 | Carga full inicial: todas 7 tabelas (SalesLT.*)   | Data Eng
S5-5 | Validar dados na landing zone (formato, volume)   | Data Eng


SEMANA 6: DLT Bronze Tables + Expectations WARN
===================================================================
DIA  | TAREFA                                          | RESPONSAVEL
-----+------------------------------------------------+-----------
S6-1 | Implementar ingest_bronze.py (7 streaming tables) | Data Eng
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
S8-1 | Implementar SalesOrderHeader_silver (dedup, tipos, StatusName) | Data Eng
S8-2 | Implementar SalesOrderDetail_silver (dedup, Revenue c/ discount) | Data Eng
S8-3 | Configurar expectations DROP em ambas               | Data Eng
S8-4 | Escrever testes unitarios (pytest)                  | Data Eng
S8-5 | Code review + merge                                 | Data Eng


SEMANA 9: Silver - Customer + Product + Address + Category
===================================================================
S9-1 | Implementar Customer_silver (dedup, FullName, Segment)  | Data Eng
S9-2 | Implementar Product_silver (dedup, IsDiscontinued)      | Data Eng
S9-3 | Implementar Address_silver + CustomerAddress_silver     | Data Eng
S9-4 | Implementar ProductCategory_silver                      | Data Eng
S9-5 | Testes unitarios + code review                          | Data Eng


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
S11-1 | Implementar dim_date (gerada por range)                        | Data Eng
S11-2 | Implementar dim_customer (metricas, churn relativo, geografia) | Data Eng
S11-3 | Testes unitarios para logica de churn e segmentacao            | Data Eng
S11-4 | Code review + merge                                            | Data Eng


SEMANA 12: dim_product + fact_sales
===================================================================
S12-1 | Implementar dim_product (JOIN com ProductCategory)     | Data Eng
S12-2 | Implementar fact_sales (joins + Revenue com discount)  | Data Eng
S12-3 | Configurar expectations FAIL (integridade ref.)        | Data Eng
S12-4 | Testes unitarios para revenue e joins                  | Data Eng
S12-5 | Z-ORDER em OrderDateKey e CustomerKey                  | Data Eng


SEMANA 13: KPIs
===================================================================
S13-1 | Implementar kpi_receita_total                          | Data Eng
S13-2 | Implementar kpi_ticket_medio (por CustomerSegment)     | Data Eng
S13-3 | Implementar kpi_churn + kpi_produtos_descontinuados    | Data Eng
S13-4 | Implementar kpi_top_produtos                           | Data Eng
S13-5 | Validacao cruzada: KPIs vs SQL Server direto           | Data Eng


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

### FASE 6 (Dev): Validacao Hml, Deploy Prd e Go-Live (S20-S24)

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
