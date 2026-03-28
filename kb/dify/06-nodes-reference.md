# Dify Nodes Reference

Complete catalog of all Dify workflow and chatflow nodes with configuration patterns.

## Node Categories

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Dify Node Taxonomy                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  TRIGGERS          PROCESSING        LOGIC           INTELLIGENCE   │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐   │
│  │ Start   │      │ LLM     │      │ IF/ELSE │      │Knowledge│   │
│  │ End     │      │ Code    │      │ Iteration│     │Retrieval│   │
│  │ Answer  │      │Template │      │ Loop    │      │ Agent   │   │
│  └─────────┘      │HTTP Req │      │Var Assign│     │Question │   │
│                   └─────────┘      │Var Aggr │      │Classifier│  │
│                                    └─────────┘      │Parameter│   │
│                                                      │Extractor│   │
│                                                      └─────────┘   │
│                                                                      │
│  INTEGRATION       UTILITY                                          │
│  ┌─────────┐      ┌─────────┐                                      │
│  │ Tool    │      │Doc Extr │                                      │
│  │ Plugin  │      │List Op  │                                      │
│  └─────────┘      │Assemble │                                      │
│                   └─────────┘                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Start Node

Entry point for workflows and chatflows. Defines input variables.

### Configuration

```yaml
start_node:
  type: start
  variables:
    - name: query
      type: string
      required: true
      max_length: 2000
      description: "User input message"

    - name: context
      type: object
      required: false
      default: {}

    - name: files
      type: array[file]
      required: false
      allowed_types: ["image", "document"]
      max_count: 5
```

### Variable Types (Actual UI Options)

| UI Type | Internal Type | Description | Use Case |
|---------|---------------|-------------|----------|
| **Short Text** | `string` | Single-line text | Names, IDs |
| **Paragraph** | `string` | Multi-line text | **JSON objects as string** |
| **Select** | `string` | Dropdown options | Enums, choices |
| **Number** | `number` | Numeric input | Counts, scores |
| **Checkbox** | `boolean` | True/False | Flags, toggles |
| **Single File** | `file` | Single upload | Document, image |
| **File List** | `array[file]` | Multiple uploads | Batch files |

#### Passing Objects (JSON) as Input

**IMPORTANT:** Dify UI does not have a native `object` type for Start Node inputs.
To pass complex objects like `lead_profile`, use **Paragraph** type and parse with Code Node:

```yaml
start_node:
  variables:
    - name: lead_profile
      type: Paragraph  # JSON string from n8n
      required: true
      description: "Lead profile as JSON string"

code_node:
  title: "Parse Lead Profile"
  code: |
    import json
    def main(lead_profile: str) -> dict:
        profile = json.loads(lead_profile)
        return {"profile": profile}
```

n8n sends: `"inputs": {"lead_profile": "{{JSON.stringify($json.lead_profile)}}"}`

### System Variables (Auto-Available)

```python
sys.query              # User message (Chatflow)
sys.user_id            # User identifier
sys.conversation_id    # Session ID (Chatflow)
sys.files              # Uploaded files
sys.dialogue_count     # Turn number (Chatflow)
sys.app_id             # Application ID
sys.workflow_id        # Workflow ID
sys.workflow_run_id    # Execution ID
```

## End Node

Exit point that defines workflow outputs.

### Configuration

```yaml
end_node:
  type: end
  outputs:
    - name: result
      type: object
      value: "{{code_node.output}}"

    - name: summary
      type: string
      value: "{{llm_node.text}}"

    - name: metadata
      type: object
      value:
        status: "success"
        tokens_used: "{{sys.total_tokens}}"
        execution_time: "{{sys.elapsed_time}}"
```

### Output Modes

| Mode | Description |
|------|-------------|
| **Single Output** | One result object |
| **Multiple Outputs** | Named output variables |
| **Structured** | Schema-validated JSON |

## Answer Node

Streaming response node for chatflows.

### Configuration

```yaml
answer_node:
  type: answer
  content: "{{llm_node.text}}"
  streaming: true
  metadata:
    sources: "{{knowledge_retrieval.sources}}"
```

### Content Sources

