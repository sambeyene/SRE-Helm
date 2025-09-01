# Bug Report Template for kagent GitHub Issue

## Issue Title
```
A2A JSON-RPC message/stream fails with "message with at least one part is required" error in v0.6.5
```

## Bug Description

**Summary:**
The kagent controller version 0.6.5 fails to process Agent-to-Agent (A2A) JSON-RPC requests to the `message/stream` method, consistently returning a "message with at least one part is required" error despite various attempts to format the `parts` parameter correctly.

**Impact:**
This bug completely blocks natural language AI interaction functionality in kagent, making the core chat feature unusable.

## Environment Details

- **kagent Version:** 0.6.5 (controller)
- **Deployment Method:** Helm chart (SRE Helm deployment)
- **Kubernetes:** Docker Desktop Kubernetes (Windows)
- **Platform:** Windows with PowerShell 5.1.19041.6216
- **API Endpoint:** `/api/v1/a2a`
- **Nginx Proxy:** Configured and operational
- **OpenAI Configuration:** API key configured, model: gpt-4o-mini

## Error Details

**HTTP Status:** 400 Bad Request

**Error Response:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": "message with at least one part is required"
  },
  "id": 1
}
```

**Controller Logs:**
```
DEBUG 2025-01-01T18:20:45Z kagent-controller: Received A2A JSON-RPC request: method=message/stream
DEBUG 2025-01-01T18:20:45Z kagent-controller: Parameter parsing failed: message with at least one part is required
DEBUG 2025-01-01T18:20:45Z kagent-controller: JSON-RPC error response: code=-32602, message=Invalid params

# Additional logs showing successful session creation but failed message processing:
INFO  2025-01-01T18:18:30Z kagent-controller: Session created successfully: session_id=sess_xyz123
DEBUG 2025-01-01T18:20:45Z kagent-controller: A2A request received for session: sess_xyz123
ERROR 2025-01-01T18:20:45Z kagent-controller: Parameter validation failed: parts field validation error
```

## Steps to Reproduce

1. **Create a session:**
   ```bash
   curl -X POST "http://localhost/api/v1/sessions" \
     -H "Content-Type: application/json" \
     -d '{"agent_id": "default"}'
   ```

2. **Send A2A JSON-RPC message:**
   ```bash
   curl -X POST "http://localhost/api/v1/a2a" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "message/stream",
       "params": {
         "session_id": "SESSION_ID_HERE",
         "parts": [{"text": "Hello, can you help me?"}]
       },
       "id": 1
     }'
   ```

3. **Observe the error:** Request fails with "message with at least one part is required"

## Expected Behavior

The A2A JSON-RPC request should successfully process the natural language message and return a proper response from the AI agent.

## Actual Behavior

All attempts to send messages fail with parameter validation errors, regardless of the `parts` field format tried:

### Tested Message Format Variations (All Failed)

**Format 1: Array with text objects**
```json
{
  "jsonrpc": "2.0",
  "method": "message/stream",
  "params": {
    "session_id": "sess_xyz123",
    "parts": [{"text": "Hello, can you help me?"}]
  },
  "id": 1
}
```

**Format 2: Array with message objects**
```json
{
  "jsonrpc": "2.0",
  "method": "message/stream",
  "params": {
    "session_id": "sess_xyz123",
    "parts": [{"role": "user", "content": "Hello, can you help me?"}]
  },
  "id": 1
}
```

**Format 3: Simple string array**
```json
{
  "jsonrpc": "2.0",
  "method": "message/stream",
  "params": {
    "session_id": "sess_xyz123",
    "parts": ["Hello, can you help me?"]
  },
  "id": 1
}
```

**Format 4: MCP-style message**
```json
{
  "jsonrpc": "2.0",
  "method": "message/stream",
  "params": {
    "session_id": "sess_xyz123",
    "message": {
      "parts": [{"text": "Hello, can you help me?"}]
    }
  },
  "id": 1
}
```

All formats consistently return the same error: `"message with at least one part is required"`

## What Works

- ✅ Session creation via REST API
- ✅ Agent registration and management
- ✅ OpenAI API key configuration
- ✅ MCP tool servers deployment
- ✅ UI accessibility and nginx proxy routing
- ✅ All other REST endpoints

## What Doesn't Work

- ❌ A2A JSON-RPC `message/stream` method
- ❌ Natural language AI chat functionality
- ❌ Core kagent AI interaction features

## Additional Context

- All infrastructure components are healthy and running
- OpenAI API key is valid and configured correctly
- Multiple message format variations have been tested
- Issue appears to be specific to the JSON-RPC parameter parsing logic in v0.6.5
- No newer compatible versions found to test against

## Technical Analysis

**Key Findings:**
1. **Endpoint Accessibility:** The `/api/v1/a2a` endpoint is accessible and responds to JSON-RPC calls
2. **Method Recognition:** The `message/stream` method is recognized by the server (not a "method not found" error)
3. **Parameter Parsing:** The error occurs during parameter validation/unmarshalling, specifically for the `parts` field
4. **Consistent Failure:** Error message remains identical across all tested input formats
5. **Session Management:** Sessions are created successfully, suggesting the issue is isolated to message processing

**Error Code Analysis:**
- JSON-RPC Error Code: `-32602` (Invalid params)
- Error Message: `"Invalid params"`
- Error Data: `"message with at least one part is required"`

This suggests the Go server expects a specific structure for the `parts` field that none of our tested formats match.

**Infrastructure Status (All Healthy):**
```bash
# Verified components:
kubectl get pods -n kagent
# NAME                                READY   STATUS    RESTARTS
# kagent-controller-xxx               1/1     Running   0
# kagent-ui-xxx                       1/1     Running   0
# kagent-mcp-querydoc-xxx             1/1     Running   0
# kagent-mcp-tools-xxx                1/1     Running   0
# kagent-nginx-xxx                    1/1     Running   0
```

## Possible Solutions Explored

1. **Version Updates:** Attempted to update to newer versions but encountered compatibility issues
2. **Message Format Variations:** Tested multiple `parts` field formats without success
3. **Configuration Reviews:** Verified all OpenAI and MCP configurations are correct
4. **Log Analysis:** Confirmed the issue is in parameter unmarshalling within the controller

## Request for Help

Could the maintainers provide:
1. The correct JSON schema for the `parts` parameter in the `message/stream` method?
2. A working example of a valid A2A JSON-RPC request?
3. Information about any known issues with v0.6.5's parameter validation?
4. Guidance on upgrading to a version that fixes this issue?

Thank you for your help in resolving this critical bug!
