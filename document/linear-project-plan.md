# Plano de Gerenciamento de Projeto Linear
## RetailMax Lakehouse Analytics

**Versao:** 1.0 | **Data:** 2026-03-28 | **Status:** Planejado

---

```
================================================================
TASK: Plano Completo de Gerenciamento de Projeto Linear
       - RetailMax Lakehouse Analytics
TYPE: [X] Project Setup  [X] Sprint Planning  [X] Issue Mgmt
SCOPE: [X] Project
THRESHOLD: 0.85
FINAL SCORE: 0.80 (ADVISORY)
================================================================
```

---

## 1. Project Setup -- Configuracao do Projeto

```
PROJECT SETUP
===============================================================

PROJETO: RetailMax Lakehouse Analytics
TEAM: Data Engineering
LEAD: (a definir)
DATA INICIO: 07/04/2026 (Segunda-feira)
DATA ALVO: 26/06/2026 (Sexta-feira) -- 12 semanas
DURACAO: 6 Sprints de 2 semanas

DESCRICAO:
Plataforma analitica moderna baseada em Data Lakehouse
(arquitetura Medallion) para suportar decisoes estrategicas
e operacionais da RetailMax, utilizando Azure, Databricks,
Spark e Delta Lake.

STAKEHOLDERS:
+-- Diretoria Executiva (sponsor)
+-- Analistas de Negocio (usuarios finais)
+-- Operacoes e Comercial (consumidores de dashboards)
+-- Time de Data Engineering (executores)

===============================================================
```

---

## 2. Milestones -- Marcos do Projeto

```
ROADMAP
===============================================================

TRIMESTRE: Q2 2026
TEMA: Plataforma Analitica Lakehouse -- MVP a Producao

MILESTONES
----------

M1: Fundacao e Infraestrutura
+-- Target Date: 01/05/2026 (fim Sprint 2)
+-- Buffer: 3 dias uteis
+-- Dependencies: Acesso ao Azure, Databricks workspace
+-- Key Deliverables:
|   +-- Workspace Databricks configurado
|   +-- Pipelines de ingestao Bronze funcionais
|   +-- Unity Catalog configurado com schemas
+-- Success Criteria:
|   +-- Dados brutos do AdventureWorks disponiveis na camada Bronze
|   +-- Pipeline de ingestao executando sem erros
|   +-- Governanca basica (catalogo, schemas, permissoes)
+-- Risk Level: [X] Medium
+-- Definition of Done:
    - [ ] Workspace Databricks provisionado e acessivel
    - [ ] Unity Catalog com catalog/schema criados
    - [ ] Pipeline Bronze ingerindo 5 tabelas principais
    - [ ] Testes de conectividade com SQL Server validados
    - [ ] Documentacao de arquitetura atualizada
    - [ ] Code review aprovado para todos os notebooks

M2: Transformacao e Modelo Dimensional
+-- Target Date: 29/05/2026 (fim Sprint 4)
+-- Buffer: 3 dias uteis
+-- Dependencies: M1 concluido, regras de negocio validadas
+-- Key Deliverables:
|   +-- Camada Silver com dados limpos e padronizados
|   +-- Modelo dimensional Gold (Star Schema)
|   +-- Regras de qualidade de dados implementadas
+-- Success Criteria:
|   +-- fact_sales e dimensoes (customer, product, date) populadas
|   +-- Regras de negocio (receita, ticket medio, churn) implementadas
|   +-- Expectations de qualidade com taxa de aprovacao > 95%
+-- Risk Level: [X] Medium
+-- Definition of Done:
    - [ ] Pipeline Silver processando deduplicacao e limpeza
    - [ ] Pipeline Gold gerando Star Schema completo
    - [ ] Expectations de qualidade ativas (nulos, chaves, integridade)
    - [ ] Regras de negocio validadas com stakeholders
    - [ ] Testes unitarios para transformacoes criticas
    - [ ] Performance < 15min para pipeline completo

M3: Dashboards, Validacao e Go-Live
+-- Target Date: 26/06/2026 (fim Sprint 6)
+-- Buffer: 5 dias uteis
+-- Dependencies: M2 concluido, acesso BI configurado
+-- Key Deliverables:
|   +-- Dashboards de vendas, clientes e estoque
|   +-- Documentacao e treinamento de usuarios
|   +-- Monitoramento e alertas em producao
+-- Success Criteria:
|   +-- Reducao de 50% no tempo de geracao de relatorios
|   +-- Stakeholders validaram dashboards e KPIs
|   +-- Pipeline em producao com monitoramento ativo
+-- Risk Level: [X] High
+-- Definition of Done:
    - [ ] Dashboard de vendas por canal publicado
    - [ ] Dashboard de clientes (churn) publicado
    - [ ] Dashboard de estoque critico publicado
    - [ ] Treinamento realizado com analistas de negocio
    - [ ] Monitoramento de pipeline configurado (alertas)
    - [ ] Runbook operacional documentado
    - [ ] Aprovacao formal dos stakeholders

TIMELINE
--------
     M1                M2                M3
    |-----------|------------|------------|--BB|
    Sprint 1-2   Sprint 3-4   Sprint 5-6  Buffer
    Fundacao     Transformacao Dashboards
    07/04-01/05  05/05-29/05  01/06-26/06

===============================================================
```