```
Direct Text:     "Hello, how can I help?"
Variable:        {{llm_node.text}}
Template:        "Based on {{topic}}, here's the answer: {{response}}"
Conditional:     {{#if has_results}}{{results}}{{else}}No results{{/if}}
```

## LLM Node

Language model invocation with prompt engineering capabilities.

### Basic Configuration

```yaml
llm_node:
  type: llm
  model:
    provider: openai
    name: gpt-4o
    mode: chat

  parameters:
    temperature: 0.7
    top_p: 1.0
    max_tokens: 4096
    presence_penalty: 0
    frequency_penalty: 0
```

### Prompt Structure

```yaml
prompts:
  system: |
    You are a helpful assistant specialized in {{domain}}.

    Guidelines:
    1. Be concise and accurate
    2. Cite sources when available
    3. Ask for clarification if needed

    Context: {{#conversation.context#}}

  user: |
    {{#sys.query#}}

    {{#if knowledge_results}}
    Relevant information:
    {{knowledge_results}}
    {{/if}}

  assistant_prefix: |
    Based on the provided information,
```

### Memory Configuration (Chatflow)

```yaml
memory:
  enabled: true
  type: window
  window_size: 10
  include_system: true
  role_prefix:
    user: "Human"
    assistant: "AI"
```

### Vision Mode

```yaml
vision:
  enabled: true
  detail: high
  image_variable: "{{sys.files}}"
```

### Structured Output (JSON Mode)

```yaml
output_schema:
  type: json_object
  schema:
    type: object
    properties:
      answer:
        type: string
        description: "The main response"
      confidence:
        type: number
        minimum: 0
        maximum: 1
      sources:
        type: array
        items:
          type: string
    required: ["answer", "confidence"]
```

### Context Variables

```
{{#sys.query#}}                    # User input
{{#conversation.variable_name#}}   # Conversation variable
{{#node_id.output_key#}}           # Previous node output
{{#env.API_KEY#}}                  # Environment variable
```

## Code Node

Execute Python or JavaScript code within workflows.

### Python Execution

```python
def main(inputs: dict) -> dict:
    """
    Process input data and return results.

    Args:
        inputs: Dictionary containing all input variables

    Returns:
        Dictionary with output keys
    """
    import json
    from datetime import datetime

    query = inputs.get("query", "")
    data = inputs.get("data", [])

    processed_items = []
    for item in data:
        processed_items.append({
            "id": item["id"],
            "normalized": item["name"].lower().strip(),
            "score": calculate_score(item)
        })

    return {
        "results": processed_items,
        "count": len(processed_items),
        "processed_at": datetime.now().isoformat()
    }

def calculate_score(item: dict) -> float:
    return (item.get("value", 0) * item.get("weight", 1)) / 100
```

### JavaScript Execution

```javascript
async function main(inputs) {
    const { data, options } = inputs;

    const processed = data.map(item => ({
        id: item.id,
        transformed: transform(item),
        timestamp: new Date().toISOString()
    }));

    return {
        results: processed,
        total: processed.length
    };
}

function transform(item) {
    return {
        ...item,
        normalized_name: item.name.toLowerCase().trim()
    };
}
```

### Available Libraries

**Python:**

- `json`, `datetime`, `re`, `math`
- `requests` (HTTP calls)
- `pandas` (data manipulation)
- `numpy` (numerical operations)

**JavaScript:**

- Standard ES6+ features
- `fetch` for HTTP requests
- `JSON` utilities

### Input/Output Schema

```yaml
code_node:
  type: code
  language: python

  inputs:
    - name: data
      type: array[object]
      source: "{{http_request.response}}"
    - name: config
      type: object
      source: "{{start.config}}"

  outputs:
    - name: results
      type: array[object]
    - name: summary
      type: object
```

## Template Node

Jinja2-based text templating.

### Configuration

