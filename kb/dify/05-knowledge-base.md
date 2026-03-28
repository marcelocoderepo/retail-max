# Dify Knowledge Base & RAG

Comprehensive guide for implementing Retrieval-Augmented Generation (RAG) with Dify's knowledge base system.

## RAG Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RAG Pipeline                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INGESTION PHASE                                                        │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐  │
│  │ Upload  │ → │ Parse   │ → │ Chunk   │ → │ Embed   │ → │ Index   │  │
│  │Documents│   │ Extract │   │ Split   │   │ Vector  │   │ Store   │  │
│  └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘  │
│                                                                          │
│  RETRIEVAL PHASE                                                        │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐  │
│  │ Query   │ → │ Rewrite │ → │ Search  │ → │ Rerank  │ → │ Context │  │
│  │ Input   │   │Transform│   │Retrieve │   │ Filter  │   │ Inject  │  │
│  └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘  │
│                                                                          │
│  GENERATION PHASE                                                       │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐                              │
│  │ Prompt  │ → │ LLM     │ → │Response │                              │
│  │ Build   │   │Generate │   │ Output  │                              │
│  └─────────┘   └─────────┘   └─────────┘                              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Document Ingestion

### Supported File Types

| Format | Extension | Max Size | Features |
|--------|-----------|----------|----------|
| **PDF** | .pdf | 15MB | OCR, Tables, Images |
| **Word** | .docx, .doc | 15MB | Formatting preserved |
| **Text** | .txt | 15MB | Plain text |
| **Markdown** | .md | 15MB | Headings, code blocks |
| **HTML** | .html, .htm | 15MB | Cleaned extraction |
| **CSV** | .csv | 15MB | Structured data |
| **Excel** | .xlsx, .xls | 15MB | Multiple sheets |
| **EPUB** | .epub | 15MB | eBook format |

### Ingestion Methods

#### File Upload API

```bash
curl -X POST 'https://api.dify.ai/v1/datasets/{dataset_id}/document/create_by_file' \
  -H 'Authorization: Bearer {api_key}' \
  -F 'file=@document.pdf' \
  -F 'data={
    "indexing_technique": "high_quality",
    "process_rule": {
      "mode": "automatic"
    }
  }'
```

#### Text Creation API

```bash
curl -X POST 'https://api.dify.ai/v1/datasets/{dataset_id}/document/create_by_text' \
  -H 'Authorization: Bearer {api_key}' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Product FAQ",
    "text": "Q: How do I reset my password?\nA: Go to Settings > Security > Reset Password...",
    "indexing_technique": "high_quality",
    "process_rule": {
      "mode": "custom",
      "rules": {
        "segmentation": {
          "separator": "\n\n",
          "max_tokens": 500
        }
      }
    }
  }'
```

#### Website Crawl API

```bash
curl -X POST 'https://api.dify.ai/v1/datasets/{dataset_id}/document/create_by_url' \
  -H 'Authorization: Bearer {api_key}' \
  -H 'Content-Type: application/json' \
  -d '{
    "data_source": {
      "type": "website_crawl",
      "info": {
        "url": "https://docs.example.com",
        "crawl_sub_pages": true,
        "max_depth": 2,
        "limit": 50
      }
    },
    "indexing_technique": "high_quality"
  }'
```

## Chunking Strategies

### Strategy Comparison

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Fixed-Size** | Split by token count | General documents |
| **Semantic** | Split by meaning boundaries | Technical docs |
| **Sentence** | Split by sentences | FAQ, Q&A |
| **Paragraph** | Split by paragraphs | Articles, reports |
| **Parent-Child** | Hierarchical chunks | Complex documents |

### Automatic Chunking

```json
{
  "process_rule": {
    "mode": "automatic"
  }
}
```

Uses intelligent defaults:
- Token limit: 500
- Overlap: 50 tokens
- Boundary detection: paragraph/sentence

### Custom Chunking