---

## 3. Workflow States -- Estados do Fluxo

```
WORKFLOW AUTOMATION
===============================================================

1. STATUS TRANSITIONS

   +----------+     +----------+     +----------+
   |  Triage  |---->| Backlog  |---->|   Todo   |
   +----------+     +----------+     +----------+
                                          |
                                          v
   +----------+     +----------+     +----------+
   |   Done   |<----|In Review |<----|In Progress|
   +----------+     +----------+     +----------+
                         |                |
                         v                v
                    +----------+     +----------+
                    | Revisao  |     | Blocked  |
                    |Solicitada|     +----------+
                    +----------+

2. REGRAS DE TRANSICAO
   +-- Triage -> Backlog: Issue com descricao e acceptance criteria
   +-- Backlog -> Todo: Priorizada e estimada
   +-- Todo -> In Progress: Assignee definido, sprint ativo
   +-- In Progress -> In Review: PR aberto ou notebook pronto
   +-- In Review -> Done: Review aprovado, testes passando
   +-- In Progress -> Blocked: Dependencia externa, documentar motivo
   +-- Blocked -> In Progress: Bloqueio resolvido

3. AUTO-ASSIGNMENT RULES
   +-- Issue criada (type=bug) -> Assign ao engenheiro de plantao
   +-- Issue criada (component=bronze) -> Assign ao engenheiro de dados
   +-- Issue criada (component=gold) -> Assign ao analista de dados
   +-- PR linkado -> Mover para In Review
   +-- PR merged -> Mover para Done

4. SLA TRACKING
   | Prioridade | 1a Resposta | Resolucao    | Escalacao        |
   |------------|-------------|--------------|------------------|
   | P0         | 15 min      | 4 horas      | Imediato ao lead |
   | P1         | 1 hora      | 1 dia        | Apos 4 horas     |
   | P2         | 4 horas     | 1 semana     | Apos 2 dias      |
   | P3         | 1 dia       | 1 sprint     | Apos 1 semana    |
   | P4         | Best effort | Best effort  | Nenhuma          |

5. NOTIFICATION RULES
   +-- P0/P1 criado -> Slack #data-incidents
   +-- Issue Blocked > 24h -> Notificar assignee + lead
   +-- Sprint Goal em risco -> Notificar team lead
   +-- Milestone atrasado -> Notificar lead + stakeholders

===============================================================
```

---

## 4. Label Taxonomy -- Taxonomia de Labels

```
LABEL STRUCTURE -- RetailMax Lakehouse
===============================================================

TIPO (obrigatorio)
+-- feature        -- Nova funcionalidade
+-- bug            -- Algo nao esta funcionando
+-- improvement    -- Melhoria em funcionalidade existente
+-- tech-debt      -- Refatoracao, manutencao de codigo
+-- spike          -- Investigacao tecnica / prova de conceito
+-- documentation  -- Documentacao tecnica ou de usuario

CAMADA (obrigatorio -- especifico Lakehouse)
+-- bronze         -- Ingestao de dados brutos
+-- silver         -- Limpeza e padronizacao
+-- gold           -- Modelo dimensional e agregacoes
+-- infra          -- Infraestrutura, Databricks, Azure
+-- bi             -- Dashboards, relatorios, visualizacao
+-- governance     -- Catalogo, permissoes, qualidade

COMPONENTE (obrigatorio)
+-- pipeline       -- Lakeflow / DLT pipelines
+-- notebook       -- Databricks notebooks
+-- sql            -- Queries e stored procedures
+-- dashboard      -- Dashboards e visualizacoes
+-- config         -- Configuracoes e parametros
+-- test           -- Testes e validacoes

DOMINIO DE DADOS (recomendado)
+-- vendas         -- SalesOrderHeader, SalesOrderDetail
+-- clientes       -- Customer, CustomerAddress
+-- produtos       -- Product, ProductCategory
+-- estoque        -- ProductInventory
+-- data-tempo     -- Dimensao de data/calendario

STATUS (conforme necessario)
+-- needs-design   -- Precisa de design antes da implementacao
+-- needs-review   -- Pronto para code review
+-- blocked        -- Nao pode prosseguir (documentar motivo)
+-- ready          -- Totalmente especificado, pronto

SIZE (obrigatorio para sprint planning)
+-- XS (1 pt)      -- < 2 horas
+-- S  (2 pts)     -- 2-4 horas
+-- M  (3 pts)     -- 0.5-1 dia
+-- L  (5 pts)     -- 1-2 dias
+-- XL (8+ pts)    -- 3+ dias (considerar quebrar)

===============================================================
```

