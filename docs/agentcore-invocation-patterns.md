# AgentCore Runtime Invocation Patterns

This document provides a comprehensive guide on how to invoke already deployed Amazon Bedrock AgentCore Runtime agents.

## Table of Contents

- [Overview](#overview)
- [Authentication Methods](#authentication-methods)
- [1. IAM/SigV4 Authentication (boto3)](#1-iamsigv4-authentication-boto3)
- [2. OAuth/JWT Authentication (HTTP + Bearer Token)](#2-oauthjwt-authentication-http--bearer-token)
- [3. Toolkit Runtime Methods](#3-toolkit-runtime-methods)
- [Streaming vs Non-Streaming Responses](#streaming-vs-non-streaming-responses)
- [Session Management](#session-management)
- [How to Determine Which Auth Method an Agent Uses](#how-to-determine-which-auth-method-an-agent-uses)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

AgentCore Runtime supports two authentication methods for invoking deployed agents:

| Method | When Used | Invocation Pattern |
|--------|-----------|-------------------|
| **IAM (SigV4)** | Agent deployed WITHOUT `customJWTAuthorizer` | `boto3.client('bedrock-agentcore').invoke_agent_runtime()` |
| **OAuth/JWT (Bearer)** | Agent deployed WITH `customJWTAuthorizer` | HTTP POST with `Authorization: Bearer {token}` header |

---

## Authentication Methods

### Comparison Table

| Aspect | IAM (SigV4) | OAuth2/JWT (Bearer Token) |
|--------|-------------|---------------------------|
| **Invocation Method** | `boto3.client().invoke_agent_runtime()` | `requests.post()` with `Authorization: Bearer {token}` |
| **Auth Location** | Request signature (AWS SigV4) | JWT Bearer token in Authorization header |
| **Token Source** | AWS credentials (IAM role, access key) | Cognito OAuth token or custom JWT |
| **Verification** | AWS service verifies SigV4 signature | Runtime validates JWT via JWKS |
| **Best For** | Internal AWS resources, Lambda, EC2 | External clients, web apps, third-party integrations |
| **Session Tracking** | `runtimeSessionId` parameter (33+ chars) | `X-Amzn-Bedrock-AgentCore-Runtime-Session-Id` header |
| **Scope/Permissions** | IAM policy documents | JWT scopes claim in token |

---

## 1. IAM/SigV4 Authentication (boto3)

Use this method when the agent is deployed **without** a JWT authorizer.

### Basic Invocation

```python
import boto3
import json

client = boto3.client('bedrock-agentcore', region_name='us-east-1')

response = client.invoke_agent_runtime(
    agentRuntimeArn='arn:aws:bedrock-agentcore:us-east-1:123456789012:runtime/my-agent-id',
    qualifier='DEFAULT',
    payload=json.dumps({'prompt': 'Hello, how can you help me?'})
)

# Handle streaming response
if 'text/event-stream' in response.get('contentType', ''):
    for line in response['response'].iter_lines(chunk_size=1):
        if line:
            line_str = line.decode('utf-8')
            if line_str.startswith('data: '):
                print(line_str[6:], end='', flush=True)
else:
    # Non-streaming response
    body = response['response'].read()
    print(json.loads(body))
```

### With Session ID and Custom Timeout

```python
import boto3
import json
import uuid
from botocore.config import Config

# Custom timeout configuration for long-running operations
config = Config(
    connect_timeout=60,
    read_timeout=300,  # 5 minutes
    retries={'max_attempts': 3, 'mode': 'adaptive'}
)

client = boto3.client(
    'bedrock-agentcore',
    region_name='us-east-1',
    config=config
)

# Session ID must be 33+ characters for tracking
session_id = f'my-session-{uuid.uuid4()}'

response = client.invoke_agent_runtime(
    agentRuntimeArn=agent_arn,
    qualifier='DEFAULT',
    runtimeSessionId=session_id,
    payload=json.dumps({
        'prompt': 'Analyze this data',
        'user_id': 'user123',
        'session_id': session_id
    })
)
```

### Extended Timeout for Long-Running Jobs

```python
from botocore.config import Config

# For complex analysis or data processing jobs
config = Config(
    connect_timeout=6000,
    read_timeout=3600,  # 1 hour
    retries={'max_attempts': 0}  # Disable retries for idempotency
)

client = boto3.client('bedrock-agentcore', config=config)
```

---

## 2. OAuth/JWT Authentication (HTTP + Bearer Token)

Use this method when the agent is deployed **with** a `customJWTAuthorizer`.

### Basic HTTP Invocation

```python
import requests
import json
import urllib.parse

# Configuration
region = 'us-east-1'
agent_arn = 'arn:aws:bedrock-agentcore:us-east-1:123456789012:runtime/my-agent-id'

# URL-encode the ARN
escaped_arn = urllib.parse.quote(agent_arn, safe='')
url = f'https://bedrock-agentcore.{region}.amazonaws.com/runtimes/{escaped_arn}/invocations'

# Headers with Bearer token
headers = {
    'Authorization': f'Bearer {bearer_token}',
    'Content-Type': 'application/json',
    'X-Amzn-Bedrock-AgentCore-Runtime-Session-Id': session_id,
}

# Payload
payload = {'prompt': 'Hello, how can you help me?'}

# Make request
response = requests.post(
    url,
    params={'qualifier': 'DEFAULT'},
    headers=headers,
    json=payload,
    timeout=120,
    stream=True  # Enable for streaming responses
)

if response.status_code == 200:
    for line in response.iter_lines():
        if line:
            line_str = line.decode('utf-8')
            if line_str.startswith('data: '):
                print(line_str[6:], end='', flush=True)
else:
    print(f'Error: {response.status_code} - {response.text}')
```

### Getting Bearer Token from Cognito (User Password Auth)

```python
import boto3
import hmac
import hashlib
import base64

def get_bearer_token(pool_id, client_id, client_secret, username, password):
    """Get JWT Bearer token using Cognito User Password Auth flow."""
    cognito = boto3.client('cognito-idp', region_name='us-east-1')

    # Compute secret hash
    message = username + client_id
    key = client_secret.encode()
    secret_hash = base64.b64encode(
        hmac.new(key, message.encode(), digestmod=hashlib.sha256).digest()
    ).decode()

    # Authenticate
    auth_response = cognito.initiate_auth(
        ClientId=client_id,
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash,
        },
    )

    return auth_response['AuthenticationResult']['AccessToken']
```

### Getting Bearer Token from Cognito (M2M Client Credentials)

```python
import requests

def fetch_m2m_access_token(client_id, client_secret, token_url):
    """Fetch OAuth access token using client credentials flow (M2M)."""
    data = f'grant_type=client_credentials&client_id={client_id}&client_secret={client_secret}'

    response = requests.post(
        token_url,
        data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'},
        timeout=30
    )
    response.raise_for_status()

    return response.json()['access_token']
```

---

## 3. Toolkit Runtime Methods

The AgentCore Starter Toolkit provides abstracted methods that handle both authentication types.

### Using invoke_streaming()

```python
from bedrock_agentcore_starter_toolkit import Runtime

# Initialize and configure runtime
runtime = Runtime()
runtime.configure(
    entrypoint='my_agent.py',
    execution_role=execution_role_arn,
    agent_name='my-agent',
    # ... other config
)

# For JWT-configured agents
response_generator = runtime.invoke_streaming(
    {'prompt': 'Hello'},
    bearer_token=bearer_token,
    session_id=session_id
)

for chunk in response_generator:
    if isinstance(chunk, dict) and 'response' in chunk:
        print(chunk['response'], end='', flush=True)
```

### Using invoke() (Non-Streaming)

```python
response = runtime.invoke(
    {'prompt': 'Hello'},
    bearer_token=bearer_token,
    session_id=session_id
)
print(response)
```

---

## Streaming vs Non-Streaming Responses

### How Streaming is Determined

**Streaming is 100% server-side determined** by your agent entrypoint implementation:

| Server Implementation | Client Gets | Content-Type |
|----------------------|-------------|--------------|
| `def invoke() → return` | Single JSON response | `application/json` |
| `async def invoke() → yield` | SSE stream (many chunks) | `text/event-stream` |

### Test Results (Verified)

| Agent Type | Entrypoint | Chunks | Content-Type |
|------------|------------|--------|--------------|
| Non-streaming | `def invoke(): return response` | 1 | `application/json` |
| Streaming | `async def invoke(): yield event` | 89 | `text/event-stream; charset=utf-8` |

### Non-Streaming Entrypoint

```python
from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()

@app.entrypoint
def invoke(payload):
    """Non-streaming - returns single response"""
    user_input = payload.get("prompt", "")
    response = agent(user_input)
    return response.message["content"][0]["text"]  # return = non-streaming
```

### Streaming Entrypoint

```python
from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()

@app.entrypoint
async def invoke(payload):
    """Streaming - yields events one by one"""
    user_input = payload.get("prompt", "")
    async for event in agent.stream_async(user_input):  # stream_async
        yield event  # yield = streaming
```

### Streaming Event Format (SSE)

Each streaming chunk follows the Server-Sent Events format:

```
data: {"init_event_loop": true}
data: {"start": true}
data: {"event": {"contentBlockDelta": {"delta": {"text": "Hello"}}}}
data: {"event": {"contentBlockDelta": {"delta": {"text": " world"}}}}
data: {"event": {"contentBlockDelta": {"delta": {"text": "!"}}}}
...
```

### Detecting Response Type

```python
# Check Content-Type header
if 'text/event-stream' in response.get('contentType', ''):
    # Streaming - Server-Sent Events (SSE)
    for line in response['response'].iter_lines(chunk_size=1):
        if line:
            line_str = line.decode('utf-8')
            if line_str.startswith('data: '):
                data = line_str[6:]
                print(data, end='', flush=True)
else:
    # Non-streaming - JSON response
    body = response['response'].read()
    result = json.loads(body)
    print(result)
```

### SSE Data Parsing Helper

```python
import json

def parse_sse_data(sse_bytes):
    """Parse Server-Sent Events (SSE) data from streaming response."""
    if not sse_bytes or len(sse_bytes) == 0:
        return None

    try:
        text = sse_bytes.decode('utf-8').strip()
        if not text:
            return None

        if text.startswith('data: '):
            json_text = text[6:].strip()
            if json_text:
                return json.loads(json_text)
        else:
            return json.loads(text)
    except:
        pass

    return None
```

### Extracting Text from Streaming Events

```python
def process_streaming_response(response):
    """Process streaming response and extract text chunks."""
    full_text = ""

    for line in response["response"].iter_lines(chunk_size=1):
        if not line:
            continue

        line_str = line.decode("utf-8")
        if not line_str.startswith("data: "):
            continue

        data = line_str[6:]

        try:
            event = json.loads(data)

            # Extract text from contentBlockDelta events
            if isinstance(event, dict):
                if "event" in event:
                    inner = event["event"]
                    if "contentBlockDelta" in inner:
                        delta = inner["contentBlockDelta"].get("delta", {})
                        text = delta.get("text", "")
                        if text:
                            print(text, end="", flush=True)
                            full_text += text

                # Or extract from data field (Strands format)
                elif "data" in event:
                    text = event["data"]
                    if isinstance(text, str):
                        print(text, end="", flush=True)
                        full_text += text

        except json.JSONDecodeError:
            # Handle plain string responses
            if data.startswith('"') and data.endswith('"'):
                text = data[1:-1].replace('\\n', '\n')
                print(text, end="", flush=True)
                full_text += text

    return full_text
```

---

## Session Management

### Session ID Requirements

- **Minimum length**: 33 characters
- **Format**: Any string, commonly UUID-based
- **Purpose**: Multi-turn conversations, observability tracking

### Examples

```python
import uuid

# Simple UUID-based session ID
session_id = str(uuid.uuid4())  # 36 chars

# Prefixed session ID for better tracking
session_id = f'user-123-session-{uuid.uuid4()}'  # 49 chars

# Timestamp-based for debugging
from datetime import datetime
session_id = f'session-{datetime.now().strftime("%Y%m%d%H%M%S")}-{uuid.uuid4().hex[:8]}'
```

---

## How to Determine Which Auth Method an Agent Uses

### 1. Check the Deployment Configuration

```python
# If deployed with customJWTAuthorizer → OAuth/JWT
authorizer_configuration={
    'customJWTAuthorizer': {
        'allowedClients': [cognito_client_id],
        'discoveryUrl': cognito_discovery_url,
    }
}

# If no authorizer_configuration → IAM/SigV4
```

### 2. Check the Error Response

```python
# This error means agent expects OAuth/JWT:
# "AccessDeniedException: Authorization method mismatch.
#  The agent is configured for a different authorization method..."
```

### 3. Check Runtime Configuration

```yaml
# In .bedrock_agentcore.yaml
authorizer_configuration:
  customJWTAuthorizer:
    allowedClients:
      - "your-cognito-client-id"
    discoveryUrl: "https://cognito-idp.region.amazonaws.com/pool-id/.well-known/openid-configuration"
```

---

## Configuration Examples

### IAM-Only Agent Deployment

```python
from bedrock_agentcore_starter_toolkit import Runtime

runtime = Runtime()
runtime.configure(
    entrypoint='my_agent.py',
    execution_role=execution_role_arn,
    agent_name='iam-only-agent',
    region='us-east-1',
    # No authorizer_configuration → IAM auth only
)
runtime.launch()
```

### JWT-Authenticated Agent Deployment

```python
from bedrock_agentcore_starter_toolkit import Runtime

runtime = Runtime()
runtime.configure(
    entrypoint='my_agent.py',
    execution_role=execution_role_arn,
    agent_name='jwt-auth-agent',
    region='us-east-1',
    authorizer_configuration={
        'customJWTAuthorizer': {
            'allowedClients': [cognito_client_id],
            'discoveryUrl': f'https://cognito-idp.{region}.amazonaws.com/{pool_id}/.well-known/openid-configuration',
        }
    },
)
runtime.launch()
```

---

## Troubleshooting

### Error: AccessDeniedException - Authorization method mismatch

**Cause**: Using boto3 (IAM auth) to invoke a JWT-configured agent

**Solution**: Use HTTP requests with Bearer token instead

```python
# Wrong (for JWT agents):
client.invoke_agent_runtime(agentRuntimeArn=arn, ...)

# Correct:
requests.post(url, headers={'Authorization': f'Bearer {token}'}, ...)
```

### Error: Token expired

**Cause**: JWT tokens have limited validity (usually 1-2 hours)

**Solution**: Re-authenticate before invoking

```python
def ensure_valid_token():
    # Check token expiration and refresh if needed
    bearer_token = reauthenticate_user(client_id, client_secret)
    return bearer_token
```

### Error: Invalid session ID

**Cause**: Session ID is less than 33 characters

**Solution**: Use UUID-based session IDs

```python
session_id = f'session-{uuid.uuid4()}'  # Always 44+ chars
```

### Error: Connection timeout

**Cause**: Default timeout too short for complex operations

**Solution**: Configure extended timeouts

```python
config = Config(
    connect_timeout=60,
    read_timeout=300,
    retries={'max_attempts': 0}
)
```

---

## References

- [Amazon Bedrock AgentCore Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [AgentCore Runtime API Reference](https://docs.aws.amazon.com/bedrock-agentcore/latest/APIReference/)
- [AgentCore Starter Toolkit](https://github.com/aws/bedrock-agentcore-starter-toolkit)
- Sample Code: `/home/ubuntu/amazon-bedrock-agentcore-samples`
