# Plano de Implementacao - Plataforma Analitica Lakehouse RetailMax

**Versao:** 1.0 | **Data:** 2026-03-28 | **Status:** Proposto

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
+-----------+     +--------------------+     +----------------+
|  FONTES   |     |   AZURE DATABRICKS |     |    CONSUMO     |
|           |     |   (LAKEHOUSE)      |     |                |
| SQL Server| --> | Bronze --> Silver   | --> | Power BI       |
| (Advent.  |     |   --> Gold          |     | Dashboards     |
| Works)    |     |                    |     |                |
|           |     | Unity Catalog      |     | Dify AI        |
|           |     | Lakeflow Pipelines |     | (chatflows)    |
+-----------+     +--------------------+     +----------------+
      |                     |                        |
 Azure Data           Delta Lake               APIs REST
 Factory              Spark/PySpark            SQL Endpoints
                      Photon
```

### 1.2 Componentes Principais

```
+-------------------------------------------------------------------+
|  COMPONENTE 1: Camada de Ingestao (Bronze)                        |
|  Proposito: Ingestao bruta do SQL Server para Delta Lake          |
|  Tecnologia: Azure Data Factory + Lakeflow Auto Loader            |
|  Interfaces: SQL Server (origem) -> ADLS Gen2 (destino)           |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 2: Camada de Transformacao (Silver)                   |
|  Proposito: Limpeza, deduplicacao, padronizacao, validacao        |
|  Tecnologia: Lakeflow Declarative Pipelines (DLT) + PySpark      |
|  Interfaces: Bronze tables -> Silver tables (Delta Lake)          |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 3: Camada Analitica (Gold)                            |
|  Proposito: Modelo dimensional Star Schema + KPIs                 |
|  Tecnologia: Lakeflow DLT + Materialized Views + SQL              |
|  Interfaces: Silver tables -> Gold tables (fact/dim)              |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 4: Governanca e Seguranca                             |
|  Proposito: Controle de acesso, linhagem, auditoria               |
|  Tecnologia: Unity Catalog + Row Filters + Column Masks           |
|  Interfaces: Transversal a todas as camadas                       |
+-------------------------------------------------------------------+

+-------------------------------------------------------------------+
|  COMPONENTE 5: Consumo e Visualizacao                             |
|  Proposito: Dashboards, relatorios, APIs, IA conversacional       |
|  Tecnologia: Databricks SQL Endpoints + Power BI + Dify           |
|  Interfaces: Gold tables -> Dashboards / APIs                     |
+-------------------------------------------------------------------+
```

### 1.3 Fluxo de Dados Detalhado

```
[SQL Server - AdventureWorks]
  |
  | (1) Azure Data Factory - Copy Activity
  |     Full Load (inicial) + Incremental (watermark/CDC)
  v
[ADLS Gen2 - Landing Zone]  (formato Parquet)
  |
  | (2) Lakeflow Auto Loader - cloudFiles
  |     Deteccao automatica de novos arquivos
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
  |-- Databricks SQL Endpoints -> Power BI (DirectQuery/Import)
  |-- Databricks SQL Endpoints -> Dify AI (consultas via API)
  |-- REST APIs -> Aplicacoes internas
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
| **Ingestao** | Azure Data Factory | JDBC direto / Airbyte | ADF tem conectores nativos SQL Server, monitoramento visual, retry automatico, integracao nativa com Azure |
| **Processamento** | Lakeflow DLT (Python) | Spark Jobs manuais / dbt | DLT e declarativo, gerencia dependencias, expectations nativas. Validado: `kb/lakeflow/01-core-concepts/concepts.md` |
| **Storage** | Delta Lake (ADLS Gen2) | Parquet puro | Delta oferece ACID, time travel, schema evolution, Z-ORDER. Validado: `kb/spark/01-performance-tuning.md` |
| **Governanca** | Unity Catalog | Hive Metastore / Ranger | UC oferece linhagem, row filters, column masks, RBAC. Validado: `kb/lakeflow/08-operations/unity-catalog.md` |
| **Qualidade** | DLT Expectations | Great Expectations | Nativo ao DLT, politicas WARN/DROP/FAIL por camada. Validado: `kb/lakeflow/06-data-quality/expectations.md` |
| **Compute** | Serverless + Photon | Classic Clusters | Elimina gerenciamento, Photon acelera queries SQL. Validado: `kb/lakeflow/05-configuration/pipeline-configuration.md` |
| **Dashboards** | Power BI + SQL Endpoints | Tableau / Looker | Integracao nativa com Azure e Databricks, ferramenta comum no ecossistema Microsoft |
| **IA Conversacional** | Dify | Custom LangChain / Genie | Dify oferece chatflows no-code, RAG nativo, API REST. Validado: `kb/dify/` |
| **Orquestracao** | Databricks Workflows + ADF | Apache Airflow | Integracao nativa com Lakeflow, menor complexidade operacional |

