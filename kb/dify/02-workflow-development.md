# Dify Workflow Development

## Workflow Architecture

Workflows are stateless processing pipelines for batch operations, data transformations, and automated tasks. Unlike chatflows, they don't maintain conversation state.

### Workflow vs Chatflow

| Aspect | Workflow | Chatflow |
|--------|----------|----------|
| State | Stateless | Conversation state |
| Variables | Input variables only | Conversation variables |
| Memory | No built-in memory | Conversation memory |
| Trigger | API/Manual | Chat input |
| Best For | Batch processing | Interactive apps |

## Workflow Structure

```
┌──────────────────────────────────────────────────────────┐
│                      Workflow                            │
├──────────────────────────────────────────────────────────┤
│  ┌─────────┐   ┌──────────┐   ┌──────────┐   ┌───────┐ │
│  │  Start  │ → │ Process  │ → │ Transform│ → │  End  │ │
│  │ (Input) │   │ (HTTP)   │   │ (Code)   │   │(Output)│ │
│  └─────────┘   └──────────┘   └──────────┘   └───────┘ │
│                     │                                    │
│              ┌──────┴──────┐                            │
│              │  IF/ELSE    │                            │
│              └──────┬──────┘                            │
│           ┌─────────┴─────────┐                         │
│           ▼                   ▼                         │
│      ┌─────────┐        ┌─────────┐                    │
│      │ Path A  │        │ Path B  │                    │
│      └─────────┘        └─────────┘                    │
└──────────────────────────────────────────────────────────┘
```

## Start Node Configuration

### Input Variable Definition
```yaml
start_node:
  variables:
    - name: document_url
      type: string
      required: true
      description: URL of document to process

    - name: processing_options
      type: object
      required: false
      default:
        extract_tables: true
        ocr_enabled: false
      description: Processing configuration

    - name: output_format
      type: string
      required: false
      default: "json"
      options: ["json", "markdown", "text"]
```

### File Input
```yaml
start_node:
  file_input:
    enabled: true
    types: ["pdf", "docx", "txt"]
    max_size_mb: 10
    variable_name: "input_files"
```

## Core Node Types

### HTTP Request Node
```yaml
http_node:
  name: Fetch External Data
  method: POST
  url: "https://api.example.com/process"
  headers:
    Authorization: "Bearer {{#env.API_KEY#}}"
    Content-Type: "application/json"
  body:
    type: json
    content:
      input: "{{#start.document_url#}}"
      options: "{{#start.processing_options#}}"
  timeout: 30000
  retry:
    enabled: true
    max_attempts: 3
    backoff: exponential
```

### LLM Node (Non-Chat)
```yaml
llm_node:
  name: Content Analysis
  model:
    provider: openai
    name: gpt-4o
  mode: completion  # Not chat mode
  prompt: |
    Analyze the following document and extract key information:

    Document:
    {{#http_node.response.content#}}

    Extract:
    1. Main topics
    2. Key entities
    3. Summary

    Output as JSON.
  parameters:
    temperature: 0.3
    max_tokens: 2000
  output_schema:
    type: json
    schema:
      topics: array
      entities: array
      summary: string
```

### Code Node

#### Python Execution
```python
def main(inputs: dict) -> dict:
    """
    Process extracted data and transform to output format.

    Args:
        inputs: Dictionary containing:
            - llm_output: LLM analysis results
            - options: Processing options

    Returns:
        Transformed data dictionary
    """
    import json

    llm_output = inputs.get("llm_output", {})
    options = inputs.get("options", {})

    if isinstance(llm_output, str):
        llm_output = json.loads(llm_output)

    result = {
        "topics": llm_output.get("topics", []),
        "entity_count": len(llm_output.get("entities", [])),
        "summary": llm_output.get("summary", ""),
        "processed_at": datetime.now().isoformat()
    }

    if options.get("include_raw", False):
        result["raw_output"] = llm_output

    return result
```

