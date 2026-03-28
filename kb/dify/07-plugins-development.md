# Dify Plugin Development

Comprehensive guide for building Dify plugins using the `dify_plugin` SDK.

## Plugin Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Dify Plugin System                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PLUGIN TYPES                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────────┐  │
│  │    Tool     │  │   Model     │  │    Agent Strategy         │  │
│  │  Plugins    │  │  Providers  │  │      Plugins              │  │
│  └─────────────┘  └─────────────┘  └───────────────────────────┘  │
│                                                                      │
│  PLUGIN RUNTIME                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Plugin Manager  │  Sandbox  │  Event System  │  Storage    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  INTERFACES                                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Tool Invoke  │  LLM Call  │  Session State  │  File I/O   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Plugin Types

| Type | Purpose | Example |
|------|---------|---------|
| **Tool** | Custom API integrations | Weather API, Database query |
| **Model Provider** | LLM integrations | Custom model endpoint |
| **Agent Strategy** | Reasoning patterns | Custom ReAct, Tree-of-Thought |
| **Extension** | Platform extensions | Custom auth, logging |

## Getting Started

### Installation

```bash
pip install dify-plugin-sdk
```

### Project Structure

```
my-plugin/
├── manifest.yaml          # Plugin metadata
├── requirements.txt       # Python dependencies
├── main.py               # Plugin entry point
├── tools/                # Tool implementations
│   ├── __init__.py
│   └── my_tool.py
├── providers/            # Model provider implementations
│   └── my_provider.py
├── strategies/           # Agent strategy implementations
│   └── my_strategy.py
├── assets/               # Static assets
│   └── icon.svg
└── tests/
    └── test_tools.py
```

### Manifest Configuration

```yaml
# manifest.yaml
version: "1.0.0"
name: my-plugin
display_name: "My Custom Plugin"
description: "A custom plugin for Dify"
author: "Your Name"
homepage: "https://github.com/username/my-plugin"

type: tool  # tool, model, strategy, extension

runtime:
  python_version: "3.11"
  entry_point: "main.py"

permissions:
  - network
  - file_read
  - environment_variables

tools:
  - name: my_tool
    description: "Description of what the tool does"
    parameters:
      - name: query
        type: string
        required: true
        description: "The search query"
      - name: limit
        type: integer
        required: false
        default: 10
        description: "Max results"

credentials:
  - name: api_key
    type: secret
    required: true
    description: "API key for the service"
```

## Tool Plugin Development

### Basic Tool Structure

```python
from dify_plugin import DifyPluginEnv, Plugin
from dify_plugin.entities.tool import ToolInvokeMessage, ToolParameter
from typing import Generator

class MyToolPlugin(Plugin):
    """Custom tool plugin implementation."""

    def __init__(self, env: DifyPluginEnv):
        super().__init__(env)
        self.api_key = env.credentials.get("api_key")

    def _invoke(
        self,
        tool_parameters: dict
    ) -> Generator[ToolInvokeMessage, None, None]:
        """
        Execute the tool with given parameters.

        Args:
            tool_parameters: Dictionary of input parameters

        Yields:
            ToolInvokeMessage objects with results
        """
        query = tool_parameters.get("query", "")
        limit = tool_parameters.get("limit", 10)

        try:
            results = self._call_external_api(query, limit)

            yield self.create_text_message(
                f"Found {len(results)} results"
            )

            yield self.create_json_message({
                "results": results,
                "query": query,
                "total": len(results)
            })

        except Exception as e:
            yield self.create_error_message(str(e))

    def _call_external_api(self, query: str, limit: int) -> list:
        """Call external API and return results."""
        import requests

        response = requests.get(
            "https://api.example.com/search",
            params={"q": query, "limit": limit},
            headers={"Authorization": f"Bearer {self.api_key}"}
        )
        response.raise_for_status()
        return response.json()["results"]
```

### Message Types

