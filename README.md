# Amazon Bedrock AgentCore Tutorial

한국 패션/뷰티 이커머스 고객 지원 시나리오로 배우는 **Amazon Bedrock AgentCore** 핸즈온 튜토리얼

## What You'll Learn

이 튜토리얼을 통해 AgentCore의 핵심 기능을 실습합니다:

| AgentCore 기능 | 학습 내용 | Lab |
|----------------|----------|-----|
| **Memory** | 고객별 컨텍스트 저장/조회, 메모리 훅 구현 | Lab 2 |
| **Gateway** | Lambda를 MCP 도구로 노출, JWT 인증 설정 | Lab 3 |
| **Runtime** | 컨테이너 기반 에이전트 배포, 자동 확장 | Lab 4 |
| **Observability** | OpenTelemetry 추적, CloudWatch GenAI 대시보드 | Lab 5 |
| **External Observability** | Langfuse 통합 (선택) | Lab 6 |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    K-Style Customer Support Agent                    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
              ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
              │  AgentCore  │───▶│   Strands   │───▶│   Bedrock   │
              │   Runtime   │    │    Agent    │    │   Claude    │
              └─────────────┘    └─────────────┘    └─────────────┘
                    │                  │
                    ▼                  ▼
             ┌─────────────┐    ┌───────────────┐
             │  AgentCore  │    │  Local Tools  │
             │   Memory    │    │  (@tool)      │
             └─────────────┘    └───────────────┘
                    │
                    ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Cognito   │    │  AgentCore  │    │  CloudWatch │
│  Identity   │    │   Gateway   │    │   GenAI     │
│  (JWT 인증)  │    │(Lambda→MCP) │    │ Observability│
└─────────────┘    └─────────────┘    └─────────────┘
```

## Prerequisites

### Required
- Python 3.12+
- AWS CLI configured
- AWS Account with `AdministratorAccess` (or equivalent permissions)

### Optional (Lab 6 - Langfuse Observability)

Langfuse는 두 가지 방식으로 사용할 수 있습니다:

| 옵션 | 설명 | 링크 |
|------|------|------|
| **Public Langfuse** | 클라우드 서비스 (빠른 시작) | [langfuse.com](https://langfuse.com) |
| **Self-hosted Fargate** | AWS ECS에 직접 배포 | [deploy-langfuse-on-ecs-with-fargate](https://github.com/gonsoomoon-ml/deploy-langfuse-on-ecs-with-fargate) |

## Quick Start

```bash
# 1. Clone and setup environment
git clone <repository-url>
cd ec-customer-support-e2e-agentcore
./setup/setup_env.sh
source .venv/bin/activate

# 2. Verify AWS credentials
./setup/setup_aws.sh

# 3. Deploy infrastructure (Cognito, IAM, Lambda)
./setup/deploy_infra.sh

# 4. Open notebooks in VS Code and run Lab 1-6
```

## Tutorial Labs

### Lab 1: Strands Agent Basics
**파일**: `lab-01-create-ecommerce-agent.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| Strands Agent 생성 | `Agent()` 클래스로 기본 에이전트 구성 |
| @tool 데코레이터 | 반품/교환/추천 도구 정의 |
| 에이전트 호출 | 동기/비동기 호출 패턴 |

### Lab 2: AgentCore Memory
**파일**: `lab-02-agentcore-memory.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| Memory 생성 | `create_memory()` API |
| 메모리 훅 | `EcommerceCustomerMemoryHooks` 구현 |
| 컨텍스트 저장 | 고객 선호도, 구매 이력, 사이즈 정보 |

### Lab 3: AgentCore Gateway
**파일**: `lab-03-agentcore-gateway.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| Gateway 생성 | Lambda를 MCP 도구로 노출 |
| Target 설정 | Lambda ARN 연결 |
| JWT 인증 | Cognito 기반 인증 설정 |