```json
{
  "process_rule": {
    "mode": "custom",
    "rules": {
      "pre_processing_rules": [
        {"id": "remove_extra_spaces", "enabled": true},
        {"id": "remove_urls_emails", "enabled": false}
      ],
      "segmentation": {
        "separator": "\n\n",
        "max_tokens": 500,
        "chunk_overlap": 50
      }
    }
  }
}
```

### Chunking Parameters

| Parameter | Range | Default | Guidance |
|-----------|-------|---------|----------|
| `max_tokens` | 100-2000 | 500 | Higher = more context, lower precision |
| `chunk_overlap` | 0-200 | 50 | Higher = better continuity |
| `separator` | any string | `\n\n` | Use document structure |

### Content-Type Recommendations

| Content Type | Max Tokens | Overlap | Separator |
|--------------|------------|---------|-----------|
| **Technical Docs** | 300-500 | 30-50 | `\n\n` or `\n#` |
| **FAQ** | 200-300 | 0-20 | `\nQ:` |
| **Legal/Policy** | 400-600 | 50-100 | `\n\n` |
| **Code Documentation** | 300-400 | 50 | `\n##` |
| **Narrative Content** | 500-800 | 100-150 | `\n\n` |
| **Tables/Structured** | 200-400 | 0-30 | `\n\n` |

### Pre-processing Rules

| Rule ID | Description | When to Enable |
|---------|-------------|----------------|
| `remove_extra_spaces` | Collapse multiple whitespace | Always |
| `remove_urls_emails` | Strip URLs and emails | Privacy-sensitive content |

## Embedding Configuration

### Embedding Models

| Provider | Model | Dimensions | Cost | Quality |
|----------|-------|------------|------|---------|
| **OpenAI** | text-embedding-3-small | 1536 | Low | Good |
| **OpenAI** | text-embedding-3-large | 3072 | Medium | Best |
| **Cohere** | embed-english-v3.0 | 1024 | Low | Good |
| **Cohere** | embed-multilingual-v3.0 | 1024 | Low | Good (multi) |
| **Voyage** | voyage-large-2 | 1536 | Medium | Excellent |
| **Local** | bge-large-en-v1.5 | 1024 | Free | Good |
| **Local** | e5-large-v2 | 1024 | Free | Good |

### Configuration

```json
{
  "embedding_model": {
    "provider": "openai",
    "model": "text-embedding-3-small"
  },
  "indexing_technique": "high_quality"
}
```

### Indexing Techniques

| Technique | Description | Use Case |
|-----------|-------------|----------|
| `high_quality` | Full vector + keyword indexing | Production |
| `economy` | Optimized for lower cost | Development, testing |

## Search Methods

### Semantic Search

Vector similarity search using embeddings.

```json
{
  "retrieval_model": {
    "search_method": "semantic_search",
    "top_k": 5,
    "score_threshold_enabled": true,
    "score_threshold": 0.5
  }
}
```

**Pros:**
- Understands meaning and context
- Handles synonyms and paraphrasing
- Good for conceptual queries

**Cons:**
- May miss exact matches
- Sensitive to embedding quality

### Keyword Search (BM25)

Traditional text matching using BM25 algorithm.

```json
{
  "retrieval_model": {
    "search_method": "keyword_search",
    "top_k": 10
  }
}
```

**Pros:**
- Exact term matching
- Fast and efficient
- Good for specific terms, codes, IDs

**Cons:**
- No semantic understanding
- Misses synonyms

### Hybrid Search (Recommended)

Combines semantic and keyword search.

```json
{
  "retrieval_model": {
    "search_method": "hybrid_search",
    "top_k": 10,
    "score_threshold_enabled": true,
    "score_threshold": 0.5,
    "weights": {
      "semantic": 0.7,
      "keyword": 0.3
    }
  }
}
```

**Weighting Guidelines:**

