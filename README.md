# K-Style E-Commerce Customer Support Agent

Amazon Bedrock AgentCore를 활용한 한국 패션/뷰티 이커머스 고객 지원 AI 에이전트

> Memory로 기억하고, Gateway로 연결하고, Runtime으로 배포하고, Observability로 관측한다.

## 기존 고객 지원의 문제 (Why?)

이커머스 고객 지원은 사람에 크게 의존하고 있습니다. 아래와 같은 문제가 있습니다.

| 기존 워크플로우 문제 | 영향 |
|---------------------|------|
| 24시간 대응 불가 | 야간/주말 문의 → 고객 이탈 |
| 일관성 없는 응답 | 상담원마다 다른 답변 → 고객 혼란 |
| 고객 정보 단절 | 매번 새로 설명 → 불만족 |
| 확장성 한계 | 트래픽 증가 시 대기 시간 증가 |
| 높은 운영 비용 | 인력 충원 → 비용 부담 |

## 만들고자 하는 것 (What?)

**목표**: AgentCore 기반으로 고객을 기억하고, 외부 시스템과 연동하며, 자동 확장되는 AI 고객 지원 시스템

| 문제 | 해결책 | 구현 방식 |
|------|--------|----------|
| 24시간 대응 불가 | AI 에이전트 상시 운영 | Bedrock Runtime으로 자동 확장 |
| 일관성 없는 응답 | 표준화된 도구 기반 응답 | Strands Agent + @tool 데코레이터 |
| 고객 정보 단절 | 고객별 컨텍스트 유지 | AgentCore Memory로 선호도/이력 저장 |
| 확장성 한계 | 서버리스 아키텍처 | AgentCore Runtime 자동 스케일링 |
| 외부 시스템 연동 | Lambda 기반 도구 통합 | AgentCore Gateway로 MCP 도구 노출 |
| 운영 가시성 부족 | 실시간 모니터링 | AgentCore Observability + CloudWatch |

### Technical Approach

| 기술 | 적용 방식 |
|------|----------|
| **Strands Agents** | @tool 데코레이터로 반품/교환/추천 도구 정의 |
| **AgentCore Memory** | 고객 선호도, 구매 이력, 사이즈 정보 영구 저장 |
| **AgentCore Gateway** | Lambda 함수를 MCP 도구로 노출하여 에이전트가 호출 |
| **AgentCore Runtime** | 컨테이너 기반 에이전트 호스팅 및 자동 확장 |
| **AgentCore Observability** | OpenTelemetry 기반 추적, CloudWatch GenAI 관측성 |
| **Cognito Identity** | JWT 인증으로 고객별 세션 관리 |

## 어떻게 만드나 (How?)

7개 Lab을 통해 단계별로 시스템을 구축합니다.

| Lab | 주제 | 학습 내용 |
|-----|------|----------|
| Lab 1 | Strands Agent | 기본 에이전트 생성, @tool 정의 |
| Lab 2 | AgentCore Memory | 고객 정보 저장/조회, 메모리 훅 |
| Lab 3 | AgentCore Gateway | Lambda → MCP 도구 변환, IAM 설정 |
| Lab 4 | AgentCore Runtime | 컨테이너 배포, JWT 인증, 엔드포인트 생성 |
| Lab 5 | AgentCore Observability | 스트리밍 배포, CloudWatch GenAI 관측성 |
| Lab 6 | Streamlit Frontend | 인증 UI, 채팅 인터페이스 |
| Lab 7 | Cleanup | 리소스 정리 |

```
┌─────────────────────────────────────────────────────────────────────┐
│                        K-Style Customer Support                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Streamlit  │───▶│  AgentCore  │───▶│   Strands   │───▶│   Bedrock   │
│     UI      │    │   Runtime   │    │    Agent    │    │   Claude    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │
       │                  │                  ▼
       │                  │         ┌───────────────┐
       │                  │         │  Local Tools  │
       │                  │         │ ┌───────────┐ │
       │                  │         │ │ 반품 처리 │ │
       │                  │         │ │ 교환 처리 │ │
       │                  │         │ │ 상품 추천 │ │
       │                  │         │ └───────────┘ │
       │                  │         └───────────────┘
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Cognito   │    │  AgentCore  │    │  AgentCore  │    │  CloudWatch │
│  Identity   │    │   Memory    │    │   Gateway   │    │   GenAI     │
│  (JWT 인증)  │    │ (고객 정보) │    │(Lambda 도구)│    │ Observability│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Prerequisites

### 시스템 요구사항
- Python 3.12+
- AWS CLI 설치 및 구성
- UV 패키지 매니저 (자동 설치됨)

### AWS IAM 권한

| 스크립트 | 필요 권한 |
|----------|-----------|
| `setup_aws.sh` | `sts:GetCallerIdentity`, `ssm:GetParameter`, `s3:ListBuckets`, `cloudformation:ListStacks` |
| `deploy_infra.sh` | `cloudformation:*`, `iam:*`, `s3:*`, `lambda:*`, `dynamodb:*`, `ssm:*`, `cognito-idp:*` |

> **권장**: `AdministratorAccess` 또는 위 권한을 포함하는 IAM 정책 사용

## Quick Start

```bash
# 1. 환경 설정
./setup/setup_env.sh
source .venv/bin/activate