```yaml
template_node:
  type: template
  engine: jinja2

  template: |
    # Report: {{ title }}

    **Generated:** {{ timestamp }}
    **Author:** {{ author }}

    ## Summary
    {{ summary }}

    ## Items
    {% for item in items %}
    ### {{ item.name }}
    - Value: {{ item.value }}
    - Status: {{ item.status | default('pending') }}
    {% endfor %}

    {% if notes %}
    ## Notes
    {{ notes }}
    {% endif %}

  variables:
    title: "{{start.report_title}}"
    timestamp: "{{code_node.timestamp}}"
    author: "{{sys.user_id}}"
    summary: "{{llm_node.summary}}"
    items: "{{data_processor.items}}"
    notes: "{{start.additional_notes}}"
```

### Jinja2 Features

```jinja2
{# Variables #}
{{ variable }}
{{ object.property }}
{{ array[0] }}

{# Filters #}
{{ text | upper }}
{{ number | round(2) }}
{{ list | length }}
{{ value | default('N/A') }}
{{ json_data | tojson }}

{# Control Flow #}
{% if condition %}...{% endif %}
{% for item in items %}...{% endfor %}
{% set var = value %}

{# Comments #}
{# This is a comment #}
```

## HTTP Request Node

External API calls with full request configuration.

### Configuration

```yaml
http_request:
  type: http_request

  method: POST
  url: "https://api.example.com/v1/process"

  headers:
    Authorization: "Bearer {{#env.API_KEY#}}"
    Content-Type: "application/json"
    X-Request-ID: "{{sys.workflow_run_id}}"

  query_params:
    page: "{{start.page}}"
    limit: 100

  body:
    type: json
    content:
      input: "{{start.data}}"
      options:
        format: "json"
        validate: true

  timeout: 30000

  retry:
    enabled: true
    max_attempts: 3
    backoff: exponential
    initial_delay: 1000

  error_handling:
    on_error: continue
    fallback_value: null
```

### Request Methods

| Method | Body Support | Use Case |
|--------|--------------|----------|
| GET | No | Retrieve data |
| POST | Yes | Create/process |
| PUT | Yes | Update |
| PATCH | Yes | Partial update |
| DELETE | Optional | Remove |

### Body Types

```yaml
# JSON Body
body:
  type: json
  content:
    key: "value"

# Form Data
body:
  type: form-data
  content:
    - key: "file"
      type: file
      value: "{{sys.files[0]}}"
    - key: "metadata"
      type: text
      value: "{{start.metadata}}"

# Raw Text
body:
  type: raw
  content: "Plain text content"

# x-www-form-urlencoded
body:
  type: x-www-form-urlencoded
  content:
    field1: "value1"
    field2: "value2"
```

### Response Handling

```yaml
response:
  extract:
    data: "$.data"
    status: "$.status"
    items: "$.results[*]"
    first_item: "$.results[0]"
```

## IF/ELSE Node

Conditional branching based on expressions.

### Configuration

```yaml
if_else:
  type: if_else

  conditions:
    - id: high_priority
      expression: "{{llm_node.priority}} == 'high'"
      output: urgent_path

    - id: has_errors
      expression: "{{validator.errors | length}} > 0"
      output: error_path

    - id: confidence_check
      expression: "{{classifier.confidence}} >= 0.8"
      output: confident_path

  else_output: default_path
```

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `{{a}} == 'value'` |
| `!=` | Not equal | `{{a}} != null` |
| `>` | Greater than | `{{score}} > 0.5` |
| `>=` | Greater or equal | `{{count}} >= 10` |
| `<` | Less than | `{{age}} < 18` |
| `<=` | Less or equal | `{{price}} <= 100` |
| `contains` | String contains | `{{text}} contains 'error'` |
| `not contains` | Doesn't contain | `{{msg}} not contains 'fail'` |
| `starts with` | Prefix match | `{{id}} starts with 'PRD'` |
| `ends with` | Suffix match | `{{file}} ends with '.pdf'` |
| `is empty` | Empty check | `{{list}} is empty` |
| `is not empty` | Not empty | `{{data}} is not empty` |

### Logical Operators

```yaml
# AND condition
expression: "{{a}} > 10 and {{b}} == 'active'"

# OR condition
expression: "{{status}} == 'error' or {{retries}} >= 3"

# NOT condition
expression: "not {{is_valid}}"

# Parentheses for grouping
expression: "({{a}} > 10 or {{b}} > 20) and {{c}} == true"
```