### 2.3 Validacao via Knowledge Base

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
ROADMAP DE IMPLEMENTACAO
===================================================================

FASE 1: Fundacao e Infraestrutura (Semanas 1-3)
|
|-- Duracao: 3 semanas
|-- Objetivos:
|   |-- Provisionar infraestrutura Azure + Databricks
|   |-- Configurar Unity Catalog e governanca base
|   |-- Estabelecer padroes de desenvolvimento
|-- Entregaveis:
|   |-- Workspace Databricks (Dev / Staging / Prod)
|   |-- Unity Catalog: catalogo "retailmax" com schemas bronze/silver/gold
|   |-- Service principals configurados
|   |-- ADLS Gen2 com containers (landing/raw/processed)
|   |-- Template de pipeline DLT validado ("hello world")
|   |-- Repositorio Git com estrutura e CI/CD basico
|-- Dependencias: Acesso Azure, credenciais SQL Server, budget aprovado
|-- Criterios de Sucesso:
|   |-- Pipeline DLT de teste executando com sucesso
|   |-- Unity Catalog acessivel com permissoes configuradas
|   |-- Ambientes Dev e Staging operacionais

FASE 2: Ingestao e Camada Bronze (Semanas 4-6)
|
|-- Duracao: 3 semanas
|-- Dependencias: Fase 1 completa
|-- Objetivos:
|   |-- Implementar ingestao do SQL Server via ADF
|   |-- Criar Streaming Tables Bronze para todas as tabelas
|   |-- Configurar Expectations de monitoramento (WARN)
|-- Entregaveis:
|   |-- Pipeline ADF: carga full + incremental (5 tabelas)
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

FASE 3: Transformacao e Camada Silver (Semanas 7-9)
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

FASE 4: Modelo Dimensional e Camada Gold (Semanas 10-13)
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

FASE 5: Consumo, Dashboards e IA (Semanas 14-17)
|
|-- Duracao: 4 semanas
|-- Dependencias: Fase 4 completa
|-- Objetivos:
|   |-- Configurar Databricks SQL Endpoints (serverless)
|   |-- Criar dashboards Power BI
|   |-- Implementar chatflow Dify para consultas IA
|-- Entregaveis:
|   |-- SQL Endpoint serverless configurado
|   |-- 3 Dashboards Power BI:
|   |   |-- Vendas (receita, ticket medio, tendencias)
|   |   |-- Clientes (churn, segmentacao, comportamento)
|   |   |-- Estoque (niveis, alertas, reposicao)
|   |-- Chatflow Dify para linguagem natural:
|   |   |-- "Qual a receita do ultimo mes?"
|   |   |-- "Quais produtos com estoque critico?"
|   |   |-- "Qual o ticket medio por canal?"
|   |-- Row Filters e Column Masks para dados sensiveis
|   |-- Documentacao de uso para areas de negocio
|-- Criterios de Sucesso:
|   |-- Dashboards carregando em < 5 segundos
|   |-- Chatflow com precisao > 90% nas respostas
|   |-- Usuarios de negocio treinados

FASE 6: Operacoes, Otimizacao e Go-Live (Semanas 18-20)
|
|-- Duracao: 3 semanas
|-- Dependencias: Fase 5 completa
|-- Objetivos:
|   |-- Otimizar performance dos pipelines
|   |-- Configurar monitoramento e alertas
|   |-- Executar go-live em producao
|-- Entregaveis:
|   |-- Pipeline otimizado:
|   |   |-- Photon habilitado
|   |   |-- Autoscaling configurado (Enhanced)
|   |   |-- AQE otimizado (ref: kb/spark/01-performance-tuning.md)
|   |-- Monitoramento:
|   |   |-- Alertas de falha (email + Slack)
|   |   |-- Dashboard operacional de pipelines
|   |   |-- Metricas de qualidade de dados
|   |-- Documentacao operacional:
|   |   |-- Runbook de operacoes
|   |   |-- Guia de troubleshooting
|   |   |-- Procedimentos de recuperacao
|   |-- Treinamento de usuarios finais
|-- Criterios de Sucesso:
|   |-- Pipeline em producao por 2 semanas sem falhas
|   |-- Refresh end-to-end < 1 hora
|   |-- Reducao de 50% no tempo de relatorios (meta BRD)

