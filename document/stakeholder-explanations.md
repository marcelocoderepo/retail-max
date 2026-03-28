# Projeto RetailMax Lakehouse Analytics -- Explicacoes Adaptativas

**Versao:** 1.0 | **Data:** 2026-03-28

**Documentos-fonte:**
- `document/brd-retail-max.md`
- `document/frd-adventure-works.md`

---

## 1. Para a Diretoria Executiva -- Visao Estrategica

### O Problema (em uma frase)

Hoje, a RetailMax tem seus dados espalhados em varios sistemas diferentes -- como se cada departamento falasse um idioma diferente e ninguem conseguisse se entender.

### O Que Estamos Construindo

Imagine que a RetailMax e uma grande biblioteca, mas os livros estao jogados em salas diferentes, sem catalogo e sem organizacao. Alguns estao em caixas no deposito, outros em mesas, outros emprestados sem registro.

**Esta plataforma e o bibliotecario profissional** que vai:
1. **Reunir todos os livros** (dados de vendas, clientes, estoque) em um unico lugar organizado
2. **Catalogar e organizar** para que qualquer pessoa encontre o que precisa em segundos
3. **Criar resumos executivos** (dashboards) que mostram o panorama geral sem precisar ler cada livro

### Valor para o Negocio

| O que muda | Antes | Depois |
|------------|-------|--------|
| Gerar um relatorio | Dias ou semanas | **50% mais rapido** |
| Saber o ticket medio | Pedir para alguem calcular | **Dashboard atualizado automaticamente** |
| Identificar churn | Descobrir tarde demais | **Alerta quando cliente fica 90 dias sem comprar** |
| Visao de estoque | Ligacoes entre lojas | **Painel unificado com alertas de estoque critico** |

### O Que Sera Entregue

- **3 dashboards prontos:** Vendas, Clientes e Estoque
- **5 KPIs automatizados:** Receita total, Ticket medio, Taxa de churn, Top produtos, Nivel de estoque
- **Uma base solida** para, no futuro, incluir inteligencia artificial e previsoes

### Riscos e Como Estamos Tratando

| Risco | Analogia | Acao |
|-------|----------|------|
| Ninguem usar a plataforma | Construir estrada sem ensinar a dirigir | Treinamento para todos os usuarios |
| Dados com problemas | Lixo entra, lixo sai | Regras automaticas de validacao e qualidade |
| Custo fora do controle | Torneira aberta sem medidor | Otimizacao de recursos desde o dia 1 |

**Resultado esperado:** Decisoes mais rapidas, baseadas em fatos, com visibilidade total sobre vendas, clientes e estoque -- tudo em um unico lugar.

---

## 2. Para Analistas de Negocio -- Como Voces Vao Trabalhar com a Plataforma

### Resumo Simples (para todos)

A plataforma vai reunir todos os dados de vendas, clientes e estoque da RetailMax em um unico lugar organizado. Voces terao acesso a dashboards interativos e KPIs calculados automaticamente, sem precisar montar planilhas ou pedir relatorios para a TI.

---

### Mais Detalhes: Como os Dados Sao Organizados e Quais Regras Aplicamos

#### O Modelo de Dados que Voces Vao Consumir

Os dados chegam ate voces em um formato chamado **Star Schema** (Esquema Estrela). Pense nisso como uma mesa de analise com uma planilha central de vendas conectada a tabelas de consulta:

```
                        +------------------+
                        |    dim_date      |
                        |                  |
                        |  Ano, Mes,       |
                        |  Trimestre       |
                        +--------+---------+
                                 |
+------------------+    +--------+----------+    +------------------+
|  dim_customer    |----+    fact_sales      +----+  dim_product     |
|                  |    |                    |    |                  |
|  ID, Conta       |    |  Receita,          |    |  Nome, Preco     |
|                  |    |  Quantidade,       |    |                  |
|                  |    |  Pedido            |    |                  |
+------------------+    +--------------------+    +------------------+
```

**fact_sales** e a tabela central -- cada linha e uma transacao de venda. As dimensoes (dim_customer, dim_product, dim_date) sao as tabelas de consulta que dao contexto: *quem* comprou, *o que* comprou, *quando* comprou.

