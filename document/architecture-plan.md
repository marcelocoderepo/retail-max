# Plano de Implementacao - Plataforma Analitica Lakehouse RetailMax

**Versao:** 2.1 | **Data:** 2026-03-28 | **Status:** Revisado

**Changelog v2.1:**
- Inclusao do ambiente de homologacao (hml) em toda a stack
- Fluxo de deploy: dev (auto) -> hml (auto) -> prd (approval gate)
- 3 ambientes completos: dev, hml, prd
- Timeline ajustado: 24 semanas (expandido de 22 para incluir validacao hml)

**Changelog v2.0:**
- Detalhamento de ambiente Azure greenfield (ponto 1)
- Estrutura Azure DevOps com projetos por camada - dev/hml/prd (ponto 2)
- ADF como orquestrador unico dos pipelines Databricks (ponto 3)
- Tabela de parametros metadata-driven para ingestao dinamica (ponto 4)
- Databricks AI/BI Dashboards + Genie substitui Power BI + Dify na fase inicial (ponto 5)
- Databricks App para validacao de master data (ponto 6)

---

```
================================================================
TASK: Plano Completo de Implementacao - Lakehouse RetailMax
TYPE: [x] Architecture  [x] Roadmap  [x] Technology  [x] Risk
SCOPE: [x] Platform
THRESHOLD: 0.90

VALIDATION
-- KB: kb/lakeflow/, kb/spark/, kb/dify/
   Result: [x] FOUND
   Summary: KB cobre Medallion Architecture, Lakeflow DLT,
            CDC, Expectations, Unity Catalog, Spark tuning

-- Validacao via KB interna do projeto retail-max
   Result: [x] AGREES
   Summary: Stack alinhado com padroes documentados no projeto

AGREEMENT: [x] HIGH
BASE SCORE: 0.92

MODIFIERS APPLIED:
  [x] Requirements clarity: +0.05 (BRD + FRD disponiveis)
  [x] Technology validation: +0.05 (Stack validado via KB)
  [x] Timeline feasibility: -0.05 (Timeline estimado, sem equipe definida)
  FINAL SCORE: 0.97

DECISION: 0.97 >= 0.90 -> EXECUTE (create plan)
================================================================
```

---

## 1. Visao Geral da Arquitetura

### 1.1 Visao Macro da Plataforma

```
+-----------+     +--------------------+     +---------------------+
|  FONTES   |     |   AZURE DATABRICKS |     |      CONSUMO        |
|           |     |   (LAKEHOUSE)      |     |                     |
| SQL Server| --> | Bronze --> Silver   | --> | Databricks AI/BI    |
| (Advent.  |     |   --> Gold          |     |   Dashboards        |
| Works)    |     |                    |     | Databricks Genie    |
|           |     | Unity Catalog      |     |   (GenAI / NL)      |
|           |     | Lakeflow Pipelines |     | Databricks App      |
+-----------+     +--------------------+     |   (Master Data)     |
      |                     |                +---------------------+
 Azure Data            Delta Lake                     |
 Factory               Spark/PySpark           SQL Endpoints
 (Orquestrador)        Photon                  APIs REST
      |
+-----+------------------+
| AZURE DEVOPS (CI/CD)       |
| Projeto: ADF (dev/hml/prd) |
| Projeto: DBX (dev/hml/prd) |
| Projeto: IaC (dev/hml/prd) |
+-----------------------------+
```

### 1.2 Componentes Principais

```
+-------------------------------------------------------------------+
|  COMPONENTE 1: Infraestrutura e DevOps (IaC)                      |
|  Proposito: Provisionamento greenfield de todos recursos Azure    |
|  Tecnologia: Terraform + Azure DevOps Pipelines                   |
|  Interfaces: Azure DevOps -> Azure Resource Manager               |
|  Ambientes: dev, hml e prd (repos e pipelines separados)          |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 2: Camada de Ingestao (Bronze)                        |
|  Proposito: Ingestao bruta do SQL Server para Delta Lake          |
|  Tecnologia: Azure Data Factory (orquestrador) + Auto Loader     |
|  Interfaces: SQL Server (origem) -> ADLS Gen2 (destino)           |
|  Controle: Tabela de parametros metadata-driven                   |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 3: Camada de Transformacao (Silver)                   |
|  Proposito: Limpeza, deduplicacao, padronizacao, validacao        |
|  Tecnologia: Lakeflow Declarative Pipelines (DLT) + PySpark      |
|  Interfaces: Bronze tables -> Silver tables (Delta Lake)          |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 4: Camada Analitica (Gold)                            |
|  Proposito: Modelo dimensional Star Schema + KPIs                 |
|  Tecnologia: Lakeflow DLT + Materialized Views + SQL              |
|  Interfaces: Silver tables -> Gold tables (fact/dim)              |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 5: Governanca e Seguranca                             |
|  Proposito: Controle de acesso, linhagem, auditoria               |
|  Tecnologia: Unity Catalog + Row Filters + Column Masks           |
|  Interfaces: Transversal a todas as camadas                       |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 6: Consumo e Visualizacao                             |
|  Proposito: Dashboards, relatorios, IA conversacional             |
|  Tecnologia: Databricks AI/BI Dashboards + Genie (GenAI)         |
|  Interfaces: Gold tables -> Dashboards / Genie / SQL Endpoints    |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 7: Aplicacao de Validacao (Master Data)               |
|  Proposito: Interface para validacao e governanca de dados mestre |
|  Tecnologia: Databricks App (Streamlit/Gradio)                   |
|  Interfaces: Silver/Gold tables -> App -> Usuarios de negocio     |
+-------------------------------------------------------------------+
```

### 1.3 Fluxo de Dados Detalhado

```
[SQL Server - AdventureWorks]
  |
  | (0) ADF - Lookup na Tabela de Parametros
  |     Leitura dinamica: quais tabelas ingerir, tipo de carga, watermark
  v
  | (1) ADF - ForEach + Copy Activity (orquestrado)
  |     Full Load (inicial) + Incremental (watermark/CDC)
  |     Controlado pela tabela de parametros (metadata-driven)
  v
[ADLS Gen2 - Landing Zone]  (formato Parquet)
  |
  | (2) ADF - Trigger Databricks Notebook/Job
  |     ADF como orquestrador unico do pipeline end-to-end
  v
[DATABRICKS - Lakeflow Auto Loader]
  |     Deteccao automatica de novos arquivos (cloudFiles)
  v
[BRONZE - Streaming Tables]
  |  SalesOrderHeader_bronze
  |  SalesOrderDetail_bronze
  |  Customer_bronze
  |  Product_bronze
  |  ProductInventory_bronze
  |
  | (3) Lakeflow DLT - Expectations (WARN)
  |     Monitoramento de qualidade sem bloqueio
  v
[SILVER - Streaming Tables]
  |  SalesOrderHeader_silver   (dedup, nulos tratados, tipos convertidos)
  |  SalesOrderDetail_silver   (dedup, validacao de quantidades)
  |  Customer_silver           (dedup, padronizacao de nomes)
  |  Product_silver            (dedup, validacao de precos)
  |  ProductInventory_silver   (dedup, validacao de quantidades)
  |
  | (4) Lakeflow DLT - Expectations (DROP)
  |     Remocao de registros invalidos
  v
[GOLD - Materialized Views]
  |  fact_sales                (OrderID, ProductID, CustomerID, Receita, Qtd)
  |  dim_customer              (CustomerID, AccountNumber, IsChurned, ...)
  |  dim_product               (ProductID, Name, ListPrice, Category, ...)
  |  dim_date                  (DateKey, Year, Quarter, Month, Day, ...)
  |  kpi_receita_total         (Receita por periodo/canal)
  |  kpi_ticket_medio          (Ticket medio por periodo)
  |  kpi_churn                 (Clientes sem compra > 90 dias)
  |  kpi_estoque_critico       (Produtos com estoque < 10)
  |
  | (5) Lakeflow DLT - Expectations (FAIL)
  |     Validacao critica de integridade
  v
[CONSUMO]
  |-- Databricks AI/BI Dashboards (Vendas, Clientes, Estoque)
  |-- Databricks Genie (consultas em linguagem natural via GenAI)
  |-- Databricks App (validacao de master data pelo negocio)
  |-- SQL Endpoints -> APIs REST / Aplicacoes futuras
```

