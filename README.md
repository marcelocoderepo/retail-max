# AI Data Engineer - Azure Databricks

**Production-grade AI agent ecosystem for data engineering on Azure and Databricks, powered by Claude Code and the Perfect Executor Model.**

AI Data Engineer is an open architecture for building reliable, grounded AI agents that assist with data engineering workflows on the Azure and Databricks stack. It combines a curated offline knowledge base, MCP-powered real-time validation, and structured agent patterns to deliver consistent, production-quality outputs across data pipelines, cloud infrastructure, and AI application development.

---

## Table of Contents

- [Architecture](#architecture)
- [Perfect Executor Model](#perfect-executor-model)
- [Agent Ecosystem](#agent-ecosystem)
- [Knowledge Base](#knowledge-base)
- [Custom Commands](#custom-commands)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [How Agents Work](#how-agents-work)
- [Creating New Agents](#creating-new-agents)
- [MCP Integration](#mcp-integration)
- [Contributing](#contributing)
- [License](#license)

---

## Architecture

```
                          +----------------------------------+
                          |          USER REQUEST            |
                          +---------------+------------------+
                                          |
                                          v
                          +----------------------------------+
                          |         CLAUDE CODE CLI          |
                          |   (orchestrator + router)        |
                          +---------------+------------------+
                                          |
                    +---------------------+---------------------+
                    |                     |                     |
                    v                     v                     v
          +-----------------+   +-----------------+   +-----------------+
          |   17 AGENTS     |   |  KNOWLEDGE BASE |   |   4 MCP         |
          |   (7 categories)|   |  (28 files)     |   |   SERVERS       |
          +-----------------+   +-----------------+   +-----------------+
          | ai-platform/    |   | kb/spark/       |   | Context7        |
          | azure/          |   | kb/lakeflow/    |   | Firecrawl       |
          | code-quality/   |   | kb/dify/        |   | Exa             |
          | communication/  |   |                 |   | Ref Tools       |
          | github-actions/ |   | 13,800+ lines   |   |                 |
          | microsoft-vscode|   | 416 KB curated  |   | Real-time       |
          | spark/          |   | content         |   | validation      |
          +-----------------+   +-----------------+   +-----------------+
                    |                     |                     |
                    +---------------------+---------------------+
                                          |
                                          v
                          +----------------------------------+
                          |     PERFECT EXECUTOR MODEL       |
                          |   Grounding + Guardrails +       |
                          |   Graceful Degradation           |
                          +----------------------------------+
```

---

## Perfect Executor Model

The core framework that ensures every agent produces reliable, validated outputs. Version 3.0 is built on three pillars:

### Grounding

Every response starts with knowledge, not guessing. Agents read from the offline knowledge base before answering, ensuring consistency with project-specific patterns and documented best practices.

```
KB File (offline, curated) --> Agent reads first --> Response is grounded
```

### Guardrails

Agents validate their knowledge against real-time sources via MCP servers. This catches outdated information, breaking changes, and API deprecations that the offline KB may not reflect.

```
KB says X --> MCP confirms X --> HIGH confidence (0.90+)
KB says X --> MCP says Y    --> CONFLICT (present both options)
KB silent --> MCP says Y    --> MEDIUM confidence (0.70-0.90)
Neither   --> Neither       --> LOW confidence (flag to user)
```

### Graceful Degradation

When information is incomplete or sources conflict, agents don't guess. They explicitly state their confidence level, present alternatives, and ask the user when certainty is too low.

| Confidence | Score | Agent Behavior |
|------------|-------|----------------|
| HIGH | 0.90+ | Execute with full conviction |
| MEDIUM | 0.70-0.90 | Execute with caveats noted |
| LOW | 0.50-0.70 | Flag for validation or POC |
| UNKNOWN | < 0.50 | Ask user before proceeding |
| CONFLICT | - | Present alternatives with trade-offs |

### Agent Patterns

| Pattern | Description | Example Agent |
|---------|-------------|---------------|
| **Grounded** | KB + MCP + Confidence scoring | `dify-developer-specialist` |
| **Expert** | KB + Deep patterns + Checklists | `spark-specialist` |
| **Quality** | Conventions + Severity + Reports | `code-reviewer` |

Full specification: [`docs/executor-model.md`](docs/executor-model.md)

---

## Agent Ecosystem

17 specialized agents organized into 7 domains. Each agent follows the Perfect Executor Model and implements 8 required sections.

### ai-platform/

| Agent | Purpose |
|-------|---------|
| `staff-ai-data-engineer` | System architecture, Spark/Delta optimization, AI agents, Databricks AI Dev Kit |
| `dify-developer-specialist` | Chatflows, workflows, RAG pipelines, agent development on Dify |

### azure/

| Agent | Purpose |
|-------|---------|
| `azure-cloud-architect` | Cloud architectures, Azure services, IaC (Terraform/Bicep), cost optimization |
| `azure-data-factory-architect` | ADF pipelines, data integration, CDC patterns, CI/CD for ADF |

### code-quality/

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Code reviews with severity classification (Critical/Warning/Suggestion) |
| `code-documenter` | Production-ready documentation, READMEs, API docs |
| `code-cleaner` | Refactoring, dead code removal, DRY principles, modernization |

### communication/

| Agent | Purpose |
|-------|---------|
| `the-planner` | Strategic architecture plans with confidence-scored decisions |
| `linear-project-manager` | Linear project management, issue tracking, sprint planning |
| `adaptive-explainer` | Adaptive explanations tailored to different audiences |
| `meeting-analyst` | Meeting analysis, summaries, action items extraction |

### github-actions/

| Agent | Purpose |
|-------|---------|
| `github-actions-architect` | CI/CD workflow design, deployment pipelines, security scanning |

### microsoft-vscode/

| Agent | Purpose |
|-------|---------|
| `vscode-extension-developer` | Extension development, workspace configuration, debug setup |

### spark/

| Agent | Purpose |
|-------|---------|
| `spark-specialist` | Spark code optimization, pipeline design, performance patterns |
| `spark-troubleshooter` | Error diagnosis, failure resolution, production debugging |
| `spark-performance-analyzer` | Profiling, bottleneck detection, tuning recommendations |
| `spark-streaming-architect` | Structured Streaming, Kafka integration, real-time processing |

---

## Knowledge Base

The KB is a curated, offline-first repository of domain knowledge. It serves as the primary source of truth for all agents. Total: **28 files, 13,800+ lines, 416 KB** of curated content.

### Domains

#### Apache Spark (`kb/spark/`) - 6 files

| File | Content |
|------|---------|
| `00-overview.md` | Core architecture, DataFrames, execution model |
| `01-performance-tuning.md` | AQE, query optimization, skew handling |
| `02-memory-management.md` | Memory regions, GC tuning, spill management |
| `03-partitioning-shuffle.md` | Partition strategies, shuffle optimization |
| `04-join-optimization.md` | Join strategies, broadcast joins, skew handling |
| `05-best-practices.md` | Code patterns, anti-patterns, production checklist |

#### Databricks Lakeflow (`kb/lakeflow/`) - 14 files

| Section | Files | Content |
|---------|-------|---------|
| Core Concepts | 1 | DLT fundamentals, Medallion architecture |
| Getting Started | 1 | Tutorial pipelines, quickstart |
| Development | 2 | Python and SQL pipeline development |
| Features | 1 | Change Data Capture (CDC), SCD patterns |
| Configuration | 2 | Pipeline config, serverless pipelines |
| Data Quality | 1 | Expectations, validation strategies |
| Advanced | 2 | Materialized views, stateful processing |
| Operations | 3 | Unity Catalog, parameters, limitations |

#### Dify AI Platform (`kb/dify/`) - 8 files

| File | Content |
|------|---------|
| `00-overview.md` | Platform architecture, differentiators |
| `01-chatflow-development.md` | Chatflow design and implementation |
| `02-workflow-development.md` | Workflow orchestration patterns |
| `03-agents-tools.md` | Agent development, tool integration |
| `04-api-reference.md` | REST API, SDK usage |
| `05-knowledge-base.md` | RAG pipelines, document processing |
| `06-nodes-reference.md` | Node types and configurations |
| `07-plugins-development.md` | Custom plugin development |

### KB Principles

1. **Read KB first** before answering domain questions
2. **Cite KB paths** in responses (e.g., `kb/spark/01-performance-tuning.md`)
3. **Note KB gaps** when coverage is missing
4. **Validate with MCP** for currency (KB = baseline, MCP = freshness)

---

## Custom Commands

| Command | Description |
|---------|-------------|
| `/publish` | Smart publish workflow for GitHub |

### `/publish` - Smart GitHub Publish

A 7-step quality gate that runs before any code reaches the remote repository:

```
Analyze Changes --> Code Review --> Stage Files --> Generate Commit
                                                         |
                    Push <-- Confirm <-- Show Summary <---+
```

**What it checks:**

| Check | What It Looks For |
|-------|-------------------|
| Security | Hardcoded secrets, API keys, `.env` files, injection vulnerabilities |
| Code Quality | PEP 8, type hints, debug statements, dead code, unused imports |
| Data Patterns | Spark optimizations, Delta Lake patterns, hardcoded paths |
| File Safety | Binary files, temp files, `.pyc`, `__pycache__`, `.DS_Store` |

**What it produces:**
- Conventional commit messages (`feat`, `fix`, `refactor`, etc.) with scope
- Pre-push summary with file stats, review results, and commit details
- Safety warnings for pushes to `main`/`master`

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Data Processing** | Apache Spark, PySpark, Delta Lake |
| **Orchestration** | Databricks Lakeflow (Delta Live Tables) |
| **AI Platform** | Dify (chatflows, workflows, agents) |
| **Cloud** | Microsoft Azure, Databricks |
| **Language** | Python 3.10+ |
| **AI Agents** | Claude Code (Anthropic) |
| **Project Management** | Linear |

---

## Project Structure

```
ai-data-engineer-azure-databricks/
├── README.md                             # This file
├── CLAUDE.md                             # Project instructions for Claude Code
├── docs/                                 # Architecture documentation
│   ├── readme.md                         # Documentation hub
│   ├── executor-model.md                 # Perfect Executor Model v3.0 spec
│   └── agent-template.md                 # Agent templates (3 patterns)
├── kb/                                   # Knowledge base (28 files, 416 KB)
│   ├── spark/                            # Apache Spark (6 files)
│   ├── lakeflow/                         # Databricks Lakeflow (14 files)
│   └── dify/                             # Dify AI platform (8 files)
├── document/                             # Business & functional requirements
│   ├── BRD_RetailMax_Lakehouse.docx      # Business Requirements Document
│   └── FRD_AdventureWorks_Avancado.docx  # Functional Requirements Document
└── .claude/                              # Claude Code configuration
    ├── settings.local.json               # Local settings
    ├── commands/                          # Custom slash commands
    │   └── publish.md                    # /publish - Smart GitHub publish
    ├── agent-memory/                     # Persistent agent memory
    └── agents/                           # 17 agents in 7 categories
        ├── ai-platform/                  # (2) AI & Data Engineering
        ├── azure/                        # (2) Azure Cloud
        ├── code-quality/                 # (3) Code quality & docs
        ├── communication/               # (4) Planning, PM, comms
        ├── github-actions/              # (1) CI/CD & DevOps
        ├── microsoft-vscode/            # (1) VS Code tooling
        └── spark/                       # (4) Apache Spark
```

---

## Getting Started

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- Python 3.10+
- Git

### Setup

1. **Clone the repository**

```bash
git clone https://github.com/marcelocoderepo/retail-max.git
cd retail-max
```

2. **Open with Claude Code**

```bash
claude
```

Claude Code will automatically read `CLAUDE.md` and load the project context, agents, and knowledge base.

3. **Verify agents are available**

All 17 agents are ready to use. Reference them with `@` in Claude Code:

```
@.claude/agents/spark/spark-specialist.md analyze this pipeline
```

4. **Use custom commands**

```
/publish
```

### MCP Server Configuration

For full agent grounding capability, configure these MCP servers in your Claude Code settings:

| Server | Purpose | Required |
|--------|---------|----------|
| Context7 | Official library documentation | Recommended |
| Exa | AI-powered code and research search | Recommended |
| Firecrawl | Deep web scraping for technical content | Optional |
| Ref Tools | Microsoft Learn and GitHub docs | Optional |

---

## How Agents Work

### Invocation Flow

```
1. User asks a question or assigns a task
2. Claude Code routes to the appropriate agent
3. Agent reads relevant KB files (grounding)
4. Agent queries MCP servers (guardrails)
5. Agent assesses confidence level
6. Agent responds with cited sources and confidence
```

### Example: Spark Performance Question

```
User: "My Spark job is slow on a skewed join"

Agent: spark-performance-analyzer
  |
  +--> Reads kb/spark/04-join-optimization.md
  |    Reads kb/spark/01-performance-tuning.md
  |
  +--> Queries Context7 for latest Spark 3.5 AQE docs
  |
  +--> Confidence: HIGH (0.95)
  |    KB confirms + MCP confirms
  |
  +--> Response:
       "Enable AQE skew join optimization:
        spark.conf.set('spark.sql.adaptive.skewJoin.enabled', 'true')

        Reference: kb/spark/04-join-optimization.md, section 3.2
        Validated: Spark 3.5 official documentation via Context7"
```

### Example: Uncertain Scenario

```
User: "Should I use feature X from the latest Dify release?"

Agent: dify-developer-specialist
  |
  +--> Reads kb/dify/00-overview.md
  |    Feature X not found in KB
  |
  +--> Queries Exa + Firecrawl for recent Dify releases
  |    Limited information found
  |
  +--> Confidence: LOW (0.55)
  |
  +--> Response:
       "Planning Note: I have incomplete information.
        KB does not cover feature X.
        MCP found limited references.
        Confidence: LOW

        Recommendation: Test in a sandbox environment first.
        Question: Can you share the Dify version you're targeting?"
```

---

## Creating New Agents

### 1. Choose a pattern

| Pattern | Best For | Example |
|---------|----------|---------|
| **Grounded** | Agents that validate against external docs | `dify-developer-specialist` |
| **Expert** | Agents with deep domain knowledge | `spark-specialist` |
| **Quality** | Agents that review and classify | `code-reviewer` |

### 2. Use the template

```bash
# Read the template
cat docs/agent-template.md
```

### 3. Create the agent file

Save to `.claude/agents/{category}/{agent-name}.md` with these required sections:

1. YAML frontmatter (`name`, `description`, `tools`)
2. Role and core philosophy
3. Knowledge base references
4. Core capabilities (3+ with code examples)
5. Invocation guidance (step-by-step)
6. Patterns and examples
7. Best practices (Always Do / Never Do)
8. Closing mission statement

### 4. Validate

```
Checklist:
[ ] YAML frontmatter has name, description, tools
[ ] Core philosophy is clear and memorable
[ ] KB files listed actually exist
[ ] At least 3 capabilities with code examples
[ ] Invocation section has clear steps
[ ] Best practices include domain-specific rules
[ ] Pattern extension matches chosen type
```

Full guide: [`docs/agent-template.md`](docs/agent-template.md)

---

## MCP Integration

MCP (Model Context Protocol) servers provide real-time intelligence that complements the offline knowledge base.

| Server | Best For | Query Example |
|--------|----------|---------------|
| **Context7** | Official library docs (Delta Lake, PySpark, Databricks) | `get-library-docs({ topic: "spark adaptive query execution" })` |
| **Ref Tools** | Microsoft Learn, tutorials, GitHub | `search({ query: "Azure Databricks Unity Catalog" })` |
| **Exa** | Code search, community examples, recent posts | `web_search_exa({ query: "Delta Lake liquid clustering 2025" })` |
| **Firecrawl** | Deep web scraping, blog posts, case studies | `firecrawl_deep_research({ query: "medallion architecture patterns" })` |

### Validation Strategy

```
+-------------------+     +-------------------+
|   KNOWLEDGE BASE  |     |   MCP SERVERS     |
|   (offline)       |     |   (real-time)     |
|                   |     |                   |
|   Curated         |     |   Current         |
|   Verified        |     |   Broad           |
|   Project-specific|     |   External        |
+--------+----------+     +--------+----------+
         |                         |
         +----------+--------------+
                    |
                    v
         +----------+----------+
         |   CONFIDENCE        |
         |   ASSESSMENT        |
         |                     |
         |   Both agree: HIGH  |
         |   One only: MEDIUM  |
         |   Conflict: FLAG    |
         |   Neither: LOW      |
         +---------------------+
```

---

## Project Stats

| Metric | Value |
|--------|-------|
| Agents | 17 across 7 categories |
| KB Files | 28 across 3 domains |
| KB Content | 13,800+ lines / 416 KB |
| Agent Patterns | 3 (Grounded, Expert, Quality) |
| MCP Servers | 4 (Context7, Exa, Firecrawl, Ref Tools) |
| Custom Commands | 1 (`/publish`) |
| Agent Sections | 8 required per agent |
| Confidence Levels | 5 (High, Medium, Low, Unknown, Conflict) |

---

## Contributing

### Adding a New Agent

1. Read [`docs/agent-template.md`](docs/agent-template.md) for the template
2. Read [`docs/executor-model.md`](docs/executor-model.md) for the framework
3. Create the agent in the appropriate `.claude/agents/{category}/` directory
4. Update `CLAUDE.md` with the new agent entry

### Adding KB Content

1. Place files in `kb/{domain}/` with numbered prefixes (`00-`, `01-`, etc.)
2. Include `Last Updated` and `MCP Validation` dates
3. Follow the existing structure within each domain

### Code Standards

- Python: PEP 8, type hints, Google-style docstrings
- Testing: `pytest` as default framework
- Project layout: `src/` with `pyproject.toml`
- Error handling: Explicit, with graceful degradation

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