#### Regras de Negocio -- Como os KPIs Sao Calculados

Estas sao as definicoes oficiais que a plataforma usa. Quando voce vir um numero no dashboard, e assim que ele foi calculado:

| KPI | Formula | Exemplo |
|-----|---------|---------|
| **Receita** | Soma de (Quantidade x Preco Unitario) | 10 unidades x R$50 = R$500 |
| **Ticket Medio** | Receita Total / Numero de Pedidos | R$100.000 / 200 pedidos = R$500 |
| **Churn** | Cliente sem compra ha mais de 90 dias | Ultima compra em 01/jan, hoje e 15/abr = churn |
| **Estoque Critico** | Quantidade disponivel menor que 10 unidades | Produto com 8 unidades = alerta |

#### Os 3 Dashboards que Voces Vao Usar

1. **Dashboard de Vendas** -- Receita total, ticket medio, vendas por canal, ranking de produtos
2. **Dashboard de Clientes** -- Taxa de churn, comportamento de compra, segmentacao
3. **Dashboard de Estoque** -- Niveis atuais, alertas de estoque critico, produtos em risco

#### De Onde Vem os Dados

Os dados vem diretamente do sistema transacional (SQL Server) e passam por um processo automatizado de limpeza:
- Duplicatas sao removidas
- Campos vazios sao tratados
- Formatos sao padronizados (ex: datas no mesmo formato)

Voces recebem os dados **ja limpos e prontos para analise**.

---

### Profundidade Tecnica: Tabelas, Campos e Mapeamentos

#### Tabelas de Origem (Sistema Transacional)

| Tabela | Descricao | Campos-Chave |
|--------|-----------|--------------|
| SalesOrderHeader | Cabecalho do pedido | OrderDate, CustomerID, TotalDue |
| SalesOrderDetail | Itens do pedido | ProductID, OrderQty, UnitPrice |
| Customer | Cadastro de clientes | CustomerID, AccountNumber |
| Product | Catalogo de produtos | ProductID, Name, ListPrice |
| ProductInventory | Posicao de estoque | ProductID, Quantity |

#### Como as Tabelas se Conectam

```
SalesOrderHeader.SalesOrderID ---- SalesOrderDetail.SalesOrderID
SalesOrderHeader.CustomerID  ---- Customer.CustomerID
SalesOrderDetail.ProductID   ---- Product.ProductID
Product.ProductID            ---- ProductInventory.ProductID
```

#### Exemplo Pratico: Receita por Produto

A consulta que alimenta o ranking de produtos mais vendidos:

```sql
SELECT ProductID,
       SUM(OrderQty * UnitPrice) AS Revenue
FROM Sales
GROUP BY ProductID
```

**Em portugues:** "Para cada produto, some todas as quantidades vendidas multiplicadas pelo preco unitario. Isso da a receita total por produto."

#### Regras de Qualidade Aplicadas

Antes dos dados chegarem ao dashboard, passam por validacoes automaticas:
- Nenhum pedido sem cliente (integridade referencial)
- Nenhum produto sem ID (validacao de nulos)
- Nenhuma duplicata na chave primaria (consistencia)

Se algum dado falhar nessas validacoes, ele e sinalizado e tratado antes de entrar nos relatorios.

---

## 3. Para a Equipe Tecnica -- Arquitetura e Especificacoes

### Mapeamento BRD para FRD: Rastreabilidade de Requisitos

O BRD define o "o que" e o "por que". O FRD define o "como". Segue o mapeamento:

| Requisito de Negocio (BRD) | Implementacao Tecnica (FRD) |
|-----------------------------|-----------------------------|
| Aumentar visibilidade sobre vendas | fact_sales + dim_product + Dashboard de Vendas |
| Melhorar tomada de decisao | Star Schema + KPIs automatizados (Receita, Ticket Medio) |
| Reduzir tempo de relatorios em 50% | Camada Gold pre-agregada + dashboards self-service |
| Habilitar analises avancadas | Modelo dimensional extensivel para futuro ML |
| Monitoramento de estoque | ProductInventory -> dim_product + regra Quantity < 10 |
| Analise de churn | Customer + SalesOrderHeader + regra > 90 dias sem compra |

### Arquitetura Medallion -- Implementacao