Esse padrao de qualidade em camadas esta validado na KB do projeto em `kb/lakeflow/06-data-quality/expectations.md`:

> **Bronze: WARN** -- Track issues
> **Silver: DROP** -- Remove bad data
> **Gold: FAIL** -- Strict validation

### 1.4 Modelo Dimensional (Gold Layer)

```
                    +------------------+
                    |    dim_date      |
                    |------------------|
                    | DateKey (PK)     |
                    | FullDate         |
                    | Year / Quarter   |
                    | Month / Day      |
                    | DayOfWeek        |
                    | IsWeekend        |
                    +--------+---------+
                             |
+------------------+         |         +------------------+
|  dim_customer    |         |         |  dim_product     |
|------------------|         |         |------------------|
| CustomerKey (PK) |         |         | ProductKey (PK)  |
| CustomerID (NK)  |         |         | ProductID (NK)   |
| AccountNumber    |         |         | Name             |
| CustomerType     |         |         | Category         |
| Territory        |         |         | Subcategory      |
| FirstPurchase    |         |         | ListPrice        |
| LastPurchase     |         |         | StandardCost     |
| TotalOrders      |         |         | Color            |
| IsChurned        |         |         +--------+---------+
+--------+---------+         |                  |
         |         +---------+----------+       |
         |         |    fact_sales       |       |
         +---------+--------------------+-------+
                   | SalesKey (PK)      |
                   | OrderID            |
                   | OrderDateKey (FK)  |----> dim_date
                   | CustomerKey (FK)   |----> dim_customer
                   | ProductKey (FK)    |----> dim_product
                   | OrderQty           |
                   | UnitPrice          |
                   | Revenue            | = OrderQty * UnitPrice
                   | LineTotal          |
                   | OrderStatus        |
                   +--------------------+
```

### 1.5 Regras de Negocio Implementadas

| KPI | Formula | Tabela Destino | Camada |
|-----|---------|----------------|--------|
| Receita Total | `SUM(OrderQty * UnitPrice)` | `kpi_receita_total` | Gold |
| Ticket Medio | `Receita / COUNT(DISTINCT OrderID)` | `kpi_ticket_medio` | Gold |
| Taxa de Churn | Clientes sem compra > 90 dias | `kpi_churn` | Gold |
| Estoque Critico | Produtos com `Quantity < 10` | `kpi_estoque_critico` | Gold |
| Top Produtos | Revenue por ProductID DESC | `kpi_top_produtos` | Gold |

### 1.6 Exemplo de Pipeline DLT (Referencia: `kb/lakeflow/index.md`)

```python
import dlt
from pyspark.sql import functions as F

# ============================================================
# BRONZE: Ingestao bruta com monitoramento
# ============================================================
@dlt.expect("has_data", "_rescued_data IS NULL")
@dlt.table(
    comment="Cabecalho de pedidos - ingestao bruta",
    table_properties={"quality": "bronze"}
)
def sales_order_header_bronze():
    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .load("/mnt/landing/SalesOrderHeader/")
    )

# ============================================================
# SILVER: Limpeza com Expectations DROP
# ============================================================
@dlt.expect_all_or_drop({
    "valid_order_id": "SalesOrderID IS NOT NULL",
    "valid_customer": "CustomerID IS NOT NULL",
    "valid_date": "OrderDate IS NOT NULL",
    "valid_total": "TotalDue >= 0"
})
@dlt.table(
    comment="Cabecalho de pedidos - limpo e validado",
    table_properties={"quality": "silver"}
)
def sales_order_header_silver():
    return (
        dlt.read_stream("sales_order_header_bronze")
        .dropDuplicates(["SalesOrderID"])
        .withColumn("OrderDate", F.to_date("OrderDate"))
        .withColumn("processed_at", F.current_timestamp())
    )

# ============================================================
# GOLD: Modelo dimensional com Expectations FAIL
# ============================================================
@dlt.expect_or_fail("revenue_positive", "Revenue >= 0")
@dlt.table(
    comment="Fato de vendas - modelo dimensional",
    table_properties={"quality": "gold"}
)
def fact_sales():
    header = spark.read.table("sales_order_header_silver")
    detail = spark.read.table("sales_order_detail_silver")

    return (
        detail
        .join(header, "SalesOrderID")
        .select(
            F.monotonically_increasing_id().alias("SalesKey"),
            "SalesOrderID",
            F.date_format("OrderDate", "yyyyMMdd").cast("int").alias("OrderDateKey"),
            "CustomerID",
            "ProductID",
            "OrderQty",
            "UnitPrice",
            (F.col("OrderQty") * F.col("UnitPrice")).alias("Revenue"),
            "LineTotal"
        )
    )

# KPI: Receita Total por periodo
@dlt.table(
    comment="KPI: Receita total agregada por periodo",
    table_properties={"quality": "gold"}
)
def kpi_receita_total():
    return (
        spark.read.table("fact_sales")
        .join(spark.read.table("dim_date"), "OrderDateKey")
        .groupBy("Year", "Quarter", "Month")
        .agg(
            F.sum("Revenue").alias("ReceitaTotal"),
            F.countDistinct("SalesOrderID").alias("TotalPedidos"),
            (F.sum("Revenue") / F.countDistinct("SalesOrderID")).alias("TicketMedio")
        )
    )
```

### 1.7 Tabela de Parametros - Ingestao Metadata-Driven

A ingestao e controlada por uma tabela de parametros (Delta Lake) que permite adicionar novas tabelas sem alterar pipelines. O ADF faz `Lookup` nessa tabela e itera com `ForEach`.

**Schema da Tabela: `retailmax.bronze.ingestion_control`**

| Coluna | Tipo | Descricao | Exemplo |
|--------|------|-----------|---------|
| `source_schema` | STRING | Schema de origem no SQL Server | `Sales` |
| `source_table` | STRING | Tabela de origem | `SalesOrderHeader` |
| `target_schema` | STRING | Schema destino no Lakehouse | `bronze` |
| `target_table` | STRING | Tabela destino | `SalesOrderHeader_bronze` |
| `load_type` | STRING | Tipo de carga: `full` ou `incremental` | `incremental` |
| `watermark_column` | STRING | Coluna para carga incremental (nullable) | `ModifiedDate` |
| `last_watermark_value` | TIMESTAMP | Ultimo valor processado | `2026-03-27T23:00:00` |
| `primary_key` | STRING | Chave primaria para dedup | `SalesOrderID` |
| `is_active` | BOOLEAN | Flag para ativar/desativar ingestao | `true` |
| `landing_path` | STRING | Caminho no ADLS Gen2 | `/landing/SalesOrderHeader/` |
| `schedule_frequency` | STRING | Frequencia: `daily`, `hourly`, `weekly` | `daily` |
| `last_load_status` | STRING | Status da ultima execucao | `SUCCESS` |
| `last_load_timestamp` | TIMESTAMP | Quando foi a ultima carga | `2026-03-28T03:15:00` |
| `row_count_last_load` | BIGINT | Registros processados na ultima carga | `1523` |
| `created_at` | TIMESTAMP | Data de criacao do registro | `2026-03-01T10:00:00` |
| `updated_at` | TIMESTAMP | Ultima atualizacao | `2026-03-28T03:15:00` |

**Dados Iniciais:**

```
| source_schema | source_table       | load_type   | watermark_column | is_active |
|---------------|--------------------|-------------|------------------|-----------|
| Sales         | SalesOrderHeader   | incremental | ModifiedDate     | true      |
| Sales         | SalesOrderDetail   | incremental | ModifiedDate     | true      |
| Sales         | Customer           | full        | NULL             | true      |
| Production    | Product            | full        | NULL             | true      |
| Production    | ProductInventory   | incremental | ModifiedDate     | true      |
```

**Fluxo no ADF:**