## Iteration Node

Loop over arrays with parallel or sequential processing.

### Configuration

```yaml
iteration:
  type: iteration

  input_array: "{{http_request.data.items}}"
  iterator_variable: "current_item"
  index_variable: "current_index"

  max_iterations: 100
  parallel: false
  parallel_count: 5

  error_handling:
    on_item_error: continue
    collect_errors: true
```

### Inner Nodes Pattern

```yaml
iteration_body:
  nodes:
    - id: process_item
      type: llm
      config:
        prompt: "Analyze: {{current_item.content}}"

    - id: transform_item
      type: code
      config:
        code: |
          def main(inputs):
              item = inputs["current_item"]
              analysis = inputs["process_item"]
              return {
                  "id": item["id"],
                  "analysis": analysis,
                  "index": inputs["current_index"]
              }
```

### Output Aggregation

```yaml
output:
  aggregation: array_concat
  variable: "processed_items"
```

## Loop Node

Conditional loop with exit conditions.

### Configuration

```yaml
loop:
  type: loop

  max_iterations: 10

  exit_conditions:
    - expression: "{{agent.finished}} == true"
    - expression: "{{iteration_count}} >= {{max_retries}}"
    - expression: "{{result.confidence}} >= 0.95"

  loop_variables:
    - name: iteration_count
      initial: 0
      increment: 1
    - name: accumulated_context
      initial: []
```

## Variable Assigner Node

Set or modify conversation and workflow variables.

### Configuration

```yaml
variable_assigner:
  type: variable_assigner

  assignments:
    - variable: "conversation.user_name"
      operation: set
      value: "{{extractor.name}}"

    - variable: "conversation.history"
      operation: append
      value: "{{llm_node.response}}"

    - variable: "conversation.score"
      operation: increment
      value: 1

    - variable: "workflow.items"
      operation: extend
      value: "{{new_items}}"
```

### Operations

| Operation | Description | Applicable Types |
|-----------|-------------|------------------|
| `set` | Replace value | All |
| `append` | Add to array | Arrays |
| `extend` | Merge arrays | Arrays |
| `increment` | Add number | Numbers |
| `decrement` | Subtract | Numbers |
| `clear` | Reset to default | All |

## Variable Aggregator Node

Combine outputs from parallel branches or iterations.

### Configuration

```yaml
aggregator:
  type: variable_aggregator

  inputs:
    - source: "branch_a.result"
    - source: "branch_b.result"
    - source: "branch_c.result"

  aggregation_method: object_merge

  output_variable: "combined_results"
```

### Aggregation Methods

| Method | Description | Output |
|--------|-------------|--------|
| `array_concat` | Concatenate arrays | Array |
| `object_merge` | Merge objects | Object |
| `first_non_null` | First valid value | Any |
| `sum` | Sum numbers | Number |
| `average` | Average numbers | Number |
| `min` | Minimum value | Number |
| `max` | Maximum value | Number |

## Knowledge Retrieval Node

RAG query against knowledge bases.

### Configuration

```yaml
knowledge_retrieval:
  type: knowledge_retrieval

  knowledge_bases:
    - id: "kb-product-docs"
      enabled: true
    - id: "kb-support-faq"
      enabled: true

  query_variable: "{{sys.query}}"

  retrieval_model:
    search_method: hybrid_search
    top_k: 5
    score_threshold_enabled: true
    score_threshold: 0.5

    weights:
      semantic: 0.7
      keyword: 0.3

    reranking_enable: true
    reranking_model:
      provider: cohere
      model: rerank-english-v2.0
    reranking_top_k: 3

  query_rewrite:
    enabled: true
    model: gpt-3.5-turbo
```

### Output Structure

```json
{
  "results": [
    {
      "content": "Retrieved text chunk...",
      "score": 0.92,
      "document_id": "doc-001",
      "document_name": "Product Guide",
      "segment_id": "seg-123",
      "position": 1,
      "metadata": {
        "source": "manual",
        "category": "setup"
      }
    }
  ],
  "total_count": 5
}
```

## Question Classifier Node

Classify user intent into predefined categories.

### Configuration