```python
class ToolPlugin(Plugin):
    def _invoke(self, params: dict) -> Generator[ToolInvokeMessage, None, None]:
        yield self.create_text_message("Plain text result")

        yield self.create_json_message({
            "structured": "data",
            "values": [1, 2, 3]
        })

        yield self.create_link_message(
            url="https://example.com",
            title="Example Link"
        )

        yield self.create_image_message(
            image_url="https://example.com/image.png",
            mime_type="image/png"
        )

        yield self.create_file_message(
            file_content=b"binary content",
            filename="output.pdf",
            mime_type="application/pdf"
        )

        yield self.create_error_message(
            "Error description",
            error_code="VALIDATION_ERROR"
        )
```

### Parameter Validation

```python
from dify_plugin.entities.tool import ToolParameter, ParameterType

class ValidatedTool(Plugin):
    @staticmethod
    def get_parameters() -> list[ToolParameter]:
        return [
            ToolParameter(
                name="query",
                type=ParameterType.STRING,
                required=True,
                description="Search query",
                min_length=1,
                max_length=500
            ),
            ToolParameter(
                name="limit",
                type=ParameterType.INTEGER,
                required=False,
                default=10,
                min_value=1,
                max_value=100
            ),
            ToolParameter(
                name="filters",
                type=ParameterType.OBJECT,
                required=False,
                properties={
                    "category": {"type": "string"},
                    "date_from": {"type": "string", "format": "date"}
                }
            ),
            ToolParameter(
                name="tags",
                type=ParameterType.ARRAY,
                required=False,
                items={"type": "string"},
                max_items=10
            )
        ]
```

### HTTP Tool with Retry

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

class HttpTool(Plugin):
    def __init__(self, env: DifyPluginEnv):
        super().__init__(env)
        self.session = self._create_session()

    def _create_session(self) -> requests.Session:
        session = requests.Session()
        retry = Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=[500, 502, 503, 504]
        )
        adapter = HTTPAdapter(max_retries=retry)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        return session

    def _invoke(self, params: dict) -> Generator[ToolInvokeMessage, None, None]:
        try:
            response = self.session.get(
                params["url"],
                timeout=30,
                headers={"Authorization": f"Bearer {self.env.credentials['api_key']}"}
            )
            response.raise_for_status()

            yield self.create_json_message(response.json())

        except requests.exceptions.Timeout:
            yield self.create_error_message("Request timed out")
        except requests.exceptions.RequestException as e:
            yield self.create_error_message(f"Request failed: {e}")
```

## Model Provider Plugin

### Provider Structure

```python
from dify_plugin import DifyPluginEnv, ModelProvider
from dify_plugin.entities.model import (
    LLMModelConfig,
    LLMResult,
    PromptMessage,
    UserPromptMessage,
    AssistantPromptMessage,
    SystemPromptMessage
)
from typing import Generator