```
[Pipeline: pl_master_ingestion]
  |
  |--> Lookup: SELECT * FROM ingestion_control WHERE is_active = true
  |
  |--> ForEach (tabela):
  |      |
  |      |--> IF load_type = 'full':
  |      |       Copy Activity (full table)
  |      |
  |      |--> IF load_type = 'incremental':
  |      |       Copy Activity (WHERE watermark_column > last_watermark_value)
  |      |
  |      |--> Update ingestion_control:
  |             SET last_watermark_value, last_load_status, last_load_timestamp
  |
  |--> Trigger Databricks Job: Lakeflow DLT Pipeline (Bronze -> Silver -> Gold)
  |
  |--> On Failure: Alertas via Azure Monitor
```

**Para incluir uma nova tabela:** basta inserir um novo registro na `ingestion_control`. Nenhuma alteracao de pipeline necessaria.

### 1.8 Databricks App - Validacao de Master Data

Aplicacao leve hospedada no Databricks Apps para que usuarios de negocio validem e monitorem a qualidade dos dados mestres (Customer, Product).

**Funcionalidades:**

| Feature | Descricao |
|---------|-----------|
| Visao geral de qualidade | Metricas de completude, unicidade e validade por tabela |
| Registros anomalos | Lista de registros que falharam em expectations (WARN/DROP) |
| Validacao manual | Interface para usuario aprovar/rejeitar registros suspeitos |
| Historico de cargas | Timeline de ingestoes com volume e status por tabela |
| Alertas de master data | Notificacao de novos clientes/produtos sem dados completos |

**Stack tecnico:**
- Framework: Streamlit (suportado nativamente por Databricks Apps)
- Backend: Databricks SQL via `databricks-sql-connector`
- Autenticacao: SSO via workspace Databricks (sem login separado)
- Deploy: CI/CD via Azure DevOps -> Databricks Apps API

---

## 2. Decisoes Tecnologicas e Validacao

### 2.1 Comparacao de Plataformas

```
COMPARACAO TECNOLOGICA: Plataforma de Dados
===================================================================

| Criterio           | Databricks    | Synapse       | Fabric        |
|                    | Lakehouse     | Analytics     |               |
|--------------------|---------------|---------------|---------------|
| Medallion Nativo   | 5/5           | 3/5           | 4/5           |
| Delta Lake         | 5/5           | 4/5           | 4/5           |
| Spark/PySpark      | 5/5           | 4/5           | 4/5           |
| CDC Nativo         | 5/5           | 3/5           | 4/5           |
| Data Quality       | 5/5           | 3/5           | 3/5           |
| Governanca (UC)    | 5/5           | 3/5           | 3/5           |
| Custo (escala)     | 4/5           | 3/5           | 4/5           |
| Ecossistema IA     | 4/5           | 3/5           | 4/5           |
|--------------------|---------------|---------------|---------------|
| TOTAL              | 38/40         | 26/40         | 30/40         |

RECOMENDACAO: Azure Databricks Lakehouse
RACIONAL: Melhor suporte nativo a Medallion Architecture,
          Lakeflow DLT para pipelines declarativos, Unity Catalog
          para governanca completa, e total alinhamento com o
          stack ja validado na KB do projeto retail-max.

===================================================================
```

### 2.2 Decisoes por Componente

| Componente | Tecnologia Escolhida | Alternativa Descartada | Racional |
|------------|---------------------|----------------------|----------|
| **IaC** | Terraform + Azure DevOps | Bicep / ARM Templates | Terraform e multi-cloud, state management robusto, modulos reutilizaveis. DevOps com projetos separados (ADF/DBX/IaC) garante isolamento e CI/CD por camada |
| **Ingestao** | Azure Data Factory (metadata-driven) | JDBC direto / Airbyte | ADF com tabela de parametros: Lookup + ForEach dinamico. Adicionar nova tabela = INSERT, sem alterar pipeline |
| **Orquestracao** | Azure Data Factory (orquestrador unico) | Databricks Workflows / Airflow | ADF como ponto unico: ingestao + trigger de Databricks Jobs. Um so lugar para monitorar e escalonar o pipeline end-to-end |
| **Processamento** | Lakeflow DLT (Python) | Spark Jobs manuais / dbt | DLT e declarativo, gerencia dependencias, expectations nativas. Validado: `kb/lakeflow/01-core-concepts/concepts.md` |
| **Storage** | Delta Lake (ADLS Gen2) | Parquet puro | Delta oferece ACID, time travel, schema evolution, Z-ORDER. Validado: `kb/spark/01-performance-tuning.md` |
| **Governanca** | Unity Catalog | Hive Metastore / Ranger | UC oferece linhagem, row filters, column masks, RBAC. Validado: `kb/lakeflow/08-operations/unity-catalog.md` |
| **Qualidade** | DLT Expectations | Great Expectations | Nativo ao DLT, politicas WARN/DROP/FAIL por camada. Validado: `kb/lakeflow/06-data-quality/expectations.md` |
| **Compute** | Serverless + Photon | Classic Clusters | Elimina gerenciamento, Photon acelera queries SQL. Validado: `kb/lakeflow/05-configuration/pipeline-configuration.md` |
| **Dashboards** | Databricks AI/BI Dashboards | Power BI / Tableau | Nativo ao Databricks, sem licenca adicional, integrado com Unity Catalog. Power BI pode ser adicionado em fase futura se necessario |
| **IA Conversacional** | Databricks Genie (AI/BI) | Dify / Custom LangChain | Genie (GA) oferece NL-to-SQL nativo sobre o Gold layer, sem infraestrutura adicional, integrado com Unity Catalog e permissoes. Dify permanece como opcao futura para chatflows customizados |
| **Master Data App** | Databricks App (Streamlit) | App externo / Power Apps | Hospedado no proprio workspace, SSO integrado, acesso direto a Delta tables sem camada intermediaria |

### 2.3 Estrutura Azure DevOps

```
Azure DevOps Organization: retailmax
===================================================================

PROJETO 1: retailmax-iac
|-- Descricao: Infraestrutura como Codigo (Terraform)
|-- Repos:
|   |-- terraform-infra (modulos: rg, adls, databricks, adf, keyvault, vnet)
|-- Pipelines:
|   |-- ci-terraform-validate  (PR -> terraform plan dev/hml/prd)
|   |-- cd-terraform-deploy    (merge main -> dev auto -> hml auto -> prd approval)
|-- Environments: dev, hml, prd
|-- Approvals: prd requer aprovacao manual

PROJETO 2: retailmax-adf
|-- Descricao: Azure Data Factory pipelines e linked services
|-- Repos:
|   |-- adf-pipelines (ARM export / ADF Git integration)
|-- Pipelines:
|   |-- ci-adf-validate       (PR -> validacao de ARM templates)
|   |-- cd-adf-deploy         (publish -> hml auto -> prd approval)
|-- Environments: dev, hml, prd
|-- Nota: ADF dev conectado ao Git (live mode), hml/prd via CI/CD

PROJETO 3: retailmax-databricks
|-- Descricao: Notebooks, DLT pipelines, Databricks App
|-- Repos:
|   |-- databricks-pipelines  (notebooks DLT, configs, testes)
|   |-- databricks-app        (Streamlit app para master data)
|-- Pipelines:
|   |-- ci-databricks-test    (PR -> pytest + linting)
|   |-- cd-databricks-deploy  (merge -> dev auto -> hml auto -> prd approval)
|   |-- cd-app-deploy         (deploy Databricks App)
|-- Environments: dev, hml, prd
|-- Ferramentas: Databricks CLI / Databricks Asset Bundles

===================================================================
```

### 2.4 Infraestrutura Azure (Greenfield)

Todos os recursos serao provisionados do zero via Terraform.

