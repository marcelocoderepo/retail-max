# Dify Chatflow Development

## Chatflow Architecture

Chatflows are conversational AI applications that maintain state across multiple turns. They're ideal for interactive assistants, customer support, and Q&A systems.

### Chatflow Structure
```
┌─────────────────────────────────────────────────────┐
│                    Chatflow                         │
├─────────────────────────────────────────────────────┤
│  ┌─────────┐   ┌─────────┐   ┌─────────────────┐   │
│  │  Start  │ → │  LLM    │ → │  Answer/End     │   │
│  │ (Input) │   │ (Chat)  │   │  (Response)     │   │
│  └─────────┘   └─────────┘   └─────────────────┘   │
│                     │                               │
│              ┌──────┴──────┐                       │
│              │  Knowledge  │                       │
│              │  Retrieval  │                       │
│              └─────────────┘                       │
└─────────────────────────────────────────────────────┘
```

## Conversation Variables

### Definition
Conversation variables persist across conversation turns within a session.

```python
variables = {
    "name": "user_preferences",
    "type": "object",
    "default": {},
    "description": "Stores user preferences during conversation"
}
```

### Variable Types

| Type | Use Case | Example |
|------|----------|---------|
| `string` | Single values | `user_name`, `language` |
| `number` | Counters, scores | `attempt_count`, `satisfaction_score` |
| `object` | Complex state | `user_profile`, `cart_state` |
| `array[string]` | Lists | `topics_discussed`, `preferences` |
| `array[object]` | Collections | `order_items`, `search_history` |

### Setting Variables

#### Via Variable Assigner Node
```yaml
Node: Variable Assigner
Configuration:
  variable: user_preferences
  operation: set
  value: "{{ code_output.preferences }}"
```

#### Via Code Node
```python
def main(inputs: dict) -> dict:
    preferences = {
        "theme": inputs.get("theme", "light"),
        "language": inputs.get("language", "en")
    }
    return {"preferences": preferences}
```

### Reading Variables
In LLM prompts:
```
User preferences: {{#conversation.user_preferences#}}
Previous topics: {{#conversation.topics_discussed#}}
```

## Start Node Configuration

### Input Variables
```yaml
start_node:
  inputs:
    - name: query
      type: string
      required: true
      description: User's message
    - name: context
      type: object
      required: false
      default: {}
      description: Additional context
```

### System Variables Access
```python
sys.query              # Current user input
sys.user_id            # User identifier
sys.conversation_id    # Session ID
sys.files              # Uploaded files
sys.dialogue_count     # Turn number
```

## LLM Node Configuration

### Basic Configuration
```yaml
llm_node:
  model:
    provider: openai
    name: gpt-4o
  parameters:
    temperature: 0.7
    max_tokens: 2048
    top_p: 1.0
```

### Prompt Engineering

#### System Prompt
```text
You are a helpful customer service assistant for {{#company_name#}}.

Current user context:
- Name: {{#conversation.user_name#}}
- Previous interactions: {{#conversation.interaction_count#}}

Guidelines:
1. Be concise and helpful
2. If you don't know, say so
3. Always verify sensitive operations
```

#### User Prompt Template
```text
User query: {{#sys.query#}}

{{#if knowledge_results#}}
Relevant information:
{{#knowledge_results#}}
{{/if}}

Please provide a helpful response.
```

### Context Window Management
```yaml
memory:
  type: conversation_window
  window_size: 10  # Last 10 messages
  token_limit: 4000
```

## Knowledge Retrieval Integration

### Basic RAG Setup
```yaml
knowledge_retrieval:
  knowledge_bases:
    - id: "kb-001"
      name: "Product Documentation"
  settings:
    search_method: hybrid_search
    top_k: 5
    score_threshold: 0.5
    reranking: true
```

### Query Rewriting
```yaml
query_rewrite:
  enabled: true
  model: gpt-3.5-turbo
  prompt: |
    Given the conversation history and current query,
    rewrite the query to be self-contained for search.

    History: {{#conversation_history#}}
    Current query: {{#sys.query#}}

    Rewritten query:
```

## Conditional Logic

### IF/ELSE Node
```yaml
if_node:
  conditions:
    - variable: "{{#llm_output.intent#}}"
      operator: equals
      value: "escalate"
      then: escalation_path
    - variable: "{{#llm_output.confidence#}}"
      operator: less_than
      value: 0.7
      then: clarification_path
  else: default_path
```

### Intent-Based Routing
```yaml
intent_router:
  conditions:
    - intent: "order_status"
      route: order_lookup_flow
    - intent: "product_inquiry"
      route: product_rag_flow
    - intent: "complaint"
      route: escalation_flow
  default: general_assistant
```

## Answer Node Configuration