#### JavaScript Execution
```javascript
async function main(inputs) {
    const { data, config } = inputs;

    const processed = data.map(item => ({
        id: item.id,
        normalized_name: item.name.toLowerCase().trim(),
        score: calculateScore(item)
    }));

    return {
        results: processed,
        count: processed.length,
        timestamp: new Date().toISOString()
    };
}

function calculateScore(item) {
    return (item.value * item.weight) / 100;
}
```

### Template Node (Jinja2)
```yaml
template_node:
  name: Generate Report
  template: |
    # Analysis Report

    **Generated:** {{ timestamp }}
    **Document:** {{ document_name }}

    ## Summary
    {{ summary }}

    ## Key Topics
    {% for topic in topics %}
    - {{ topic.name }}: {{ topic.relevance }}%
    {% endfor %}

    ## Entities Found
    {% if entities %}
    | Entity | Type | Confidence |
    |--------|------|------------|
    {% for entity in entities %}
    | {{ entity.name }} | {{ entity.type }} | {{ entity.confidence }} |
    {% endfor %}
    {% else %}
    No entities found.
    {% endif %}

  variables:
    timestamp: "{{#code_node.processed_at#}}"
    document_name: "{{#start.document_url#}}"
    summary: "{{#code_node.summary#}}"
    topics: "{{#code_node.topics#}}"
    entities: "{{#llm_node.entities#}}"
```

## Control Flow Nodes

### IF/ELSE Node
```yaml
if_else_node:
  name: Route by Type
  conditions:
    - id: condition_1
      variable: "{{#start.processing_options.type#}}"
      operator: equals
      value: "document"
      output: document_processing_path

    - id: condition_2
      variable: "{{#http_node.response.status#}}"
      operator: not_equals
      value: 200
      output: error_handling_path

  else_output: default_path
```

### Iteration Node
```yaml
iteration_node:
  name: Process Each Item
  input_array: "{{#http_node.response.items#}}"
  iterator_variable: current_item
  max_iterations: 100
  parallel: false  # Sequential processing

  # Nodes inside iteration
  inner_nodes:
    - type: llm
      name: Analyze Item
      prompt: "Analyze: {{#current_item#}}"

    - type: code
      name: Transform
      code: |
        def main(inputs):
            return {"processed": inputs["current_item"]}
```

### Variable Aggregator
```yaml
aggregator_node:
  name: Collect Results
  input_variable: "iteration_output"
  aggregation_method: "array_concat"  # or "object_merge", "sum", "average"
  output_variable: "all_results"
```

## End Node Configuration

### Output Definition
```yaml
end_node:
  outputs:
    - name: result
      type: object
      value: "{{#code_node.result#}}"

    - name: report
      type: string
      value: "{{#template_node.output#}}"

    - name: metadata
      type: object
      value:
        processed_items: "{{#aggregator_node.count#}}"
        duration_ms: "{{#sys.execution_time#}}"
        status: "success"
```

### File Output
```yaml
end_node:
  file_output:
    enabled: true
    filename: "report_{{#sys.execution_id#}}.pdf"
    content: "{{#template_node.output#}}"
    mime_type: "application/pdf"
```

## Workflow Patterns

### ETL Pipeline
```yaml
name: Document ETL Pipeline
nodes:
  - id: start
    type: start
    variables:
      - name: source_url
        type: string

  - id: extract
    type: http_request
    config:
      url: "{{#start.source_url#}}"
      method: GET

  - id: transform
    type: code
    config:
      language: python
      code: |
        def main(inputs):
            raw = inputs["extract"]["response"]
            return {"data": clean_and_transform(raw)}

  - id: validate
    type: if_else
    conditions:
      - "{{#transform.data#}} != null"
    true_output: load
    false_output: error_end

  - id: load
    type: http_request
    config:
      url: "https://api.destination.com/ingest"
      method: POST
      body: "{{#transform.data#}}"

  - id: end
    type: end
    outputs:
      - name: status
        value: "success"
      - name: records_processed
        value: "{{#transform.record_count#}}"
```