```
RECURSOS AZURE A PROVISIONAR
===================================================================

Resource Group: rg-retailmax-dev / rg-retailmax-hml / rg-retailmax-prd
|
|-- Azure Data Lake Storage Gen2
|   |-- Storage Account: stretailmax{env}
|   |-- Containers: landing, bronze, silver, gold
|   |-- Acesso: Managed Identity + RBAC
|
|-- Azure Data Factory
|   |-- ADF: adf-retailmax-{env}
|   |-- Linked Services: SQL Server, ADLS Gen2, Databricks
|   |-- Managed Identity para autenticacao
|   |-- Git integration (dev) / CI/CD (prd)
|
|-- Azure Databricks
|   |-- Workspace: dbx-retailmax-{env}
|   |-- Unity Catalog: retailmax_{env}
|   |-- Clusters: Serverless + Photon
|   |-- Catalogos: bronze, silver, gold
|
|-- Azure Key Vault
|   |-- KV: kv-retailmax-{env}
|   |-- Secrets: SQL Server connection, SPN credentials
|   |-- Acesso: Managed Identity (ADF, Databricks)
|
|-- Networking
|   |-- VNet: vnet-retailmax-{env}
|   |-- Subnets: snet-databricks-public, snet-databricks-private
|   |-- Private Endpoints: ADLS, Key Vault, SQL Server
|   |-- NSGs: regras de seguranca por subnet
|
|-- Monitoring
|   |-- Azure Monitor + Log Analytics Workspace
|   |-- Diagnostic Settings para ADF, Databricks
|   |-- Alertas: falhas de pipeline, custos acima do threshold
|
|-- Identity
|   |-- Service Principal: spn-retailmax-{env}
|   |-- Managed Identities: ADF, Databricks
|   |-- Azure AD Groups: grp-retailmax-admins, grp-retailmax-analysts

===================================================================
```

### 2.5 Validacao via Knowledge Base

| Decisao | Arquivo KB | Status |
|---------|-----------|--------|
| Lakeflow DLT | `kb/lakeflow/index.md` | VALIDADO |
| Medallion Architecture | `kb/lakeflow/02-getting-started/tutorial-pipelines.md` | VALIDADO |
| CDC com SCD Type 1/2 | `kb/lakeflow/04-features/cdc.md` | VALIDADO |
| Expectations WARN/DROP/FAIL | `kb/lakeflow/06-data-quality/expectations.md` | VALIDADO |
| Unity Catalog + RBAC | `kb/lakeflow/08-operations/unity-catalog.md` | VALIDADO |
| Spark AQE + Performance | `kb/spark/01-performance-tuning.md` | VALIDADO |
| Particionamento e Z-ORDER | `kb/spark/03-partitioning-shuffle.md` | VALIDADO |
| Best Practices PySpark | `kb/spark/05-best-practices.md` | VALIDADO |
| Pipeline Configuration | `kb/lakeflow/05-configuration/pipeline-configuration.md` | VALIDADO |

---

## 3. Roadmap de Implementacao

```
ROADMAP DE IMPLEMENTACAO (24 semanas, 6 fases)
===================================================================

FASE 1: Fundacao, Infraestrutura e DevOps (Semanas 1-4)
|
|-- Duracao: 4 semanas (expandida - ambiente greenfield)
|-- Objetivos:
|   |-- Provisionar TODA infraestrutura Azure do zero (Terraform)
|   |-- Configurar Azure DevOps com 3 projetos (IaC, ADF, Databricks)
|   |-- Configurar Unity Catalog e governanca base
|   |-- Estabelecer CI/CD pipelines para todas as camadas
|-- Entregaveis:
|   |-- Semana 1-2: Infraestrutura base
|   |   |-- Azure DevOps Organization + 3 projetos configurados
|   |   |-- Terraform modules: Resource Groups, VNet, ADLS Gen2, Key Vault
|   |   |-- Pipelines CI/CD para Terraform (plan/apply dev, hml e prd)
|   |   |-- Resource Groups provisionados (dev + hml + prd)
|   |   |-- ADLS Gen2 com containers (landing/bronze/silver/gold)
|   |   |-- Key Vault com secrets iniciais
|   |   |-- VNet + Subnets + Private Endpoints
|   |-- Semana 3: Databricks + ADF
|   |   |-- Workspace Databricks provisionado (dev + hml + prd)
|   |   |-- Unity Catalog: catalogo "retailmax_{env}" com schemas
|   |   |-- ADF provisionado com Git integration (dev)
|   |   |-- Service Principals e Managed Identities configurados
|   |   |-- Linked Services: SQL Server, ADLS, Databricks
|   |   |-- CI/CD pipelines para ADF e Databricks
|   |-- Semana 4: Validacao e tabela de controle
|   |   |-- Tabela ingestion_control criada no Unity Catalog
|   |   |-- Dados iniciais (5 tabelas) inseridos
|   |   |-- Pipeline ADF master (Lookup + ForEach) criado e testado
|   |   |-- Template DLT de teste ("hello world") executando
|   |   |-- Documentacao de onboarding para equipe
|-- Dependencias: Subscription Azure ativa, credenciais SQL Server, budget aprovado
|-- Criterios de Sucesso:
|   |-- Todos os recursos Azure provisionados via Terraform
|   |-- CI/CD operacional nos 3 projetos DevOps
|   |-- Pipeline DLT de teste executando com sucesso
|   |-- Unity Catalog acessivel com permissoes configuradas
|   |-- Tabela ingestion_control populada e funcional

FASE 2: Ingestao e Camada Bronze (Semanas 5-7)
|
|-- Duracao: 3 semanas
|-- Dependencias: Fase 1 completa
|-- Objetivos:
|   |-- Implementar ingestao metadata-driven do SQL Server via ADF
|   |-- Criar Streaming Tables Bronze para todas as tabelas
|   |-- Configurar Expectations de monitoramento (WARN)
|-- Entregaveis:
|   |-- Pipeline ADF metadata-driven operacional:
|   |   |-- Lookup na ingestion_control
|   |   |-- ForEach com Copy Activity (full + incremental)
|   |   |-- Update automatico de watermark e status
|   |   |-- Trigger Databricks Job pos-ingestao
|   |-- 5 Streaming Tables Bronze:
|   |   |-- SalesOrderHeader_bronze
|   |   |-- SalesOrderDetail_bronze
|   |   |-- Customer_bronze
|   |   |-- Product_bronze
|   |   |-- ProductInventory_bronze
|   |-- Expectations WARN para monitoramento
|   |-- Auto Loader configurado para landing zone
|   |-- Linhagem visivel no Unity Catalog
|-- Criterios de Sucesso:
|   |-- Dados SQL Server chegando ao Bronze em < 1 hora
|   |-- Metricas de qualidade visiveis no dashboard DLT
|   |-- Zero perda de dados na ingestao
|   |-- Adicionar nova tabela = INSERT na ingestion_control (validar)

FASE 3: Transformacao e Camada Silver (Semanas 8-10)
|
|-- Duracao: 3 semanas
|-- Dependencias: Fase 2 completa
|-- Objetivos:
|   |-- Implementar limpeza e padronizacao de dados
|   |-- Aplicar regras de deduplicacao e tratamento de nulos
|   |-- Configurar Expectations de qualidade (DROP)
|-- Entregaveis:
|   |-- 5 Streaming Tables Silver com transformacoes:
|   |   |-- Deduplicacao por chave primaria
|   |   |-- Tratamento de nulos (coalesce/default ou exclusao)
|   |   |-- Conversao de tipos (string -> date, cast corretos)
|   |   |-- Padronizacao de campos texto (trim, upper)
|   |-- Expectations DROP implementadas:
|   |   |-- valid_order_id, valid_customer, valid_product
|   |   |-- positive_quantity, valid_price, valid_date
|   |-- Testes unitarios para transformacoes (pytest)
|-- Criterios de Sucesso:
|   |-- Taxa de registros invalidos dropados < 5%
|   |-- Todas as regras de qualidade documentadas
|   |-- Testes com cobertura > 80%

FASE 4: Modelo Dimensional e Camada Gold (Semanas 11-14)
|
|-- Duracao: 4 semanas
|-- Dependencias: Fase 3 completa
|-- Objetivos:
|   |-- Construir Star Schema (fact_sales + dimensoes)
|   |-- Implementar KPIs e metricas de negocio
|   |-- Configurar Expectations criticas (FAIL)
|-- Entregaveis:
|   |-- Tabela Fato: fact_sales (grao: linha de pedido)
|   |-- Dimensoes: dim_customer, dim_product, dim_date
|   |-- Materialized Views de KPIs:
|   |   |-- kpi_receita_total (por periodo, canal, produto)
|   |   |-- kpi_ticket_medio (por periodo, segmento)
|   |   |-- kpi_churn (clientes sem compra > 90 dias)
|   |   |-- kpi_estoque_critico (produtos com qty < 10)
|   |   |-- kpi_top_produtos (ranking por receita)
|   |-- Expectations FAIL (integridade referencial)
|   |-- Z-ORDER em colunas mais filtradas
|-- Criterios de Sucesso:
|   |-- Modelo validado com stakeholders de negocio
|   |-- KPIs corretos (validacao cruzada com SQL Server)
|   |-- Refresh do Gold layer < 30 minutos

FASE 5: Consumo, Dashboards, GenAI e Databricks App (Semanas 15-18)
|
|-- Duracao: 4 semanas
|-- Dependencias: Fase 4 completa
|-- Objetivos:
|   |-- Configurar Databricks SQL Endpoints (serverless)
|   |-- Criar Databricks AI/BI Dashboards
|   |-- Habilitar Databricks Genie para consultas em linguagem natural
|   |-- Desenvolver Databricks App para validacao de master data
|-- Entregaveis:
|   |-- SQL Endpoint serverless configurado
|   |-- 3 Databricks AI/BI Dashboards:
|   |   |-- Vendas (receita, ticket medio, tendencias)
|   |   |-- Clientes (churn, segmentacao, comportamento)
|   |   |-- Estoque (niveis, alertas, reposicao)
|   |-- Databricks Genie configurado:
|   |   |-- Genie Space vinculado ao Gold layer
|   |   |-- Instrucoes de contexto (glossario de negocios, KPIs)
|   |   |-- Exemplos de perguntas: "Qual a receita do ultimo mes?"
|   |   |-- Permissoes via Unity Catalog (acesso por grupo)
|   |-- Databricks App (Master Data Validation):
|   |   |-- Streamlit app deployado via Databricks Apps
|   |   |-- Tela: visao geral de qualidade (Customer, Product)
|   |   |-- Tela: registros anomalos para revisao
|   |   |-- Tela: historico de cargas (da ingestion_control)
|   |   |-- CI/CD via DevOps (projeto retailmax-databricks)
|   |-- Row Filters e Column Masks para dados sensiveis
|   |-- Documentacao de uso para areas de negocio
|-- Criterios de Sucesso:
|   |-- Dashboards carregando em < 5 segundos
|   |-- Genie respondendo com precisao > 85% nas queries
|   |-- App de master data operacional e aprovado pelo negocio
|   |-- Usuarios de negocio treinados

FASE 6: Operacoes, Otimizacao e Go-Live (Semanas 19-24)
|
|-- Duracao: 6 semanas (expandida - inclui deploy hml + validacao + prd)
|-- Dependencias: Fase 5 completa
|-- Objetivos:
|   |-- Deploy em producao via CI/CD (Terraform + ADF + Databricks)
|   |-- Otimizar performance dos pipelines
|   |-- Configurar monitoramento e alertas
|   |-- Executar go-live em producao
|-- Entregaveis:
|   |-- Deploy em homologacao e producao:
|   |   |-- Terraform apply em hml + prd (todos os recursos)
|   |   |-- Validacao e testes de aceite em hml com stakeholders
|   |   |-- ADF pipelines deployados em hml/prd via CI/CD
|   |   |-- Notebooks e DLT pipelines deployados em hml/prd
|   |   |-- Databricks App deployado em hml/prd
|   |-- Pipeline otimizado:
|   |   |-- Photon habilitado
|   |   |-- Autoscaling configurado (Enhanced)
|   |   |-- AQE otimizado (ref: kb/spark/01-performance-tuning.md)
|   |-- Monitoramento:
|   |   |-- Azure Monitor: alertas de falha (email + Slack)
|   |   |-- Dashboard operacional de pipelines (ADF + DLT)
|   |   |-- Metricas de qualidade de dados
|   |   |-- Alertas de custo (budget threshold)
|   |-- Documentacao operacional:
|   |   |-- Runbook de operacoes
|   |   |-- Guia de troubleshooting
|   |   |-- Procedimentos de recuperacao
|   |   |-- Guia de onboarding de novas tabelas (ingestion_control)
|   |-- Treinamento de usuarios finais
|-- Criterios de Sucesso:
|   |-- Homologacao validada e aprovada por stakeholders
|   |-- Pipeline em producao por 2 semanas sem falhas
|   |-- Refresh end-to-end < 1 hora
|   |-- Reducao de 50% no tempo de relatorios (meta BRD)
|   |-- CI/CD operacional em todos os 3 projetos DevOps (dev->hml->prd)

===================================================================
```

