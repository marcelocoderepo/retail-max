# Dify Agents & Tools

Comprehensive guide for building autonomous AI agents with tool-using capabilities in Dify.

## Agent Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Agent Execution Loop                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐             │
│  │  Query  │ →  │ Reason  │ →  │  Act    │ →  │Observe  │ ────┐       │
│  │  Input  │    │ (Think) │    │ (Tool)  │    │(Result) │     │       │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘     │       │
│       ↑                                                        │       │
│       └────────────────────────────────────────────────────────┘       │
│                         (Loop until done)                               │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Final Response                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Agent Strategies

### Strategy Comparison

| Strategy | Description | Best For | Models |
|----------|-------------|----------|--------|
| **Function Calling** | Native LLM tool use | GPT-4, Claude | OpenAI, Anthropic |
| **ReAct** | Reasoning + Acting | Complex reasoning | Any LLM |
| **Chain-of-Thought** | Step-by-step thinking | Analysis tasks | Any LLM |

### Function Calling Strategy

Native tool invocation using LLM function calling capabilities.

```yaml
agent:
  strategy: function_call
  config:
    parallel_tool_calls: true
    tool_choice: auto
    strict_mode: false
```

**How it works:**

1. LLM receives query + tool definitions
2. LLM decides which tool(s) to call with arguments
3. Tools execute and return results
4. LLM generates final response

**Advantages:**

- Most reliable tool selection
- Native to modern LLMs
- Supports parallel tool calls
- Structured argument parsing

### ReAct Strategy

Reasoning and Acting in an interleaved loop.

```yaml
agent:
  strategy: react
  config:
    thought_prompt: |
      Think step by step about how to solve this problem.
      Consider what information you need and which tools can help.

    action_prompt: |
      Based on your thinking, select the appropriate tool and input.

    observation_prompt: |
      Review the tool output. Does it answer the question?
      If not, what additional steps are needed?

    max_iterations: 10
    early_stopping:
      enabled: true
      condition: "contains 'FINAL ANSWER'"
```

**ReAct Format:**

```
Question: What is the weather in Paris and what should I wear?

Thought: I need to find the current weather in Paris first.
Action: weather_lookup
Action Input: {"location": "Paris, France"}
Observation: Temperature: 15°C, Conditions: Partly cloudy

Thought: Now I know the weather, I can suggest clothing.
Action: FINISH
Final Answer: The weather in Paris is 15°C and partly cloudy.
I recommend wearing layers - a light jacket or sweater would be ideal.
```

### Chain-of-Thought Strategy

Step-by-step reasoning before tool use.

```yaml
agent:
  strategy: cot
  config:
    reasoning_prompt: |
      Let's approach this step by step:
      1. First, understand what's being asked
      2. Break down the problem into parts
      3. Consider what information is needed
      4. Plan the approach
      5. Execute and verify

    include_reasoning_in_output: false
```

## Agent Configuration

### Complete Agent Setup

```yaml
agent:
  name: Research Assistant
  description: An agent that searches and analyzes information

  model:
    provider: openai
    name: gpt-4o
    parameters:
      temperature: 0.3
      max_tokens: 4096

  strategy: function_call

  system_prompt: |
    You are a research assistant with access to various tools.

    Your capabilities:
    - Web search for current information
    - Document analysis and summarization
    - Mathematical calculations
    - Knowledge base retrieval

    Guidelines:
    1. Always verify information from multiple sources
    2. Cite your sources in responses
    3. Express confidence levels when uncertain
    4. Break complex tasks into steps

  tools:
    - name: web_search
      type: builtin
    - name: calculator
      type: builtin
    - name: knowledge_retrieval
      type: knowledge
      knowledge_base_id: "kb-docs"
    - name: document_processor
      type: workflow
      workflow_id: "wf-processor"

  max_iterations: 10

  conversation_variables:
    - name: research_notes
      type: array[object]
      default: []
    - name: sources_consulted
      type: array[string]
      default: []

  error_handling:
    on_tool_failure: retry_or_skip
    max_consecutive_errors: 3
    graceful_degradation: true
```

## Tool Types

### Built-in Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| **web_search** | Search the web | `query`, `max_results` |
| **wikipedia** | Wikipedia lookup | `query`, `language` |
| **calculator** | Math calculations | `expression` |
| **current_time** | Get current datetime | `timezone` |
| **weather** | Weather information | `location`, `units` |

