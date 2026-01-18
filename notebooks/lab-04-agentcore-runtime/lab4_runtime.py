"""
AgentCore Runtime용 이커머스 고객 지원 에이전트
도구를 ecommerce_tools.py에서 import하여 사용합니다.
"""
from bedrock_agentcore.runtime import (
    BedrockAgentCoreApp,
)  #### AGENTCORE RUNTIME - LINE 1 ####
from strands import Agent
from strands.models import BedrockModel

# 같은 디렉토리의 ecommerce_tools에서 도구와 설정 import
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

app = BedrockAgentCoreApp()  #### AGENTCORE RUNTIME - LINE 2 ####


@app.entrypoint  #### AGENTCORE RUNTIME - LINE 3 ####
def invoke(payload):
    """AgentCore Runtime 엔트리포인트 함수"""
    user_input = payload.get("prompt", "")
    response = agent(user_input)
    return response.message["content"][0]["text"]


if __name__ == "__main__":
    app.run()  #### AGENTCORE RUNTIME - LINE 4 ####