---

## 5. Backlog Completo de Issues

### P1 -- Urgente (Fundacao critica)

#### Issue #001: [FEAT] Provisionar Workspace Databricks no Azure

```
## Summary
Criar e configurar o workspace Databricks no Azure com
networking, identidade e parametros de seguranca.

## Context
Prerequisito para todo o projeto. Sem o workspace, nenhuma
pipeline pode ser desenvolvida.

## Acceptance Criteria
- [ ] Workspace Databricks criado no Azure (Premium tier)
- [ ] VNet injection configurada
- [ ] Service Principal criado com permissoes adequadas
- [ ] Cluster policy definida (controle de custos)
- [ ] Acesso validado por pelo menos 2 membros do time

## Technical Notes
- Azure Region: Brazil South (ou East US 2 para custo)
- SKU: Premium (requerido para Unity Catalog)
- Terraform/Bicep para IaC

## Priority: P1 | Size: L (5 pts) | Milestone: M1
## Labels: feature, infra, config
```

#### Issue #002: [FEAT] Configurar Unity Catalog com Schemas Medallion

```
## Summary
Criar catalogo, schemas (bronze, silver, gold) e permissoes
no Unity Catalog do Databricks.

## Acceptance Criteria
- [ ] Catalog "retailmax" criado no Unity Catalog
- [ ] Schema "bronze" criado com permissoes de escrita para pipelines
- [ ] Schema "silver" criado com permissoes adequadas
- [ ] Schema "gold" criado com acesso de leitura para analistas
- [ ] External locations configuradas para storage
- [ ] Linhagem de dados visivel no Catalog Explorer

## Priority: P1 | Size: M (3 pts) | Milestone: M1
## Labels: feature, governance, config
```

#### Issue #003: [FEAT] Pipeline Bronze -- Ingestao SalesOrderHeader

```
## Summary
Criar pipeline Lakeflow (DLT) para ingestao incremental
da tabela SalesOrderHeader do SQL Server.

## Acceptance Criteria
- [ ] Pipeline DLT criado com Auto Loader ou JDBC
- [ ] Dados ingeridos na tabela bronze.sales_order_header
- [ ] Schema evolution habilitado
- [ ] Metadados de ingestao adicionados (_ingestion_timestamp, _source_file)
- [ ] Pipeline executando em modo triggered sem erros
- [ ] Pelo menos 1 expectation de qualidade (ex: OrderDate NOT NULL)

## Priority: P1 | Size: M (3 pts) | Milestone: M1
## Labels: feature, bronze, pipeline, vendas
```

#### Issue #004: [FEAT] Pipeline Bronze -- Ingestao SalesOrderDetail

```
## Summary
Criar pipeline Lakeflow para ingestao incremental da tabela
SalesOrderDetail do SQL Server.

## Acceptance Criteria
- [ ] Pipeline DLT criado para SalesOrderDetail
- [ ] Dados ingeridos na tabela bronze.sales_order_detail
- [ ] Join key (SalesOrderID) validada via expectation
- [ ] Schema evolution habilitado
- [ ] Metadados de ingestao adicionados

## Priority: P1 | Size: M (3 pts) | Milestone: M1
## Labels: feature, bronze, pipeline, vendas
```

#### Issue #005: [FEAT] Pipeline Bronze -- Ingestao Customer