| Content Type | Semantic Weight | Keyword Weight |
|--------------|-----------------|----------------|
| General knowledge | 0.7 | 0.3 |
| Technical documentation | 0.6 | 0.4 |
| FAQ with exact terms | 0.5 | 0.5 |
| Code/API reference | 0.4 | 0.6 |
| Legal/regulatory | 0.5 | 0.5 |

### Full-Text Search

Elasticsearch-style full-text search.

```json
{
  "retrieval_model": {
    "search_method": "full_text_search",
    "top_k": 20
  }
}
```

**Best for:**
- Large document collections
- Complex boolean queries
- When Elasticsearch is configured

## Reranking

### Why Rerank?

Initial retrieval optimizes for recall (finding all relevant docs).
Reranking optimizes for precision (ordering by true relevance).

```
Initial Retrieval (top_k=20) → Reranker → Final Results (reranking_top_k=5)
```

### Reranking Models

| Provider | Model | Quality | Cost | Languages |
|----------|-------|---------|------|-----------|
| **Cohere** | rerank-english-v2.0 | Excellent | Medium | English |
| **Cohere** | rerank-multilingual-v2.0 | Excellent | Medium | 100+ |
| **Cohere** | rerank-english-v3.0 | Best | Higher | English |
| **BGE** | bge-reranker-v2-m3 | Very Good | Free | Multi |
| **Jina** | jina-reranker-v1-base | Good | Free | Multi |

### Configuration

```json
{
  "retrieval_model": {
    "search_method": "hybrid_search",
    "top_k": 20,
    "reranking_enable": true,
    "reranking_model": {
      "reranking_provider_name": "cohere",
      "reranking_model_name": "rerank-english-v2.0"
    },
    "reranking_top_k": 5,
    "score_threshold_enabled": true,
    "score_threshold": 0.5
  }
}
```

### Reranking Best Practices

1. **Retrieve more, rerank to fewer**: `top_k=20`, `reranking_top_k=5`
2. **Use reranking for quality-critical apps**
3. **Consider latency impact** (~100-200ms additional)
4. **Match language to reranker model**

## Multi-Knowledge Base Retrieval

### Configuration

```json
{
  "knowledge_bases": [
    {
      "id": "kb-product-docs",
      "enabled": true,
      "weight": 0.5
    },
    {
      "id": "kb-support-faq",
      "enabled": true,
      "weight": 0.3
    },
    {
      "id": "kb-policies",
      "enabled": true,
      "weight": 0.2
    }
  ],
  "retrieval_model": {
    "search_method": "hybrid_search",
    "top_k": 10,
    "reranking_enable": true
  }
}
```

### Multi-KB Strategies

| Strategy | Description | When to Use |
|----------|-------------|-------------|
| **Weighted** | Different importance per KB | Diverse content types |
| **Sequential** | Search KBs in priority order | Fallback pattern |
| **Merged** | Combine all, rerank together | Related content |

## Query Transformation

### Query Rewriting

Transform user queries for better retrieval.

```yaml
query_rewrite:
  enabled: true
  model: gpt-3.5-turbo
  prompt: |
    Given the conversation context and current query,
    rewrite the query to be self-contained and specific for search.

    Conversation History:
    {{conversation_history}}

    Current Query: {{query}}

    Guidelines:
    - Resolve pronouns (he, she, it, they)
    - Include relevant context
    - Be specific and searchable
    - Keep under 100 words

    Rewritten Query:
```

### Hypothetical Document Embeddings (HyDE)

Generate hypothetical answer, embed that instead of query.

```yaml
hyde:
  enabled: true
  model: gpt-3.5-turbo
  prompt: |
    Write a short, factual paragraph that would answer this question.
    Do not include phrases like "According to..." or "The document states..."

    Question: {{query}}

    Answer paragraph:
```

### Multi-Query Retrieval

Generate multiple query variations.

