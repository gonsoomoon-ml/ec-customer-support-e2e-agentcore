Ask me to confirm before action.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

K-Style E-Commerce AI Customer Support Platform - Korean fashion/beauty e-commerce using Amazon Bedrock AgentCore with Strands Agents. Handles returns, exchanges, and styling advice.

## Common Commands

```bash
# Environment (requires Python 3.12+)
./setup/setup_env.sh && source .venv/bin/activate
./setup/setup_aws.sh  # Verify AWS credentials

# Deploy infrastructure
./setup/deploy_infra.sh

# Run Streamlit UI
streamlit run src/ui/streamlit_app.py

# Run tutorials
jupyter lab notebooks/

# Package management (UV)
uv sync
uv add <package-name>

# Cleanup
./setup/cleanup_infra.sh
```

## Architecture

- **LLM**: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`
- **Agent Framework**: Strands Agents (`@tool` decorator)
- **AgentCore Services**: Memory, Gateway, Runtime, Identity (Cognito)
- **UI**: Streamlit
- **Infrastructure**: CloudFormation (`EcommerceCustomerSupportStackInfra`, `EcommerceCustomerSupportStackCognito`)
- **Config**: SSM parameters under `/app/ecommerce/agentcore/`

## Code Patterns

### Agent Creation
```python
# From project root or notebooks
from agent import create_ecommerce_agent
agent = create_ecommerce_agent()
response = agent("반품하고 싶어요")
```

### Tool Definition
```python
from strands.tools import tool

@tool
def tool_name(param: str) -> str:
    """Tool description for the agent."""
    return result
```

### Key Files
- `src/agent.py` - Standalone agent with inline tools for testing
- `src/tools/` - Modular tools used by Streamlit UI
- `src/helpers/ecommerce_memory.py` - `EcommerceCustomerMemoryHooks` for customer memory
- `src/helpers/utils.py` - SSM, Cognito, IAM utilities
- `notebooks/lab-01` to `lab-06` - Step-by-step tutorials

## Notes
- Documentation in `docs/` is in Korean
- Notebooks import helpers as `lab_helpers` (aliased from `src/helpers`)
- All dependencies should use `setup/pyproject.toml` and `uv sync` - do not use pip directly
