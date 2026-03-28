# Perfect Executor Model - Documentation

Architecture documentation for building reliable AI agents in Claude Code.

---

## Quick Start: Creating a New Agent

1. Read [executor-model.md](./executor-model.md) to understand the architecture
2. Choose your agent pattern (Grounded, Expert, or Quality)
3. Copy the matching template from [agent-template.md](./agent-template.md)
4. Fill in placeholders with your agent's specifics
5. Save to `.claude/agents/{agent-name}.md`

---

## Documentation

| Document | Purpose |
|----------|---------|
| [executor-model.md](./executor-model.md) | Complete architecture spec (pillars, KB, MCP, confidence, patterns) |
| [agent-template.md](./agent-template.md) | Copy-paste templates for 3 agent patterns |

---

## Project Structure

```
retail-max/
├── CLAUDE.md                          ← Project instructions
├── docs/                              ← You are here
│   ├── readme.md                      ← This file
│   ├── executor-model.md              ← Architecture spec
│   └── agent-template.md              ← Agent templates
├── kb/                                ← Knowledge base (by domain)
│   ├── lakeflow/                      ← Databricks Lakeflow
│   ├── spark/                         ← Apache Spark
│   └── dify/                          ← Dify AI platform
└── .claude/
    ├── settings.local.json
    ├── agent-memory/                  ← Persistent agent memory
    └── agents/                        ← All AI agents (11 total)
```

---

## Related

- [CLAUDE.md](../CLAUDE.md) - Project instructions and agent index
- [kb/](../kb/) - Domain-specific knowledge bases