```yaml
multi_query:
  enabled: true
  model: gpt-3.5-turbo
  num_queries: 3
  prompt: |
    Generate {{num_queries}} different versions of this query
    that might help find relevant information:

    Original: {{query}}

    Variations:
```

## Context Injection Patterns

### Basic Pattern

```text
Use the following context to answer the user's question.
If the information is not in the context, say "I don't have that information."

---
Context:
{{knowledge_results}}
---

Question: {{query}}

Answer:
```

### Citation Pattern

```text
Answer the question based on the provided sources.
Include citations [1], [2], etc. when referencing information.

Sources:
{{#each knowledge_results}}
[{{@index}}] {{this.content}}
Source: {{this.document_name}}
{{/each}}

Question: {{query}}

Provide your answer with inline citations:
```

### Structured Context Pattern

```text
You have access to the following knowledge base results:

{{#each knowledge_results}}
## Source {{@index}}: {{this.document_name}}
Relevance Score: {{this.score}}
Content: {{this.content}}
---
{{/each}}

Based on these sources, answer: {{query}}

Format your response as:
- Main answer
- Supporting evidence
- Confidence level (high/medium/low)
```

### Conditional Context Pattern

```text
{{#if knowledge_results.length > 0}}
I found relevant information in our knowledge base:

{{knowledge_results}}

Based on this information:
{{else}}
I couldn't find specific information about this topic in our knowledge base.
Let me provide a general response:
{{/if}}

Question: {{query}}
```

## Knowledge Base API Reference

### Create Dataset

```http
POST /v1/datasets
Authorization: Bearer {api_key}
Content-Type: application/json

{
  "name": "Product Documentation",
  "description": "Official product docs and guides",
  "permission": "only_me",
  "indexing_technique": "high_quality"
}
```

### List Datasets

```http
GET /v1/datasets?page=1&limit=20
Authorization: Bearer {api_key}
```

Response:

```json
{
  "data": [
    {
      "id": "ds-abc123",
      "name": "Product Documentation",
      "description": "Official product docs",
      "permission": "only_me",
      "data_source_type": "upload_file",
      "indexing_technique": "high_quality",
      "app_count": 3,
      "document_count": 15,
      "word_count": 50000,
      "created_at": 1699000000
    }
  ],
  "has_more": false,
  "limit": 20,
  "total": 1
}
```

### Delete Dataset

```http
DELETE /v1/datasets/{dataset_id}
Authorization: Bearer {api_key}
```

### Hit Testing (Query Testing)

```http
POST /v1/datasets/{dataset_id}/retrieve
Authorization: Bearer {api_key}
Content-Type: application/json

{
  "query": "How do I reset my password?",
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

Response:

```json
{
  "query": "How do I reset my password?",
  "records": [
    {
      "segment": {
        "id": "seg-001",
        "content": "To reset your password: 1. Go to Settings...",
        "word_count": 45,
        "tokens": 60,
        "keywords": ["password", "reset", "security"],
        "position": 1
      },
      "document": {
        "id": "doc-001",
        "name": "User Guide",
        "data_source_type": "upload_file"
      },
      "score": 0.92
    }
  ],
  "total": 5
}
```

### List Documents

```http
GET /v1/datasets/{dataset_id}/documents?page=1&limit=20
Authorization: Bearer {api_key}
```

### Update Document

```http
PUT /v1/datasets/{dataset_id}/documents/{document_id}/update_by_text
Authorization: Bearer {api_key}
Content-Type: application/json

{
  "name": "Updated Document Title",
  "text": "Updated content..."
}
```

### Delete Document

```http
DELETE /v1/datasets/{dataset_id}/documents/{document_id}
Authorization: Bearer {api_key}
```

### List Segments

```http
GET /v1/datasets/{dataset_id}/documents/{document_id}/segments
Authorization: Bearer {api_key}
```

### Add Segment

```http
POST /v1/datasets/{dataset_id}/documents/{document_id}/segments
Authorization: Bearer {api_key}
Content-Type: application/json