#### Web Search Configuration

```yaml
tool:
  type: builtin
  name: web_search
  provider: google
  config:
    max_results: 5
    safe_search: true
    language: en
    region: us
```

#### Wikipedia Configuration

```yaml
tool:
  type: builtin
  name: wikipedia
  config:
    language: en
    max_chars: 5000
    extract_sections: true
```

### Custom API Tools

Define tools using OpenAPI specification.

#### OpenAPI Tool Definition

```yaml
openapi: 3.0.0
info:
  title: Weather API Tool
  version: 1.0.0
  description: Get weather information for any location

servers:
  - url: https://api.weather.com/v1

paths:
  /weather:
    get:
      operationId: getWeather
      summary: Get current weather
      description: Retrieves current weather conditions for a location
      parameters:
        - name: location
          in: query
          required: true
          schema:
            type: string
          description: City name or coordinates (lat,lon)
        - name: units
          in: query
          required: false
          schema:
            type: string
            enum: [metric, imperial]
            default: metric
          description: Temperature units
      responses:
        '200':
          description: Weather data
          content:
            application/json:
              schema:
                type: object
                properties:
                  temperature:
                    type: number
                    description: Current temperature
                  conditions:
                    type: string
                    description: Weather conditions
                  humidity:
                    type: number
                    description: Humidity percentage
                  wind_speed:
                    type: number
                    description: Wind speed
```

#### Tool Registration

```yaml
custom_tool:
  name: weather_lookup
  description: Get current weather conditions for any location worldwide
  api_spec: openapi_schema.yaml

  authentication:
    type: api_key
    header: X-API-Key
    value_from: env.WEATHER_API_KEY

  timeout_ms: 10000

  retry:
    enabled: true
    max_attempts: 2
    backoff: exponential

  response_mapping:
    temperature: "$.data.temperature"
    conditions: "$.data.conditions"
```

### Knowledge Base Tools

RAG retrieval as a tool.

```yaml
knowledge_tool:
  name: company_docs
  description: Search company documentation, policies, and procedures
  type: knowledge

  knowledge_base_ids:
    - kb-policies
    - kb-procedures
    - kb-faq

  retrieval_config:
    search_method: hybrid_search
    top_k: 5
    score_threshold: 0.5
    reranking: true
    reranking_model: cohere/rerank-english-v2.0
```

### Workflow Tools

Execute Dify workflows as tools.

```yaml
workflow_tool:
  name: document_processor
  description: Process and analyze documents, extract key information

  workflow_id: "wf-abc123"

  input_mapping:
    document_url: "{{tool_input.url}}"
    analysis_type: "{{tool_input.type}}"
    options: "{{tool_input.options}}"

  output_mapping:
    result: "{{workflow_output.analysis}}"
    summary: "{{workflow_output.summary}}"
    entities: "{{workflow_output.entities}}"

  timeout_ms: 60000
```

## Tool Input/Output Schemas

### Input Schema

```yaml
tool_input_schema:
  type: object
  properties:
    query:
      type: string
      description: Search query
      minLength: 1
      maxLength: 500

    filters:
      type: object
      properties:
        date_range:
          type: string
          enum: [today, week, month, year, all]
          default: all
        source_type:
          type: string
          enum: [news, academic, all]
          default: all
        language:
          type: string
          default: en

    limit:
      type: integer
      minimum: 1
      maximum: 50
      default: 10

  required: [query]
```

### Output Schema

```yaml
tool_output_schema:
  type: object
  properties:
    results:
      type: array
      items:
        type: object
        properties:
          title:
            type: string
          url:
            type: string
            format: uri
          snippet:
            type: string
          source:
            type: string
          published_date:
            type: string
            format: date

    total_count:
      type: integer

    search_time_ms:
      type: number

    metadata:
      type: object
      properties:
        query_used:
          type: string
        filters_applied:
          type: object
```

## Multi-Agent Patterns

### Supervisor Agent

Orchestrates multiple specialized agents.

