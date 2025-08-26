# Kagent Helm Charts

Production-ready Helm charts for deploying [kagent](https://github.com/kagent-dev/kagent) - Cloud Native Agentic AI platform.

## Quick Start

```powershell
# Build charts
.\scripts\Build-Chart.ps1

# Install development environment
$Env:OPENAI_API_KEY = "your-openai-key"
.\scripts\Install-Kagent.ps1 -Env dev -CreateNamespace -Wait
```

## Prerequisites

- **Helm 3.x** (located at `C:\Users\AiO PC - Sam\helm.exe`)
- **kubectl** configured with target Kubernetes cluster
- **PowerShell 5.1+** (Windows environment)

## Project Structure

```
kagent-chart/
├── charts/                     # Downloaded dependencies
├── environments/               # Environment-specific values
│   ├── values-dev.yaml        # Development overrides
│   ├── values-stage.yaml      # Staging overrides
│   └── values-prod.yaml       # Production overrides
├── kagent/                     # Main application chart
│   ├── templates/             # Kubernetes manifests
│   ├── Chart.yaml            # Generated from template
│   └── values.yaml           # Default values
├── kagent-crds/               # Custom Resource Definitions
│   ├── templates/            # CRD manifests
│   └── Chart.yaml           # Generated from template
├── scripts/                   # Management scripts
│   ├── Build-Chart.ps1       # Build and package charts
│   ├── Install-Kagent.ps1    # Install deployment
│   ├── Upgrade-Kagent.ps1    # Upgrade deployment
│   └── Uninstall-Kagent.ps1  # Remove deployment
└── tools/
    └── Render-ChartTemplate.ps1  # Template processor
```

## Environment Configuration

| Environment | AI Provider | Replicas | Agents Enabled |
|------------|-------------|----------|----------------|
| **dev**    | OpenAI (gpt-4o-mini) | 1 | Core agents only |
| **stage**  | Anthropic (claude-3-5-sonnet) | 2 | Most agents |
| **prod**   | Azure OpenAI (gpt-4) | 3+ | All agents |

### API Key Configuration

Set environment variables before installation:

```powershell
# Development (OpenAI)
$Env:OPENAI_API_KEY = "sk-..."

# Staging (Anthropic)  
$Env:ANTHROPIC_API_KEY = "claude-..."

# Production (Azure OpenAI)
$Env:AZUREOPENAI_API_KEY = "azure-key-..."
```

## Scripts Usage

### Build Charts
```powershell
# Full build with linting and packaging
.\scripts\Build-Chart.ps1 -Version "1.0.0"

# Quick build (skip slow steps)
.\scripts\Build-Chart.ps1 -SkipLint -SkipPackage
```

### Install kagent
```powershell
# Development installation
.\scripts\Install-Kagent.ps1 -Env dev -CreateNamespace -Wait

# Production installation with custom namespace
.\scripts\Install-Kagent.ps1 -Env prod -Namespace kagent-prod -Wait

# Dry run to validate configuration
.\scripts\Install-Kagent.ps1 -Env stage -DryRun
```

### Upgrade Deployment
```powershell
# Standard upgrade
.\scripts\Upgrade-Kagent.ps1 -Env dev -Wait

# Force upgrade with value reset
.\scripts\Upgrade-Kagent.ps1 -Env prod -Force -ResetValues
```

### Uninstall
```powershell
# Remove main application (keep CRDs)
.\scripts\Uninstall-Kagent.ps1 -Env dev

# Complete removal including CRDs (⚠️ destructive)
.\scripts\Uninstall-Kagent.ps1 -Env dev -IncludeCrds

# Production removal (requires confirmation)
.\scripts\Uninstall-Kagent.ps1 -Env prod -IncludeCrds
```

## Chart Values

### Core Configuration
```yaml
# Image settings
tag: "latest"                   # Container image tag
registry: "cr.kagent.dev"       # Container registry
imagePullPolicy: IfNotPresent   # Pull policy

# AI Provider (environment-specific)
providers:
  default: openAI               # openAI, anthropic, azureOpenAI, ollama
  openAI:
    model: "gpt-4o-mini"       # Model to use
    apiKeySecretRef: kagent-openai  # Secret name
```

### Resource Limits
```yaml
# Development
controller:
  replicas: 1
  resources:
    requests: { cpu: 50m, memory: 64Mi }
    limits: { cpu: 1, memory: 256Mi }

# Production  
controller:
  replicas: 3
  resources:
    requests: { cpu: 200m, memory: 256Mi }
    limits: { cpu: 2000m, memory: 1Gi }
```

### Override Examples
```powershell
# Custom AI model
helm install kagent ./kagent --set providers.openAI.model="gpt-4"

# Development with debug logging
helm install kagent ./kagent -f environments/values-dev.yaml --set controller.loglevel="debug"
```

## Troubleshooting

### Common Issues

**Chart dependencies failing:**
```powershell
# Dependencies require exact local structure - skip for standalone use
.\scripts\Build-Chart.ps1 -SkipLint
```

**API key errors:**
```powershell
# Verify environment variable is set
echo $Env:OPENAI_API_KEY

# Check Kubernetes secret exists
kubectl get secret kagent-openai -n kagent
```

**Pod startup issues:**
```powershell
# Check pod status and logs
kubectl get pods -n kagent
kubectl logs -n kagent -l app.kubernetes.io/name=kagent --tail=50
```

### Health Checks
```powershell
# Verify installation
kubectl get all -n kagent
helm status kagent -n kagent

# Check specific components
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kagent -n kagent --timeout=300s
```

## Development Workflow

1. **Make Changes** - Modify templates or values
2. **Build** - `.\scripts\Build-Chart.ps1`  
3. **Test Locally** - `.\scripts\Install-Kagent.ps1 -Env dev -DryRun`
4. **Deploy** - `.\scripts\Install-Kagent.ps1 -Env dev`
5. **Validate** - Check pods and logs
6. **Upgrade** - `.\scripts\Upgrade-Kagent.ps1 -Env dev`

## Chart Dependencies

The kagent chart includes optional dependencies:
- **kagent-tools**: Built-in tools and utilities
- **querydoc**: Document processing MCP server
- **Agent charts**: k8s, istio, observability agents

Dependencies are conditionally enabled via values configuration.

## Security Notes

- **Production**: Always use Kubernetes secrets for API keys
- **Development**: Environment variables acceptable for local testing  
- **Staging**: Test with production-like security configurations

## Support

- **Issues**: Create issue in kagent-dev/kagent repository
- **Documentation**: https://kagent.dev/docs
- **Discord**: https://bit.ly/kagentdiscord
