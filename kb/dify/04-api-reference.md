# Dify API Reference

## Authentication

All API requests require authentication via Bearer token.

```http
Authorization: Bearer {api_key}
Content-Type: application/json
```

### API Key Types
| Key Type | Format | Use Case |
|----------|--------|----------|
| App API Key | `app-xxxxx` | Single app access |
| Dataset API Key | `dataset-xxxxx` | Knowledge base operations |

## Chat Messages API

### Send Chat Message
```http
POST /v1/chat-messages
```

#### Request Body
```json
{
  "inputs": {
    "custom_var": "value"
  },
  "query": "User's message",
  "response_mode": "blocking",
  "conversation_id": "",
  "user": "user-123",
  "files": [
    {
      "type": "image",
      "transfer_method": "remote_url",
      "url": "https://example.com/image.png"
    }
  ],
  "auto_generate_name": true
}
```

#### Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `inputs` | object | No | Input variables defined in app |
| `query` | string | Yes | User's message |
| `response_mode` | string | Yes | `blocking` or `streaming` |
| `conversation_id` | string | No | For multi-turn conversations |
| `user` | string | Yes | Unique user identifier |
| `files` | array | No | File attachments |
| `auto_generate_name` | boolean | No | Auto-generate conversation title |

#### Blocking Response
```json
{
  "message_id": "msg-abc123",
  "conversation_id": "conv-xyz789",
  "mode": "chat",
  "answer": "AI response text",
  "metadata": {
    "usage": {
      "prompt_tokens": 150,
      "completion_tokens": 200,
      "total_tokens": 350
    },
    "retriever_resources": [
      {
        "position": 1,
        "dataset_id": "ds-001",
        "dataset_name": "Knowledge Base",
        "document_id": "doc-001",
        "document_name": "FAQ.md",
        "segment_id": "seg-001",
        "score": 0.95,
        "content": "Relevant content..."
      }
    ]
  },
  "created_at": 1699000000
}
```

#### Streaming Response (SSE)
```text
event: message
data: {"event": "message", "message_id": "msg-abc", "answer": "Hello"}

event: message
data: {"event": "message", "message_id": "msg-abc", "answer": " there"}

event: message_end
data: {"event": "message_end", "message_id": "msg-abc", "conversation_id": "conv-xyz", "metadata": {...}}
```

### Stop Response Generation
```http
POST /v1/chat-messages/{task_id}/stop
```

```json
{
  "user": "user-123"
}
```

### Message Feedback
```http
POST /v1/messages/{message_id}/feedbacks
```

```json
{
  "rating": "like",
  "user": "user-123"
}
```

## Workflow API

### Execute Workflow
```http
POST /v1/workflows/run
```

#### Request Body
```json
{
  "inputs": {
    "input_var_1": "value1",
    "input_var_2": {
      "nested": "value"
    }
  },
  "response_mode": "blocking",
  "user": "user-123"
}
```

#### Response
```json
{
  "workflow_run_id": "run-abc123",
  "task_id": "task-xyz",
  "data": {
    "id": "run-abc123",
    "workflow_id": "wf-001",
    "status": "succeeded",
    "outputs": {
      "result": "processed output",
      "metadata": {...}
    },
    "error": null,
    "elapsed_time": 5.23,
    "total_tokens": 1500,
    "total_steps": 5,
    "created_at": 1699000000,
    "finished_at": 1699000005
  }
}
```

### Get Workflow Run Status
```http
GET /v1/workflows/run/{workflow_run_id}
```

### Stop Workflow
```http
POST /v1/workflows/run/{workflow_run_id}/stop
```

## Completion Messages API

### Send Completion Request
```http
POST /v1/completion-messages
```

```json
{
  "inputs": {
    "text": "Input text to process"
  },
  "response_mode": "blocking",
  "user": "user-123"
}
```

## Conversations API

### List Conversations
```http
GET /v1/conversations
```

#### Query Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| `user` | string | User identifier (required) |
| `last_id` | string | Last conversation ID for pagination |
| `limit` | integer | Results per page (default: 20, max: 100) |
| `pinned` | boolean | Filter by pinned status |