class MyModelProvider(ModelProvider):
    """Custom model provider implementation."""

    def __init__(self, env: DifyPluginEnv):
        super().__init__(env)
        self.api_endpoint = env.credentials.get("endpoint")
        self.api_key = env.credentials.get("api_key")

    def invoke(
        self,
        model_config: LLMModelConfig,
        prompt_messages: list[PromptMessage],
        stream: bool = False
    ) -> Generator[LLMResult, None, None]:
        """
        Invoke the language model.

        Args:
            model_config: Model configuration parameters
            prompt_messages: List of prompt messages
            stream: Whether to stream responses

        Yields:
            LLMResult objects with model outputs
        """
        formatted_messages = self._format_messages(prompt_messages)

        if stream:
            yield from self._stream_invoke(model_config, formatted_messages)
        else:
            yield self._blocking_invoke(model_config, formatted_messages)

    def _format_messages(
        self,
        messages: list[PromptMessage]
    ) -> list[dict]:
        """Convert prompt messages to API format."""
        formatted = []
        for msg in messages:
            if isinstance(msg, SystemPromptMessage):
                formatted.append({"role": "system", "content": msg.content})
            elif isinstance(msg, UserPromptMessage):
                formatted.append({"role": "user", "content": msg.content})
            elif isinstance(msg, AssistantPromptMessage):
                formatted.append({"role": "assistant", "content": msg.content})
        return formatted

    def _blocking_invoke(
        self,
        config: LLMModelConfig,
        messages: list[dict]
    ) -> LLMResult:
        """Synchronous model invocation."""
        import requests

        response = requests.post(
            f"{self.api_endpoint}/v1/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}"},
            json={
                "model": config.model,
                "messages": messages,
                "temperature": config.temperature,
                "max_tokens": config.max_tokens
            }
        )
        response.raise_for_status()
        data = response.json()

        return LLMResult(
            content=data["choices"][0]["message"]["content"],
            usage={
                "prompt_tokens": data["usage"]["prompt_tokens"],
                "completion_tokens": data["usage"]["completion_tokens"],
                "total_tokens": data["usage"]["total_tokens"]
            },
            finish_reason=data["choices"][0]["finish_reason"]
        )

    def _stream_invoke(
        self,
        config: LLMModelConfig,
        messages: list[dict]
    ) -> Generator[LLMResult, None, None]:
        """Streaming model invocation."""
        import requests

        response = requests.post(
            f"{self.api_endpoint}/v1/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}"},
            json={
                "model": config.model,
                "messages": messages,
                "temperature": config.temperature,
                "max_tokens": config.max_tokens,
                "stream": True
            },
            stream=True
        )

        for line in response.iter_lines():
            if line:
                chunk = self._parse_sse_line(line)
                if chunk:
                    yield LLMResult(
                        content=chunk["content"],
                        is_final=chunk.get("finish_reason") is not None
                    )

    def _parse_sse_line(self, line: bytes) -> dict | None:
        """Parse SSE line into chunk data."""
        import json
        text = line.decode("utf-8")
        if text.startswith("data: "):
            data = text[6:]
            if data.strip() == "[DONE]":
                return None
            return json.loads(data)["choices"][0]["delta"]
        return None
```

### Model Configuration Schema

```yaml
# In manifest.yaml
models:
  - name: my-model-v1
    display_name: "My Model v1"
    type: llm
    features:
      - chat
      - completion
      - function_calling
    parameters:
      temperature:
        type: float
        default: 0.7
        min: 0
        max: 2
      max_tokens:
        type: integer
        default: 4096
        max: 128000
      top_p:
        type: float
        default: 1.0
    pricing:
      input: 0.001
      output: 0.002
      unit: 1000_tokens
```

## Agent Strategy Plugin

### Strategy Implementation

```python
from dify_plugin import DifyPluginEnv, AgentStrategy
from dify_plugin.entities.agent import (
    AgentInvokeMessage,
    AgentThought,
    ToolCall,
    ToolResult
)
from typing import Generator, Any