A arquitetura segue o padrao Medallion (Bronze/Silver/Gold), alinhada com os padroes do projeto documentados em `kb/lakeflow/01-core-concepts/concepts.md`.

```
+-------------------------------------------------------------------------+
|                     ARQUITETURA MEDALLION                                |
+-------------------------------------------------------------------------+
|                                                                         |
|  +-------------+      +-----------------+      +--------------------+   |
|  |   BRONZE    |      |     SILVER      |      |       GOLD         |   |
|  |             |      |                 |      |                    |   |
|  | Ingestao    |----->| Limpeza e       |----->| Modelo             |   |
|  | bruta do    |      | padronizacao    |      | Dimensional        |   |
|  | SQL Server  |      |                 |      | (Star Schema)      |   |
|  |             |      | - Deduplicacao  |      |                    |   |
|  | Tabelas:    |      | - Nulos         |      | - fact_sales       |   |
|  | - SalesOrder|      | - Tipos         |      | - dim_customer     |   |
|  |   Header    |      | - Validacao     |      | - dim_product      |   |
|  | - SalesOrder|      |   de chaves     |      | - dim_date         |   |
|  |   Detail    |      |                 |      |                    |   |
|  | - Customer  |      |                 |      | KPIs:              |   |
|  | - Product   |      |                 |      | - Receita          |   |
|  | - Product   |      |                 |      | - Ticket Medio     |   |
|  |   Inventory |      |                 |      | - Churn            |   |
|  +-------------+      +-----------------+      +--------------------+   |
|                                                                         |
|  Formato: Parquet/    Formato: Delta       Formato: Delta               |
|  Delta (raw)          Lake (cleaned)       Lake (aggregated)            |
+-------------------------------------------------------------------------+
```

### Transformacoes ETL -- Detalhamento por Camada

**Bronze -> Silver (Limpeza)**

| Transformacao | Descricao | Aplicacao |
|---------------|-----------|-----------|
| Deduplicacao | Remocao por chave primaria | Todas as tabelas |
| Tratamento de nulos | Default ou exclusao | Campos obrigatorios (CustomerID, ProductID) |
| Conversao de tipos | string -> date, string -> decimal | OrderDate, UnitPrice, ListPrice |
| Validacao referencial | FK deve existir na tabela pai | CustomerID em SalesOrderHeader -> Customer |

**Silver -> Gold (Modelagem)**

| Transformacao | Descricao | Tabela Destino |
|---------------|-----------|----------------|
| Join analitico | SalesOrderHeader + SalesOrderDetail + Customer + Product | fact_sales |
| Agregacao de receita | SUM(OrderQty * UnitPrice) | fact_sales.Receita |
| Calculo de churn | Clientes com ultima compra > 90 dias | Derivado de dim_customer + fact_sales |
| Alerta de estoque | Filtro Quantity < 10 | Derivado de dim_product + ProductInventory |
| Dimensao de data | Extracao de ano, mes, trimestre, dia da semana | dim_date |

### Modelo Dimensional -- Detalhamento

```sql
-- fact_sales (tabela fato)
CREATE TABLE gold.fact_sales (
    OrderID         INT,          -- FK -> SalesOrderHeader
    ProductID       INT,          -- FK -> dim_product
    CustomerID      INT,          -- FK -> dim_customer
    DateKey         INT,          -- FK -> dim_date
    Receita         DECIMAL,      -- SUM(OrderQty * UnitPrice)
    Quantidade      INT           -- OrderQty
);

-- dim_customer (dimensao)
CREATE TABLE gold.dim_customer (
    CustomerID      INT,
    AccountNumber   VARCHAR,
    ChurnFlag       BOOLEAN       -- true se > 90 dias sem compra
);

-- dim_product (dimensao)
CREATE TABLE gold.dim_product (
    ProductID       INT,
    Name            VARCHAR,
    ListPrice       DECIMAL,
    EstoqueCritico  BOOLEAN       -- true se Quantity < 10
);

-- dim_date (dimensao)
CREATE TABLE gold.dim_date (
    DateKey         INT,
    FullDate        DATE,
    Year            INT,
    Quarter         INT,
    Month           INT,
    DayOfWeek       INT
);
```

### Regras de Qualidade -- Checklist de Implementacao

