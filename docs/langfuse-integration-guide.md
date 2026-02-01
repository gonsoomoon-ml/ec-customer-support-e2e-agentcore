# Langfuse Integration Guide for AWS Bedrock AgentCore

This document provides a comprehensive guide on integrating Langfuse observability with Amazon Bedrock AgentCore and Strands Agents.

## Table of Contents

- [Overview](#overview)
- [Langfuse Hosting Options](#langfuse-hosting-options)
- [Architecture: How It Works](#architecture-how-it-works)
- [OpenTelemetry: The Bridge](#opentelemetry-the-bridge)
- [Trace Hierarchy and Data Captured](#trace-hierarchy-and-data-captured)
- [Authentication Flow](#authentication-flow)
- [Deployment Modes](#deployment-modes)
- [Configuration](#configuration)
- [The Agentic Loop in Detail](#the-agentic-loop-in-detail)
- [LLM Input/Output Per Step](#llm-inputoutput-per-step)
- [CloudWatch vs Langfuse Comparison](#cloudwatch-vs-langfuse-comparison)
- [Implementation Examples](#implementation-examples)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

Langfuse is an open-source LLM observability platform that provides tracing, monitoring, and evaluation capabilities for AI agents. When integrated with Amazon Bedrock AgentCore, it offers:

- **Trace Visualization**: Hierarchical view of agent execution
- **Cost Tracking**: Detailed per-model token usage and pricing
- **LLM Playground**: Replay and test prompts directly
- **Evaluations**: LLM-as-a-judge automated evaluation
- **Prompt Management**: Version control for prompts
- **Session Analytics**: Group and analyze multi-turn conversations

### Integration Method

The integration uses **OpenTelemetry (OTEL)** as the transport layer. Strands Agents emit OTEL-format traces, which are sent to Langfuse's OTEL endpoint via HTTP.

```
Strands Agent → OTEL Exporter → Langfuse OTEL Endpoint → Langfuse Dashboard
```

---

## Langfuse Hosting Options

Langfuse는 두 가지 방식으로 배포할 수 있습니다:

| 옵션 | 설명 | 장점 | 단점 |
|------|------|------|------|
| **Public Cloud** | Langfuse 관리형 서비스 | 즉시 시작, 유지보수 불필요 | 데이터가 외부 서버에 저장 |
| **Self-hosted Fargate** | AWS ECS에 직접 배포 | 데이터 완전 제어, VPC 내부 운영 | 인프라 관리 필요 |

### Option 1: Public Langfuse Cloud

가장 빠르게 시작할 수 있는 방법입니다. Free tier가 제공됩니다.

**설정 방법:**
1. [langfuse.com](https://langfuse.com) 에서 계정 생성
2. 프로젝트 생성
3. Settings → API Keys에서 키 발급
4. `.env` 파일 설정:
   ```bash
   LANGFUSE_PUBLIC_KEY=pk-lf-your-public-key
   LANGFUSE_SECRET_KEY=sk-lf-your-secret-key
   LANGFUSE_BASE_URL=https://us.cloud.langfuse.com  # US region
   # 또는 https://cloud.langfuse.com  # EU region
   ```

**Endpoints:**
| Region | Base URL |
|--------|----------|
| US | `https://us.cloud.langfuse.com` |
| EU | `https://cloud.langfuse.com` |

### Option 2: Self-hosted on AWS Fargate

데이터를 AWS 내부에서 완전히 제어하려면 ECS Fargate에 Langfuse를 직접 배포할 수 있습니다.

**배포 가이드:** [deploy-langfuse-on-ecs-with-fargate](https://github.com/gonsoomoon-ml/deploy-langfuse-on-ecs-with-fargate)

**아키텍처:**
```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │     ALB     │───▶│  ECS Fargate │───▶│   Aurora    │     │
│  │  (Public)   │    │  (Langfuse)  │    │ PostgreSQL  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                                                    │
│         │ HTTP/HTTPS                                         │
│         ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              AgentCore Runtime                       │    │
│  │         (OTEL traces → Langfuse ALB)                │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**설정 방법:**
1. GitHub 저장소 클론 및 CDK 배포
2. 배포 완료 후 ALB DNS 확인
3. Langfuse 웹 UI (ALB 주소)에서 프로젝트 및 API 키 생성
4. `.env` 파일 설정:
   ```bash
   LANGFUSE_PUBLIC_KEY=pk-lf-your-key
   LANGFUSE_SECRET_KEY=sk-lf-your-key
   LANGFUSE_BASE_URL=http://your-alb-endpoint.region.elb.amazonaws.com
   ```

**Self-hosted 장점:**
- 데이터가 AWS VPC 내부에만 저장
- 기업 보안 정책 준수 용이
- 네트워크 지연 시간 최소화
- 커스텀 도메인 및 SSL 설정 가능

---

## Architecture: How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Agent Code                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │ LLM Call    │───▶│ Tool Call   │───▶│ LLM Call    │              │
│  │ (Claude)    │    │ (check_     │    │ (Final      │              │
│  │             │    │  return)    │    │  Response)  │              │
│  └─────────────┘    └─────────────┘    └─────────────┘              │
│         │                  │                  │                      │
│         ▼                  ▼                  ▼                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Strands Telemetry (Auto-Instrumentation)        │    │
│  │   - Captures: inputs, outputs, tokens, latency, errors      │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
└──────────────────────────────│───────────────────────────────────────┘
                               │ OTEL Protocol (HTTP/gRPC)
                               ▼
                    ┌─────────────────────┐
                    │   OTEL Exporter     │
                    │ (OTLP over HTTPS)   │
                    └─────────────────────┘
                               │
                               │ Authorization: Basic {base64(pk:sk)}
                               ▼
                    ┌─────────────────────┐
                    │     Langfuse        │
                    │  /api/public/otel   │
                    └─────────────────────┘
```

---

## OpenTelemetry: The Bridge

OpenTelemetry (OTEL) is a CNCF standard for distributed tracing. It serves as the bridge between your agent and Langfuse.

### Key Concepts

| Concept | Description | Langfuse Mapping |
|---------|-------------|------------------|
| **Trace** | A complete request/response cycle | Langfuse Trace |
| **Span** | An individual operation within a trace | Langfuse Observation |
| **Event** | A point-in-time occurrence within a span | Langfuse Event |
| **Attribute** | Key-value metadata attached to spans | Langfuse Metadata |

### How Strands Telemetry Works

When you call `StrandsTelemetry().setup_otlp_exporter()`, it:

1. Initializes the OTEL SDK with the configured exporter
2. Instruments the Strands Agent SDK automatically
3. Captures all LLM calls, tool executions, and agent lifecycle events
4. Batches and sends traces to the configured endpoint

```python
from strands.telemetry import StrandsTelemetry

# This single line enables all telemetry
strands_telemetry = StrandsTelemetry().setup_otlp_exporter()
```

---

## Trace Hierarchy and Data Captured

### Trace Structure

```
Trace (one per agent invocation)
│
├── Span: agent.invoke
│   ├── Attribute: user.id = "customer@example.com"
│   ├── Attribute: session.id = "session-123"
│   │
│   ├── Span: llm.chat (1st LLM call)
│   │   ├── Event: gen_ai.system.message (system prompt)
│   │   ├── Event: gen_ai.user.message (user input)
│   │   ├── Event: gen_ai.choice (tool_use decision)
│   │   ├── Attribute: gen_ai.usage.input_tokens = 1500
│   │   ├── Attribute: gen_ai.usage.output_tokens = 200
│   │   └── Attribute: gen_ai.response.model = "claude-3-7-sonnet"
│   │
│   ├── Span: tool.execute (tool call)
│   │   ├── Attribute: tool.name = "check_return_eligibility"
│   │   ├── Attribute: tool.input = {"order_id": "ORD-123"}
│   │   ├── Attribute: tool.output = {"eligible": true, ...}
│   │   └── Attribute: duration_ms = 150
│   │
│   └── Span: llm.chat (2nd LLM call - final response)
│       ├── Event: gen_ai.tool.message (tool result)
│       ├── Event: gen_ai.choice (end_turn)
│       └── Attribute: gen_ai.usage.output_tokens = 350
```

### Data Captured at Each Level

| Level | Data | Purpose |
|-------|------|---------|
| **Trace** | trace_id, session_id, user_id, tags | Group related operations |
| **Span** | name, start_time, end_time, status | Measure individual operations |
| **Event** | gen_ai.* events with content | Capture message content |
| **Attribute** | tokens, model, latency, metadata | Metrics and context |

### Event Types (gen_ai.* namespace)

| Event | Description |
|-------|-------------|
| `gen_ai.system.message` | System prompt content |
| `gen_ai.user.message` | User input message |
| `gen_ai.assistant.message` | LLM response (including tool calls) |
| `gen_ai.tool.message` | Tool execution result |
| `gen_ai.choice` | LLM decision (`tool_use` or `end_turn`) |
| `strands.telemetry.tracer` | Strands agent internal events |

---

## Authentication Flow

Langfuse uses **Basic Auth** over the OTEL HTTP endpoint.

### Step-by-Step

```python
# Step 1: Get credentials from Langfuse project settings
LANGFUSE_PUBLIC_KEY = "pk-lf-xxxxxxxx"
LANGFUSE_SECRET_KEY = "sk-lf-xxxxxxxx"

# Step 2: Create Basic Auth token
import base64
auth_string = f"{LANGFUSE_PUBLIC_KEY}:{LANGFUSE_SECRET_KEY}"
auth_token = base64.b64encode(auth_string.encode()).decode()
# Result: "cGstbGYteHh4eHh4eHg6c2stbGYteHh4eHh4eHg="

# Step 3: Set OTEL exporter headers
os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://us.cloud.langfuse.com/api/public/otel"
os.environ["OTEL_EXPORTER_OTLP_HEADERS"] = f"Authorization=Basic {auth_token}"
```

### HTTP Request Format

When traces are sent to Langfuse:

```
POST https://us.cloud.langfuse.com/api/public/otel/v1/traces
Headers:
  Authorization: Basic cGstbGYteHh4eHh4eHg6c2stbGYteHh4eHh4eHg=
  Content-Type: application/x-protobuf
Body: [OTEL trace data in protobuf format]
```

### Langfuse Endpoints

| Region | Endpoint |
|--------|----------|
| US | `https://us.cloud.langfuse.com/api/public/otel` |
| EU | `https://cloud.langfuse.com/api/public/otel` |
| Self-hosted | `https://your-domain.com/api/public/otel` |

---

## Deployment Modes

### Mode A: Local Development (Direct OTEL)

Use this mode when running agents locally for development and testing.

```python
import os
import base64
from strands import Agent
from strands.telemetry import StrandsTelemetry
from strands.models.bedrock import BedrockModel

# Configure Langfuse credentials
os.environ["LANGFUSE_PUBLIC_KEY"] = "pk-lf-..."
os.environ["LANGFUSE_SECRET_KEY"] = "sk-lf-..."
os.environ["LANGFUSE_BASE_URL"] = "https://us.cloud.langfuse.com"

LANGFUSE_AUTH = base64.b64encode(
    f"{os.environ['LANGFUSE_PUBLIC_KEY']}:{os.environ['LANGFUSE_SECRET_KEY']}".encode()
).decode()

os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = f"{os.environ['LANGFUSE_BASE_URL']}/api/public/otel"
os.environ["OTEL_EXPORTER_OTLP_HEADERS"] = f"Authorization=Basic {LANGFUSE_AUTH}"

# Initialize telemetry - sends directly to Langfuse
StrandsTelemetry().setup_otlp_exporter()

model = BedrockModel(model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0")

agent = Agent(
    model=model,
    system_prompt="You are a helpful assistant.",
    trace_attributes={
        "session.id": "local-test-123",
        "user.id": "developer@example.com",
        "langfuse.tags": ["development", "test"]
    }
)

# Traces go to Langfuse immediately
response = agent("Hello, how can you help me?")
```

**Data Flow:**
```
┌──────────────┐         ┌──────────────┐
│  Your Code   │──OTEL──▶│   Langfuse   │
│  (Local)     │         │   Cloud      │
└──────────────┘         └──────────────┘
```

### Mode B: AgentCore Runtime (Container Environment)

Use this mode when deploying agents to AgentCore Runtime in production.

**Entrypoint file (e.g., `agent_entrypoint.py`):**

```python
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.telemetry import StrandsTelemetry
from strands.models.bedrock import BedrockModel

app = BedrockAgentCoreApp()

def initialize_agent():
    """Initialize agent with telemetry from environment variables."""
    # Telemetry reads OTEL_* env vars set during launch()
    StrandsTelemetry().setup_otlp_exporter()

    model = BedrockModel(model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0")

    agent = Agent(
        model=model,
        system_prompt="You are a helpful assistant.",
        tools=[...]
    )
    return agent

@app.entrypoint
async def invoke(payload):
    """Streaming entrypoint for AgentCore Runtime."""
    agent = initialize_agent()
    user_input = payload.get("prompt", "")

    async for event in agent.stream_async(user_input):
        yield event

if __name__ == "__main__":
    app.run()
```

**Deployment notebook:**

```python
import base64
from bedrock_agentcore_starter_toolkit import Runtime

# Langfuse configuration
langfuse_public_key = "pk-lf-..."
langfuse_secret_key = "sk-lf-..."
langfuse_auth = base64.b64encode(
    f"{langfuse_public_key}:{langfuse_secret_key}".encode()
).decode()

otel_endpoint = "https://us.cloud.langfuse.com/api/public/otel"
otel_headers = f"Authorization=Basic {langfuse_auth}"

# Configure runtime
runtime = Runtime()
runtime.configure(
    entrypoint="agent_entrypoint.py",
    execution_role=execution_role_arn,
    agent_name="my-agent-with-langfuse",
    region=region,
    disable_otel=True,  # Disable CloudWatch OTEL, use Langfuse instead
)

# Launch with Langfuse environment variables
runtime.launch(
    env_vars={
        "OTEL_EXPORTER_OTLP_ENDPOINT": otel_endpoint,
        "OTEL_EXPORTER_OTLP_HEADERS": otel_headers,
        "DISABLE_ADOT_OBSERVABILITY": "true"
    }
)
```

**Data Flow:**
```
┌─────────────────────────────────────────────────────────────┐
│                   AgentCore Runtime                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Container   │    │   Strands    │    │    OTEL      │  │
│  │  (ECR)       │───▶│   Agent      │───▶│   Exporter   │──┼──▶ Langfuse
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         ▲                                                    │
│         │ env_vars from launch()                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Configuration

### Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `LANGFUSE_PUBLIC_KEY` | Langfuse public API key | `pk-lf-xxxxxxxx` |
| `LANGFUSE_SECRET_KEY` | Langfuse secret API key | `sk-lf-xxxxxxxx` |
| `LANGFUSE_BASE_URL` | Langfuse instance URL | `https://us.cloud.langfuse.com` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTEL exporter endpoint | `https://us.cloud.langfuse.com/api/public/otel` |
| `OTEL_EXPORTER_OTLP_HEADERS` | OTEL auth headers | `Authorization=Basic xxx...` |
| `OTEL_SERVICE_NAME` | Service name in traces | `ecommerce-agent` |
| `DISABLE_ADOT_OBSERVABILITY` | Disable AWS ADOT | `true` |

### Trace Attributes

Configure trace attributes in the Agent constructor to organize data in Langfuse:

```python
agent = Agent(
    model=model,
    trace_attributes={
        # Required for Langfuse grouping
        "session.id": "unique-session-id",      # Groups multi-turn conversations
        "user.id": "customer@example.com",      # User-level analytics

        # Optional Langfuse-specific
        "langfuse.tags": ["production", "kr"],  # Filterable tags
        "langfuse.metadata": {                  # Custom metadata
            "customer_tier": "premium",
            "order_value": 150000
        }
    }
)
```

### Installation

```bash
# Install required packages
pip install strands-agents[otel] langfuse

# Or with UV
uv add strands-agents[otel] langfuse
```

The `[otel]` extra is required to enable OpenTelemetry instrumentation.

---

## The Agentic Loop in Detail

When your agent processes a request, here's what gets traced:

```
Request: "반품하고 싶어요" (I want to return something)

┌─────────────────────────────────────────────────────────────────────┐
│ Trace: agent-invocation-abc123                                       │
│ Session: lab5-session-xyz                                           │
│ User: customer@example.com                                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ [0ms] ─────────────────────────────────────────────────────────────│
│       │                                                              │
│       ▼                                                              │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Span: llm.chat.completion (1200ms)                              │ │
│ │ Model: us.anthropic.claude-3-7-sonnet                           │ │
│ │ Input Tokens: 1,847  |  Output Tokens: 156                      │ │
│ │                                                                  │ │
│ │ Events:                                                          │ │
│ │   • gen_ai.system.message: "당신은 K-Style 이커머스..."          │ │
│ │   • gen_ai.user.message: "반품하고 싶어요"                       │ │
│ │   • gen_ai.choice: tool_use → check_return_eligibility          │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│       │                                                              │
│       ▼                                                              │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Span: tool.check_return_eligibility (89ms)                      │ │
│ │ Input: {"order_id": "ORD-20240115-TEST"}                        │ │
│ │ Output: {"eligible": true, "reason": "14일 이내", ...}          │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│       │                                                              │
│       ▼                                                              │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Span: llm.chat.completion (1850ms)                              │ │
│ │ Model: us.anthropic.claude-3-7-sonnet                           │ │
│ │ Input Tokens: 2,103  |  Output Tokens: 287                      │ │
│ │                                                                  │ │
│ │ Events:                                                          │ │
│ │   • gen_ai.tool.message: {"eligible": true, ...}                │ │
│ │   • gen_ai.choice: end_turn                                     │ │
│ │   • gen_ai.assistant.message: "네, 반품 가능합니다..."           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│ [3139ms] ──────────────────────────────────────────────────────────│
│                                                                      │
│ Total: 3.14s | Tokens: 3,950 in / 443 out | Cost: $0.0156          │
└─────────────────────────────────────────────────────────────────────┘
```

### What Langfuse Shows

Once Langfuse receives the OTEL traces, it provides:

| Feature | How It Uses Trace Data |
|---------|------------------------|
| **Trace Timeline** | Visualizes spans hierarchically with timing |
| **Cost Calculation** | Uses `input_tokens` + `output_tokens` + model pricing |
| **Latency Analysis** | Aggregates span durations by operation type |
| **Session Grouping** | Groups traces by `session.id` attribute |
| **User Analytics** | Tracks usage per `user.id` |
| **Error Debugging** | Shows span status and error messages |
| **LLM Playground** | Replays prompts using captured messages |
| **Evaluations** | Runs LLM-as-a-judge on captured inputs/outputs |

---

## LLM Input/Output Per Step

This section shows the actual message content that flows into and out of the LLM at each step of the agentic loop.

### Step 1: First LLM Call (User Request → Tool Decision)

**INPUT to LLM:**

```json
{
  "messages": [
    {
      "role": "system",
      "content": "당신은 K-Style 이커머스 고객 지원 에이전트입니다.\n\n사용 가능한 도구:\n- check_return_eligibility: 주문의 반품 가능 여부 확인\n- get_product_recommendations: 상품 추천\n- process_return_request: 반품 처리\n\n고객에게 친절하고 도움이 되는 응답을 제공하세요."
    },
    {
      "role": "user",
      "content": "주문번호 ORD-20240115-TEST의 '플라워 패턴 원피스' 반품이 가능한가요?"
    }
  ],
  "tools": [
    {
      "name": "check_return_eligibility",
      "description": "Check if an order is eligible for return",
      "input_schema": {
        "type": "object",
        "properties": {
          "order_id": {"type": "string"}
        },
        "required": ["order_id"]
      }
    }
  ]
}
```

**OUTPUT from LLM:**

```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "네, 주문번호 ORD-20240115-TEST의 반품 가능 여부를 확인해 드리겠습니다."
    },
    {
      "type": "tool_use",
      "id": "toolu_01ABC123",
      "name": "check_return_eligibility",
      "input": {
        "order_id": "ORD-20240115-TEST"
      }
    }
  ],
  "stop_reason": "tool_use",
  "usage": {
    "input_tokens": 1500,
    "output_tokens": 156
  }
}
```

### Step 2: Tool Execution (Agent Runtime, not LLM)

The agent runtime executes the tool function locally. This is NOT an LLM call.

**Tool Input:**

```json
{
  "order_id": "ORD-20240115-TEST"
}
```

**Tool Output:**

```json
{
  "order_id": "ORD-20240115-TEST",
  "product_name": "플라워 패턴 원피스",
  "eligible": true,
  "reason": "구매 후 14일 이내",
  "purchase_date": "2024-01-15",
  "return_deadline": "2024-01-29",
  "refund_amount": 89000,
  "return_method": "무료 반품 픽업"
}
```

### Step 3: Second LLM Call (Tool Result → Final Response)

**INPUT to LLM:**

Note how all previous messages are included (conversation history accumulates).

```json
{
  "messages": [
    {
      "role": "system",
      "content": "당신은 K-Style 이커머스 고객 지원 에이전트입니다..."
    },
    {
      "role": "user",
      "content": "주문번호 ORD-20240115-TEST의 '플라워 패턴 원피스' 반품이 가능한가요?"
    },
    {
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "네, 주문번호 ORD-20240115-TEST의 반품 가능 여부를 확인해 드리겠습니다."
        },
        {
          "type": "tool_use",
          "id": "toolu_01ABC123",
          "name": "check_return_eligibility",
          "input": {"order_id": "ORD-20240115-TEST"}
        }
      ]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "tool_result",
          "tool_use_id": "toolu_01ABC123",
          "content": "{\"order_id\": \"ORD-20240115-TEST\", \"product_name\": \"플라워 패턴 원피스\", \"eligible\": true, \"reason\": \"구매 후 14일 이내\", \"purchase_date\": \"2024-01-15\", \"return_deadline\": \"2024-01-29\", \"refund_amount\": 89000, \"return_method\": \"무료 반품 픽업\"}"
        }
      ]
    }
  ]
}
```

**OUTPUT from LLM:**

```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "네, 주문번호 ORD-20240115-TEST의 '플라워 패턴 원피스' 반품이 가능합니다!\n\n📋 **반품 정보**\n- **반품 가능 여부**: 가능\n- **사유**: 구매 후 14일 이내 (구매일: 2024-01-15)\n- **반품 기한**: 2024년 1월 29일까지\n- **환불 금액**: 89,000원\n- **반품 방법**: 무료 반품 픽업\n\n반품을 진행하시겠습니까? 진행을 원하시면 말씀해 주세요. 무료 픽업 서비스를 예약해 드리겠습니다."
    }
  ],
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 2103,
    "output_tokens": 287
  }
}
```

### Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AGENTIC LOOP                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ╔═══════════════════════════════════════════════════════════════════════════╗  │
│  ║  STEP 1: First LLM Call                                                   ║  │
│  ╠═══════════════════════════════════════════════════════════════════════════╣  │
│  ║                                                                           ║  │
│  ║  INPUT                              OUTPUT                                ║  │
│  ║  ┌─────────────────────┐           ┌─────────────────────┐               ║  │
│  ║  │ System: K-Style     │           │ Text: "확인해       │               ║  │
│  ║  │ 고객 지원 에이전트... │    ───▶   │ 드리겠습니다"       │               ║  │
│  ║  ├─────────────────────┤           ├─────────────────────┤               ║  │
│  ║  │ User: "반품이       │           │ Tool Use:           │               ║  │
│  ║  │ 가능한가요?"        │           │ check_return_       │               ║  │
│  ║  ├─────────────────────┤           │ eligibility         │               ║  │
│  ║  │ Tools: [check_      │           │ {order_id: "ORD-"}  │               ║  │
│  ║  │ return_eligibility] │           └─────────────────────┘               ║  │
│  ║  └─────────────────────┘           stop_reason: "tool_use"               ║  │
│  ║                                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════════════════════╝  │
│                                     │                                            │
│                                     ▼                                            │
│  ╔═══════════════════════════════════════════════════════════════════════════╗  │
│  ║  STEP 2: Tool Execution (Agent Runtime - NOT LLM)                         ║  │
│  ╠═══════════════════════════════════════════════════════════════════════════╣  │
│  ║                                                                           ║  │
│  ║  ┌─────────────────────┐           ┌─────────────────────┐               ║  │
│  ║  │ Tool Input:         │           │ Tool Output:        │               ║  │
│  ║  │ {                   │    ───▶   │ {                   │               ║  │
│  ║  │   order_id:         │  (DB/API) │   eligible: true,   │               ║  │
│  ║  │   "ORD-20240115"    │           │   refund: 89000,    │               ║  │
│  ║  │ }                   │           │   deadline: "1/29"  │               ║  │
│  ║  └─────────────────────┘           │ }                   │               ║  │
│  ║                                    └─────────────────────┘               ║  │
│  ║                                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════════════════════╝  │
│                                     │                                            │
│                                     ▼                                            │
│  ╔═══════════════════════════════════════════════════════════════════════════╗  │
│  ║  STEP 3: Second LLM Call                                                  ║  │
│  ╠═══════════════════════════════════════════════════════════════════════════╣  │
│  ║                                                                           ║  │
│  ║  INPUT                              OUTPUT                                ║  │
│  ║  ┌─────────────────────┐           ┌─────────────────────┐               ║  │
│  ║  │ System: (same)      │           │ Text:               │               ║  │
│  ║  ├─────────────────────┤           │ "네, 반품이         │               ║  │
│  ║  │ User: "반품 가능?"  │    ───▶   │ 가능합니다!         │               ║  │
│  ║  ├─────────────────────┤           │                     │               ║  │
│  ║  │ Assistant: tool_use │           │ 📋 반품 정보        │               ║  │
│  ║  ├─────────────────────┤           │ - 환불: 89,000원    │               ║  │
│  ║  │ User (tool_result): │           │ - 기한: 1/29        │               ║  │
│  ║  │ {eligible: true...} │           │ - 무료 픽업 가능"   │               ║  │
│  ║  └─────────────────────┘           └─────────────────────┘               ║  │
│  ║                                    stop_reason: "end_turn"               ║  │
│  ║                                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════════════════════╝  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Message Accumulation Pattern

The key insight is that **messages accumulate** with each LLM call:

| LLM Call | Messages in Context |
|----------|---------------------|
| **1st** | `[system, user]` |
| **2nd** | `[system, user, assistant(tool_use), user(tool_result)]` |
| **3rd** (if needed) | `[system, user, assistant, user(tool_result), assistant(tool_use_2), user(tool_result_2)]` |

This is why `input_tokens` increases with each call:
- 1st call: 1,500 tokens (system + user)
- 2nd call: 2,103 tokens (system + user + assistant + tool_result)

### Multi-Tool Example

If the agent needs multiple tools, the loop continues:

```
Step 1: LLM → tool_use (tool A)
Step 2: Execute tool A → result A
Step 3: LLM → tool_use (tool B)  ← receives result A, decides to call another tool
Step 4: Execute tool B → result B
Step 5: LLM → end_turn           ← receives both results, generates final response
```

**Message accumulation for multi-tool:**

```json
{
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "original question"},
    {"role": "assistant", "content": [{"type": "tool_use", "name": "tool_A", ...}]},
    {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "A", ...}]},
    {"role": "assistant", "content": [{"type": "tool_use", "name": "tool_B", ...}]},
    {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "B", ...}]}
  ]
}
```

---

## CloudWatch vs Langfuse Comparison

### Feature Comparison

| Feature | CloudWatch GenAI Observability | Langfuse |
|---------|-------------------------------|----------|
| **Setup** | Automatic (default in AgentCore) | Manual configuration required |
| **Cost Tracking** | Basic | Detailed per-model pricing |
| **LLM Playground** | No | Yes (test prompts directly) |
| **Evaluations** | Manual | LLM-as-a-judge built-in |
| **Prompt Management** | No | Version control for prompts |
| **Open Source** | No | Yes (self-host option) |
| **AWS Native** | Yes | Partner integration |
| **X-Ray Integration** | Yes | No |
| **Logs Insights** | Yes | Limited |

### Data Flow Comparison

```
                    ┌─────────────────────────────────────────────────┐
                    │            AgentCore Runtime                     │
                    │  ┌─────────────────────────────────────────┐    │
                    │  │          Strands Agent                   │    │
                    │  │    (with OTEL instrumentation)          │    │
                    │  └─────────────────────────────────────────┘    │
                    │                     │                            │
                    │                     │ OTEL traces                │
                    │                     ▼                            │
                    │  ┌─────────────────────────────────────────┐    │
                    │  │         OTEL Collector/Exporter          │    │
                    │  └─────────────────────────────────────────┘    │
                    │              │                  │                │
                    └──────────────│──────────────────│────────────────┘
                                   │                  │
           ┌───────────────────────┘                  └───────────────────────┐
           │ (Default: AWS ADOT)                      │ (Custom: Langfuse)    │
           ▼                                          ▼
┌─────────────────────────┐                ┌─────────────────────────┐
│   CloudWatch GenAI      │                │       Langfuse          │
│   Observability         │                │                         │
├─────────────────────────┤                ├─────────────────────────┤
│ • AWS native            │                │ • Open source           │
│ • Auto-enabled          │                │ • LLM Playground        │
│ • X-Ray integration     │                │ • Prompt versioning     │
│ • Basic dashboards      │                │ • LLM-as-judge evals    │
│ • Logs Insights queries │                │ • Rich UI               │
└─────────────────────────┘                └─────────────────────────┘
```

### When to Use Which

| Use Case | Recommendation |
|----------|----------------|
| AWS-only infrastructure, minimal setup | CloudWatch |
| Need prompt versioning and A/B testing | Langfuse |
| Want LLM-as-a-judge evaluations | Langfuse |
| Require X-Ray distributed tracing | CloudWatch |
| Open source / self-hosted requirement | Langfuse |
| Multi-cloud or hybrid deployments | Langfuse |

---

## Implementation Examples

### Example 1: Local Development with Langfuse

```python
import os
import base64
from strands import Agent
from strands.telemetry import StrandsTelemetry
from strands.models.bedrock import BedrockModel

# Configure Langfuse
os.environ["LANGFUSE_PUBLIC_KEY"] = "pk-lf-..."
os.environ["LANGFUSE_SECRET_KEY"] = "sk-lf-..."
LANGFUSE_AUTH = base64.b64encode(
    f"{os.environ['LANGFUSE_PUBLIC_KEY']}:{os.environ['LANGFUSE_SECRET_KEY']}".encode()
).decode()
os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://us.cloud.langfuse.com/api/public/otel"
os.environ["OTEL_EXPORTER_OTLP_HEADERS"] = f"Authorization=Basic {LANGFUSE_AUTH}"

# Initialize telemetry
StrandsTelemetry().setup_otlp_exporter()

# Create agent
model = BedrockModel(model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0")
agent = Agent(
    model=model,
    system_prompt="You are a helpful e-commerce assistant.",
    trace_attributes={
        "session.id": "dev-session-001",
        "user.id": "developer@example.com"
    }
)

# Run agent
response = agent("What products do you have?")
print(response)
```

### Example 2: AgentCore Runtime with Langfuse

**File: `langfuse_agent.py`**

```python
import os
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent, tool
from strands.telemetry import StrandsTelemetry
from strands.models.bedrock import BedrockModel

app = BedrockAgentCoreApp()

@tool
def check_return_eligibility(order_id: str) -> dict:
    """Check if an order is eligible for return."""
    return {
        "order_id": order_id,
        "eligible": True,
        "reason": "Within 14-day return window"
    }

def create_agent():
    StrandsTelemetry().setup_otlp_exporter()

    model = BedrockModel(
        model_id=os.getenv("BEDROCK_MODEL_ID", "us.anthropic.claude-3-7-sonnet-20250219-v1:0")
    )

    return Agent(
        model=model,
        system_prompt="You are a K-Style e-commerce customer support agent.",
        tools=[check_return_eligibility]
    )

@app.entrypoint
async def invoke(payload):
    agent = create_agent()
    user_input = payload.get("prompt", "")
    async for event in agent.stream_async(user_input):
        yield event

if __name__ == "__main__":
    app.run()
```

**Deployment:**

```python
import base64
from bedrock_agentcore_starter_toolkit import Runtime

# Langfuse credentials
langfuse_pk = "pk-lf-..."
langfuse_sk = "sk-lf-..."
langfuse_auth = base64.b64encode(f"{langfuse_pk}:{langfuse_sk}".encode()).decode()

runtime = Runtime()
runtime.configure(
    entrypoint="langfuse_agent.py",
    execution_role=execution_role_arn,
    agent_name="ecommerce-agent-langfuse",
    region=region,
    disable_otel=True,
)

runtime.launch(
    env_vars={
        "BEDROCK_MODEL_ID": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        "OTEL_EXPORTER_OTLP_ENDPOINT": "https://us.cloud.langfuse.com/api/public/otel",
        "OTEL_EXPORTER_OTLP_HEADERS": f"Authorization=Basic {langfuse_auth}",
        "DISABLE_ADOT_OBSERVABILITY": "true"
    }
)
```

### Example 3: Using Langfuse Python SDK with Strands

For more advanced use cases, you can combine Strands telemetry with Langfuse's Python SDK:

```python
from langfuse import observe, propagate_attributes, get_client
from strands import Agent
from strands.telemetry import StrandsTelemetry

StrandsTelemetry().setup_otlp_exporter()

@observe()
def process_customer_request(user_input: str, customer_id: str):
    """Process a customer request with additional Langfuse tracking."""
    with propagate_attributes(
        user_id=customer_id,
        session_id=f"session-{customer_id}",
        tags=["customer-support"],
        metadata={"source": "web-chat"}
    ):
        agent = Agent(model=model, tools=[...])
        result = agent(user_input)

        # Update trace with custom data
        langfuse = get_client()
        langfuse.update_current_trace(
            input=user_input,
            output=result,
            metadata={"customer_id": customer_id}
        )

        return result

langfuse.flush()  # Ensure all traces are sent
```

---

## Troubleshooting

### Error: Traces not appearing in Langfuse

**Possible causes:**

1. **Missing OTEL extra**: Ensure you installed with `[otel]`
   ```bash
   pip install strands-agents[otel]
   ```

2. **Incorrect credentials**: Verify your public/secret keys
   ```python
   # Test authentication
   import requests
   response = requests.get(
       "https://us.cloud.langfuse.com/api/public/health",
       headers={"Authorization": f"Basic {langfuse_auth}"}
   )
   print(response.status_code)  # Should be 200
   ```

3. **Telemetry not initialized**: Ensure `setup_otlp_exporter()` is called before agent creation

4. **Environment variables not set**: Check all required env vars are set
   ```python
   print(os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT"))
   print(os.environ.get("OTEL_EXPORTER_OTLP_HEADERS"))
   ```

### Error: ADOT and Langfuse conflict

**Cause**: Both CloudWatch ADOT and Langfuse OTEL exporters are active

**Solution**: Disable ADOT when using Langfuse
```python
runtime.configure(
    ...
    disable_otel=True,  # Disable AgentCore's built-in OTEL
)

runtime.launch(
    env_vars={
        "DISABLE_ADOT_OBSERVABILITY": "true",
        ...
    }
)
```

### Error: Missing trace attributes in Langfuse

**Cause**: `trace_attributes` not passed to Agent

**Solution**: Always include trace attributes
```python
agent = Agent(
    model=model,
    trace_attributes={
        "session.id": session_id,
        "user.id": user_id
    }
)
```

### Error: High latency in trace delivery

**Cause**: Traces are batched and sent periodically

**Solution**: For real-time debugging, flush manually
```python
from langfuse import get_client
langfuse = get_client()
langfuse.flush()
```

---

## References

### Official Documentation

- [Langfuse + Amazon Bedrock Integration](https://langfuse.com/integrations/model-providers/amazon-bedrock)
- [Langfuse + Amazon Bedrock AgentCore](https://langfuse.com/integrations/frameworks/amazon-agentcore)
- [Langfuse + Strands Agents](https://langfuse.com/integrations/frameworks/strands-agents)
- [AWS Blog: AgentCore Observability with Langfuse](https://aws.amazon.com/blogs/machine-learning/amazon-bedrock-agentcore-observability-with-langfuse/)

### Sample Code

- [AgentCore Samples - Langfuse Notebook](https://github.com/awslabs/amazon-bedrock-agentcore-samples/blob/main/01-tutorials/06-AgentCore-observability/04-Agentcore-runtime-partner-observability/Langfuse/runtime_with_strands_and_langfuse.ipynb)
- [Strands Agents Observability Sample](https://github.com/strands-agents/samples/blob/main/01-tutorials/01-fundamentals/08-observability-and-evaluation/Observability-and-Evaluation-sample.ipynb)
- [Langfuse Docs - AWS Strands Agents Cookbook](https://github.com/langfuse/langfuse-docs/blob/main/cookbook/integration_aws_strands_agents.ipynb)

### Self-hosted Deployment

- [Deploy Langfuse on ECS with Fargate](https://github.com/gonsoomoon-ml/deploy-langfuse-on-ecs-with-fargate) - AWS Fargate에 Langfuse 배포 가이드

### Related Documentation

- [Amazon Bedrock AgentCore Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [OpenTelemetry Python SDK](https://opentelemetry.io/docs/languages/python/)
- [Langfuse OpenTelemetry Integration](https://langfuse.com/docs/integrations/opentelemetry)