class CustomAgentStrategy(AgentStrategy):
    """Custom agent reasoning strategy."""

    def __init__(self, env: DifyPluginEnv):
        super().__init__(env)

    def _invoke(
        self,
        parameters: dict[str, Any]
    ) -> Generator[AgentInvokeMessage, None, None]:
        """
        Execute the agent strategy.

        Args:
            parameters: Agent parameters including query, tools, model config

        Yields:
            AgentInvokeMessage with thoughts, tool calls, and final response
        """
        query = parameters["query"]
        tools = parameters["tools"]
        model_config = parameters["model"]
        max_iterations = parameters.get("max_iterations", 10)

        yield AgentInvokeMessage(
            thought=AgentThought(
                content=f"Starting to process: {query}",
                observation="Analyzing the request..."
            )
        )

        iteration = 0
        context = []

        while iteration < max_iterations:
            iteration += 1

            reasoning_result = self._reason(query, context, tools, model_config)

            if reasoning_result["action"] == "finish":
                yield AgentInvokeMessage(
                    thought=AgentThought(
                        content="Task completed",
                        observation=reasoning_result["reasoning"]
                    ),
                    final_answer=reasoning_result["answer"]
                )
                return

            tool_call = ToolCall(
                tool_name=reasoning_result["tool"],
                tool_input=reasoning_result["input"]
            )

            yield AgentInvokeMessage(
                thought=AgentThought(
                    content=reasoning_result["reasoning"],
                    observation=f"Calling tool: {tool_call.tool_name}"
                ),
                tool_call=tool_call
            )

            tool_result = self._execute_tool(tool_call, tools)

            yield AgentInvokeMessage(
                tool_result=ToolResult(
                    tool_name=tool_call.tool_name,
                    result=tool_result
                )
            )

            context.append({
                "tool": tool_call.tool_name,
                "input": tool_call.tool_input,
                "result": tool_result
            })

        yield AgentInvokeMessage(
            final_answer="Max iterations reached without completion"
        )

    def _reason(
        self,
        query: str,
        context: list,
        tools: list,
        model_config: dict
    ) -> dict:
        """
        Reasoning step - decide next action.

        Returns:
            Dict with action, tool, input, reasoning, or answer
        """
        prompt = self._build_reasoning_prompt(query, context, tools)

        response = self.session.model.llm.invoke(
            model_config=model_config,
            prompt_messages=[
                {"role": "system", "content": self._get_system_prompt()},
                {"role": "user", "content": prompt}
            ],
            stream=False
        )

        return self._parse_reasoning_response(response.content)

    def _get_system_prompt(self) -> str:
        return """You are an intelligent agent that solves problems step by step.

For each step, you must either:
1. Use a tool to gather information
2. Provide a final answer

Format your response as:
THOUGHT: [Your reasoning about what to do next]
ACTION: [tool_name OR finish]
INPUT: [tool input if using a tool]
ANSWER: [final answer if action is finish]"""

    def _build_reasoning_prompt(
        self,
        query: str,
        context: list,
        tools: list
    ) -> str:
        tool_descriptions = "\n".join([
            f"- {t['name']}: {t['description']}"
            for t in tools
        ])

        context_str = ""
        if context:
            context_str = "Previous actions:\n" + "\n".join([
                f"Tool: {c['tool']}, Result: {c['result']}"
                for c in context
            ])

        return f"""Query: {query}

Available tools:
{tool_descriptions}

{context_str}

What should be done next?"""

    def _parse_reasoning_response(self, response: str) -> dict:
        """Parse LLM response into structured action."""
        lines = response.strip().split("\n")
        result = {}

        for line in lines:
            if line.startswith("THOUGHT:"):
                result["reasoning"] = line[8:].strip()
            elif line.startswith("ACTION:"):
                result["action"] = line[7:].strip().lower()
            elif line.startswith("INPUT:"):
                result["input"] = line[6:].strip()
            elif line.startswith("ANSWER:"):
                result["answer"] = line[7:].strip()

        if result.get("action") == "finish":
            result["tool"] = None
        else:
            result["tool"] = result.get("action")
            result["action"] = "tool"

        return result

    def _execute_tool(self, tool_call: ToolCall, tools: list) -> str:
        """Execute a tool and return result."""
        tool = next(
            (t for t in tools if t["name"] == tool_call.tool_name),
            None
        )

        if not tool:
            return f"Tool {tool_call.tool_name} not found"

        tool_instance = self._get_tool_instance(tool)
        result = tool_instance.invoke(tool_call.tool_input)

        return str(result)
