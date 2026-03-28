# The Perfect Executor Model

**Version:** 3.0
**Status:** Production Standard
**Applies To:** All Claude Code Agents

---

## Overview

The Perfect Executor Model is the architecture for building reliable AI agents. It solves the fundamental challenge: **how to execute tasks confidently without hallucination**.

**Core Principle:** *"Trust but Verify, Fail Gracefully"*

### The Three Pillars

```
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   GROUNDING   │  │  GUARDRAILS   │  │   GRACEFUL    │
│  (Knowledge)  │  │ (Validation)  │  │  DEGRADATION  │
│               │  │               │  │               │
│ "What do I    │  │ "Is it still  │  │ "What if I'm  │
│  know?"       │  │  true?"       │  │  uncertain?"  │
│               │  │               │  │               │
│ - Local KB    │  │ - MCP Query   │  │ - Disclaimer  │
│ - Project ctx │  │ - Agreement   │  │ - Partial ans │
│ - Domain exp  │  │   check       │  │ - Ask user    │
└───────────────┘  └───────────────┘  └───────────────┘
```

Not all agents implement all three pillars equally. See [Agent Patterns](#agent-patterns) for how agents apply these in practice.

---

## Pillar 1: Grounding (Knowledge Base)

The KB is the primary source of truth for project-specific patterns.

### KB Structure

```
kb/
├── lakeflow/       ← Databricks Lakeflow (DLT, CDC, expectations)
├── spark/          ← Apache Spark (performance, memory, joins)
└── dify/           ← Dify AI platform (chatflows, workflows, agents)
```

### KB Integration Rules

**Rule 1: Read KB First**
Before answering domain questions, read the relevant KB file. Never answer from memory alone.

**Rule 2: Cite Sources**
Reference KB file paths in responses (e.g., `kb/spark/01-performance-tuning.md`).

**Rule 3: Note Gaps**
When KB doesn't cover a topic, explicitly say so. Don't pretend KB has it.

**Rule 4: KB Wins for Project Context**
When KB has a project-specific pattern that differs from generic documentation, KB wins.

### KB Query Patterns

**Single File** - For focused questions:
```
Read kb/spark/01-performance-tuning.md → Extract relevant section → Answer with citation
```

**Multi-File** - For questions spanning topics:
```
Read kb/spark/01-performance-tuning.md + kb/spark/03-partitioning-shuffle.md → Synthesize → Answer
```

**Cross-Section** - For questions spanning domains:
```
Read kb/lakeflow/05-configuration/pipeline-configuration.md (primary)
Read kb/spark/05-best-practices.md (supporting)
→ Combine patterns → Answer
```

---

## Pillar 2: Guardrails (MCP Validation)

MCP tools provide real-time validation against current documentation.

### Available MCP Servers

| Server | Tool Prefix | Best For |
|--------|-------------|----------|
| **Context7** | `mcp__upstash-context-7-mcp__*` | Official library docs |
| **Ref Tools** | `mcp__ref-tools-ref-tools-mcp__*` | Tutorials, Microsoft Learn |
| **Exa** | `mcp__exa__*` | Code search, community examples |
| **Firecrawl** | `mcp__krieg-2065-firecrawl-mcp-server__*` | Deep web scraping |

### Essential MCP Patterns

**Resolve Library ID:**
```typescript
mcp__upstash-context-7-mcp__resolve-library-id({
  libraryName: "delta lake"  // or "pyspark", "databricks"
})
```

**Query Documentation:**
```typescript
mcp__upstash-context-7-mcp__get-library-docs({
  context7CompatibleLibraryID: "{library-id}",
  topic: "{balanced-keywords}",
  tokens: 5000
})
```

**Search Tutorials:**
```typescript
mcp__ref-tools-ref-tools-mcp__ref_search_documentation({
  query: "{technology} {topic} tutorial"
})
```

**Code Examples:**
```typescript
mcp__exa__get_code_context_exa({
  query: "{technology} {task} code example",
  tokensNum: 5000
})
```

**Deep Research:**
```typescript
mcp__krieg-2065-firecrawl-mcp-server__firecrawl_deep_research({
  query: "{topic} best practices",
  maxDepth: 3, maxUrls: 20, timeLimit: 60
})
```

### MCP Response Handling

| Response | Action |
|----------|--------|
| **Content returned** | Extract info, compare with KB, determine agreement |
| **Empty / No results** | Note as "silent", fall back to KB-only (MEDIUM confidence) |
| **Error / Timeout** | Fall back to KB-only, note limitation |
| **Contradicts KB** | Flag as CONFLICT, investigate before proceeding |

---

## Pillar 3: Graceful Degradation

When confidence is insufficient, fail safely rather than hallucinate.

### Confidence Levels

| Level | When | Agent Action |
|-------|------|-------------|
| **HIGH** | KB has pattern + MCP confirms | Execute with full confidence |
| **MEDIUM** | KB has pattern, MCP silent or unavailable | Execute with disclaimer |
| **LOW** | Neither KB nor MCP has info | Partial answer, flag gaps, ask user |
| **CONFLICT** | KB and MCP disagree | Investigate, present both options |

### Conflict Resolution

When KB and MCP disagree:

1. **Check Recency** - MCP shows API change or deprecation → MCP wins
2. **Check Specificity** - KB has project-specific pattern → KB wins
3. **Still Unclear** - Present both options to user with trade-offs

### Response When Uncertain

```markdown
**What I know:**
- {partial information from KB/MCP}

**What I'm uncertain about:**
- {specific gaps}

**Recommended next steps:**
1. {action to get more info}
2. {alternative approach}

Would you like me to proceed with partial information or research further?
```

---

## Agent Patterns

Agents follow 3 distinct patterns based on their domain needs:

### Pattern 1: Grounded Agent

**Used by:** `dify-developer-specialist`

Full implementation of all 3 pillars: KB files + MCP validation + confidence levels + graceful degradation.

```
KB files → MCP validation → Agreement check → Confidence level → Execute/Degrade
```

**When to use:** Domains where documentation changes frequently and accuracy is critical.

### Pattern 2: Expert Agent

**Used by:** `spark-specialist`, `spark-streaming-architect`, `spark-troubleshooter`, `spark-performance-analyzer`

Implements Pillar 1 (Grounding) strongly. KB + deep technical patterns + production checklists. Minimal or no MCP validation.

```
KB files → Expert patterns → Code examples → Production checklists
```

**When to use:** Mature, stable domains where KB content is reliable and comprehensive.

### Pattern 3: Quality Agent

**Used by:** `code-reviewer`, `code-cleaner`, `code-documenter`

Implements Pillars 1+3 via conventions. Uses project conventions instead of KB files, with confidence-based severity classification.

```
Project conventions → Analysis → Severity classification → Recommendations
```

**When to use:** Cross-domain agents that operate on code quality, not domain knowledge.

### Standalone Agents

**`the-planner`** and **`linear-project-manager`** are task-oriented agents that don't follow KB/MCP patterns. They focus on planning and project management workflows.

**`staff-ai-data-engineer`** is a comprehensive skill agent with its own memory system.

---

## Agent Sections

Every agent MUST include these 8 sections (the common foundation):

| # | Section | Purpose |
|---|---------|---------|
| 1 | **YAML Frontmatter** | name, description, tools |
| 2 | **Role + Philosophy** | Who you are, core belief |
| 3 | **Knowledge Base** | KB files or project conventions |
| 4 | **Core Capabilities** | What you can do (domain expertise) |
| 5 | **Invocation Guidance** | What to do when called |
| 6 | **Patterns & Examples** | Working code, configs, workflows |
| 7 | **Best Practices** | Always/Never rules, checklists |
| 8 | **Closing Statement** | Mission reminder |

Additional sections depend on the agent pattern (see [agent-template.md](./agent-template.md)).

---

## Checklist for New Agents

Before deploying a new agent:

- [ ] YAML frontmatter has name, description, and tools
- [ ] Agent pattern chosen (Grounded, Expert, or Quality)
- [ ] KB files listed (if applicable) and verified to exist
- [ ] At least 3 capabilities with code examples
- [ ] Best practices include domain-specific Always/Never rules
- [ ] Closing statement captures the agent's mission
- [ ] File saved to `.claude/agents/{agent-name}.md`

---

*"Trust but Verify, Fail Gracefully"*
