# Strands Agents Tool 결과 Mocking 가이드

외부 검증자가 Agent 코드 수정 없이 Tool 결과를 모킹하여 테스트하는 방법을 설명합니다.

## Table of Contents

- [Overview](#overview)
- [Use Cases](#use-cases)
- [방법 1: Messages 파라미터로 History 주입](#방법-1-messages-파라미터로-history-주입)
- [방법 2: Hook으로 Tool 실행 가로채기](#방법-2-hook으로-tool-실행-가로채기)
- [Message Format Reference](#message-format-reference)
- [방법 비교](#방법-비교)

---

## Overview

Strands Agents에서 Tool 결과를 모킹하는 두 가지 방법이 있습니다:

| 방법 | 설명 | Agent 코드 수정 |
|------|------|----------------|
| **Messages 주입** | Agent 생성 시 가짜 대화 History 전달 | 불필요 |
| **Hook 사용** | Tool 실행 직전 가로채서 Mock 결과 반환 | 불필요 |

---

## Use Cases

- **QA/평가**: 다양한 Tool 응답 시나리오 테스트
- **보안 감사**: 악의적인 Tool 응답에 대한 Agent 반응 검증
- **외부 검증**: Agent 구성을 건드리지 않고 동작 검증
- **개발/디버깅**: 실제 외부 서비스 호출 없이 빠른 테스트

---

## 방법 1: Messages 파라미터로 History 주입

Agent 생성 시 `messages` 파라미터로 이전 대화 기록(Tool call 포함)을 주입합니다.

### 기본 사용법

```python
from strands import Agent

# 가짜 Tool call history 구성
fake_history = [
    # 1. User 요청
    {
        "role": "user",
        "content": [{"text": "재고 확인해줘"}]
    },
    # 2. Assistant의 Tool 호출
    {
        "role": "assistant",
        "content": [
            {"text": "재고를 확인하겠습니다."},
            {
                "toolUse": {
                    "toolUseId": "tool_123",
                    "name": "check_inventory",
                    "input": {"product_id": "SKU001"}
                }
            }
        ]
    },
    # 3. Tool 결과 (user role로 전달)
    {
        "role": "user",
        "content": [
            {
                "toolResult": {
                    "toolUseId": "tool_123",  # toolUse의 ID와 일치해야 함
                    "status": "success",
                    "content": [{"text": "품절입니다. 재입고 예정일: 2024-01-15"}]
                }
            }
        ]
    }
]

# Agent 생성 시 history 주입
agent = Agent(
    model="us.anthropic.claude-3-7-sonnet-20250219-v1:0",
    tools=[check_inventory, process_return],
    messages=fake_history  # ← History 주입
)

# 이후 호출 - Agent는 이전 Tool call이 있었던 것처럼 인식
response = agent("그럼 어떻게 해야해?")
```

### 복수 Tool 호출 시나리오

```python
fake_history = [
    {
        "role": "user",
        "content": [{"text": "주문 ORD-123 반품 처리해줘"}]
    },
    {
        "role": "assistant",
        "content": [
            {"text": "주문 정보를 확인하고 반품 처리를 진행하겠습니다."},
            {
                "toolUse": {
                    "toolUseId": "tool_001",
                    "name": "get_order_info",
                    "input": {"order_id": "ORD-123"}
                }
            }
        ]
    },
    {
        "role": "user",
        "content": [
            {
                "toolResult": {
                    "toolUseId": "tool_001",
                    "status": "success",
                    "content": [{"text": "주문번호: ORD-123, 상품: 코트, 금액: 150,000원"}]
                }
            }
        ]
    },
    {
        "role": "assistant",
        "content": [
            {"text": "주문 확인되었습니다. 반품 접수를 진행합니다."},
            {
                "toolUse": {
                    "toolUseId": "tool_002",
                    "name": "process_return",
                    "input": {"order_id": "ORD-123", "reason": "사이즈 불일치"}
                }
            }
        ]
    },
    {
        "role": "user",
        "content": [
            {
                "toolResult": {
                    "toolUseId": "tool_002",
                    "status": "success",
                    "content": [{"text": "반품 접수 완료. 반품번호: RET-456"}]
                }
            }
        ]
    }
]

agent = Agent(model=model, tools=tools, messages=fake_history)
response = agent("환불은 언제 되나요?")
```

---

## 방법 2: Hook으로 Tool 실행 가로채기

`BeforeToolCallEvent` Hook을 사용하여 Tool 실행 직전에 가로채고 Mock 결과를 반환합니다.

### 작동 원리

```
[User] "재고 확인해줘"
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent                                                       │
│       │                                                      │
│       ▼                                                      │
│  [LLM] "check_inventory tool을 호출해야겠다"                  │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────┐                │
│  │  BeforeToolCallEvent 발생               │ ◀── Hook 개입  │
│  │                                         │                │
│  │  event.tool_use = {                     │                │
│  │    "name": "check_inventory",           │                │
│  │    "toolUseId": "xxx",                  │                │
│  │    "input": {"product_id": "SKU001"}    │                │
│  │  }                                      │                │
│  │                                         │                │
│  │  ⚡ event.cancel_tool = "품절입니다"     │ ◀── Mock 주입  │
│  └─────────────────────────────────────────┘                │
│       │                                                      │
│       ▼                                                      │
│  [실제 Tool 실행 SKIP] ← cancel_tool 설정 시 실행 안함        │
│       │                                                      │
│       ▼                                                      │
│  [LLM] Mock 결과("품절입니다")를 받고 응답 생성               │
└───────┼─────────────────────────────────────────────────────┘
        ▼
[User] "해당 상품은 현재 품절 상태입니다..."
```

### 기본 구현

```python
from strands import Agent
from strands.hooks import BeforeToolCallEvent, HookProvider, HookRegistry

class MockToolHooks(HookProvider):
    def __init__(self, mock_responses: dict):
        """
        mock_responses 형식:
        {
            "tool_name": "mocked result string"
        }
        """
        self.mock_responses = mock_responses

    def register_hooks(self, registry: HookRegistry) -> None:
        registry.add_callback(BeforeToolCallEvent, self.intercept)

    def intercept(self, event: BeforeToolCallEvent) -> None:
        tool_name = event.tool_use["name"]

        if tool_name in self.mock_responses:
            # cancel_tool에 문자열 설정 → 실제 실행 취소, 이 값이 Tool 결과로 사용
            event.cancel_tool = self.mock_responses[tool_name]

# 사용
mock_data = {
    "check_inventory": "품절입니다. 재입고 예정일: 2024-01-15",
    "process_return": "반품 접수 완료. 반품번호: RET-12345"
}

agent = Agent(
    model="us.anthropic.claude-3-7-sonnet-20250219-v1:0",
    tools=[check_inventory, process_return],
    hooks=[MockToolHooks(mock_data)]  # ← Hook 주입
)

response = agent("SKU001 재고 확인해줘")
```

### `cancel_tool` 속성 동작

| `cancel_tool` 값 | 동작 |
|------------------|------|
| `False` (기본값) | 실제 Tool 실행 |
| `"문자열"` | Tool 실행 취소, 이 문자열이 Tool 결과로 LLM에 전달 |
| `True` | Tool 실행 취소, 기본 에러 메시지 반환 |

### 선택적 Mocking (일부 Tool만)

```python
class SelectiveMockHooks(HookProvider):
    def __init__(self, mock_responses: dict):
        self.mock_responses = mock_responses

    def register_hooks(self, registry: HookRegistry) -> None:
        registry.add_callback(BeforeToolCallEvent, self.intercept)

    def intercept(self, event: BeforeToolCallEvent) -> None:
        tool_name = event.tool_use["name"]

        if tool_name in self.mock_responses:
            event.cancel_tool = self.mock_responses[tool_name]  # Mock
        # else: cancel_tool = False 유지 → 실제 Tool 실행

# check_inventory만 Mock, 나머지 Tool은 실제 실행
hooks = SelectiveMockHooks({"check_inventory": "품절입니다"})
agent = Agent(model=model, tools=tools, hooks=[hooks])
```

### Input 기반 조건부 Mocking

```python
class ConditionalMockHooks(HookProvider):
    def __init__(self):
        self.mock_rules = {
            "check_inventory": {
                "SKU001": "품절입니다",
                "SKU002": "재고 10개",
                "default": "상품을 찾을 수 없습니다"
            }
        }

    def register_hooks(self, registry: HookRegistry) -> None:
        registry.add_callback(BeforeToolCallEvent, self.intercept)

    def intercept(self, event: BeforeToolCallEvent) -> None:
        tool_name = event.tool_use["name"]
        tool_input = event.tool_use["input"]

        if tool_name == "check_inventory":
            product_id = tool_input.get("product_id", "")
            rules = self.mock_rules[tool_name]

            if product_id in rules:
                event.cancel_tool = rules[product_id]
            else:
                event.cancel_tool = rules["default"]
```

### 디버깅용 로깅 추가

```python
class MockToolHooksWithLogging(HookProvider):
    def __init__(self, mock_responses: dict):
        self.mock_responses = mock_responses

    def register_hooks(self, registry: HookRegistry) -> None:
        registry.add_callback(BeforeToolCallEvent, self.intercept)

    def intercept(self, event: BeforeToolCallEvent) -> None:
        tool_name = event.tool_use["name"]
        tool_input = event.tool_use["input"]
        tool_id = event.tool_use["toolUseId"]

        print(f"[Hook] Tool 호출 감지")
        print(f"  - Name: {tool_name}")
        print(f"  - ID: {tool_id}")
        print(f"  - Input: {tool_input}")

        if tool_name in self.mock_responses:
            event.cancel_tool = self.mock_responses[tool_name]
            print(f"  - Action: MOCKED → {event.cancel_tool}")
        else:
            print(f"  - Action: REAL EXECUTION")
```

---

## Message Format Reference

### ContentBlock 구조

```python
from typing import TypedDict, List, Any

class ToolUse(TypedDict):
    toolUseId: str   # 고유 식별자
    name: str        # Tool 이름
    input: Any       # Tool에 전달될 파라미터

class ToolResultContent(TypedDict, total=False):
    text: str
    json: Any

class ToolResult(TypedDict):
    toolUseId: str                    # ToolUse의 ID와 일치해야 함
    status: str                       # "success" | "error"
    content: List[ToolResultContent]

class ContentBlock(TypedDict, total=False):
    text: str
    toolUse: ToolUse
    toolResult: ToolResult

class Message(TypedDict):
    role: str                    # "user" | "assistant"
    content: List[ContentBlock]
```

### 예시: 완전한 Message History

```python
messages = [
    # User 메시지
    {
        "role": "user",
        "content": [
            {"text": "사용자 입력 텍스트"}
        ]
    },

    # Assistant 메시지 (텍스트 + Tool 호출)
    {
        "role": "assistant",
        "content": [
            {"text": "응답 텍스트"},
            {
                "toolUse": {
                    "toolUseId": "unique_id_123",
                    "name": "tool_name",
                    "input": {"param1": "value1"}
                }
            }
        ]
    },

    # Tool 결과 (user role)
    {
        "role": "user",
        "content": [
            {
                "toolResult": {
                    "toolUseId": "unique_id_123",
                    "status": "success",
                    "content": [{"text": "Tool 실행 결과"}]
                }
            }
        ]
    }
]
```

---

## 방법 비교

| 측면 | Messages 주입 | Hook 사용 |
|------|--------------|-----------|
| **Agent 코드 수정** | 불필요 | 불필요 |
| **구현 복잡도** | 낮음 (데이터 구성만) | 중간 (Hook 클래스 작성) |
| **유연성** | 정적 시나리오 | 동적/조건부 Mocking 가능 |
| **사용 시점** | Agent 생성 시 | Tool 호출 시점 |
| **선택적 Mocking** | 어려움 | 쉬움 |
| **Best For** | 전체 대화 흐름 시뮬레이션 | 특정 Tool만 Mocking |

### 권장 사용 시나리오

- **Messages 주입**: 특정 시점부터의 Agent 동작 테스트, 저장된 대화 재현
- **Hook 사용**: 실시간 Tool Mocking, 조건부 응답, 선택적 Mocking

---

## References

- Strands Agents SDK: `/strands/agent/agent.py`
- Hook Events: `/strands/hooks/events.py`
- Message Types: `/strands/types/content.py`
- Tool Types: `/strands/types/tools.py`
