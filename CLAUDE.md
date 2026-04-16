# Retail Max - Project Instructions

## Project Overview

Retail Max is a data engineering and AI project focused on building production-grade data pipelines, analytics, and AI-powered applications. The project uses the **Perfect Executor Model** architecture for reliable AI agent development.

## Tech Stack

- **Data Processing:** Apache Spark, PySpark, Delta Lake
- **Orchestration:** Databricks Lakeflow (formerly Delta Live Tables)
- **AI Platform:** Dify (chatflows, workflows, agents)
- **Cloud:** Azure, Databricks
- **Language:** Python 3.10+
- **Project Management:** Linear

## Repository

- **GitHub:** `https://github.com/marcelocoderepo/retail-max.git`
- **Branch principal:** `main`

## Project Structure

```
retail-max/
├── CLAUDE.md                  ← This file
├── README.md                  ← Project documentation (public)
├── .gitignore
├── .secrets/                  ← Local credentials (git-ignored, never committed)
│   ├── README.md              ← Setup guide for credentials
│   ├── azure-tenant.env       ← Azure Tenant (shared across environments)
│   ├── azure-devops.env       ← Azure DevOps PAT
│   ├── sql-server.env         ← AdventureWorks SQL Server connection
│   ├── terraform-backend.env  ← Terraform state backend
│   ├── dev/                   ← DEV environment credentials
│   ├── hml/                   ← HML (staging) environment credentials
│   └── prd/                   ← PRD (production) environment credentials
├── terraform-infra/           ← Terraform IaC (Azure infrastructure)
│   ├── README.md              ← Setup guide and module reference
│   ├── environments/          ← Per-environment configs (dev/hml/prd)
│   ├── modules/               ← 10 reusable Terraform modules
│   ├── azure-pipelines/       ← Azure DevOps CI/CD pipeline YAML
│   └── scripts/               ← Bootstrap scripts (init-backend, validate)
├── docs/                      ← Architecture & framework documentation
│   ├── readme.md              ← Documentation hub
│   ├── executor-model.md      ← Perfect Executor Model spec (consolidated)
│   └── agent-template.md      ← Agent templates (3 patterns)
├── document/                  ← Business requirements & implementation plans
│   ├── brd-retail-max.md      ← Business Requirements Document
│   ├── frd-adventure-works.md ← Functional Requirements (AdventureWorks)
│   ├── architecture-plan.md   ← Architecture plan (3-environment stack)
│   ├── implementation-plan.md ← Master implementation plan
│   ├── implementation-plan-dev.md   ← Dev environment plan
│   ├── implementation-plan-infra.md ← Infrastructure plan
│   └── linear-project-plan.md      ← Linear project milestones
├── kb/                        ← Knowledge base (curated, offline-first)
│   ├── lakeflow/              ← Databricks Lakeflow pipelines
│   ├── spark/                 ← Apache Spark optimization
│   └── dify/                  ← Dify AI platform
└── .claude/
    ├── settings.local.json
    ├── agent-memory/          ← Persistent agent memory
    ├── commands/              ← Custom slash commands
    │   └── publish.md         ← /publish - Smart GitHub publish
    └── agents/                ← All AI agents (organized by category)
        ├── ai-platform/       ← AI & Data Engineering agents
        │   ├── staff-ai-data-engineer.md
        │   └── dify-developer-specialist.md
        ├── azure/             ← Azure Cloud agents
        │   ├── azure-cloud-architect.md
        │   └── azure-data-factory-architect.md
        ├── code-quality/      ← Code quality & documentation agents
        │   ├── code-reviewer.md
        │   ├── code-documenter.md
        │   └── code-cleaner.md
        ├── communication/     ← Planning, PM & communication agents
        │   ├── the-planner.md
        │   ├── linear-project-manager.md
        │   ├── adaptive-explainer.md
        │   └── meeting-analyst.md
        ├── github-actions/    ← CI/CD & DevOps agents
        │   └── github-actions-architect.md
        ├── microsoft-vscode/  ← VS Code & developer tooling agents
        │   └── vscode-extension-developer.md
        └── spark/             ← Apache Spark agents
            ├── spark-specialist.md
            ├── spark-troubleshooter.md
            ├── spark-performance-analyzer.md
            └── spark-streaming-architect.md
```

## Business Context

RetailMax is an omnichannel retail company. The project builds a **Lakehouse Analytics Platform** using the AdventureWorks database as the data source.

### Data Architecture
- **Medallion Architecture:** Bronze (raw ingestion) → Silver (cleaned/normalized) → Gold (Star Schema)
- **Data Source:** AdventureWorks SQL Server (SalesOrderHeader, SalesOrderDetail, Customer, Product, ProductInventory)
- **Dimensional Model:** `fact_sales` + `dim_customer`, `dim_product`, `dim_date`
- **Key KPIs:** Revenue, Average Ticket, Churn Rate (>90 days no purchase), Inventory Level

### Planning Documents
All business and implementation plans are in `document/`:
- **BRD** (`brd-retail-max.md`) — Business objectives, stakeholders, KPIs, scope
- **FRD** (`frd-adventure-works.md`) — Data dictionary, business rules, ETL transformations, dimensional model
- **Architecture** (`architecture-plan.md`) — 3-environment stack (dev/staging/prod)
- **Implementation Plans** — Master, dev, and infrastructure breakdown
- **Linear Plan** (`linear-project-plan.md`) — Project milestones and issue tracking