```
## Summary
Criar pipeline Lakeflow para ingestao da tabela Customer.

## Acceptance Criteria
- [ ] Pipeline DLT para Customer criado
- [ ] Dados na tabela bronze.customer
- [ ] CustomerID validado como NOT NULL e UNIQUE (expectation)
- [ ] AccountNumber preservado

## Priority: P1 | Size: S (2 pts) | Milestone: M1
## Labels: feature, bronze, pipeline, clientes
```

#### Issue #006: [FEAT] Pipeline Bronze -- Ingestao Product

```
## Summary
Criar pipeline Lakeflow para ingestao da tabela Product.

## Acceptance Criteria
- [ ] Pipeline DLT para Product criado
- [ ] Dados na tabela bronze.product
- [ ] ProductID validado como NOT NULL e UNIQUE
- [ ] ListPrice preservado para calculos de margem

## Priority: P1 | Size: S (2 pts) | Milestone: M1
## Labels: feature, bronze, pipeline, produtos
```

#### Issue #007: [FEAT] Pipeline Bronze -- Ingestao ProductInventory

```
## Summary
Criar pipeline Lakeflow para ingestao da tabela ProductInventory.

## Acceptance Criteria
- [ ] Pipeline DLT para ProductInventory criado
- [ ] Dados na tabela bronze.product_inventory
- [ ] Quantity validado como >= 0 (expectation)
- [ ] ProductID referencia validada

## Priority: P1 | Size: S (2 pts) | Milestone: M1
## Labels: feature, bronze, pipeline, estoque
```

---

### P2 -- Alto (Transformacao e Modelo)

#### Issue #008: [FEAT] Pipeline Silver -- Limpeza e Padronizacao de Vendas

```
## Summary
Criar transformacoes Silver para SalesOrderHeader e
SalesOrderDetail com deduplicacao, tratamento de nulos
e conversao de tipos.

## Acceptance Criteria
- [ ] Deduplicacao por chave primaria implementada
- [ ] Campos de data convertidos para DateType
- [ ] Nulos tratados conforme regra de negocio
- [ ] Tabelas silver.sales_order_header e silver.sales_order_detail criadas
- [ ] Expectations: < 1% de registros rejeitados
- [ ] Testes de integridade referencial entre header e detail

## Priority: P2 | Size: L (5 pts) | Milestone: M2
## Labels: feature, silver, pipeline, vendas
```

#### Issue #009: [FEAT] Pipeline Silver -- Limpeza Customer e Product

```
## Summary
Criar transformacoes Silver para Customer, Product e ProductInventory.

## Acceptance Criteria
- [ ] silver.customer com dados limpos e deduplicados
- [ ] silver.product com ListPrice padronizado (DecimalType)
- [ ] silver.product_inventory com Quantity validado
- [ ] Todos os IDs validados como NOT NULL
- [ ] Nomes padronizados (trim, case normalization)

## Priority: P2 | Size: M (3 pts) | Milestone: M2
## Labels: feature, silver, pipeline, clientes, produtos, estoque
```

#### Issue #010: [FEAT] Modelo Dimensional Gold -- fact_sales

```
## Summary
Criar a tabela fato fact_sales no schema Gold com metricas
de receita, quantidade e ticket medio.

## Acceptance Criteria
- [ ] Tabela gold.fact_sales criada com Star Schema
- [ ] Coluna receita = OrderQty * UnitPrice
- [ ] Coluna ticket_medio calculavel (receita / contagem de pedidos)
- [ ] Foreign keys para dim_customer, dim_product, dim_date
- [ ] Particionamento por OrderDate (ano/mes)
- [ ] Delta Lake com Z-Ordering em CustomerID e ProductID

## Priority: P2 | Size: L (5 pts) | Milestone: M2
## Labels: feature, gold, pipeline, vendas
```

#### Issue #011: [FEAT] Modelo Dimensional Gold -- dim_customer

```
## Summary
Criar dimensao de clientes com atributos analiticos e flag de churn.

## Acceptance Criteria
- [ ] Tabela gold.dim_customer criada (SCD Type 1)
- [ ] Flag is_churned calculada (ultima compra > 90 dias)
- [ ] Data da ultima compra (last_purchase_date)
- [ ] Total de compras e receita total por cliente
- [ ] Surrogate key (customer_sk) implementada

## Priority: P2 | Size: M (3 pts) | Milestone: M2
## Labels: feature, gold, pipeline, clientes
```

#### Issue #012: [FEAT] Modelo Dimensional Gold -- dim_product

