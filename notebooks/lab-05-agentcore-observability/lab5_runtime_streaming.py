"""
AgentCore Runtime용 이커머스 고객 지원 에이전트 - STREAMING 버전
Lab 05: AgentCore 관측성 테스트용

이 파일은 Lab 04의 non-streaming 버전과 달리:
- async def invoke() 사용
- agent.stream_async() 사용
- yield로 이벤트 스트리밍
"""
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel

from ecommerce_tools import (
    check_return_eligibility,
    process_return_request,
    get_product_recommendations,
    ECOMMERCE_SYSTEM_PROMPT,
    ECOMMERCE_MODEL_ID,
)

# ============================================================
# 에이전트 및 런타임 앱 설정
# ============================================================
model = BedrockModel(model_id=ECOMMERCE_MODEL_ID)

agent = Agent(
    model=model,
    tools=[check_return_eligibility, process_return_request, get_product_recommendations],
    system_prompt=ECOMMERCE_SYSTEM_PROMPT,
)

app = BedrockAgentCoreApp()


@app.entrypoint
async def invoke(payload):
    """
    AgentCore Runtime 엔트리포인트 - STREAMING 버전

    Lab 04 (Non-streaming):
        def invoke(payload):
            response = agent(user_input)
            return response.message["content"][0]["text"]

    Lab 05 (Streaming):
        async def invoke(payload):
            async for event in agent.stream_async(user_input):
                yield event
    """
    user_input = payload.get("prompt", "")

    # stream_async()를 사용하여 스트리밍 응답 생성
    async for event in agent.stream_async(user_input):
        yield event


if __name__ == "__main__":
    app.run()