### 3.1 Visualizacao do Timeline

```
     Fase 1         Fase 2     Fase 3     Fase 4       Fase 5       Fase 6
    |-----------|---------|---------|-----------|-----------|---------------|
    S1-S4        S5-S7      S8-S10    S11-S14     S15-S18     S19-S24

    [Fundacao]   [Ingestao] [Silver]   [Gold]    [Consumo]    [Ops]
     Terraform    Bronze     Limpeza   Star       DB Dashb.   Hml Validate
     DevOps       ADF+DLT    DQ DROP   Schema     Genie AI    Prd Deploy
     Unity Cat    Metadata             DQ FAIL    DB App      Go-Live
     ADF/DBX      Table                           Seguranca   Monitor+Tuning
```

### 3.2 Caminho Critico

```
Fase 1 --> Fase 2 --> Fase 3 --> Fase 4  (CAMINHO CRITICO)
                                   |
                                   +--> Fase 5 --+
                                   |             |--> Go-Live (S24)
                                   +--> Fase 6 --+
```

Qualquer atraso nas Fases 1 a 4 impacta diretamente o go-live. Fases 5 e 6 possuem alguma flexibilidade (dashboards podem ser entregues de forma iterativa).

### 3.3 Marcos (Milestones)

| Marco | Semana | Entregavel |
|-------|--------|------------|
| M1 - Infra Ready | S4 | Azure provisionado + DevOps + Unity Catalog operacionais |
| M2 - Data Landing | S7 | Dados do SQL Server no Bronze (metadata-driven) |
| M3 - Clean Data | S10 | Silver layer com qualidade validada |
| M4 - Analytics Ready | S14 | Star Schema + KPIs calculados |
| M5 - User Access | S18 | Dashboards + Genie + App disponiveis |
| M5.5 - Hml Validated | S20 | Homologacao validada com stakeholders |
| M6 - Go-Live | S24 | Producao operacional (deploy completo via CI/CD) |

---

## 4. Avaliacao de Riscos