```
## Summary
Criar dimensao de produtos com categorias e metricas de estoque.

## Acceptance Criteria
- [ ] Tabela gold.dim_product criada
- [ ] ListPrice e StandardCost incluidos
- [ ] Flag estoque_critico (Quantity < 10 conforme FRD)
- [ ] Surrogate key (product_sk)
- [ ] Categorias de produto incluidas (quando disponivel)

## Priority: P2 | Size: M (3 pts) | Milestone: M2
## Labels: feature, gold, pipeline, produtos, estoque
```

#### Issue #013: [FEAT] Modelo Dimensional Gold -- dim_date

```
## Summary
Criar dimensao de data/calendario para analises temporais.

## Acceptance Criteria
- [ ] Tabela gold.dim_date criada com range adequado
- [ ] Campos: date_key, year, quarter, month, month_name,
      week, day_of_week, is_weekend, is_holiday
- [ ] Granularidade diaria
- [ ] Range cobrindo pelo menos 3 anos de dados historicos

## Priority: P2 | Size: S (2 pts) | Milestone: M2
## Labels: feature, gold, pipeline, data-tempo
```

#### Issue #014: [FEAT] Regras de Qualidade de Dados -- Expectations DLT

```
## Summary
Implementar regras de qualidade de dados como DLT Expectations
em todas as camadas.

## Acceptance Criteria
- [ ] Bronze: Expectations de NOT NULL para primary keys
- [ ] Silver: Expectations de integridade referencial
- [ ] Gold: Expectations de completude (< 1% nulos em metricas)
- [ ] Metricas de qualidade visiveis no Databricks UI
- [ ] Alertas configurados para violacoes > 5%
- [ ] Dashboard de qualidade de dados criado

## Priority: P2 | Size: L (5 pts) | Milestone: M2
## Labels: feature, governance, pipeline, test
```

#### Issue #015: [FEAT] Dashboard de Vendas por Canal

```
## Summary
Criar dashboard analitico de vendas com KPIs principais
e segmentacao por canal.

## Acceptance Criteria
- [ ] KPI cards: Receita Total, Ticket Medio, Total Pedidos
- [ ] Grafico de receita por periodo (mensal/trimestral)
- [ ] Top 10 produtos mais vendidos
- [ ] Filtros por periodo, produto, cliente
- [ ] Drill-down por canal (quando disponivel)
- [ ] Refresh automatico apos pipeline Gold

## Priority: P2 | Size: L (5 pts) | Milestone: M3
## Labels: feature, bi, dashboard, vendas
```

#### Issue #016: [FEAT] Dashboard de Clientes e Churn

```
## Summary
Criar dashboard de analise de comportamento de clientes
com identificacao de churn.

## Acceptance Criteria
- [ ] KPI cards: Total Clientes, Taxa de Churn, CLV medio
- [ ] Lista de clientes em risco de churn
- [ ] Segmentacao por frequencia de compra (RFM simplificado)
- [ ] Tendencia de churn ao longo do tempo
- [ ] Filtros por periodo e segmento

## Priority: P2 | Size: L (5 pts) | Milestone: M3
## Labels: feature, bi, dashboard, clientes
```

#### Issue #017: [FEAT] Dashboard de Estoque Critico

```
## Summary
Criar dashboard de monitoramento de niveis de estoque
com alertas para itens criticos.

## Acceptance Criteria
- [ ] KPI cards: Produtos em Estoque Critico, Nivel Medio
- [ ] Tabela com produtos abaixo do nivel critico
- [ ] Semaforo visual (verde/amarelo/vermelho)
- [ ] Tendencia de estoque por produto
- [ ] Filtros por produto e categoria

## Priority: P2 | Size: M (3 pts) | Milestone: M3
## Labels: feature, bi, dashboard, estoque
```

#### Issue #018: [FEAT] Configurar Storage Account e Conectividade SQL Server

```
## Summary
Provisionar Azure Storage Account para o Lakehouse e
configurar conectividade com o SQL Server fonte.

## Acceptance Criteria
- [ ] Storage Account criado (ADLS Gen2)
- [ ] Containers: bronze, silver, gold, staging
- [ ] Managed Identity ou Service Principal com acesso
- [ ] Conectividade com SQL Server validada
- [ ] Firewall rules e Private Endpoints configurados
- [ ] Lifecycle policies para custo (mover staging para cool apos 30d)

## Priority: P2 | Size: M (3 pts) | Milestone: M1
## Labels: feature, infra, config
```

#### Issue #019: [FEAT] Monitoramento e Alertas de Pipeline