```yaml
multi_agent:
  type: supervisor

  supervisor:
    model: gpt-4o
    system_prompt: |
      You are a supervisor coordinating specialized agents.
      Analyze requests and route to the appropriate specialist.

      Available specialists:
      - research_agent: Information gathering and synthesis
      - code_agent: Programming and technical tasks
      - analysis_agent: Data analysis and insights

      For each request:
      1. Understand the task requirements
      2. Select the appropriate agent(s)
      3. Synthesize results if multiple agents used
      4. Provide a coherent final response

  agents:
    - id: research_agent
      role: Research Specialist
      model: gpt-4o
      tools: [web_search, wikipedia, knowledge_retrieval]
      system_prompt: |
        You are a research specialist. Gather information
        from multiple sources and synthesize findings.

    - id: code_agent
      role: Code Assistant
      model: gpt-4o
      tools: [code_interpreter, file_operations]
      system_prompt: |
        You are a coding expert. Write, review, and debug code.

    - id: analysis_agent
      role: Data Analyst
      model: gpt-4o
      tools: [calculator, data_visualization]
      system_prompt: |
        You are a data analyst. Analyze data and provide insights.

  routing:
    strategy: llm_decision
    fallback: research_agent
```

### Sequential Agent Chain

Agents process in sequence, passing results.

```yaml
multi_agent:
  type: sequential

  agents:
    - id: planner
      role: Task Planner
      output_to: executor
      system_prompt: |
        Create a detailed plan for completing the user's request.
        Output a structured plan with steps.

    - id: executor
      role: Task Executor
      input_from: planner
      output_to: reviewer
      tools: [web_search, document_reader, calculator]
      system_prompt: |
        Execute the plan provided by the planner.
        Document your progress and findings.

    - id: reviewer
      role: Quality Reviewer
      input_from: executor
      system_prompt: |
        Review the work completed by the executor.
        Verify accuracy and suggest improvements.
        Provide the final polished response.
```

### Parallel Agent Execution

Multiple agents work simultaneously.

```yaml
multi_agent:
  type: parallel

  agents:
    - id: web_researcher
      tools: [web_search]
      query_transform: "Find recent news about: {{query}}"

    - id: academic_researcher
      tools: [academic_search]
      query_transform: "Find academic papers about: {{query}}"

    - id: internal_search
      tools: [knowledge_retrieval]
      query_transform: "Search internal docs for: {{query}}"

  aggregator:
    model: gpt-4o
    prompt: |
      Synthesize findings from multiple sources:

      Web Research: {{web_researcher.output}}
      Academic Research: {{academic_researcher.output}}
      Internal Knowledge: {{internal_search.output}}

      Provide a comprehensive summary with citations.
```

## Error Handling

### Tool Error Handling

```yaml
tool_error_handling:
  on_failure:
    action: retry_or_skip
    max_retries: 2
    retry_delay_ms: 1000
    fallback_response: "Tool temporarily unavailable"

  on_timeout:
    timeout_ms: 30000
    action: skip
    fallback_response: "Request timed out"

  on_rate_limit:
    action: wait_and_retry
    max_wait_ms: 60000

  on_invalid_input:
    action: ask_clarification
    message: "I need more specific information to use this tool."
```

### Agent-Level Error Handling

```yaml
agent_error_handling:
  max_consecutive_errors: 3

  on_max_errors:
    action: graceful_exit
    response: |
      I encountered several issues while processing your request.
      Here's what I found so far: {{partial_results}}

  on_iteration_limit:
    response: |
      I've reached my iteration limit.
      Current findings: {{current_findings}}
      Would you like me to continue with a different approach?

  on_tool_unavailable:
    action: use_alternative
    alternatives:
      web_search: [wikipedia, knowledge_retrieval]
      calculator: [llm_math]

  graceful_degradation:
    enabled: true
    fallback_to_llm: true
```

## Agent Prompting Best Practices

### System Prompt Structure

```text
# Role Definition
You are a [specific role] with expertise in [domain].

# Capabilities
You have access to the following tools:
{{#each tools}}
- {{name}}: {{description}}
{{/each}}

# Guidelines
1. [Specific instruction 1]
2. [Specific instruction 2]
3. [Specific instruction 3]

# Constraints
- Do not [limitation 1]
- Always [requirement 1]
- When uncertain, [fallback behavior]

# Output Format
[Describe expected response format]
```

### Tool Selection Guidance

```text
When deciding which tool to use:

1. **web_search**: Use for current events, recent information, or topics
   likely to have changed since your training.

2. **knowledge_retrieval**: Use for company-specific information,
   internal policies, or documented procedures.

3. **calculator**: Use for any mathematical calculation, even simple ones,
   to ensure accuracy.

4. **No tool needed**: For general knowledge, opinions, or creative tasks.

Always prefer the most specific tool for the task.
```