===================================================================
```

### 3.1 Visualizacao do Timeline

```
     Fase 1     Fase 2     Fase 3     Fase 4       Fase 5       Fase 6
    |---------|---------|---------|-----------|-----------|---------|
    S1-S3      S4-S6      S7-S9     S10-S13     S14-S17     S18-S20

    [Fundacao] [Ingestao] [Silver]   [Gold]    [Consumo]    [Ops]
     Infra      Bronze     Limpeza   Star       Power BI    Go-Live
     Unity Cat  ADF+DLT    DQ DROP   Schema     Dify AI     Monitor
     Git/CI                          DQ FAIL    Seguranca   Tuning
```

### 3.2 Caminho Critico

```
Fase 1 --> Fase 2 --> Fase 3 --> Fase 4  (CAMINHO CRITICO)
                                   |
                                   +--> Fase 5 --+
                                   |             |--> Go-Live (S20)
                                   +--> Fase 6 --+
```

Qualquer atraso nas Fases 1 a 4 impacta diretamente o go-live. Fases 5 e 6 possuem alguma flexibilidade (dashboards podem ser entregues de forma iterativa).

### 3.3 Marcos (Milestones)

| Marco | Semana | Entregavel |
|-------|--------|------------|
| M1 - Infra Ready | S3 | Workspace + Unity Catalog operacionais |
| M2 - Data Landing | S6 | Dados do SQL Server no Bronze |
| M3 - Clean Data | S9 | Silver layer com qualidade validada |
| M4 - Analytics Ready | S13 | Star Schema + KPIs calculados |
| M5 - User Access | S17 | Dashboards + IA disponiveis |
| M6 - Go-Live | S20 | Producao operacional |

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
|---|------------------------------|---------|--------|-------------------------------|
| 2 | Baixa adocao pelos usuarios  | ALTO    | MEDIO  | Treinamento na Fase 6.        |
|   |                              |         |        | Chatflow Dify para acesso     |
|   |                              |         |        | simplificado. Dashboards      |
|   |                              |         |        | validados com stakeholders.   |
|---|------------------------------|---------|--------|-------------------------------|
| 3 | Custos Azure acima do        | MEDIO   | MEDIO  | Serverless (pay-per-use).     |
|   | orcamento                    |         |        | Autoscaling com limites max.  |
|   |                              |         |        | Triggered mode (nao           |
|   |                              |         |        | continuous). Cluster tags.    |
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
|   |                              |         |        | Service principals. Audit log.|
|---|------------------------------|---------|--------|-------------------------------|
| 7 | Mudancas de schema na        | MEDIO   | MEDIO  | Delta Lake schema evolution.  |
|   | origem (SQL Server)          |         |        | Schema enforcement no Silver. |
|   |                              |         |        | Alertas de mudanca de schema. |
|---|------------------------------|---------|--------|-------------------------------|
| 8 | Indisponibilidade do SQL     | BAIXO   | BAIXO  | ADF com retry automatico.     |
|   | Server durante ingestao      |         |        | Janela de ingestao noturna.   |
|---|------------------------------|---------|--------|-------------------------------|
| 9 | Complexidade na integracao   | MEDIO   | MEDIO  | Comecar com DirectQuery.      |
|   | Power BI + Databricks        |         |        | SQL Endpoints serverless para |
|   |                              |         |        | concorrencia. Import se nec.  |
|---|------------------------------|---------|--------|-------------------------------|
|10 | Falta de conhecimento da     | MEDIO   | MEDIO  | KB do projeto como base.      |
|   | equipe com Lakeflow/DLT      |         |        | Capacitacao na Fase 1.        |
|   |                              |         |        | Templates prontos de pipeline.|

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
              |               | R9 (PowerBI)  |                |
              |               | R10 (Conhec.) |                |
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

### 4.3 Planos de Contingencia

| Gatilho | Resposta |
|---------|----------|
| R1: Mais de 20% de registros invalidos | Pausar pipeline, remediar na fonte, ajustar expectations |
| R2: Adocao < 30% em 30 dias pos go-live | Sprint dedicado de UX com usuarios, simplificar dashboards |
| R5: Atraso > 2 semanas no caminho critico | Reduzir escopo Gold para MVP (fact_sales + 2 KPIs), dashboards simplificados |
| R3: Custo > 150% do budget | Migrar para triggered com menor frequencia, desligar Photon temporariamente |

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

  Catalogo: retailmax_prod   (producao)
  Catalogo: retailmax_dev    (desenvolvimento)
  Catalogo: retailmax_stg    (staging)
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

### ADR-003: Azure Data Factory para Ingestao do SQL Server

```
ADR-003: Azure Data Factory para Ingestao
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
Os dados de origem estao em SQL Server (AdventureWorks).
Precisamos de um mecanismo confiavel para extrair dados batch
e depositar na landing zone do ADLS Gen2, de onde o Auto Loader
do Lakeflow ira consumir.