{
  "segments": [
    {
      "content": "New segment content to add...",
      "keywords": ["keyword1", "keyword2"]
    }
  ]
}
```

### Update Segment

```http
PUT /v1/datasets/{dataset_id}/documents/{document_id}/segments/{segment_id}
Authorization: Bearer {api_key}
Content-Type: application/json

{
  "content": "Updated segment content",
  "keywords": ["updated", "keywords"]
}
```

## Knowledge Retrieval Node

### Basic Configuration

```yaml
knowledge_retrieval:
  type: knowledge_retrieval

  knowledge_bases:
    - id: "kb-product-docs"
      enabled: true
    - id: "kb-faq"
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
```

### With Query Rewriting

```yaml
knowledge_retrieval:
  query_variable: "{{sys.query}}"

  query_rewrite:
    enabled: true
    model: gpt-3.5-turbo
    include_conversation_history: true

  retrieval_model:
    search_method: hybrid_search
    top_k: 10
    reranking_enable: true
    reranking_top_k: 5
```

### Output Usage

```yaml
llm_node:
  prompt: |
    Use the following knowledge to answer:

    {{#each knowledge_retrieval.results}}
    Source: {{this.document_name}}
    Content: {{this.content}}
    ---
    {{/each}}

    Question: {{sys.query}}
```

## Best Practices

### Chunking Optimization

1. **Test different chunk sizes** with your actual queries
2. **Use meaningful separators** that match document structure
3. **Include overlap** for context continuity
4. **Consider parent-child** for hierarchical content

### Retrieval Tuning

1. **Start with hybrid search** (0.7 semantic, 0.3 keyword)
2. **Enable reranking** for quality-critical apps
3. **Set appropriate top_k** (5-10 for most cases)
4. **Use score thresholds** to filter noise (0.5-0.7)
5. **Test with real queries** from your users

### Content Quality

1. **Clean documents** before uploading
2. **Add metadata** to improve searchability
3. **Use consistent formatting** across documents
4. **Include relevant keywords** in content
5. **Update stale content** regularly

### Performance Optimization

1. **Cache frequently accessed queries**
2. **Use appropriate embedding model** for your needs
3. **Monitor retrieval latency**
4. **Consider chunking strategy impact** on index size
5. **Use economy indexing** for development

## Monitoring & Analytics

### Key Metrics

| Metric | Target | Action if Below |
|--------|--------|-----------------|
| **Avg Relevance Score** | > 0.7 | Improve content, reindex |
| **Zero Result Rate** | < 5% | Add content, lower threshold |
| **Avg Latency** | < 200ms | Enable caching, reduce top_k |
| **User Satisfaction** | > 80% | Review missed queries |

### Retrieval Analysis

```json
{
  "metrics": {
    "total_queries": 1000,
    "avg_latency_ms": 150,
    "cache_hit_rate": 0.35,
    "avg_relevance_score": 0.78,
    "zero_result_rate": 0.05,
    "top_missed_queries": [
      "query that returned no results",
      "another missed query"
    ]
  }
}
```

### Quality Improvement Workflow

```
1. Monitor zero-result queries
2. Analyze low-score retrievals
3. Identify content gaps
4. Add/update documents
5. Re-index affected content
6. Test with original queries
7. Measure improvement
```

## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| No results | Query too specific | Lower threshold, add content |
| Irrelevant results | Poor chunking | Adjust chunk size, overlap |
| Slow retrieval | Large index | Enable caching, reduce top_k |
| Missing context | Chunk too small | Increase max_tokens |
| Duplicates | Overlap too high | Reduce chunk_overlap |

### Debug Checklist

1. **Check document status** - Is it indexed?
2. **Test with hit testing** - Does the query find content?
3. **Review chunk content** - Is information preserved?
4. **Verify embeddings** - Is the model configured?
5. **Check thresholds** - Is score filter too aggressive?