### Streaming Response
```yaml
answer_node:
  type: streaming
  content: "{{#llm_output#}}"
  metadata:
    sources: "{{#knowledge_results.sources#}}"
    confidence: "{{#llm_output.confidence#}}"
```

### Structured Response
```yaml
answer_node:
  type: structured
  schema:
    response: "{{#llm_output.response#}}"
    actions:
      - type: "{{#llm_output.action_type#}}"
        data: "{{#llm_output.action_data#}}"
    suggested_replies: "{{#llm_output.suggestions#}}"
```

## Multi-Turn Patterns

### Slot Filling
```yaml
slot_filling:
  slots:
    - name: order_id
      prompt: "What is your order number?"
      validation: "^ORD-[0-9]{6}$"
    - name: email
      prompt: "What email is associated with this order?"
      validation: "^[^@]+@[^@]+\\.[^@]+$"
  completion_action: process_order_lookup
```

### Clarification Loop
```python
def check_clarification_needed(inputs: dict) -> dict:
    confidence = inputs.get("llm_confidence", 1.0)
    ambiguous_entities = inputs.get("ambiguous_entities", [])

    if confidence < 0.7 or len(ambiguous_entities) > 0:
        return {
            "needs_clarification": True,
            "clarification_prompt": generate_clarification(ambiguous_entities)
        }
    return {"needs_clarification": False}
```

## Error Handling

### Fallback Responses
```yaml
error_handling:
  llm_failure:
    response: "I'm having trouble processing your request. Please try again."
    retry: true
    max_retries: 2
  knowledge_failure:
    response: "I couldn't find relevant information. Let me try to help anyway."
    fallback_to_llm: true
  timeout:
    response: "The request is taking longer than expected. Please try again."
```

### Graceful Degradation
```python
def handle_errors(inputs: dict) -> dict:
    error = inputs.get("error")
    error_type = inputs.get("error_type")

    fallback_responses = {
        "model_overloaded": "I'm experiencing high demand. Please try again shortly.",
        "context_too_long": "Your conversation is quite long. Let me summarize...",
        "tool_failure": "I couldn't complete that action, but I can help another way."
    }

    return {
        "response": fallback_responses.get(error_type, "An error occurred."),
        "should_retry": error_type in ["model_overloaded", "timeout"]
    }
```

## Complete Chatflow Example

### Customer Support Bot
```yaml
name: Customer Support Chatflow
description: Multi-turn support with RAG and escalation

conversation_variables:
  - name: customer_info
    type: object
    default: {}
  - name: ticket_id
    type: string
    default: ""
  - name: escalation_requested
    type: boolean
    default: false

nodes:
  - id: start
    type: start
    outputs:
      - id: intent_classifier

  - id: intent_classifier
    type: llm
    config:
      model: gpt-3.5-turbo
      prompt: |
        Classify the user intent:
        Query: {{#sys.query#}}

        Categories: order_status, product_question, complaint, general
    outputs:
      - id: intent_router

  - id: intent_router
    type: if_else
    conditions:
      - "{{#intent_classifier.intent#}} == 'complaint'"
    true_output: escalation_check
    false_output: knowledge_retrieval

  - id: knowledge_retrieval
    type: knowledge_retrieval
    config:
      knowledge_base_id: "support-kb"
      top_k: 5
    outputs:
      - id: main_llm

  - id: main_llm
    type: llm
    config:
      model: gpt-4o
      system_prompt: |
        You are a helpful support assistant.
        Customer: {{#conversation.customer_info.name#}}

        Use the following knowledge to answer:
        {{#knowledge_retrieval.results#}}
    outputs:
      - id: answer

  - id: answer
    type: answer
    config:
      streaming: true
```

## Performance Optimization

### Caching Strategy
```yaml
caching:
  enabled: true
  ttl: 3600  # 1 hour
  cache_key: "{{#sys.user_id#}}_{{#query_hash#}}"
  invalidation:
    on_knowledge_update: true
```

### Token Management
```yaml
token_optimization:
  max_context_tokens: 8000
  reserve_output_tokens: 2000
  truncation_strategy: "drop_oldest_messages"
  summarization:
    enabled: true
    trigger_threshold: 6000
    model: gpt-3.5-turbo
```

## Testing Chatflows

### Test Cases
```yaml
test_cases:
  - name: "Basic greeting"
    input: "Hello"
    expected:
      contains: ["Hello", "help"]
      intent: "greeting"

  - name: "Order status inquiry"
    input: "Where is my order ORD-123456?"
    conversation_context:
      customer_info:
        email: "test@example.com"
    expected:
      calls_tool: "order_lookup"
      contains: ["order", "status"]
```

### Debug Mode
```yaml
debug:
  enabled: true
  log_level: "verbose"
  capture:
    - llm_prompts
    - variable_values
    - node_outputs
    - latency_metrics
```