```
## Summary
Configurar monitoramento de pipelines com alertas para
falhas, SLA e qualidade de dados.

## Acceptance Criteria
- [ ] Alertas de falha de pipeline via email/Slack
- [ ] Metricas de duracao de pipeline (baseline + SLA)
- [ ] Dashboard operacional de health check
- [ ] Alertas de qualidade de dados (expectations violadas)
- [ ] Log centralizado de execucoes

## Priority: P2 | Size: M (3 pts) | Milestone: M3
## Labels: feature, infra, pipeline
```

#### Issue #020: [FEAT] Runbook Operacional e Documentacao

```
## Summary
Criar documentacao operacional para sustentacao do ambiente
em producao.

## Acceptance Criteria
- [ ] Runbook com procedimentos de troubleshooting
- [ ] Guia de re-execucao de pipelines (full e incremental)
- [ ] Dicionario de dados atualizado com linhagem
- [ ] Guia de acesso e permissoes
- [ ] Procedimento de disaster recovery

## Priority: P2 | Size: M (3 pts) | Milestone: M3
## Labels: documentation, governance
```

---

### P3 -- Medio (Melhorias e Otimizacoes)

#### Issue #021: [IMPROVE] Otimizacao de Performance -- Pipelines Spark

```
## Summary
Tuning de performance das pipelines Spark (particionamento,
cache, broadcast joins).

## Acceptance Criteria
- [ ] Z-Ordering aplicado em colunas de filtro frequente
- [ ] Broadcast join para dimensoes pequenas (< 10MB)
- [ ] Particionamento otimizado (nao over-partition)
- [ ] OPTIMIZE e VACUUM configurados (Delta Lake)
- [ ] Metricas de antes/depois documentadas

## Priority: P3 | Size: L (5 pts) | Milestone: M3
## Labels: improvement, pipeline, gold, silver
```

#### Issue #022: [SPIKE] Investigar CDC para Ingestao Incremental

```
## Summary
Avaliar viabilidade de Change Data Capture (CDC) para
ingestao incremental em tempo quase real.

## Acceptance Criteria
- [ ] Avaliar CDC via Lakeflow (DLT) -- APPLY CHANGES
- [ ] Avaliar CDC via SQL Server Change Tracking
- [ ] POC com 1 tabela (SalesOrderHeader)
- [ ] Documento de recomendacao com pros/contras
- [ ] Estimativa de custo vs batch

## Priority: P3 | Size: M (3 pts) | Milestone: M3
## Labels: spike, bronze, pipeline
```

#### Issue #023: [FEAT] Seguranca e Controle de Acesso (RBAC)

```
## Summary
Implementar controle de acesso baseado em roles para
as diferentes camadas e stakeholders.

## Acceptance Criteria
- [ ] Roles definidos: data_engineer, data_analyst, business_user
- [ ] Permissoes por schema (bronze: eng only, gold: all read)
- [ ] Row-level security avaliado
- [ ] Audit log de acessos habilitado
- [ ] Documentacao de politica de acesso

## Priority: P3 | Size: M (3 pts) | Milestone: M2
## Labels: feature, governance, config
```

---

### P4 -- Baixo (Futuro / Nice to Have)

#### Issue #024: [FEAT] Tabelas Agregadas para Performance de Consultas

```
## Acceptance Criteria
- [ ] gold.agg_vendas_mensal (receita, qtd, ticket por mes)
- [ ] gold.agg_vendas_produto (top produtos por periodo)
- [ ] Refresh automatico apos pipeline Gold
- [ ] Performance de consulta < 3 segundos

## Priority: P4 | Size: M (3 pts) | Milestone: (Futuro)
## Labels: improvement, gold, pipeline
```

#### Issue #025: [SPIKE] Avaliacao de Dify para Chatbot Analitico

```
## Acceptance Criteria
- [ ] POC de chatflow conectando ao Gold layer
- [ ] 5 perguntas de negocio respondidas corretamente
- [ ] Documento de viabilidade e custo
- [ ] Recomendacao go/no-go

## Priority: P4 | Size: L (5 pts) | Milestone: (Futuro)
## Labels: spike, bi
```

#### Issue #026: [IMPROVE] CI/CD para Pipelines Databricks

```
## Acceptance Criteria
- [ ] GitHub Actions workflow para deploy
- [ ] Testes automatizados pre-deploy
- [ ] Ambientes dev/staging/prod separados
- [ ] Rollback automatizado

## Priority: P4 | Size: L (5 pts) | Milestone: (Futuro)
## Labels: improvement, infra, config
```

