# Dify Platform Overview

## What is Dify?

Dify is an open-source LLM application development platform that enables building AI-powered applications through visual orchestration. It combines **no-code/low-code** development with production-grade capabilities for chatbots, AI agents, RAG systems, and workflow automation.

### Key Differentiators
- **Visual Orchestration**: Drag-and-drop workflow builder
- **Multi-LLM Support**: 50+ model providers (OpenAI, Anthropic, Google, Azure, local models)
- **RAG Pipeline**: Built-in knowledge base with hybrid search and reranking
- **Plugin Architecture**: Extensible via custom tools, model providers, agent strategies
- **Self-Hosted Option**: Full data control with Docker/Kubernetes deployment

## Platform Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Dify Platform                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Application Layer                             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │  Chatflow   │  │  Workflow   │  │  Agent + Text Generator │ │   │
│  │  │ (Multi-turn)│  │ (Stateless) │  │  (Tool-using, Single)   │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Orchestration Layer                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │   Nodes     │  │ Variables   │  │     Control Flow        │ │   │
│  │  │ (LLM, Code) │  │ (Sys, Conv) │  │ (IF/ELSE, Loop, Iter)   │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Intelligence Layer                            │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │  RAG/KB     │  │   Tools     │  │     Agent Strategies    │ │   │
│  │  │ (Retrieval) │  │ (APIs/Ext)  │  │ (FC, ReAct, CoT)        │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Infrastructure Layer                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │  Model      │  │   Vector    │  │      Plugin             │ │   │
│  │  │  Providers  │  │   Stores    │  │      Runtime            │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Application Types

### Chatflow (Conversational Applications)

**Purpose**: Build multi-turn conversational AI with memory and context management.

| Feature | Description |
|---------|-------------|
| **Conversation Memory** | Maintains context via `conversation_id` |
| **Session Variables** | Conversation variables persist across turns |
| **User Tracking** | Built-in `user_id` for personalization |
| **Streaming** | Real-time SSE response streaming |

**Use Cases**:
- Customer support chatbots
- Q&A assistants with knowledge bases
- Multi-step form collection
- Personalized recommendation systems

**Entry Points**:
```
Chat Trigger → Conversation Flow → Answer Node
```

### Workflow (Stateless Pipelines)

**Purpose**: Build automation pipelines for batch processing and integrations.

| Feature | Description |
|---------|-------------|
| **Stateless** | No memory between executions |
| **Input Variables** | Defined at workflow start |
| **Parallel Processing** | Concurrent node execution |
| **File Processing** | Built-in file handling |

**Use Cases**:
- Document processing pipelines
- Data transformation (ETL)
- Batch content generation
- API orchestration
- Scheduled automation

**Entry Points**:
```
API Trigger → Processing Nodes → End Node
```

### Agent (Autonomous Tool-Using AI)

**Purpose**: Build AI that can autonomously use tools and make decisions.

| Feature | Description |
|---------|-------------|
| **Tool Use** | Native function calling |
| **Reasoning** | ReAct, Chain-of-Thought |
| **Iteration** | Multi-step problem solving |
| **Knowledge Access** | RAG integration |

**Strategies**:
- **Function Calling**: Native LLM tool use (GPT-4, Claude)
- **ReAct**: Reasoning + Acting loop for complex tasks
- **Chain-of-Thought**: Step-by-step reasoning

### Text Generator (Single-Turn Completion)

**Purpose**: Simple completion tasks without conversation context.

**Use Cases**:
- Content generation
- Text summarization
- Translation
- Classification

## Chatflow vs Workflow Comparison

| Aspect | Chatflow | Workflow |
|--------|----------|----------|
| **State** | Conversation state (conversation_id) | Stateless per run |
| **Variables** | System + Conversation variables | Input variables only |
| **Memory** | Built-in conversation memory | No built-in memory |
| **Trigger** | Chat input, API | API, Manual, Scheduled |
| **Response** | Streaming supported | Blocking or async |
| **Best For** | Interactive applications | Batch processing |

## System Variables

Built-in variables available in all applications:

