# Especificação Funcional Avançada (FRD)
## Projeto: Lakehouse Analytics - AdventureWorks

---

## 1. Objetivo

Documento avançado detalhando regras funcionais, modelagem analítica, dicionário de dados e fluxos de transformação para o banco AdventureWorks.

---

## 2. Arquitetura de Dados (Medallion)

- **Bronze:** ingestão bruta  
- **Silver:** dados tratados e normalizados  
- **Gold:** modelo dimensional (Star Schema)  

---

## 3. Dicionário de Dados (Principais Tabelas)

### 3.1 SalesOrderHeader
- Cabeçalho de pedidos  
- Campo: OrderDate  
- Campo: CustomerID  
- Campo: TotalDue  

### 3.2 SalesOrderDetail
- Itens do pedido  
- Campo: ProductID  
- Campo: OrderQty  
- Campo: UnitPrice  

### 3.3 Customer
- Clientes  
- Campo: CustomerID  
- Campo: AccountNumber  

### 3.4 Product
- Produtos  
- Campo: ProductID  
- Campo: Name  
- Campo: ListPrice  

### 3.5 ProductInventory
- Estoque  
- Campo: ProductID  
- Campo: Quantity  

---

## 4. Regras de Negócio Detalhadas

- Receita = SUM(OrderQty * UnitPrice)  
- Ticket Médio = Receita / Total de Pedidos  
- Churn: cliente sem compra > 90 dias  
- Estoque crítico: Quantity < 10  

---

## 5. Transformações (ETL/ELT)

- Deduplicação por chave primária  
- Tratamento de nulos com default ou exclusão  
- Conversão de tipos (string → date)  
- Joins entre tabelas para construção analítica  

---

## 6. Modelo Dimensional

### 6.1 Tabela Fato: fact_sales
- Chaves: OrderID, ProductID, CustomerID  
- Métricas: Receita, Quantidade  

### 6.2 Dimensões
- dim_customer  
- dim_product  
- dim_date  

---

## 7. Mapeamento Bronze → Silver → Gold

- Bronze: ingestão direta do SQL Server  
- Silver: limpeza e padronização  
- Gold: agregações e KPIs  

---

## 8. Regras de Qualidade de Dados

- Validação de nulos  
- Consistência de chaves  
- Regras de integridade referencial  

---

## 9. Dashboards e Consumo

- Dashboard de vendas (receita, ticket médio)  
- Dashboard de clientes (churn)  
- Dashboard de estoque  

---

## 10. Exemplos de Transformação (Pseudo SQL)

```sql
SELECT ProductID, 
       SUM(OrderQty * UnitPrice) as Revenue 
FROM Sales
GROUP BY ProductID