#### Response
```json
{
  "data": [
    {
      "id": "conv-abc123",
      "name": "Conversation Title",
      "inputs": {},
      "status": "normal",
      "introduction": "",
      "created_at": 1699000000,
      "updated_at": 1699000100
    }
  ],
  "has_more": true,
  "limit": 20
}
```

### Get Conversation
```http
GET /v1/conversations/{conversation_id}
```

### Delete Conversation
```http
DELETE /v1/conversations/{conversation_id}
```

```json
{
  "user": "user-123"
}
```

### Rename Conversation
```http
POST /v1/conversations/{conversation_id}/name
```

```json
{
  "name": "New Conversation Name",
  "auto_generate": false,
  "user": "user-123"
}
```

## Messages API

### List Messages
```http
GET /v1/messages
```

#### Query Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| `user` | string | User identifier (required) |
| `conversation_id` | string | Conversation ID (required) |
| `first_id` | string | First message ID for pagination |
| `limit` | integer | Results per page (default: 20) |

#### Response
```json
{
  "data": [
    {
      "id": "msg-abc123",
      "conversation_id": "conv-xyz",
      "inputs": {},
      "query": "User's question",
      "answer": "AI's response",
      "message_files": [],
      "feedback": {
        "rating": "like"
      },
      "retriever_resources": [...],
      "created_at": 1699000000
    }
  ],
  "has_more": false,
  "limit": 20
}
```

### Get Suggested Questions
```http
GET /v1/messages/{message_id}/suggested
```

```json
{
  "result": "success",
  "data": [
    "Follow-up question 1?",
    "Follow-up question 2?",
    "Follow-up question 3?"
  ]
}
```

## Knowledge Base API

### List Datasets
```http
GET /v1/datasets
```

```json
{
  "data": [
    {
      "id": "ds-abc123",
      "name": "Knowledge Base Name",
      "description": "Description",
      "permission": "only_me",
      "data_source_type": "upload_file",
      "indexing_technique": "high_quality",
      "app_count": 3,
      "document_count": 15,
      "word_count": 50000,
      "created_by": "user-123",
      "created_at": 1699000000,
      "updated_at": 1699000100
    }
  ]
}
```

### Create Dataset
```http
POST /v1/datasets
```

```json
{
  "name": "New Knowledge Base",
  "description": "Description of the knowledge base",
  "indexing_technique": "high_quality",
  "permission": "only_me"
}
```

### Create Document from Text
```http
POST /v1/datasets/{dataset_id}/document/create_by_text
```

```json
{
  "name": "Document Title",
  "text": "Document content...",
  "indexing_technique": "high_quality",
  "process_rule": {
    "mode": "automatic"
  }
}
```

### Create Document from File
```http
POST /v1/datasets/{dataset_id}/document/create_by_file
```

```
Content-Type: multipart/form-data

file: (binary file data)
data: {
  "name": "Document Name",
  "indexing_technique": "high_quality",
  "process_rule": {
    "mode": "custom",
    "rules": {
      "pre_processing_rules": [
        {"id": "remove_extra_spaces", "enabled": true},
        {"id": "remove_urls_emails", "enabled": true}
      ],
      "segmentation": {
        "separator": "\n\n",
        "max_tokens": 500
      }
    }
  }
}
```

### List Documents
```http
GET /v1/datasets/{dataset_id}/documents
```

### Delete Document
```http
DELETE /v1/datasets/{dataset_id}/documents/{document_id}
```

### Query Dataset (Hit Testing)
```http
POST /v1/datasets/{dataset_id}/hit_testing
```

```json
{
  "query": "Search query",
  "retrieval_model": {
    "search_method": "hybrid_search",
    "reranking_enable": true,
    "reranking_model": {
      "reranking_provider_name": "cohere",
      "reranking_model_name": "rerank-english-v2.0"
    },
    "top_k": 5,
    "score_threshold_enabled": true,
    "score_threshold": 0.5
  }
}
```

## Audio API