```python
sys.query                  # User's current input message
sys.user_id                # Unique user identifier
sys.conversation_id        # Session identifier (Chatflow only)
sys.files                  # Array of uploaded files
sys.dialogue_count         # Number of conversation turns
sys.app_id                 # Application identifier
sys.workflow_id            # Workflow identifier
sys.workflow_run_id        # Current execution ID
```

### File Object Structure
```json
{
  "type": "image",
  "transfer_method": "remote_url",
  "url": "https://example.com/image.png",
  "upload_file_id": "file-abc123"
}
```

## Conversation Variables

Session-scoped variables that persist across conversation turns:

### Supported Types
| Type | Description | Example |
|------|-------------|---------|
| `string` | Text values | `"user_name"`, `"language"` |
| `number` | Numeric values | `42`, `3.14` |
| `object` | JSON objects | `{"key": "value"}` |
| `array[string]` | String arrays | `["a", "b", "c"]` |
| `array[number]` | Number arrays | `[1, 2, 3]` |
| `array[object]` | Object arrays | `[{"id": 1}, {"id": 2}]` |

### Definition
```json
{
  "conversation_variables": [
    {
      "name": "user_preferences",
      "type": "object",
      "default": {},
      "description": "User preferences for this session"
    },
    {
      "name": "items_discussed",
      "type": "array[string]",
      "default": []
    }
  ]
}
```

### Access Patterns
```
In LLM Prompts:    {{#conversation.user_preferences#}}
In Code Nodes:     inputs["conversation_variables"]["user_preferences"]
In Templates:      {{ conversation.user_preferences }}
```

## Node Types Overview

### Input/Output Nodes
| Node | Purpose |
|------|---------|
| **Start** | Entry point, defines input variables |
| **End** | Exit point, defines outputs |
| **Answer** | Streaming text response |

### Processing Nodes
| Node | Purpose |
|------|---------|
| **LLM** | Language model invocation |
| **Code** | Python/JavaScript execution |
| **Template** | Jinja2 text templating |
| **HTTP Request** | External API calls |

### Logic Nodes
| Node | Purpose |
|------|---------|
| **IF/ELSE** | Conditional branching |
| **Iteration** | Loop over arrays |
| **Loop** | Conditional loops |
| **Variable Assigner** | Modify variables |
| **Variable Aggregator** | Combine outputs |

### Intelligence Nodes
| Node | Purpose |
|------|---------|
| **Knowledge Retrieval** | RAG query |
| **Agent** | Tool-using autonomous AI |
| **Question Classifier** | Intent classification |
| **Parameter Extractor** | Entity extraction |

### Integration Nodes
| Node | Purpose |
|------|---------|
| **Tool** | Custom tool invocation |
| **Doc Extractor** | Document parsing |
| **List Operator** | Array manipulation |

## Model Configuration

### Supported Providers
| Provider | Models | Features |
|----------|--------|----------|
| **OpenAI** | GPT-4o, GPT-4, GPT-3.5 | Function calling, vision |
| **Anthropic** | Claude 3.5, Claude 3 | Large context, tools |
| **Google** | Gemini Pro, PaLM | Multi-modal |
| **Azure OpenAI** | All OpenAI models | Enterprise features |
| **AWS Bedrock** | Claude, Titan | AWS integration |
| **Ollama** | Llama, Mistral | Local deployment |
| **vLLM** | Any HF model | High throughput |

### Model Parameters
```json
{
  "model": {
    "provider": "openai",
    "name": "gpt-4o",
    "mode": "chat"
  },
  "model_parameters": {
    "temperature": 0.7,
    "top_p": 1.0,
    "max_tokens": 4096,
    "presence_penalty": 0,
    "frequency_penalty": 0,
    "response_format": {"type": "json_object"}
  }
}
```

## RAG/Knowledge Base

### Pipeline Overview
```
Documents → Chunking → Embedding → Vector Store → Retrieval → Reranking → Context
```

### Search Methods
| Method | Description | Best For |
|--------|-------------|----------|
| **semantic_search** | Vector similarity | Conceptual queries |
| **keyword_search** | BM25 text matching | Exact term matching |
| **hybrid_search** | Combined approach | General use (recommended) |
| **full_text_search** | Elasticsearch-style | Large document sets |

### Reranking Models
- **Cohere rerank-english-v2.0**: English content
- **Cohere rerank-multilingual-v2.0**: Multi-language
- **BGE bge-reranker-v2-m3**: Self-hosted option

