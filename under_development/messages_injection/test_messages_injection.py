"""
Tool 호출 없이 Agent 테스트: 가짜 Tool 결과를 대화 기록으로 주입

Agent 생성 시 messages 파라미터에 가짜 대화 기록(Tool call 포함)을
주입하여 Agent가 이전 Tool 호출이 있었던 것처럼 인식하게 합니다.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from strands import Agent
from strands.models import BedrockModel
import boto3

from src.agent import process_return, process_exchange, web_search, MODEL_ID, SYSTEM_PROMPT


def create_test_agent(messages=None):
    """테스트용 Agent 생성"""
    region = boto3.session.Session().region_name

    model = BedrockModel(
        model_id=MODEL_ID,
        temperature=0.3,
        region_name=region
    )

    agent = Agent(
        model=model,
        tools=[process_return, process_exchange, web_search],
        system_prompt=SYSTEM_PROMPT,
        messages=messages
        # callback_handler 제거 → 스트리밍 출력 활성화
    )

    return agent


def test_return_tool_history():
    """Tool 결과 주입 후 Agent가 자연스럽게 응답하는지 테스트"""

    # 가짜 Tool call history
    fake_history = [
        {"role": "user", "content": [{"text": "주문번호 KS-2024-001234 니트 반품해주세요"}]},
        {"role": "assistant", "content": [
            {"text": "반품 처리 진행합니다."},
            {"toolUse": {"toolUseId": "mock_001", "name": "process_return",
                        "input": {"order_number": "KS-2024-001234", "item_name": "니트", "reason": "사이즈"}}}
        ]},
        {"role": "user", "content": [
            {"toolResult": {"toolUseId": "mock_001", "status": "success",
                           "content": [{"text": "✅ 반품 접수 완료. 접수번호: RT-MOCK-001, 환불 예정액: 59,000원"}]}}
        ]}
    ]

    # Trace Diagram 스타일 출력
    print("\n📖 시나리오: 반품 Tool 결과 주입 테스트")
    print("=" * 70)

    print("\n📝 fake_history 구조:")
    print("-" * 70)
    print("""
    fake_history = [
        # [1] User → Agent
        {"role": "user",
         "content": [{"text": "주문번호 KS-2024-001234 니트 반품해주세요"}]},

        # [3] LLM → Agent (text + toolUse)
        {"role": "assistant",
         "content": [
            {"text": "반품 처리 진행합니다."},
            {"toolUse": {"toolUseId": "mock_001", "name": "process_return",
                        "input": {"order_number": "...", "item_name": "니트"}}}
        ]},

        # [5] Tool → Agent (toolResult)
        {"role": "user",
         "content": [
            {"toolResult": {"toolUseId": "mock_001", "status": "success",
                           "content": [{"text": "✅ 반품 접수 완료. RT-MOCK-001"}]}}
        ]}
    ]
    """)
    print("-" * 70)

    print("\n📊 Trace Diagram:")
    print("=" * 70)
    print("    User              Agent              LLM               Tool")
    print("=" * 70)

    print("\n[1] User → Agent: 고객 요청 (fake_history[0])")
    print("    │")
    print("    │  \"주문번호 KS-2024-001234 니트 반품해주세요\"")
    print("    │")
    print("    ▼")
    print("-" * 70)

    print("\n[2] Agent → LLM: 메시지 전달")
    print("                  │")
    print("                  │  messages + tools 정보")
    print("                  │")
    print("                  ▼")
    print("-" * 70)

    print("\n[3] LLM → Agent: Tool 호출 결정 (fake_history[1])")
    print("                  │")
    print("                  │  text: \"반품 처리 진행합니다.\"")
    print("                  │  toolUse: process_return(...)")
    print("                  │")
    print("                  ▼")
    print("-" * 70)

    print("\n[4] Agent → Tool: Tool 실행")
    print("                                          │")
    print("                                          │  process_return()")
    print("                                          │")
    print("                                          ▼")
    print("-" * 70)

    print("\n[5] Tool → Agent: 결과 반환 (fake_history[2])")
    print("                                          │")
    print("                  ◀─────────────────────────")
    print("                  │")
    print("                  │  \"✅ 반품 접수 완료. RT-MOCK-001, 59,000원\"")
    print("                  │")
    print("-" * 70)
    print("\n" + "=" * 70)
    print("    ↑↑↑ 여기까지 fake_history로 주입 (실제 실행 X) ↑↑↑")
    print("=" * 70)
    print("    ↓↓↓ 여기서부터 실제 실행 ↓↓↓")
    print("=" * 70)

    print("\n[6] User → Agent: 후속 메시지 (실제)")
    print("    │")
    print("    │  \"네 알겠습니다\"")
    print("    │")
    print("    ▼")
    print("-" * 70)

    print("\n[7] Agent → LLM: API 호출 (실제)")
    print("                  │")
    print("                  │  fake_history + 새 메시지")
    print("                  │")
    print("                  ▼")
    print("-" * 70)

    print("\n[8] LLM → Agent: 응답 생성")
    print("                  │")
    print("                  ▼")
    print("-" * 70)

    print("\n[9] Agent → User: 최종 응답 전달")
    print("-" * 70)

    agent = create_test_agent(messages=fake_history)

    try:
        print("\n👤 User Input: \"네 알겠습니다\"")
        print("   └─▶ agent(\"네 알겠습니다\") 호출")
        print("       └─▶ fake_history + 새 메시지를 LLM에 전송")
        print("\n🤖 Agent Response (실시간 스트리밍):")
        print("=" * 40)
        agent("네 알겠습니다")  # 실제 LLM API 호출 → 스트리밍 응답
        print("\n" + "=" * 40)
        print("\n" + "-" * 70)

        print("\n📊 결과 분석")
        print("=" * 70)

        print("\n• [1]~[5]: fake_history로 주입됨 (Tool 실행 없음)")
        print("• [6]~[8]: 실제 API 호출 발생")
        print("• LLM은 fake_history를 실제 대화로 인식")
        print("• Mock 데이터(RT-MOCK-001, 59,000원)를 참조하여 응답 생성")
        print("-" * 70)
    except Exception as e:
        print(f"[오류] {e}")


if __name__ == "__main__":
    print("Tool 호출 없이 Agent 테스트: 가짜 Tool 결과를 대화 기록으로 주입")
    print("=" * 50)
    test_return_tool_history()