```
AVALIACAO DE RISCOS
===================================================================

| # | Risco                        | Impacto | Prob.  | Mitigacao                     |
|---|------------------------------|---------|--------|-------------------------------|
| 1 | Qualidade ruim dos dados     | ALTO    | ALTO   | Expectations em 3 camadas     |
|   | de origem (SQL Server)       |         |        | (WARN/DROP/FAIL). Relatorios  |
|   |                              |         |        | de qualidade desde a Fase 2.  |
|   |                              |         |        | DB App para validacao master. |
|---|------------------------------|---------|--------|-------------------------------|
| 2 | Baixa adocao pelos usuarios  | ALTO    | MEDIO  | Treinamento na Fase 6.        |
|   |                              |         |        | Genie para acesso em          |
|   |                              |         |        | linguagem natural. Dashboards |
|   |                              |         |        | validados com stakeholders.   |
|---|------------------------------|---------|--------|-------------------------------|
| 3 | Custos Azure acima do        | MEDIO   | MEDIO  | Serverless (pay-per-use).     |
|   | orcamento                    |         |        | Autoscaling com limites max.  |
|   |                              |         |        | Triggered mode (nao           |
|   |                              |         |        | continuous). Azure Monitor    |
|   |                              |         |        | alertas de budget.            |
|---|------------------------------|---------|--------|-------------------------------|
| 4 | Performance insuficiente     | MEDIO   | BAIXO  | Photon habilitado. AQE        |
|   | nos pipelines                |         |        | configurado. Z-ORDER em       |
|   |                              |         |        | colunas de filtro frequente.  |
|---|------------------------------|---------|--------|-------------------------------|
| 5 | Atraso na entrega do         | ALTO    | MEDIO  | Buffer de 1 semana na Fase 4. |
|   | projeto                      |         |        | Dashboards iterativos (MVP).  |
|   |                              |         |        | Reducao de escopo se preciso. |
|---|------------------------------|---------|--------|-------------------------------|
| 6 | Problemas de seguranca       | ALTO    | BAIXO  | Unity Catalog RBAC. Row       |
|   | e conformidade               |         |        | filters e column masks.       |
|   |                              |         |        | Private Endpoints. Key Vault. |
|   |                              |         |        | Service principals. Audit log.|
|---|------------------------------|---------|--------|-------------------------------|
| 7 | Mudancas de schema na        | MEDIO   | MEDIO  | Delta Lake schema evolution.  |
|   | origem (SQL Server)          |         |        | Schema enforcement no Silver. |
|   |                              |         |        | Alertas de mudanca de schema. |
|---|------------------------------|---------|--------|-------------------------------|
| 8 | Indisponibilidade do SQL     | BAIXO   | BAIXO  | ADF com retry automatico.     |
|   | Server durante ingestao      |         |        | Janela de ingestao noturna.   |
|---|------------------------------|---------|--------|-------------------------------|
| 9 | Complexidade na configuracao | MEDIO   | MEDIO  | Terraform modularizado.       |
|   | greenfield do Azure          |         |        | Templates reutilizaveis.      |
|   |                              |         |        | Fase 1 expandida para 4 sem.  |
|   |                              |         |        | Documentacao de IaC detalhada.|
|---|------------------------------|---------|--------|-------------------------------|
|10 | Falta de conhecimento da     | MEDIO   | MEDIO  | KB do projeto como base.      |
|   | equipe com Lakeflow/DLT      |         |        | Capacitacao na Fase 1.        |
|   |                              |         |        | Templates prontos de pipeline.|
|---|------------------------------|---------|--------|-------------------------------|
|11 | Drift entre ambientes        | MEDIO   | MEDIO  | IaC (Terraform) como unica    |
|   | dev, hml e prd               |         |        | fonte de verdade. CI/CD com   |
|   |                              |         |        | deploy progressivo dev->hml-> |
|   |                              |         |        | prd. Sem alteracao manual em  |
|   |                              |         |        | hml/prd.                      |

===================================================================
```

### 4.1 Matriz de Risco

```
              | Baixo Impacto | Medio Impacto | Alto Impacto   |
--------------+---------------+---------------+----------------+
Alta Prob.    | Monitorar     | Planejar      | ** CRITICO **  |
              |               |               | R1 (Qualidade) |
--------------+---------------+---------------+----------------+
Media Prob.   | Aceitar       | Monitorar     | Planejar       |
              |               | R3 (Custos)   | R2 (Adocao)    |
              |               | R7 (Schema)   | R5 (Atraso)    |
              |               | R9 (Greenf.)  |                |
              |               | R10 (Conhec.) |                |
              |               | R11 (Drift)   |                |
--------------+---------------+---------------+----------------+
Baixa Prob.   | Aceitar       | Aceitar       | Monitorar      |
              | R8 (SQL Down) | R4 (Perf.)    | R6 (Seguranca) |
--------------+---------------+---------------+----------------+
```

### 4.2 Riscos Criticos (requerem mitigacao imediata)

**R1 - Qualidade dos dados de origem** e o unico risco classificado como CRITICO (alto impacto + alta probabilidade).

Acoes imediatas:
1. Implementar Expectations desde o dia 1 da Fase 2
2. Criar relatorio de qualidade para stakeholders mostrando taxa de invalidos
3. Definir SLAs de qualidade com a equipe responsavel pelo SQL Server
4. Estabelecer threshold de aceitacao (ex: < 5% invalidos no Silver)
5. Usar Databricks App (master data) para validacao manual de registros criticos

### 4.3 Planos de Contingencia

| Gatilho | Resposta |
|---------|----------|
| R1: Mais de 20% de registros invalidos | Pausar pipeline, remediar na fonte, ajustar expectations |
| R2: Adocao < 30% em 30 dias pos go-live | Sprint dedicado de UX com usuarios, simplificar dashboards, treinar Genie |
| R5: Atraso > 2 semanas no caminho critico | Reduzir escopo Gold para MVP (fact_sales + 2 KPIs), dashboards simplificados |
| R3: Custo > 150% do budget | Migrar para triggered com menor frequencia, desligar Photon temporariamente |
| R9: Terraform com erros de provisionamento | Fallback para portal Azure (manual) com documentacao, corrigir IaC depois |

---

## 5. ADRs - Architecture Decision Records

### ADR-001: Medallion Architecture com Lakeflow DLT

```
ADR-001: Medallion Architecture com Lakeflow Declarative Pipelines
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
A RetailMax precisa transformar dados brutos do SQL Server em
modelos dimensionais para dashboards e IA. O projeto requer
rastreabilidade, qualidade de dados e governanca. O BRD define
ingestao batch, transformacao e modelagem como escopo.

DECISAO:
Adotar a Medallion Architecture (Bronze/Silver/Gold) implementada
com Lakeflow Declarative Pipelines (DLT) em Python.

- Bronze: Streaming Tables com ingestao via Auto Loader
- Silver: Streaming Tables com Expectations (DROP)
- Gold: Materialized Views com Expectations (FAIL)

Referencia KB: kb/lakeflow/index.md (Pattern 1: Medallion)
Referencia KB: kb/lakeflow/06-data-quality/expectations.md

CONSEQUENCIAS:
- Positivo: Framework declarativo reduz codigo boilerplate
- Positivo: Expectations nativas em cada camada
- Positivo: Orquestracao automatica de dependencias entre tabelas
- Positivo: Processamento incremental nativo (so processa novos dados)
- Negativo: Vendor lock-in com Databricks
- Negativo: Curva de aprendizado para equipe nova em DLT

ALTERNATIVAS CONSIDERADAS:
1. Spark Jobs manuais: Rejeitado - requer orquestracao manual,
   sem expectations nativas, mais codigo para manter
2. dbt + Spark: Rejeitado - nao suporta streaming nativo,
   expectations limitadas, camada adicional de complexidade
3. Azure Synapse Pipelines: Rejeitado - menor suporte nativo
   a Medallion, sem Unity Catalog, ecossistema Spark inferior

===================================================================
```

### ADR-002: Unity Catalog como Plataforma de Governanca

```
ADR-002: Unity Catalog para Governanca de Dados
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
O BRD exige seguranca e governanca de dados. A plataforma precisa
controlar acesso por perfil (diretoria, analistas, operacoes),
rastrear linhagem de dados, e proteger informacoes sensiveis.

DECISAO:
Unity Catalog como plataforma centralizada de governanca:

  Catalogo: retailmax_dev   (desenvolvimento)
  Catalogo: retailmax_hml   (homologacao)
  Catalogo: retailmax_prd   (producao)
    Schema: bronze
    Schema: silver
    Schema: gold

Implementar:
- RBAC com grants por grupo (diretoria, analistas, operacoes)
- Row Filters para restricao por territorio/regiao
- Column Masks para dados sensiveis (AccountNumber)
- Service Principals para execucao de pipelines
- Audit Logging para conformidade

Referencia KB: kb/lakeflow/08-operations/unity-catalog.md

CONSEQUENCIAS:
- Positivo: Governanca centralizada e consistente
- Positivo: Linhagem automatica (column-level lineage)
- Positivo: Row filters e column masks nativos
- Positivo: Separacao clara de ambientes via catalogos
- Negativo: Overhead inicial de configuracao de permissoes
- Negativo: JAR libraries nao suportadas em UC pipelines

ALTERNATIVAS CONSIDERADAS:
1. Hive Metastore: Rejeitado - sem RBAC granular, sem linhagem,
   sem row filters/column masks
2. Apache Ranger + Atlas: Rejeitado - complexidade operacional
   alta, nao integrado nativamente com Databricks

===================================================================
```

### ADR-003: ADF como Orquestrador Unico e Ingestao Metadata-Driven