### Text to Speech
```http
POST /v1/text-to-audio
```

```json
{
  "text": "Text to convert to speech",
  "user": "user-123",
  "streaming": false
}
```

### Speech to Text
```http
POST /v1/audio-to-text
```

```
Content-Type: multipart/form-data

file: (audio file binary)
user: user-123
```

## File Upload API

### Upload File
```http
POST /v1/files/upload
```

```
Content-Type: multipart/form-data

file: (binary file data)
user: user-123
```

#### Response
```json
{
  "id": "file-abc123",
  "name": "document.pdf",
  "size": 1024000,
  "extension": "pdf",
  "mime_type": "application/pdf",
  "created_by": "user-123",
  "created_at": 1699000000
}
```

## Application Info API

### Get App Parameters
```http
GET /v1/parameters
```

```json
{
  "opening_statement": "Hello! How can I help you?",
  "suggested_questions": [
    "What can you do?",
    "Tell me about..."
  ],
  "suggested_questions_after_answer": {
    "enabled": true
  },
  "speech_to_text": {
    "enabled": true
  },
  "retriever_resource": {
    "enabled": true
  },
  "annotation_reply": {
    "enabled": false
  },
  "user_input_form": [
    {
      "text-input": {
        "label": "Name",
        "variable": "name",
        "required": true,
        "max_length": 100,
        "default": ""
      }
    }
  ],
  "file_upload": {
    "image": {
      "enabled": true,
      "number_limits": 3,
      "transfer_methods": ["remote_url", "local_file"]
    }
  },
  "system_parameters": {
    "image_file_size_limit": "10"
  }
}
```

### Get App Meta Info
```http
GET /v1/meta
```

```json
{
  "tool_icons": {
    "web_search": "https://icons.example.com/web_search.png"
  }
}
```

## Error Handling

### Error Response Format
```json
{
  "code": "invalid_param",
  "message": "Invalid parameter: query is required",
  "status": 400
}
```

### Common Error Codes
| Code | Status | Description |
|------|--------|-------------|
| `invalid_param` | 400 | Invalid request parameter |
| `app_unavailable` | 400 | App not published or deleted |
| `provider_not_initialize` | 400 | Model provider not configured |
| `provider_quota_exceeded` | 400 | Model quota exceeded |
| `model_currently_not_support` | 400 | Model not supported |
| `completion_request_error` | 400 | Model completion error |
| `unauthorized` | 401 | Invalid API key |
| `not_found` | 404 | Resource not found |
| `rate_limit_exceeded` | 429 | Rate limit exceeded |
| `internal_server_error` | 500 | Server error |

### Rate Limiting
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1699000060
```

## SDKs

### Python SDK
```python
from dify_client import Client

client = Client(api_key="app-xxx")

response = client.chat_messages.create(
    query="Hello",
    user="user-123",
    response_mode="blocking"
)
print(response.answer)
```

### JavaScript SDK
```javascript
import { DifyClient } from 'dify-client';

const client = new DifyClient({ apiKey: 'app-xxx' });

const response = await client.chatMessages.create({
  query: 'Hello',
  user: 'user-123',
  responseMode: 'blocking'
});
console.log(response.answer);
```

### cURL Examples

#### Chat Message
```bash
curl -X POST 'https://api.dify.ai/v1/chat-messages' \
  -H 'Authorization: Bearer app-xxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputs": {},
    "query": "Hello",
    "response_mode": "blocking",
    "user": "user-123"
  }'
```

#### Streaming Chat
```bash
curl -X POST 'https://api.dify.ai/v1/chat-messages' \
  -H 'Authorization: Bearer app-xxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputs": {},
    "query": "Tell me a story",
    "response_mode": "streaming",
    "user": "user-123"
  }'
```

#### Execute Workflow
```bash
curl -X POST 'https://api.dify.ai/v1/workflows/run' \
  -H 'Authorization: Bearer app-xxx' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputs": {
      "document_url": "https://example.com/doc.pdf"
    },
    "response_mode": "blocking",
    "user": "user-123"
  }'
```