## Testing Agents

### Test Case Definition

```yaml
tests:
  - name: "Simple search task"
    input: "What is the capital of France?"
    expected:
      contains: ["Paris"]
      tools_used: []
      max_iterations: 1

  - name: "Tool-requiring task"
    input: "What is the weather in Tokyo right now?"
    expected:
      tools_used: ["weather_lookup"]
      contains: ["Tokyo", "temperature"]
      max_iterations: 3

  - name: "Multi-tool research"
    input: "Compare the populations of New York and Tokyo"
    expected:
      tools_used: ["web_search"]
      contains: ["New York", "Tokyo", "population"]
      response_format: "comparison"

  - name: "Knowledge base query"
    input: "What is our company's vacation policy?"
    expected:
      tools_used: ["knowledge_retrieval"]
      not_contains: ["I don't know", "I'm not sure"]
      source_cited: true
```

### Debug Configuration

```yaml
debug:
  enabled: true
  log_level: verbose

  capture:
    - thought_process
    - tool_calls
    - tool_responses
    - iteration_count
    - token_usage

  output:
    format: json
    include_timestamps: true
```

## Performance Monitoring

### Agent Metrics

```yaml
monitoring:
  metrics:
    - tool_call_latency
    - iteration_count
    - total_tokens
    - success_rate
    - tool_error_rate
    - average_response_time

  alerts:
    - metric: iteration_count
      threshold: "> 8"
      action: log_warning

    - metric: tool_error_rate
      threshold: "> 0.2"
      action: send_alert

    - metric: average_response_time
      threshold: "> 30000"
      action: investigate

  logging:
    level: info
    include:
      - tool_calls
      - reasoning_traces
      - final_outputs
    exclude:
      - raw_prompts
      - sensitive_data
```

### Cost Tracking

```yaml
cost_tracking:
  enabled: true

  budgets:
    per_request: 0.50
    daily: 100.00
    monthly: 2000.00

  alerts:
    - threshold: 0.80
      action: warn
    - threshold: 0.95
      action: throttle

  optimization:
    prefer_smaller_models: true
    cache_tool_results: true
    max_tokens_per_iteration: 2000
```

## Complete Agent Example

### Customer Support Agent

```yaml
name: Customer Support Agent
description: AI assistant for customer support with tool access

model:
  provider: openai
  name: gpt-4o
  parameters:
    temperature: 0.3
    max_tokens: 2048

strategy: function_call

system_prompt: |
  You are a helpful customer support agent for TechCorp.

  Your responsibilities:
  - Answer product questions using the knowledge base
  - Look up order status using the order tool
  - Help with account issues
  - Escalate complex issues to human agents

  Guidelines:
  1. Always be polite and professional
  2. Verify customer identity before accessing account info
  3. Use tools to provide accurate, up-to-date information
  4. If you can't help, offer to connect with a human agent

  Available information:
  - Customer ID: {{conversation.customer_id}}
  - Account type: {{conversation.account_type}}

tools:
  - name: knowledge_search
    type: knowledge
    knowledge_base_ids: [kb-faq, kb-products, kb-policies]
    config:
      search_method: hybrid_search
      top_k: 5
      reranking: true

  - name: order_lookup
    type: api
    description: Look up order status and details
    openapi_spec: |
      openapi: 3.0.0
      paths:
        /orders/{order_id}:
          get:
            operationId: getOrder
            parameters:
              - name: order_id
                in: path
                required: true
                schema:
                  type: string

  - name: create_ticket
    type: api
    description: Create a support ticket for escalation
    openapi_spec: |
      openapi: 3.0.0
      paths:
        /tickets:
          post:
            operationId: createTicket
            requestBody:
              content:
                application/json:
                  schema:
                    type: object
                    properties:
                      subject:
                        type: string
                      description:
                        type: string
                      priority:
                        type: string
                        enum: [low, medium, high]

conversation_variables:
  - name: customer_id
    type: string
  - name: verified
    type: boolean
    default: false
  - name: ticket_created
    type: boolean
    default: false

max_iterations: 8

error_handling:
  on_tool_failure: retry_or_skip
  max_consecutive_errors: 2
  fallback_response: |
    I'm having trouble accessing that information right now.
    Would you like me to create a support ticket for a team member
    to follow up with you?
```