---

### Issues de Risco (Risk Tracking)

#### Issue #R01: [RISK] Baixa Adocao pelos Usuarios de Negocio

```
## Risk Assessment
- Probabilidade: MEDIA | Impacto: ALTO | Score: ALTO

## Mitigation Plan
- [ ] Envolver analistas de negocio desde Sprint 3
- [ ] Sessoes de feedback quinzenais
- [ ] Treinamento hands-on antes do go-live
- [ ] Documentar quick-start guide para cada dashboard
- [ ] Identificar champion users em cada area

## Owner: Project Lead | Labels: risk | Milestone: M3
```

#### Issue #R02: [RISK] Qualidade de Dados no Sistema Fonte

```
## Risk Assessment
- Probabilidade: ALTA | Impacto: MEDIO | Score: ALTO

## Mitigation Plan
- [ ] Profiling de dados na Sprint 1
- [ ] Expectations agressivas na camada Bronze
- [ ] Quarentena para registros rejeitados
- [ ] Dashboard de qualidade de dados
- [ ] Reuniao semanal de qualidade com data owners

## Owner: Data Engineer Lead | Labels: risk, governance | Milestone: M1
```

#### Issue #R03: [RISK] Custos Elevados de Infraestrutura Azure/Databricks

```
## Risk Assessment
- Probabilidade: MEDIA | Impacto: MEDIO | Score: MEDIO

## Mitigation Plan
- [ ] Cluster policies com auto-termination (15 min)
- [ ] Spot instances para workloads batch
- [ ] Cost alerts no Azure (50%, 80%, 100% do budget)
- [ ] Revisao semanal de custos na Sprint Review
- [ ] Serverless pipelines onde possivel

## Owner: Cloud Architect | Labels: risk, infra | Milestone: M1
```

#### Issue #R04: [RISK] Dependencia de Acesso ao Ambiente de Producao

```
## Risk Assessment
- Probabilidade: MEDIA | Impacto: ALTO | Score: ALTO

## Mitigation Plan
- [ ] Solicitar todos os acessos na Sprint 0 (pre-kickoff)
- [ ] Ambiente de dev disponivel desde Day 1
- [ ] Escalation path definido para aprovacoes
- [ ] Dados sinteticos como fallback

## Owner: Project Lead | Labels: risk, infra | Milestone: M1
```

---

## 6. Sprint Plans

### Premissas de Capacidade

```
Time Estimado: 3 engenheiros de dados
Velocidade Base: 2 pts/dia/pessoa (time novo, conservador)
Focus Factor: 0.8

Calculo por Sprint (2 semanas = 10 dias uteis):
- Por pessoa: 10 dias x 0.8 = 8 dias efetivos x 2 pts = 16 pts
- Time total: 3 x 16 = 48 pts brutos
- Buffer 20%: 48 x 0.8 = 38 pts commitaveis por sprint

Nota: Time novo sem historico de velocidade. Valores
serao ajustados apos Sprint 1 com dados reais.
```

---

### Sprint 1 -- Fundacao (07/04 - 17/04/2026)

```
GOAL: Infraestrutura Azure/Databricks provisionada e
      primeiras pipelines Bronze funcionando

COMMITMENT (30 / 38 pts = 79% -- Right-sized)
| Issue | Titulo                              | Pri | Size |
|-------|-------------------------------------|-----|------|
| #001  | Provisionar Workspace Databricks    | P1  | 5    |
| #018  | Storage Account e Conectividade     | P2  | 3    |
| #002  | Configurar Unity Catalog            | P1  | 3    |
| #003  | Pipeline Bronze - SalesOrderHeader  | P1  | 3    |
| #004  | Pipeline Bronze - SalesOrderDetail  | P1  | 3    |
| #005  | Pipeline Bronze - Customer          | P1  | 2    |
| #006  | Pipeline Bronze - Product           | P1  | 2    |
| #007  | Pipeline Bronze - ProductInventory  | P1  | 2    |
| #R02  | [RISK] Profiling dados fonte        | P2  | 3    |
| #R03  | [RISK] Cost alerts e policies       | P2  | 3    |
| #R04  | [RISK] Solicitar acessos            | P2  | 1    |
| TOTAL |                                     | --  | 30   |

DEPENDENCIES
+-- #001 bloqueia #002 que bloqueia #003-#007
+-- External: Acesso Azure subscription, SQL Server credentials

DEFINITION OF DONE
- [ ] Workspace Databricks operacional
- [ ] 5 tabelas ingeridas na camada Bronze
- [ ] Unity Catalog configurado
- [ ] Profiling de dados fonte documentado
- [ ] Cost alerts configurados
```