```
ADR-003: ADF para Orquestracao e Ingestao Metadata-Driven
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
Os dados de origem estao em SQL Server (AdventureWorks).
Precisamos de um mecanismo confiavel para extrair dados e
orquestrar todo o pipeline end-to-end (ingestao + processamento).
O ambiente e novo (greenfield) e a solucao deve escalar para
novas tabelas sem alteracao de codigo.

DECISAO:
Azure Data Factory (ADF) como orquestrador unico:

1. Ingestao metadata-driven:
   - Tabela de parametros (ingestion_control) em Delta Lake
   - Lookup + ForEach para iterar tabelas dinamicamente
   - Full load e incremental (watermark) controlados por config
   - Adicionar nova tabela = INSERT na ingestion_control

2. Orquestracao do pipeline completo:
   - ADF inicia copia do SQL Server -> ADLS Gen2 (landing)
   - ADF trigger Databricks Job (DLT: Bronze -> Silver -> Gold)
   - ADF atualiza ingestion_control com status e metricas
   - Um unico ponto de monitoramento e scheduling

3. Linked Services:
   - SQL Server (via Self-Hosted IR ou Private Endpoint)
   - ADLS Gen2 (Managed Identity)
   - Databricks (via Linked Service com token/SPN)

CONSEQUENCIAS:
- Positivo: Ponto unico de orquestracao e monitoramento
- Positivo: Metadata-driven elimina code changes para novas tabelas
- Positivo: Conectores nativos para SQL Server e Databricks
- Positivo: Retry, alertas e logging nativos
- Positivo: Controle centralizado de schedule e dependencias
- Negativo: Custo adicional do ADF (Data Integration Units)
- Negativo: Latencia adicional no trigger ADF -> Databricks

ALTERNATIVAS CONSIDERADAS:
1. Databricks Workflows + ADF (dupla orquestracao):
   Rejeitado - dois pontos de controle, complexidade de debug,
   dificuldade de rastrear pipeline end-to-end
2. Apache Airflow: Rejeitado - requer infra propria (VM/AKS),
   maior complexidade operacional para o tamanho do projeto
3. JDBC direto no Spark: Rejeitado - coloca carga no SQL Server,
   sem retry nativo, sem monitoramento visual

===================================================================
```

### ADR-004: Star Schema como Modelo Dimensional

```
ADR-004: Star Schema para Camada Gold
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
O FRD especifica um modelo dimensional com fact_sales e dimensoes
(dim_customer, dim_product, dim_date). O modelo deve suportar
queries analiticas performaticas para Databricks Dashboards e KPIs.

DECISAO:
Star Schema na camada Gold:
- 1 Tabela Fato: fact_sales (grao: linha de pedido)
- 3 Dimensoes: dim_customer, dim_product, dim_date
- Materialized Views para KPIs pre-calculados
- Z-ORDER nas colunas mais filtradas (OrderDateKey, CustomerKey)

Regras de negocio conforme FRD:
- Receita = SUM(OrderQty * UnitPrice)
- Ticket Medio = Receita / COUNT(DISTINCT OrderID)
- Churn = LastPurchaseDate < CURRENT_DATE - 90 days
- Estoque Critico = Quantity < 10

CONSEQUENCIAS:
- Positivo: Performance otimizada para queries analiticas
- Positivo: Modelo familiar para analistas de BI
- Positivo: Excelente performance com Databricks SQL Endpoints
- Positivo: Compativel com Genie (NL-to-SQL sobre Star Schema)
- Negativo: Requer manutencao quando novas metricas surgem
- Negativo: Menos flexivel que Data Vault para multiplas fontes

ALTERNATIVAS CONSIDERADAS:
1. Data Vault 2.0: Rejeitado para esta fase - complexidade
   desnecessaria para volume e velocidade de mudanca atual.
   Considerar em fases futuras com multiplas fontes.
2. One Big Table (OBT): Rejeitado - dificil de manter,
   redundancia, problemas de performance em escala

===================================================================
```

### ADR-005: Databricks AI/BI (Dashboards + Genie) para Consumo Inicial

```
ADR-005: Databricks AI/BI Dashboards + Genie para Consumo
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
O BRD requer dashboards e acesso facilitado a dados para areas
de negocio. O ambiente e greenfield e precisamos minimizar
dependencias externas na fase inicial. Databricks AI/BI
Dashboards e Genie estao GA e integrados ao workspace.

DECISAO:
Usar Databricks nativamente para toda a camada de consumo:

1. Databricks AI/BI Dashboards:
   - 3 dashboards: Vendas, Clientes, Estoque
   - Conectados diretamente ao Gold layer via SQL Endpoints
   - Compartilhamento via workspace (sem licenca adicional)
   - Agendamento de refresh automatico

2. Databricks Genie (GenAI):
   - Genie Space vinculado as tabelas Gold
   - Instrucoes de contexto: glossario, KPIs, regras de negocio
   - Usuarios fazem perguntas em linguagem natural
   - Genie gera SQL e retorna resultados formatados
   - Permissoes respeitam Unity Catalog (Row Filters, RBAC)

CONSEQUENCIAS:
- Positivo: Zero infraestrutura adicional (tudo no Databricks)
- Positivo: Sem custo de licenca separado (incluso no workspace)
- Positivo: Genie usa NL-to-SQL com contexto do Unity Catalog
- Positivo: Permissoes de dados aplicadas automaticamente
- Positivo: Time-to-value rapido (sem integracao externa)
- Negativo: Dashboards menos sofisticados que Power BI
- Negativo: Genie depende de descricoes e instrucoes bem escritas
- Negativo: Limitado a usuarios com acesso ao workspace

EVOLUCAO FUTURA:
- Power BI pode ser adicionado quando houver necessidade de
  dashboards mais elaborados ou distribuicao para usuarios
  sem acesso ao workspace Databricks
- Dify pode complementar com chatflows customizados e
  integracao com canais externos (Slack, Teams, web)

ALTERNATIVAS CONSIDERADAS:
1. Power BI + Dify (plano v1.0): Rejeitado para fase inicial -
   Power BI requer licencas Pro/Premium, integracao adicional,
   e Dify requer infraestrutura separada. Ambos adicionam
   complexidade em um projeto greenfield.
2. Custom chatbot (LangChain): Rejeitado - maior esforco de
   desenvolvimento, sem UI pronta, mais manutencao

===================================================================
```

### ADR-006: Azure DevOps com Projetos Separados por Camada

```
ADR-006: Azure DevOps - 3 Projetos (IaC, ADF, Databricks)
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
O ambiente e greenfield e todo o ciclo de vida (infra, pipelines,
notebooks) precisa de CI/CD. Cada camada tem seu proprio ritmo
de deploy, equipe responsavel, e ferramentas especificas.

DECISAO:
3 projetos Azure DevOps separados, cada um com ambientes dev, hml e prd:

1. retailmax-iac (Terraform):
   - Terraform modules para todos os recursos Azure
   - CI: terraform validate + plan em PRs
   - CD: terraform apply (dev automatico, prd com approval gate)
   - State file: Azure Storage Account (backend remoto)

2. retailmax-adf (Data Factory):
   - ADF Git integration (dev = live mode com Git)
   - CI: validacao de ARM templates em PRs
   - CD: deploy parametrizado (dev -> prd)
   - ADF publish gera ARM, pipeline faz deploy

3. retailmax-databricks (Notebooks + App):
   - Databricks Asset Bundles ou Databricks CLI
   - CI: pytest + linting em PRs
   - CD: deploy de notebooks, DLT configs, e App
   - Repos separados: pipelines e app

Ambientes:
- dev: deploy automatico em merge para main
- hml: deploy automatico apos sucesso em dev (validacao com stakeholders)
- prd: release gate com aprovacao manual obrigatoria

CONSEQUENCIAS:
- Positivo: Isolamento de responsabilidades e permissoes
- Positivo: Cada camada tem CI/CD independente
- Positivo: prd protegido por approval gates
- Positivo: Equipes podem trabalhar em paralelo
- Negativo: Overhead de manter 3 projetos
- Negativo: Coordenacao entre projetos em releases grandes

ALTERNATIVAS CONSIDERADAS:
1. Monorepo unico: Rejeitado - acoplamento entre camadas,
   CI/CD lento, permissoes dificeis de segregar
2. GitHub Actions: Rejeitado - menor integracao nativa com
   Azure e Databricks, ADF Git integration favorece DevOps

===================================================================
```