Com base no FRD, implementar as seguintes validacoes (alinhadas com o padrao de expectations do Lakeflow documentado em `kb/lakeflow/06-data-quality/expectations.md`):

```
+----------------------------------------------------------+
|             REGRAS DE QUALIDADE DE DADOS                 |
+----------------------------------------------------------+
|                                                          |
|  [ ] Validacao de Nulos                                  |
|      - CustomerID nunca nulo em SalesOrderHeader         |
|      - ProductID nunca nulo em SalesOrderDetail          |
|      - OrderDate nunca nulo                              |
|                                                          |
|  [ ] Consistencia de Chaves                              |
|      - SalesOrderID unico (sem duplicatas)               |
|      - CustomerID unico na tabela Customer               |
|      - ProductID unico na tabela Product                 |
|                                                          |
|  [ ] Integridade Referencial                             |
|      - Todo CustomerID em pedidos existe em Customer     |
|      - Todo ProductID em itens existe em Product         |
|      - Todo ProductID em inventario existe em Product    |
|                                                          |
|  [ ] Regras de Negocio                                   |
|      - OrderQty > 0                                      |
|      - UnitPrice >= 0                                    |
|      - TotalDue >= 0                                     |
|      - Quantity >= 0 em ProductInventory                 |
|                                                          |
+----------------------------------------------------------+
```

### Camada de Consumo -- Dashboards

```
+-----------------------------------------------------+
|               CAMADA DE CONSUMO                      |
+-----------------------------------------------------+
|                                                      |
|  Dashboard de Vendas                                 |
|  Fontes: fact_sales + dim_product + dim_date         |
|  KPIs: Receita, Ticket Medio, Vendas por Canal,      |
|        Top Produtos                                  |
|                                                      |
|  Dashboard de Clientes                               |
|  Fontes: dim_customer + fact_sales + dim_date        |
|  KPIs: Taxa de Churn, Comportamento de Compra        |
|                                                      |
|  Dashboard de Estoque                                |
|  Fontes: dim_product (com flag de estoque critico)   |
|  KPIs: Nivel de Estoque, Alertas de Reposicao        |
|                                                      |
+-----------------------------------------------------+
```

---

## 4. Resumo Visual -- Fluxo Ponta a Ponta

```
+---------------------------------------------------------------------------------+
|                   FLUXO COMPLETO: ORIGEM ATE DASHBOARDS                         |
+---------------------------------------------------------------------------------+

  ORIGEM              BRONZE            SILVER              GOLD            CONSUMO
  (SQL Server)        (Cru)             (Limpo)             (Modelado)      (Dashboards)

 +------------+    +----------+    +--------------+    +--------------+   +--------------+
 |SalesOrder  |    |          |    |              |    |              |   |  Dashboard   |
 |Header      |--->|          |    | Deduplicacao |    |  fact_sales  |-->|  de Vendas   |
 |            |    |          |    |              |    |              |   |              |
 +------------+    |  Copia   |    | Tratamento   |    +--------------+   +--------------+
 |SalesOrder  |--->|  direta  |--->| de nulos     |--->|              |-->|  Dashboard   |
 |Detail      |    |  dos     |    |              |    | dim_customer |   |  de Clientes |
 |            |    |  dados   |    | Conversao    |    |              |   |              |
 +------------+    |  brutos  |    | de tipos     |    +--------------+   +--------------+
 |Customer    |--->|          |    |              |    |              |-->|  Dashboard   |
 |            |    |          |    | Validacao    |    | dim_product  |   |  de Estoque  |
 +------------+    |          |    | de chaves    |    |              |   |              |
 |Product     |--->|          |    |              |    +--------------+   +--------------+
 |            |    |          |    | Integridade  |    |              |
 +------------+    |          |    | referencial  |    |  dim_date    |
 |Product     |--->|          |    |              |    |              |
 |Inventory   |    |          |    |              |    +--------------+
 +------------+    +----------+    +--------------+

                   Formato:        Formato:            Formato:
                   Raw / Delta     Delta Lake           Delta Lake
                                   (cleaned)            (Star Schema)

                   -------------------------------------------------------->
                                    FLUXO DE DADOS
```

