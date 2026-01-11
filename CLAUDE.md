Ask me to confirm before action.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

K-Style E-Commerce AI Customer Support Platform - a Korean fashion/beauty e-commerce platform using Amazon Bedrock AgentCore with Strands Agents framework. The primary completed use case is customer support (returns, exchanges, styling advice).

## Common Commands

### Environment Setup
```bash
# Create virtual environment with Python 3.11 or 3.12
./infra/scripts/setup_env.sh

# Activate virtual environment
source .venv/bin/activate

# Verify AWS credentials
./infra/scripts/setup_aws.sh
```

### Infrastructure
```bash
# Deploy CloudFormation stacks (S3, Lambda, DynamoDB, Cognito, IAM)
./infra/scripts/deploy.sh

# List deployed SSM parameters
./infra/scripts/list_ssm_parameters.sh

# Clean up all AWS resources (interactive prompts)
./infra/scripts/cleanup.sh
```

### Running the Application
```bash
# Streamlit customer support UI
streamlit run src/ui/streamlit_app.py

# Or use quick-start wrapper
./infra/scripts/run_streamlit.sh

# Jupyter Lab for tutorials
jupyter lab notebooks/
```

### Package Management
```bash
# Sync dependencies using UV
uv sync

# Add new package
uv add <package-name>
```

## Architecture

### Technology Stack
- **Agent Framework**: Strands Agents with tool decorators (`@tool`)
- **LLM**: Amazon Bedrock (Claude 3.7 Sonnet: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **AgentCore Services**: Memory (customer data persistence), Gateway (Lambda tools), Runtime (containerized deployment), Identity (Cognito JWT)
- **UI**: Streamlit with Plotly visualizations
- **Package Manager**: UV with pyproject.toml

### Directory Structure
```
ec-customer-support-e2e-agentcore/
├── README.md
├── CLAUDE.md
├── src/                          # Python source code
│   ├── agent.py                  # Main agent with tools
│   ├── tools/                    # Tool modules
│   │   ├── return_tools.py
│   │   ├── exchange_tools.py
│   │   └── search_tools.py
│   ├── helpers/                  # Utility modules
│   │   ├── utils.py
│   │   ├── ecommerce_memory.py
│   │   └── cleanup_iam.py
│   └── ui/
│       └── streamlit_app.py      # Customer portal
├── notebooks/                    # Jupyter tutorials
│   ├── lab-01 to lab-06
│   └── .bedrock_agentcore.yaml
├── infra/                        # Infrastructure
│   ├── cloudformation/
│   │   ├── infrastructure.yaml
│   │   └── cognito.yaml
│   ├── lambda/                   # Lambda function code
│   └── scripts/                  # Shell scripts
│       ├── deploy.sh
│       ├── cleanup.sh
│       ├── setup_env.sh
│       └── run_streamlit.sh
├── docs/                         # Documentation
│   ├── ARCHITECTURE.md
│   ├── AWS_SETUP_GUIDE.md
│   └── TROUBLESHOOTING.md
└── setup/                        # Package config
    └── pyproject.toml
```

### CloudFormation Stacks
Two stacks are deployed:
1. `EcommerceCustomerSupportStackInfra` - S3, Lambda, DynamoDB, IAM roles, SSM parameters
2. `EcommerceCustomerSupportStackCognito` - Cognito User Pool and clients

### SSM Parameter Namespace
All configuration stored under `/app/ecommerce/agentcore/`:
- cognito_* (auth configuration)
- gateway_iam_role, runtime_iam_role
- lambda_arn, userpool_id, etc.

## Code Patterns

### Agent Tool Definition
```python
from strands.tools import tool

@tool
def tool_name(param: str) -> str:
    """Tool description for the agent."""
    # Implementation
    return result
```

### Memory Hooks
Customer memory integration uses `EcommerceCustomerMemoryHooks` class in `src/helpers/ecommerce_memory.py`.

## Documentation Language
All primary documentation in `docs/` is in Korean, targeting Korean learners.