---

### Sprint 2 -- Consolidacao Bronze + Inicio Silver (21/04 - 01/05/2026)

```
GOAL: Camada Bronze completa e estavel, inicio das
      transformacoes Silver com regras de limpeza

COMMITMENT (26 / 38 pts = 68% -- Under-committed intencional)
| Issue | Titulo                              | Pri | Size |
|-------|-------------------------------------|-----|------|
| #008  | Pipeline Silver - Vendas            | P2  | 5    |
| #009  | Pipeline Silver - Customer/Product  | P2  | 3    |
| #014  | Regras Qualidade - Expectations     | P2  | 5    |
| #013  | dim_date                            | P2  | 2    |
| #023  | Seguranca e RBAC                    | P3  | 3    |
| --    | Bug fixes / ajustes Bronze Sprint 1 | --  | 5    |
| --    | Testes e validacao Bronze end-to-end | --  | 3    |
| TOTAL |                                     | --  | 26   |

DEFINITION OF DONE
- [ ] Camada Bronze 100% estavel (0 falhas em 5 dias)
- [ ] Silver de vendas processando corretamente
- [ ] Silver de dimensoes (customer, product) criadas
- [ ] dim_date populada
- [ ] Expectations ativas em Bronze e Silver
- [ ] RBAC basico implementado

== FIM MILESTONE M1 (01/05/2026) ==
```

---

### Sprint 3 -- Modelo Dimensional Gold (05/05 - 15/05/2026)

```
GOAL: Star Schema completo na camada Gold com fact_sales
      e todas as dimensoes, regras de negocio validadas

COMMITMENT (25 / 38 pts = 66% -- Under-committed intencional)
| Issue | Titulo                              | Pri | Size |
|-------|-------------------------------------|-----|------|
| #010  | fact_sales                          | P2  | 5    |
| #011  | dim_customer (com churn)            | P2  | 3    |
| #012  | dim_product (com estoque critico)   | P2  | 3    |
| #022  | [SPIKE] Investigar CDC              | P3  | 3    |
| --    | Validacao regras de negocio c/ BAs  | --  | 3    |
| --    | Testes end-to-end Bronze->Gold      | --  | 5    |
| --    | Ajustes Silver baseados em feedback | --  | 3    |
| TOTAL |                                     | --  | 25   |

DEFINITION OF DONE
- [ ] fact_sales populada e validada
- [ ] dim_customer com flag de churn funcionando
- [ ] dim_product com flag de estoque critico
- [ ] dim_date integrada com fact_sales
- [ ] Regras de negocio validadas por pelo menos 1 analista
- [ ] Pipeline end-to-end (Bronze -> Silver -> Gold) < 15 min
- [ ] POC de CDC documentada (go/no-go)
```

---

## 7. Views do Linear

```
1. Sprint Board (Kanban) -- Filtro: Sprint ativo
2. Backlog Priorizado    -- Agrupamento: Milestone, Ordem: Prioridade
3. Roadmap por Milestone -- Agrupamento: M1, M2, M3
4. Riscos               -- Filtro: Label = "risk"
5. Qualidade de Dados   -- Filtro: Label = "governance" OR "test"
6. Pipeline por Camada  -- Agrupamento: bronze, silver, gold
```

---

## 8. Resumo Executivo

```
EXECUTIVE DASHBOARD
===============================================================

PROJETO: RetailMax Lakehouse Analytics
PERIODO: Q2 2026 (Abril - Junho)

BACKLOG SUMMARY
| Prioridade | Issues | Total Pts |
|------------|--------|-----------|
| P1         | 7      | 20        |
| P2         | 12     | 44        |
| P3         | 3      | 11        |
| P4         | 3      | 13        |
| Riscos     | 4      | --        |
| TOTAL      | 29     | 88+       |

DECISOES NECESSARIAS
+-- Aprovacao de budget Azure: Antes de 07/04
+-- Definir Project Lead: Antes de 07/04
+-- Validar fonte de dados (SQL Server prod vs replica): Ate 10/04
+-- Escolher ferramenta de BI (Power BI / Databricks SQL): Ate 17/04

===============================================================
```