### ADR-007: Tabela de Parametros Metadata-Driven

```
ADR-007: Tabela ingestion_control para Ingestao Dinamica
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
A plataforma inicia com 5 tabelas do AdventureWorks mas deve
escalar para novas tabelas sem alteracao de codigo nos pipelines.
O padrao metadata-driven e uma pratica consolidada em projetos
de Data Engineering com ADF.

DECISAO:
Tabela Delta Lake no Unity Catalog (retailmax.bronze.ingestion_control)
contendo metadados de todas as tabelas a serem ingeridas.

Campos principais:
- source_schema, source_table (origem)
- target_schema, target_table (destino)
- load_type: full ou incremental
- watermark_column: coluna para carga incremental
- last_watermark_value: ultimo valor processado
- primary_key: chave para deduplicacao
- is_active: flag para ativar/desativar
- schedule_frequency: daily, hourly, weekly
- last_load_status, last_load_timestamp, row_count_last_load

Fluxo ADF:
1. Lookup -> ingestion_control WHERE is_active = true
2. ForEach (tabela) -> Copy Activity parametrizado
3. Update -> last_watermark_value, status, timestamp

Para incluir nova tabela:
INSERT INTO ingestion_control VALUES (...)
-- Proximo run do pipeline ja processa a nova tabela

CONSEQUENCIAS:
- Positivo: Escala sem alteracao de pipeline
- Positivo: Visibilidade total de todas as cargas
- Positivo: Historico de execucoes na propria tabela
- Positivo: Facil de auditar e monitorar
- Positivo: Databricks App pode consultar para exibir status
- Negativo: Requer logica de update de watermark no ADF
- Negativo: Tabela pode crescer (resolver com particionamento)

ALTERNATIVAS CONSIDERADAS:
1. Pipeline por tabela (hardcoded): Rejeitado - nao escala,
   cada nova tabela requer novo pipeline ADF
2. Config em arquivo JSON/YAML: Rejeitado - menos auditavel,
   sem historico de execucoes, requer deploy para alterar

===================================================================
```

### ADR-008: Databricks App para Validacao de Master Data

```
ADR-008: Databricks App (Streamlit) para Master Data Validation
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
Dados mestres (Customer, Product) sao criticos para a qualidade
das analises. Registros com dados incompletos ou incorretos
impactam KPIs e dashboards. O negocio precisa de uma interface
para validar e monitorar a qualidade desses dados sem depender
da equipe tecnica.

DECISAO:
Databricks App usando Streamlit, hospedado no workspace:

Funcionalidades:
1. Visao geral de qualidade:
   - % completude por tabela e coluna
   - Total de registros com anomalias
   - Trend de qualidade ao longo do tempo

2. Registros anomalos:
   - Lista de registros flagados por expectations
   - Filtros por tabela, tipo de anomalia, data
   - Opcao de marcar como "validado" ou "requer correcao"

3. Historico de cargas:
   - Timeline de execucoes (da ingestion_control)
   - Volume processado por tabela
   - Status de cada execucao

4. Alertas de master data:
   - Novos clientes sem dados completos
   - Produtos sem categoria ou preco zerado

Stack:
- Streamlit (framework de UI)
- databricks-sql-connector (acesso a Delta tables)
- SSO via workspace (sem autenticacao separada)
- Deploy via Databricks Apps API + CI/CD

CONSEQUENCIAS:
- Positivo: Autonomia do negocio para validar dados
- Positivo: SSO sem gestao de credenciais separada
- Positivo: Deploy e hosting nativos no Databricks
- Positivo: Acesso direto a Delta tables (sem API intermediaria)
- Negativo: Databricks Apps ainda em evolucao
- Negativo: Streamlit limitado para UIs muito complexas

ALTERNATIVAS CONSIDERADAS:
1. Power Apps: Rejeitado - requer licenca adicional, integracao
   com Databricks via API customizada, mais complexo
2. App externo (Flask/FastAPI): Rejeitado - requer infra
   separada (App Service), autenticacao propria, mais manutencao
3. Notebook interativo: Rejeitado - UX ruim para usuarios de
   negocio, sem interface amigavel

===================================================================
```

---

## 6. Checklist de Qualidade Final

```
REQUISITOS
[x] Requisitos claramente entendidos (BRD + FRD analisados)
[x] Restricoes documentadas (sem ML, sem mudancas em sistemas fonte, batch)
[x] Criterios de sucesso definidos (50% reducao relatorios, adocao dashboards)
[x] Stakeholders identificados (Diretoria, Analistas, Operacoes/Comercial)

ARQUITETURA
[x] Componentes claramente definidos (7 componentes principais)
[x] Interfaces especificadas (SQL Server -> ADF -> ADLS -> DLT -> Gold -> Dashboards/Genie/App)
[x] Fluxo de dados documentado (Bronze -> Silver -> Gold -> Consumo)
[x] Decisoes tecnologicas validadas (KB + comparacao de alternativas)
[x] Infraestrutura greenfield detalhada (todos os recursos Azure)
[x] Tabela de parametros metadata-driven definida

DEVOPS / CI/CD
[x] Azure DevOps com 3 projetos (IaC, ADF, Databricks)
[x] Ambientes dev, hml e prd separados com approval gates
[x] IaC via Terraform (modulos, state, pipelines)
[x] CI/CD definido para cada camada

PLANEJAMENTO
[x] Fases definidas com dependencias (6 fases, 24 semanas)
[x] Timeline realista (Fase 1 expandida para greenfield, buffer na Fase 4)
[x] Caminho critico identificado (Fases 1-4)
[x] Marcos definidos (M1 a M6)

RISCO
[x] Riscos identificados (11 riscos mapeados)
[x] Impacto avaliado (matriz de risco completa)
[x] Estrategias de mitigacao definidas (para cada risco)
[x] Planos de contingencia prontos (5 cenarios)
[x] Riscos de greenfield e drift documentados

DOCUMENTACAO
[x] Decisoes documentadas (8 ADRs)
[x] Alternativas registradas (em cada ADR com racional)
[x] Racional explicado (com referencias KB)
[x] Proximos passos claros (roadmap + acoes imediatas)
```

---

## Proximos Passos

1. **Imediato:** Revisar este plano com stakeholders tecnicos e de negocio
2. **Semana 1:** Aprovar ADRs e criar Azure Subscription / Resource Groups
3. **Semana 1:** Configurar Azure DevOps Organization + 3 projetos
4. **Semana 1:** Definir equipe e atribuir responsabilidades por fase
5. **Semana 1-2:** Implementar Terraform modules e provisionar infra base
6. **Semana 3:** Configurar Workspace Databricks e Unity Catalog
7. **Semana 4:** Criar tabela ingestion_control e pipeline ADF master
8. **Continuo:** Usar Linear para tracking de issues e sprints (via agente `linear-project-manager`)

---

## Fontes e Referencias KB

| Arquivo | Conteudo Utilizado |
|---------|-------------------|
| `kb/lakeflow/index.md` | Medallion Architecture, patterns, best practices |
| `kb/lakeflow/01-core-concepts/concepts.md` | Flows, Streaming Tables, Materialized Views |
| `kb/lakeflow/04-features/cdc.md` | CDC com SCD Type 1/2, sequencing |
| `kb/lakeflow/06-data-quality/expectations.md` | WARN/DROP/FAIL, constraint patterns |
| `kb/lakeflow/08-operations/unity-catalog.md` | Governanca, RBAC, row filters, column masks |
| `kb/lakeflow/05-configuration/pipeline-configuration.md` | Serverless, Photon, editions |
| `kb/spark/01-performance-tuning.md` | AQE, partition optimization, Z-ORDER |
| `kb/spark/03-partitioning-shuffle.md` | Partitioning strategy, shuffle optimization |
| `kb/spark/05-best-practices.md` | DataFrame patterns, anti-patterns, testing |
| `document/brd-retail-max.md` | Requisitos de negocio |
| `document/frd-adventure-works.md` | Especificacao funcional |