## Agent Architecture: Perfect Executor Model

All agents follow the **Perfect Executor Model v3.0** with three pillars:

1. **Grounding** - Knowledge from KB files (`kb/`) + project context
2. **Guardrails** - MCP validation against current docs
3. **Graceful Degradation** - Safe handling of uncertainty

Agents implement 3 patterns: **Grounded** (KB+MCP+Confidence), **Expert** (KB+Patterns+Checklists), **Quality** (Conventions+Severity). See [docs/executor-model.md](docs/executor-model.md) for details.

## Available Agents

Agents are organized in `.claude/agents/` by category (17 total, 7 categories).

### ai-platform/
| Agent | Domain | Use When |
|-------|--------|----------|
| `staff-ai-data-engineer` | AI & Data Engineering | System architecture, Spark/Delta optimization, AI agents, Databricks AI Dev Kit |
| `dify-developer-specialist` | Dify AI platform | Chatflows, workflows, RAG, agents |

### azure/
| Agent | Domain | Use When |
|-------|--------|----------|
| `azure-cloud-architect` | Azure Cloud | Cloud architectures, Azure services, IaC, cost optimization |
| `azure-data-factory-architect` | Azure Data Factory | ADF pipelines, data integration, CDC, CI/CD for ADF |

### code-quality/
| Agent | Domain | Use When |
|-------|--------|----------|
| `code-reviewer` | Code quality | Code reviews, security, maintainability |
| `code-documenter` | Documentation | Code documentation, docstrings |
| `code-cleaner` | Code cleanup | Refactoring, dead code, formatting |

### communication/
| Agent | Domain | Use When |
|-------|--------|----------|
| `the-planner` | Strategic planning | Architecture decisions, project planning |
| `linear-project-manager` | Project management | Linear operations, issue tracking, sprints |
| `adaptive-explainer` | Communication | Adaptive explanations for different audiences |
| `meeting-analyst` | Meetings | Meeting analysis, summaries, action items |

### github-actions/
| Agent | Domain | Use When |
|-------|--------|----------|
| `github-actions-architect` | CI/CD & DevOps | Workflow design, deployment pipelines, PR validation, security scanning |

### microsoft-vscode/
| Agent | Domain | Use When |
|-------|--------|----------|
| `vscode-extension-developer` | VS Code | Extension development, workspace config, debug setup, task automation |

### spark/
| Agent | Domain | Use When |
|-------|--------|----------|
| `spark-specialist` | Apache Spark | Spark code, pipelines, performance |
| `spark-troubleshooter` | Spark debugging | Spark errors, failures, debugging |
| `spark-performance-analyzer` | Spark optimization | Performance tuning, bottlenecks |
| `spark-streaming-architect` | Streaming | Structured streaming, real-time pipelines |

## Knowledge Base Usage

KB files are the **primary source of truth** for project-specific patterns. Always:

1. **Read KB first** before answering domain questions
2. **Cite KB paths** in responses (e.g., `kb/spark/01-performance-tuning.md`)
3. **Note KB gaps** when coverage is missing
4. **Validate with MCP** for currency (KB = baseline, MCP = freshness check)

### KB Domains

| Domain | Path | Content |
|--------|------|---------|
| Lakeflow | `kb/lakeflow/` | DLT pipelines, CDC, expectations, Unity Catalog |
| Spark | `kb/spark/` | Performance tuning, memory, partitioning, joins, best practices |
| Dify | `kb/dify/` | Chatflows, workflows, agents, API, knowledge base, plugins |

## MCP Tools Available

| MCP Server | Best For |
|------------|----------|
| **Context7** (`mcp__upstash-context-7-mcp__*`) | Official library docs (Delta Lake, PySpark, Databricks) |
| **Ref Tools** (`mcp__ref-tools-ref-tools-mcp__*`) | Microsoft Learn, tutorials, GitHub |
| **Exa** (`mcp__exa__*`) | Code search, community examples, recent posts |
| **Firecrawl** (`mcp__krieg-2065-firecrawl-mcp-server__*`) | Deep web scraping, blog posts |

## Custom Commands

| Command | Description |
|---------|-------------|
| `/publish` | Smart publish to GitHub: analyzes changes, reviews code (security + quality), generates commit message, shows summary, and pushes with confirmation |
| `/archflow` | Gera visualizacao HTML interativa da arquitetura Azure (diagramas, inventario, seguranca, custos) |

## Conventions

### Code Standards
- Python: PEP 8, type hints, Google-style docstrings
- Testing: `pytest` as default framework
- Project layout: `src/` with `pyproject.toml`
- Error handling: Explicit, with graceful degradation

### Agent Development
- Agents are organized in `.claude/agents/{category}/` subdirectories
- Follow `docs/agent-template.md` when creating new agents
- Every agent must implement the 8 required sections
- KB files must have `Last Updated` and `MCP Validation` dates
- See `docs/executor-model.md` for the full spec

### Documentation
- Architecture docs live in `docs/`
- Business & implementation plans live in `document/`
- KB content lives in `kb/{domain}/`