### Retrieval Configuration
```json
{
  "retrieval_model": {
    "search_method": "hybrid_search",
    "reranking_enable": true,
    "reranking_model": {
      "provider": "cohere",
      "model": "rerank-english-v2.0"
    },
    "top_k": 5,
    "score_threshold_enabled": true,
    "score_threshold": 0.5,
    "weights": {
      "semantic": 0.7,
      "keyword": 0.3
    }
  }
}
```

## API Structure

### Authentication
```http
Authorization: Bearer {api_key}
Content-Type: application/json
```

### Key Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/chat-messages` | POST | Chat completion |
| `/v1/workflows/run` | POST | Execute workflow |
| `/v1/completion-messages` | POST | Text completion |
| `/v1/conversations` | GET | List conversations |
| `/v1/messages` | GET | Message history |
| `/v1/datasets` | POST | Knowledge base ops |
| `/v1/files/upload` | POST | File upload |

### Response Modes
| Mode | Description |
|------|-------------|
| `blocking` | Wait for complete response |
| `streaming` | Server-Sent Events (SSE) |

## Plugin Architecture

### Plugin Types
| Type | Purpose |
|------|---------|
| **Tool** | Custom API tools |
| **Model Provider** | New LLM integrations |
| **Agent Strategy** | Custom reasoning patterns |
| **Extension** | Platform extensions |

### Plugin SDK (dify_plugin)
```python
from dify_plugin import DifyPluginEnv, Plugin
from dify_plugin.entities.tool import ToolInvokeMessage

class MyTool(Plugin):
    def _invoke(self, tool_parameters: dict) -> ToolInvokeMessage:
        result = process(tool_parameters["input"])
        return self.create_text_message(result)
```

## Best Practices

### Application Design
1. **Define clear schemas** for inputs/outputs
2. **Use conversation variables** for state management
3. **Implement error handling** with fallbacks
4. **Set appropriate model parameters** per task
5. **Configure response modes** based on UX needs

### Performance Optimization
1. **Enable caching** for repeated queries
2. **Use streaming** for better perceived latency
3. **Optimize chunk size** (300-500 tokens typical)
4. **Configure appropriate top_k** values (5-10)
5. **Enable reranking** for quality-critical apps

### Security
1. **Validate user inputs** before processing
2. **Sanitize tool outputs** to prevent injection
3. **Use environment variables** for secrets
4. **Implement rate limiting** on APIs
5. **Monitor for prompt injection** attempts

### Cost Management
1. **Use smaller models** for classification/routing
2. **Cache frequently accessed content**
3. **Set max_tokens appropriately**
4. **Monitor token usage** per endpoint
5. **Use economy indexing** for development

## Deployment Options

### Dify Cloud
- Managed service at api.dify.ai
- No infrastructure management
- Automatic updates

### Self-Hosted
```yaml
# docker-compose deployment
version: '3.8'
services:
  api:
    image: langgenius/dify-api
    environment:
      - DB_HOST=postgres
      - REDIS_HOST=redis
      - VECTOR_STORE=weaviate
  web:
    image: langgenius/dify-web
  worker:
    image: langgenius/dify-api
    command: celery
```

### Environment Variables
| Variable | Purpose |
|----------|---------|
| `SECRET_KEY` | Application secret |
| `DB_HOST` | PostgreSQL host |
| `REDIS_HOST` | Redis host |
| `VECTOR_STORE` | Vector DB (weaviate, qdrant, milvus) |
| `STORAGE_TYPE` | File storage (local, s3, azure) |

## Related KB Files

| File | Coverage |
|------|----------|
| [01-chatflow-development.md](01-chatflow-development.md) | Multi-turn conversation patterns |
| [02-workflow-development.md](02-workflow-development.md) | Workflow node patterns |
| [03-agents-tools.md](03-agents-tools.md) | Agent strategies and tools |
| [04-api-reference.md](04-api-reference.md) | Complete API documentation |
| [05-knowledge-base.md](05-knowledge-base.md) | RAG implementation |
| [06-nodes-reference.md](06-nodes-reference.md) | Node catalog and configuration |
| [07-plugins-development.md](07-plugins-development.md) | Plugin SDK guide |