### Lab 4: AgentCore Runtime
**파일**: `lab-04-agentcore-runtime/lab-04-agentcore-runtime.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| Runtime 배포 | 컨테이너 기반 에이전트 호스팅 |
| 엔드포인트 생성 | HTTPS 엔드포인트 자동 생성 |
| JWT 인증 호출 | Cognito 토큰으로 인증된 호출 |

### Lab 5: AgentCore Observability (CloudWatch)
**파일**: `lab-05-agentcore-observability/lab-05-agentcore-observability.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| ADOT 설정 | OpenTelemetry 자동 계측 |
| 스트리밍 배포 | 실시간 응답 스트리밍 |
| CloudWatch GenAI | 추적, 세션, 이벤트 시각화 |

### Lab 6: Langfuse Observability (Optional)
**파일**: `lab-06-agentcore-observability-langfuse/lab-06-agentcore-observability-langfuse.ipynb`

| 학습 목표 | 내용 |
|----------|------|
| Langfuse 통합 | `StrandsTelemetry` 설정 |
| 배포 옵션 | Public Cloud 또는 Self-hosted Fargate 선택 |
| 비용 추적 | 토큰 사용량, 비용 시각화 |

**Langfuse 배포 옵션:**
- **Public**: [langfuse.com](https://langfuse.com) - 빠른 설정, Free tier 제공
- **Self-hosted**: [deploy-langfuse-on-ecs-with-fargate](https://github.com/gonsoomoon-ml/deploy-langfuse-on-ecs-with-fargate) - 데이터 완전 제어

📖 **상세 가이드**: [Langfuse Integration Guide](docs/langfuse-integration-guide.md)

> **Note**: CloudWatch와 Langfuse는 동시 사용 불가 (TracerProvider 충돌)

### Lab 9: Cleanup
**파일**: `lab-09-cleanup.ipynb`

| 기능 | 내용 |
|------|------|
| 패턴 기반 삭제 | 프로젝트 리소스만 선택적 삭제 |
| 전체 삭제 | `DELETE_ALL=True`로 모든 AgentCore 리소스 삭제 |
| 인프라 삭제 | Step 11 주석 해제로 CloudFormation까지 삭제 |

## Project Structure

```
ec-customer-support-e2e-agentcore/
├── notebooks/                    # Tutorial Labs
│   ├── lab-01-create-ecommerce-agent.ipynb
│   ├── lab-02-agentcore-memory.ipynb
│   ├── lab-03-agentcore-gateway.ipynb
│   ├── lab-04-agentcore-runtime/
│   ├── lab-05-agentcore-observability/
│   ├── lab-06-agentcore-observability-langfuse/
│   └── lab-09-cleanup.ipynb
├── src/                          # Source Code
│   ├── agent.py                  # Main agent
│   ├── tools/                    # Customer support tools
│   └── helpers/                  # Utilities (SSM, Cognito, Memory hooks)
├── setup/                        # Infrastructure
│   ├── setup_env.sh              # Python environment
│   ├── setup_aws.sh              # AWS verification
│   ├── deploy_infra.sh           # CloudFormation deployment
│   └── cloudformation/           # CFn templates
└── docs/                         # Documentation
```

## Tech Stack

| Category | Technologies |
|----------|-------------|
| **LLM** | Amazon Bedrock, Claude Sonnet |
| **Agent Framework** | Strands Agents |
| **AgentCore** | Memory, Gateway, Runtime, Observability |
| **Observability** | OpenTelemetry, CloudWatch GenAI, Langfuse |
| **Infrastructure** | CloudFormation, Cognito, Lambda |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `bedrock-agentcore-control` not found | Update AWS CLI and boto3 to latest version |
| Gateway target deletion fails | Check `items` key in API response (not `targets`) |
| Dual observability not working | Use either CloudWatch OR Langfuse, not both |
| Runtime deployment timeout | Check IAM permissions for CodeBuild |

## References

- [Amazon Bedrock AgentCore Documentation](https://docs.aws.amazon.com/bedrock-agentcore/)
- [Strands Agents Framework](https://github.com/strands-agents/strands-agents)
- [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/)
- [Langfuse Documentation](https://langfuse.com/docs)
- [Deploy Langfuse on ECS with Fargate](https://github.com/gonsoomoon-ml/deploy-langfuse-on-ecs-with-fargate)