```yaml
question_classifier:
  type: question_classifier

  model:
    provider: openai
    name: gpt-3.5-turbo

  input_variable: "{{sys.query}}"

  classes:
    - id: order_status
      name: "Order Status"
      description: "Questions about order tracking, delivery, shipping"
      examples:
        - "Where is my order?"
        - "When will my package arrive?"
        - "Track order #12345"

    - id: product_inquiry
      name: "Product Inquiry"
      description: "Questions about products, features, pricing"
      examples:
        - "How much does X cost?"
        - "What colors are available?"

    - id: complaint
      name: "Complaint"
      description: "Complaints, issues, problems"
      examples:
        - "I'm not satisfied"
        - "This is broken"

    - id: general
      name: "General"
      description: "General questions, greetings"
      examples:
        - "Hello"
        - "Thank you"
```

### Output

```json
{
  "class_id": "order_status",
  "class_name": "Order Status",
  "confidence": 0.95
}
```

## Parameter Extractor Node

Extract structured data from natural language.

### Configuration

```yaml
parameter_extractor:
  type: parameter_extractor

  model:
    provider: openai
    name: gpt-4o

  input_variable: "{{sys.query}}"

  parameters:
    - name: order_id
      type: string
      description: "Order identifier, format: ORD-XXXXXX"
      required: true
      validation: "^ORD-[0-9]{6}$"

    - name: email
      type: string
      description: "Customer email address"
      required: false
      validation: "^[^@]+@[^@]+\\.[^@]+$"

    - name: date_range
      type: object
      description: "Date range for query"
      properties:
        start_date:
          type: string
          format: date
        end_date:
          type: string
          format: date

    - name: product_ids
      type: array
      items:
        type: string
      description: "List of product IDs"

  extraction_prompt: |
    Extract the following information from the user's message.
    If a parameter is not mentioned, leave it null.
    Be precise with formats and validation.
```

### Output

```json
{
  "order_id": "ORD-123456",
  "email": "user@example.com",
  "date_range": {
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  },
  "product_ids": ["PRD-001", "PRD-002"],
  "extraction_confidence": 0.92
}
```

## Agent Node

Autonomous tool-using AI within workflows.

### CRITICAL: Agent Node Input Architecture

**Understanding the Two Input Channels:**

Agent Nodes have separate fields for different purposes:

| Field | Purpose | Configuration |
|-------|---------|---------------|
| **INSTRUCTION** | System prompt with agent personality, context, rules | Node panel → INSTRUCTION |
| **User** | User message input | Automatically receives `{{#sys.query#}}` |
| **Context** | Additional context (must be a LIST) | Node panel → Context |

**Common Errors and Solutions:**

```yaml
# ❌ ERROR: "Variable '' does not exist"
# Cause: Redundant {{#sys.query#}} in INSTRUCTION when User field already has it
system_prompt: |
  **User Message:** {{#sys.query#}}  # WRONG - redundant!

# ✅ CORRECT: User message is in dedicated User field
system_prompt: |
  ## Context from Orchestrator
  - Stage: {{#llm.structured_output.current_stage#}}
  - Action: {{#llm.structured_output.context_for_agent.priority_action#}}
  # User message automatically provided via User field - don't duplicate!

# ❌ ERROR: "ReActParams context - Input should be a valid list"
# Cause: Passing JSON object to Context field
context: "{{#llm.structured_output#}}"  # WRONG - expects list!

# ✅ CORRECT: Leave Context empty, put orchestrator data in INSTRUCTION
context: []
instruction: |
  Use this context: {{#llm.structured_output.context_for_agent#}}
```

**Best Practice for Multi-Agent Chatflows:**

When building supervisor-worker patterns:
1. Put orchestrator output references in **INSTRUCTION** field
2. Leave **Context** field empty (or provide a proper list)
3. Do NOT add `{{#sys.query#}}` in INSTRUCTION - the **User** field handles this
4. Reference previous node outputs using correct Dify syntax: `{{#node_id.output_path#}}`

### Configuration

