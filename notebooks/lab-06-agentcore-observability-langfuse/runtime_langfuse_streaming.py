"""
AgentCore Runtime용 이커머스 고객 지원 에이전트 - Langfuse 관측성 버전
Lab 06: Langfuse를 사용한 AgentCore 관측성

Lab 05와의 차이점:
- StrandsTelemetry로 OTEL 익스포터 설정 (Langfuse로 전송)
- trace_attributes로 세션/사용자 추적
- AWS ADOT 대신 Langfuse 사용
"""
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel
from strands.telemetry import StrandsTelemetry

from ecommerce_tools import (
    check_return_eligibility,
    process_return_request,
    get_product_recommendations,
    ECOMMERCE_SYSTEM_PROMPT,
    ECOMMERCE_MODEL_ID,
)

# ============================================================
# Langfuse 텔레메트리 설정
# OTEL_EXPORTER_OTLP_ENDPOINT 및 OTEL_EXPORTER_OTLP_HEADERS
# 환경 변수를 통해 Langfuse로 트레이스 전송
# ============================================================
StrandsTelemetry().setup_otlp_exporter()

# ============================================================
# 모델 설정
# ============================================================
model = BedrockModel(model_id=ECOMMERCE_MODEL_ID)

app = BedrockAgentCoreApp()


def create_agent(session_id: str = None, user_id: str = None) -> Agent:
    """
    Langfuse 추적이 가능한 에이전트 생성

    Args:
        session_id: Langfuse에서 대화를 그룹화하는 세션 ID
        user_id: Langfuse에서 사용자별 분석을 위한 사용자 ID

    Returns:
        trace_attributes가 설정된 Agent 인스턴스
    """
    trace_attributes = {}

    if session_id:
        trace_attributes["session.id"] = session_id
    if user_id:
        trace_attributes["user.id"] = user_id

    # Langfuse 태그 추가 (선택사항)
    trace_attributes["langfuse.tags"] = ["ecommerce", "agentcore", "customer-support", "lab-06"]

    return Agent(
        model=model,
        tools=[check_return_eligibility, process_return_request, get_product_recommendations],
        system_prompt=ECOMMERCE_SYSTEM_PROMPT,
        trace_attributes=trace_attributes if trace_attributes else None,
    )


@app.entrypoint
async def invoke(payload):
    """
    AgentCore Runtime 엔트리포인트 - Langfuse 관측성 버전

    payload 형식:
    {
        "prompt": "사용자 메시지",
        "session_id": "세션 ID (선택)",
        "user_id": "사용자 ID (선택)"
    }

    Langfuse에서 확인할 수 있는 정보:
    - 트레이스 타임라인 (각 LLM 호출 및 도구 실행)
    - 토큰 사용량 및 비용
    - 세션별 대화 그룹화
    - 사용자별 분석
    """
    user_input = payload.get("prompt", "")
    session_id = payload.get("session_id")
    user_id = payload.get("user_id")

    # 세션/사용자 ID가 포함된 에이전트 생성
    agent = create_agent(session_id=session_id, user_id=user_id)

    # 스트리밍 응답 생성
    async for event in agent.stream_async(user_input):
        yield event


if __name__ == "__main__":
    app.run()