```
+---------------------------------------------------------------------------------+
|                      FLUXO DE CALCULO DOS KPIs                                  |
+---------------------------------------------------------------------------------+

  DADOS LIMPOS (Silver)                    KPIs CALCULADOS (Gold)
  ---------------------                    ----------------------

  OrderQty x UnitPrice -----------------> RECEITA TOTAL
            |
            +--- / Total de Pedidos -----> TICKET MEDIO

  Max(OrderDate) por cliente
            |
            +--- se > 90 dias ----------> FLAG DE CHURN

  ProductInventory.Quantity
            |
            +--- se < 10 ---------------> ALERTA ESTOQUE CRITICO

  fact_sales GROUP BY ProductID
            |
            +--- ORDER BY Receita DESC -> RANKING TOP PRODUTOS
```

---

## 5. Glossario -- Termos Tecnicos em Linguagem de Negocio

| Termo Tecnico | O Que Significa no Dia a Dia |
|---------------|------------------------------|
| **Lakehouse** | Um armazem de dados moderno que combina o melhor de dois mundos: a flexibilidade de guardar qualquer tipo de dado com a organizacao e velocidade de um banco de dados tradicional. Pense em um supermercado que tambem funciona como atacado. |
| **Medallion (Bronze/Silver/Gold)** | O processo de refinamento dos dados, como o beneficiamento de minerio: Bronze e a materia-prima bruta, Silver e o material limpo e tratado, Gold e o produto final pronto para uso. |
| **Star Schema (Esquema Estrela)** | Uma forma de organizar dados para analise. No centro fica a tabela de fatos (vendas) e ao redor ficam as tabelas de contexto (clientes, produtos, datas) -- como uma estrela. |
| **ETL / ELT** | O processo automatizado de "Extrair, Transformar e Carregar" dados. Como uma esteira de fabrica que pega materia-prima, processa e entrega o produto final. |
| **Delta Lake** | A tecnologia que garante que os dados estejam sempre corretos e consistentes, mesmo durante atualizacoes. Como um cofre que permite guardar e consultar sem risco de perda. |
| **Tabela Fato (fact_sales)** | A tabela central com os numeros do negocio: vendas, receita, quantidades. Cada linha representa uma transacao que realmente aconteceu. |
| **Dimensao (dim_customer, dim_product, dim_date)** | Tabelas de referencia que dao contexto aos numeros. Respondem: quem comprou? o que comprou? quando comprou? |
| **Churn** | Taxa de evasao de clientes. Na plataforma, um cliente e considerado "churn" se nao compra ha mais de 90 dias. |
| **Ticket Medio** | Valor medio de cada pedido. Calculado dividindo a receita total pelo numero de pedidos. |
| **Estoque Critico** | Quando um produto tem menos de 10 unidades disponiveis. A plataforma gera alerta automatico. |
| **KPI** | Indicador-chave de desempenho. Os numeros mais importantes que mostram se o negocio vai bem ou mal. |
| **Dashboard** | Painel visual interativo com graficos e numeros atualizados automaticamente. Substitui relatorios manuais em Excel. |
| **Ingestao de Dados** | O processo de copiar os dados do sistema de origem (SQL Server) para a plataforma analitica. Como abastecer o armazem com mercadorias. |
| **Deduplicacao** | Remocao de registros duplicados. Garante que um mesmo pedido nao seja contado duas vezes. |
| **Integridade Referencial** | Garantia de que as conexoes entre tabelas estao corretas. Todo pedido tem um cliente valido, todo item tem um produto valido. |
| **SQL Server** | O banco de dados transacional atual da RetailMax, de onde os dados serao extraidos. E o sistema do dia a dia das operacoes. |
| **Governanca de Dados** | Conjunto de regras e processos que garantem seguranca, qualidade e uso correto dos dados. Quem pode ver o que, e como garantir que os dados estejam certos. |

---

**Nota:** O BRD referencia a empresa "RetailMax" enquanto o FRD referencia o banco de dados "AdventureWorks". O AdventureWorks e o banco de dados de exemplo (sample database) utilizado como fonte de dados para a implementacao. As explicacoes acima tratam o projeto de forma unificada, onde AdventureWorks e a base transacional que alimenta a plataforma analitica da RetailMax.