```

### ReAct Strategy Example

```python
class ReActStrategy(AgentStrategy):
    """ReAct (Reasoning + Acting) agent strategy."""

    REACT_PROMPT = """Answer the following questions as best you can.

You have access to the following tools:
{tools}

Use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

Question: {input}
{agent_scratchpad}"""

    def _invoke(self, parameters: dict) -> Generator[AgentInvokeMessage, None, None]:
        query = parameters["query"]
        tools = parameters["tools"]

        scratchpad = ""
        max_iterations = parameters.get("max_iterations", 10)

        for i in range(max_iterations):
            prompt = self.REACT_PROMPT.format(
                tools=self._format_tools(tools),
                tool_names=", ".join([t["name"] for t in tools]),
                input=query,
                agent_scratchpad=scratchpad
            )

            response = self._call_llm(prompt, parameters["model"])
            parsed = self._parse_react_output(response)

            yield AgentInvokeMessage(
                thought=AgentThought(
                    content=parsed.get("thought", ""),
                    observation=parsed.get("observation", "")
                )
            )

            if "final_answer" in parsed:
                yield AgentInvokeMessage(
                    final_answer=parsed["final_answer"]
                )
                return

            if "action" in parsed:
                tool_result = self._execute_tool(
                    parsed["action"],
                    parsed["action_input"],
                    tools
                )

                scratchpad += f"\nThought: {parsed['thought']}"
                scratchpad += f"\nAction: {parsed['action']}"
                scratchpad += f"\nAction Input: {parsed['action_input']}"
                scratchpad += f"\nObservation: {tool_result}"

                yield AgentInvokeMessage(
                    tool_result=ToolResult(
                        tool_name=parsed["action"],
                        result=tool_result
                    )
                )
```

## Plugin Testing

### Unit Tests

```python
import pytest
from unittest.mock import Mock, patch
from my_plugin.tools.my_tool import MyToolPlugin

@pytest.fixture
def plugin_env():
    env = Mock()
    env.credentials = {"api_key": "test-key"}
    return env

@pytest.fixture
def plugin(plugin_env):
    return MyToolPlugin(plugin_env)

def test_tool_invoke_success(plugin):
    with patch.object(plugin, '_call_external_api') as mock_api:
        mock_api.return_value = [{"id": 1, "name": "Result"}]

        results = list(plugin._invoke({"query": "test", "limit": 5}))

        assert len(results) == 2
        assert "Found 1 results" in results[0].content
        assert results[1].json_data["total"] == 1

def test_tool_invoke_error(plugin):
    with patch.object(plugin, '_call_external_api') as mock_api:
        mock_api.side_effect = Exception("API Error")

        results = list(plugin._invoke({"query": "test"}))

        assert len(results) == 1
        assert results[0].error is not None

def test_parameter_validation():
    params = MyToolPlugin.get_parameters()

    query_param = next(p for p in params if p.name == "query")
    assert query_param.required is True
    assert query_param.type == ParameterType.STRING
```

### Integration Tests

```python
import pytest
from dify_plugin.testing import PluginTestClient

@pytest.fixture
def client():
    return PluginTestClient(
        manifest_path="manifest.yaml",
        credentials={"api_key": "test-key"}
    )

def test_full_tool_flow(client):
    response = client.invoke_tool(
        tool_name="my_tool",
        parameters={"query": "test query", "limit": 5}
    )

    assert response.success
    assert len(response.messages) > 0

def test_streaming_response(client):
    messages = []

    for msg in client.invoke_tool_stream(
        tool_name="my_tool",
        parameters={"query": "test"}
    ):
        messages.append(msg)

    assert len(messages) > 0
```

## Plugin Deployment

### Building

```bash
dify-plugin build --output dist/my-plugin.zip
```

### Local Testing

```bash
dify-plugin run --manifest manifest.yaml --port 8080
```

### Publishing

```bash
dify-plugin publish --manifest manifest.yaml
```

### Environment Configuration

```yaml
# .env.plugin
API_KEY=your-api-key
ENDPOINT=https://api.example.com