DECISAO:
Azure Data Factory (ADF) para ingestao:
- Copy Activity para carga full inicial (5 tabelas)
- Change Tracking ou Watermark para cargas incrementais
- Linked Service com Managed Identity para SQL Server
- Destino: ADLS Gen2 em formato Parquet (landing zone)
- Schedule: diario, janela noturna (02h-05h)

CONSEQUENCIAS:
- Positivo: Conectores nativos para SQL Server
- Positivo: Monitoramento visual e retry automatico
- Positivo: Integracao nativa Azure (RBAC, Key Vault, Monitor)
- Negativo: Custo adicional do ADF (Data Integration Units)
- Negativo: Duas ferramentas de orquestracao (ADF + Lakeflow)

ALTERNATIVAS CONSIDERADAS:
1. JDBC direto no Spark: Rejeitado - coloca carga no SQL Server,
   sem retry nativo, sem monitoramento visual
2. Airbyte: Rejeitado - camada adicional de infra, custo,
   menor integracao com Azure
3. Fivetran: Rejeitado - custo por conector, vendor lock-in
   adicional, overhead de gerenciamento

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
queries analiticas performaticas para Power BI e KPIs.

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
- Positivo: Excelente performance com DirectQuery no Power BI
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

### ADR-005: Dify como Plataforma de IA Conversacional

```
ADR-005: Dify para Interface de IA Conversacional
===================================================================

STATUS: [x] Proposto  [ ] Aceito  [ ] Depreciado  [ ] Substituido

CONTEXTO:
O BRD menciona facilitar o acesso a dados para areas de negocio.
Uma interface conversacional permite que usuarios nao-tecnicos
facam perguntas sobre dados em linguagem natural, reduzindo
dependencia de analistas para queries simples.

DECISAO:
Chatflow no Dify conectado ao Databricks SQL Endpoint:
- LLM para interpretar perguntas em linguagem natural
- Conversao para SQL queries executadas no Gold layer
- Respostas formatadas com dados e visualizacoes
- RAG com Knowledge Base contendo dicionario de dados e glossario

Referencia KB: kb/dify/01-chatflow-development.md

CONSEQUENCIAS:
- Positivo: Acesso democratizado aos dados
- Positivo: Reduz dependencia de analistas para queries ad-hoc
- Positivo: Plataforma no-code para customizacao
- Positivo: API REST para integracao com outros sistemas
- Negativo: Precisao depende da qualidade do prompt engineering
- Negativo: Custo de tokens LLM para cada interacao
- Negativo: Necessidade de guardrails contra SQL injection/queries pesadas

ALTERNATIVAS CONSIDERADAS:
1. Databricks Genie: Rejeitado - ainda em preview, menos
   customizavel, sem workflow capabilities
2. Custom chatbot (LangChain): Rejeitado - maior esforco de
   desenvolvimento, sem UI pronta, mais manutencao

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
[x] Componentes claramente definidos (5 componentes principais)
[x] Interfaces especificadas (SQL Server -> ADF -> ADLS -> DLT -> Gold -> BI)
[x] Fluxo de dados documentado (Bronze -> Silver -> Gold -> Consumo)
[x] Decisoes tecnologicas validadas (KB + comparacao de alternativas)

PLANEJAMENTO
[x] Fases definidas com dependencias (6 fases, 20 semanas)
[x] Timeline realista (buffer na Fase 4, dashboards iterativos)
[x] Caminho critico identificado (Fases 1-4)
[x] Marcos definidos (M1 a M6)

RISCO
[x] Riscos identificados (10 riscos mapeados)
[x] Impacto avaliado (matriz de risco completa)
[x] Estrategias de mitigacao definidas (para cada risco)
[x] Planos de contingencia prontos (4 cenarios)

DOCUMENTACAO
[x] Decisoes documentadas (5 ADRs)
[x] Alternativas registradas (em cada ADR com racional)
[x] Racional explicado (com referencias KB)
[x] Proximos passos claros (roadmap + acoes imediatas)
```

---

## Proximos Passos

1. **Imediato:** Revisar este plano com stakeholders tecnicos e de negocio
2. **Semana 1:** Aprovar ADRs e iniciar provisionamento de recursos Azure
3. **Semana 1:** Definir equipe e atribuir responsabilidades por fase
4. **Semana 2:** Configurar Workspace Databricks e Unity Catalog
5. **Continuo:** Usar Linear para tracking de issues e sprints (via agente `linear-project-manager`)

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