### Parallel Processing
```yaml
name: Parallel Analysis Pipeline
nodes:
  - id: start
    type: start

  - id: split_tasks
    type: code
    config:
      code: |
        def main(inputs):
            return {
                "text_task": inputs["document"]["text"],
                "image_task": inputs["document"]["images"],
                "metadata_task": inputs["document"]["metadata"]
            }

  - id: text_analysis
    type: llm
    parallel_group: analysis
    config:
      input: "{{#split_tasks.text_task#}}"

  - id: image_analysis
    type: http_request
    parallel_group: analysis
    config:
      url: "https://vision-api.com/analyze"
      body: "{{#split_tasks.image_task#}}"

  - id: metadata_extraction
    type: code
    parallel_group: analysis
    config:
      input: "{{#split_tasks.metadata_task#}}"

  - id: merge_results
    type: code
    wait_for: [text_analysis, image_analysis, metadata_extraction]
    config:
      code: |
        def main(inputs):
            return {
                "combined": {
                    "text": inputs["text_analysis"],
                    "images": inputs["image_analysis"],
                    "metadata": inputs["metadata_extraction"]
                }
            }

  - id: end
    type: end
```

### Error Handling Workflow
```yaml
name: Robust Processing Pipeline
error_handling:
  global_error_handler: error_handler_node
  retry_policy:
    max_attempts: 3
    backoff: exponential
    initial_delay_ms: 1000

nodes:
  - id: risky_operation
    type: http_request
    error_handling:
      on_error: continue  # or "stop", "retry"
      error_output: error_path
    config:
      url: "https://unreliable-api.com"
      timeout: 5000

  - id: check_success
    type: if_else
    conditions:
      - "{{#risky_operation.error#}} == null"
    true_output: success_path
    false_output: error_path

  - id: error_handler
    type: code
    config:
      code: |
        def main(inputs):
            error = inputs.get("error", {})
            return {
                "error_type": error.get("type", "unknown"),
                "message": error.get("message", "An error occurred"),
                "should_retry": error.get("retryable", False)
            }

  - id: end_success
    type: end
    outputs:
      - name: status
        value: "success"

  - id: end_error
    type: end
    outputs:
      - name: status
        value: "failed"
      - name: error
        value: "{{#error_handler.message#}}"
```

## API Execution

### Execute Workflow
```bash
curl -X POST "https://api.dify.ai/v1/workflows/run" \
  -H "Authorization: Bearer {api_key}" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": {
      "document_url": "https://example.com/doc.pdf",
      "processing_options": {
        "extract_tables": true,
        "ocr_enabled": true
      }
    },
    "response_mode": "blocking",
    "user": "user-123"
  }'
```

### Response Format
```json
{
  "workflow_run_id": "run-abc123",
  "task_id": "task-xyz789",
  "data": {
    "outputs": {
      "result": { "...": "..." },
      "report": "# Analysis Report...",
      "metadata": {
        "processed_items": 42,
        "duration_ms": 5230,
        "status": "success"
      }
    },
    "status": "succeeded",
    "elapsed_time": 5.23,
    "total_tokens": 1250,
    "total_cost": "0.0025"
  }
}
```

## Performance Optimization

### Caching
```yaml
caching:
  enabled: true
  nodes:
    - id: http_request_1
      ttl: 3600
      cache_key: "{{#inputs.url#}}"
    - id: llm_analysis
      ttl: 7200
      cache_key: "{{#inputs.content_hash#}}"
```

### Batch Processing
```yaml
batch_config:
  enabled: true
  max_batch_size: 100
  concurrent_executions: 10
  timeout_per_item_ms: 30000
```

## Testing Workflows

### Test Definition
```yaml
tests:
  - name: "Happy path test"
    inputs:
      document_url: "https://test.com/sample.pdf"
      processing_options:
        extract_tables: true
    expected_outputs:
      status: "success"
    assertions:
      - "{{#outputs.metadata.processed_items#}} > 0"
      - "{{#outputs.result#}} != null"

  - name: "Error handling test"
    inputs:
      document_url: "https://invalid-url"
    expected_outputs:
      status: "failed"
    assertions:
      - "{{#outputs.error#}} contains 'fetch failed'"
```