# In code
import os
api_key = os.environ.get("API_KEY")
```

## Best Practices

### Error Handling

```python
class RobustTool(Plugin):
    def _invoke(self, params: dict) -> Generator[ToolInvokeMessage, None, None]:
        try:
            self._validate_params(params)
            result = self._process(params)
            yield self.create_json_message(result)

        except ValidationError as e:
            yield self.create_error_message(
                f"Invalid parameters: {e}",
                error_code="VALIDATION_ERROR"
            )
        except RateLimitError:
            yield self.create_error_message(
                "Rate limit exceeded. Please try again later.",
                error_code="RATE_LIMIT"
            )
        except Exception as e:
            self._log_error(e)
            yield self.create_error_message(
                "An unexpected error occurred",
                error_code="INTERNAL_ERROR"
            )
```

### Logging

```python
import logging

logger = logging.getLogger(__name__)

class LoggedTool(Plugin):
    def _invoke(self, params: dict) -> Generator[ToolInvokeMessage, None, None]:
        logger.info(f"Tool invoked with params: {params}")

        try:
            result = self._process(params)
            logger.info(f"Tool completed successfully")
            yield self.create_json_message(result)

        except Exception as e:
            logger.error(f"Tool failed: {e}", exc_info=True)
            yield self.create_error_message(str(e))
```

### Performance

```python
from functools import lru_cache
import asyncio

class OptimizedTool(Plugin):
    @lru_cache(maxsize=100)
    def _cached_lookup(self, key: str) -> dict:
        """Cache frequently accessed data."""
        return self._fetch_from_api(key)

    async def _async_process(self, items: list) -> list:
        """Process items concurrently."""
        tasks = [self._process_item(item) for item in items]
        return await asyncio.gather(*tasks)
```

### Security

```python
class SecureTool(Plugin):
    def _invoke(self, params: dict) -> Generator[ToolInvokeMessage, None, None]:
        sanitized_input = self._sanitize(params.get("input", ""))

        if not self._validate_url(params.get("url")):
            yield self.create_error_message("Invalid URL")
            return

        if len(sanitized_input) > 10000:
            yield self.create_error_message("Input too large")
            return

        result = self._process(sanitized_input)
        yield self.create_json_message(result)

    def _sanitize(self, text: str) -> str:
        """Remove potentially dangerous content."""
        import re
        text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
        return text.strip()

    def _validate_url(self, url: str) -> bool:
        """Validate URL is safe to access."""
        from urllib.parse import urlparse
        parsed = urlparse(url)
        blocked_hosts = ["localhost", "127.0.0.1", "0.0.0.0"]
        return parsed.hostname not in blocked_hosts
```

## Plugin Manifest Reference

```yaml
version: "1.0.0"
name: plugin-name
display_name: "Plugin Display Name"
description: "Detailed plugin description"
author: "Author Name"
homepage: "https://github.com/author/plugin"
license: "MIT"
icon: "assets/icon.svg"

type: tool  # tool, model, strategy, extension

runtime:
  python_version: "3.11"
  entry_point: "main.py"
  dependencies:
    - "requirements.txt"

permissions:
  - network           # HTTP requests
  - file_read         # Read files
  - file_write        # Write files
  - environment_variables  # Access env vars

credentials:
  - name: api_key
    type: secret
    required: true
    description: "API key for authentication"
  - name: base_url
    type: string
    required: false
    default: "https://api.example.com"
    description: "API base URL"

tools:
  - name: tool_name
    description: "Tool description"
    parameters:
      - name: param1
        type: string
        required: true
      - name: param2
        type: integer
        required: false
        default: 10

models:
  - name: model-name
    display_name: "Model Display Name"
    type: llm
    features:
      - chat
      - function_calling

strategies:
  - name: strategy-name
    display_name: "Strategy Display Name"
    description: "Strategy description"

tags:
  - productivity
  - integration
  - ai
```
