# SRE Kagent Permanent Access Configuration

## Overview
This document provides the permanent access URLs for the SRE Helm-based kagent deployment in the `sre-dev` namespace.

## Permanent URLs

### 🌐 **Kagent UI (Web Interface)**
- **URL**: http://34.46.69.206
- **Service**: `sre-kagent-ui-external`
- **Type**: LoadBalancer
- **Status**: ✅ Active and Accessible

### 🔗 **Kagent API (Controller)**
- **Base URL**: http://34.66.199.52:8083
- **Health Check**: http://34.66.199.52:8083/health
- **Service**: `sre-kagent-controller-external`  
- **Type**: LoadBalancer
- **Status**: ✅ Active and Accessible

## Available Agents

All agents are configured with **GPT-4o-mini** via OpenAI:

1. **PromQL Agent** - Prometheus query generation and monitoring
2. **K8s Agent** - Kubernetes operations and troubleshooting  
3. **Helm Agent** - Helm release management
4. **Observability Agent** - Monitoring and Grafana dashboards

## Service Details

### UI LoadBalancer Service
```yaml
Name: sre-kagent-ui-external
Namespace: sre-dev
External IP: 34.46.69.206
Port: 80 → 8080 (target)
```

### Controller LoadBalancer Service
```yaml
Name: sre-kagent-controller-external
Namespace: sre-dev  
External IP: 34.66.199.52
Ports: 
  - 8083 → 8083 (API)
  - 8000 → 8000 (Grafana MCP)
```

## Usage

### Accessing the UI
Simply navigate to: **http://34.46.69.206**

The UI will provide:
- Agent selection interface
- Chat interface for natural language queries
- Session management
- Real-time responses from AI agents

### API Access
For programmatic access: **http://34.66.199.52:8083/api/**

Common endpoints:
- `/health` - Service health check
- `/api/agents` - List available agents (requires auth)
- `/api/modelconfigs` - Model configuration info

## Configuration Files

The LoadBalancer services were created using:
- `sre-kagent-ui-loadbalancer.yaml`
- `sre-kagent-controller-loadbalancer.yaml`

## Maintenance

These LoadBalancer services provide **permanent external access** without requiring:
- Port forwarding
- VPN connections  
- Temporary tunnels

The external IPs are stable and will persist unless the services are deleted.

## Security Notes

- The UI is publicly accessible on port 80
- The API requires authentication for most endpoints
- All traffic uses HTTP (consider HTTPS for production)
- Services are scoped to the `sre-dev` namespace only

---
**Created**: August 27, 2025  
**Last Updated**: August 27, 2025  
**Project**: SRE Helm-based Kagent Deployment