```yaml
agent:
  type: agent

  model:
    provider: openai
    name: gpt-4o

  strategy: function_call

  system_prompt: |
    You are a research assistant with access to tools.
    Use tools to gather information and complete tasks.

  tools:
    - type: builtin
      name: web_search
    - type: builtin
      name: calculator
    - type: knowledge
      knowledge_base_id: "kb-docs"
    - type: workflow
      workflow_id: "wf-processor"

  max_iterations: 10

  tool_call_config:
    parallel_calls: true
    tool_choice: auto
```

### Tool Types

| Type | Description |
|------|-------------|
| `builtin` | Platform tools (web_search, calculator) |
| `custom` | OpenAPI-defined tools |
| `knowledge` | Knowledge base retrieval |
| `workflow` | Execute sub-workflow |

## Tool Node

Invoke custom or built-in tools.

### Configuration

```yaml
tool:
  type: tool

  tool_type: custom
  tool_id: "weather_api"

  inputs:
    location: "{{extractor.city}}"
    units: "metric"

  timeout: 10000

  error_handling:
    on_error: fallback
    fallback_value:
      temperature: null
      conditions: "Unable to fetch weather"
```

### Built-in Tools

| Tool | Purpose |
|------|---------|
| `web_search` | Search the web |
| `wikipedia` | Wikipedia lookup |
| `calculator` | Math calculations |
| `current_time` | Current datetime |
| `weather` | Weather data |

## Document Extractor Node

Parse and extract content from documents.

### Configuration

```yaml
doc_extractor:
  type: doc_extractor

  input_file: "{{sys.files[0]}}"

  extraction_mode: full

  options:
    ocr_enabled: true
    ocr_language: "en"
    extract_tables: true
    extract_images: false
    preserve_formatting: true

  output_format: markdown
```

### Supported Formats

| Format | OCR Support | Tables |
|--------|-------------|--------|
| PDF | Yes | Yes |
| DOCX | N/A | Yes |
| XLSX | N/A | Yes |
| Images | Yes | Limited |
| HTML | N/A | Yes |

## List Operator Node

Array manipulation operations.

### Configuration

```yaml
list_operator:
  type: list_operator

  input: "{{data_source.items}}"

  operations:
    - type: filter
      condition: "item.status == 'active'"

    - type: map
      expression: |
        {
          "id": item.id,
          "name": item.name.toUpperCase()
        }

    - type: sort
      key: "score"
      order: descending

    - type: limit
      count: 10

    - type: unique
      key: "category"
```

### Available Operations

| Operation | Description |
|-----------|-------------|
| `filter` | Keep items matching condition |
| `map` | Transform each item |
| `sort` | Order by field |
| `limit` | Restrict count |
| `slice` | Get range of items |
| `unique` | Remove duplicates |
| `flatten` | Flatten nested arrays |
| `group_by` | Group by field |
| `reduce` | Aggregate to single value |

## Node Connection Patterns

### Sequential Flow

```
Start → LLM → Code → End
```

### Parallel Branches

```
          ┌─→ Branch A ─┐
Start ──→ │             ├─→ Aggregator → End
          └─→ Branch B ─┘
```

### Conditional Routing

```
Start → IF/ELSE ─┬─→ Path A → End A
                 ├─→ Path B → End B
                 └─→ Default → End C
```

### Iteration Pattern

```
Start → Iteration ─┬─→ Process ─┬─→ Aggregator → End
                   │            │
                   └────────────┘
```

### Agent Loop

```
Start → Agent ─┬─→ Tool Call ─┬─→ Answer → End
               │              │
               └──────────────┘
```

## Best Practices

### Node Naming

```yaml
naming_conventions:
  llm_nodes: "llm_{purpose}"
  code_nodes: "code_{function}"
  conditions: "check_{condition}"
  retrievals: "retrieve_{source}"
```

### Error Handling

```yaml
error_patterns:
  retry_transient:
    - http_request
    - tool
  fallback_graceful:
    - llm
    - knowledge_retrieval
  fail_fast:
    - validation_code
```

### Performance

```yaml
optimization:
  parallel_execution:
    - independent_branches
    - iteration_items (when safe)
  caching:
    - knowledge_retrieval
    - http_request (idempotent)
  streaming:
    - llm_final_response
    - answer_node
```