# 2. AWS 인증 확인
./setup/setup_aws.sh

# 3. 인프라 배포 (CloudFormation)
./setup/deploy_infra.sh

# 4. Jupyter Lab 실행
jupyter lab notebooks/

# 5. Streamlit 앱 실행
streamlit run src/ui/streamlit_app.py
```

### Lab 실행 순서

```bash
# notebooks/ 폴더에서 순서대로 실행
notebooks/
├── lab-01-create-ecommerce-agent.ipynb     # 기본 에이전트
├── lab-02-agentcore-memory.ipynb           # 메모리 통합
├── lab-03-agentcore-gateway.ipynb          # Gateway 설정
├── lab-04-agentcore-runtime/               # Runtime 배포 (JWT 인증)
│   └── lab-04-agentcore-runtime.ipynb
├── lab-05-agentcore-observability/         # 관측성 (스트리밍 + CloudWatch)
│   └── lab-05-agentcore-observability.ipynb
├── lab-06-frontend.ipynb                   # Streamlit UI
└── lab-07-cleanup.ipynb                    # 리소스 정리
```

## Project Structure

```
ec-customer-support-e2e-agentcore/
├── src/                          # Python 소스 코드
│   ├── agent.py                  # 메인 에이전트
│   ├── tools/                    # 고객 지원 도구
│   │   ├── return_tools.py       # 반품 처리
│   │   ├── exchange_tools.py     # 교환 처리
│   │   └── search_tools.py       # 웹 검색
│   ├── helpers/                  # 유틸리티
│   │   ├── utils.py              # SSM, Cognito, HTTP 스트리밍 헬퍼
│   │   └── ecommerce_memory.py   # 메모리 훅
│   └── ui/
│       └── streamlit_app.py      # 고객 포털
├── notebooks/                    # 단계별 튜토리얼 (Lab 1-7)
│   ├── lab-04-agentcore-runtime/ # Runtime 배포 파일
│   ├── lab-05-agentcore-observability/ # Observability 배포 파일
│   └── images/                   # 스크린샷
├── setup/                        # 환경 설정 및 인프라
│   ├── setup_env.sh              # Python 환경 구성
│   ├── setup_aws.sh              # AWS 검증
│   ├── deploy_infra.sh           # 인프라 배포
│   ├── cleanup_infra.sh          # 리소스 정리
│   ├── cloudformation/           # CFn 템플릿
│   ├── lambda/                   # Lambda 함수
│   └── pyproject.toml            # 의존성 정의
└── docs/                         # 문서
    └── agentcore-invocation-patterns.md  # 호출 패턴 가이드
```

## Tech Stack

Python 3.12+ · AWS Bedrock · Claude Sonnet · Strands Agents · AgentCore (Memory, Gateway, Runtime, Observability) · OpenTelemetry · CloudWatch GenAI · Streamlit · CloudFormation

## AgentCore Observability

Lab 5에서 다루는 관측성 기능:

| 기능 | 설명 |
|------|------|
| **OpenTelemetry 자동 계측** | `opentelemetry-instrument`로 LLM 호출 자동 추적 |
| **CloudWatch GenAI Dashboard** | 세션, 추적, 이벤트 시각화 |
| **Trace/Span 계층** | AgentCore → Agent → LLM → Tool 추적 |
| **gen_ai.* 이벤트** | system.message, user.message, choice, tool.message |
| **메트릭** | 토큰 사용량, 지연 시간, 오류율 |

## Documentation

### 참고 자료

- [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/)
- [Strands Agents Framework](https://github.com/strands-agents/strands-agents)
- [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/)
