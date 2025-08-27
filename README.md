# SRE Kagent Helm Charts

Production-ready Helm charts for deploying Kagent with custom SRE features in Kubernetes environments.

## Overview

This repository provides a structured approach to deploying Kagent using Helm charts with support for:

- **Base Kagent deployment** (`sre-kagent-base`)
- **Custom Resource Definitions** (`sre-kagent-crds`) 
- **Environment-specific configurations** (dev/staging/prod)
- **Cloud Build integration** for automated CI/CD
- **SRE operational enhancements** (monitoring, observability, custom features)

## Project Structure

```
├── charts/                        # Helm charts
│   ├── sre-kagent-base/           # Base kagent chart
│   └── sre-kagent-crds/           # Custom Resource Definitions
├── env/                           # Environment configurations
│   ├── dev/values.yaml
│   ├── staging/values.yaml
│   └── prod/values.yaml
├── scripts/ps/                    # PowerShell automation
├── .cloudbuild/cloudbuild.yaml    # Cloud Build pipeline
├── Makefile                       # Local development automation
└── README.md
```

## Prerequisites

### Required Tools
- **Helm** >= 3.16
- **kubectl** >= 1.31
- **gcloud CLI** 
- **PowerShell** 5.1+ (Windows)
- **make** (optional, for Makefile usage)

### GCP Setup
- Project: `gke-infra-969184`
- Artifact Registry: `us-central1-docker.pkg.dev/gke-infra-969184/sre-helm`
- GKE clusters for each environment (dev/staging/prod)

## Quick Start

### 1. Local Development

```powershell
# Test chart linting
make lint

# Render templates for verification
make template ENV=dev

# Build and package charts
make build

# Deploy to dev environment
make deploy-dev
```

### 2. Using PowerShell Scripts

```powershell
# Install to development environment
.\scripts\ps\Install-Kagent.ps1 -Environment dev -Namespace sre-dev

# Upgrade existing deployment
.\scripts\ps\Upgrade-Kagent.ps1 -Environment dev -Namespace sre-dev

# Uninstall
.\scripts\ps\Uninstall-Kagent.ps1 -Environment dev -Namespace sre-dev
```

### 3. Manual Helm Commands

```powershell
# Install CRDs first
helm upgrade --install sre-kagent-crds charts/sre-kagent-crds -n sre-dev --create-namespace

# Install base kagent
helm upgrade --install sre-kagent-dev charts/sre-kagent-base -n sre-dev -f env/dev/values.yaml
```

## Environment Configuration

### Development (`env/dev/values.yaml`)
- Single replica deployments
- Debug logging enabled  
- Development AI providers (OpenAI)
- Reduced resource limits

### Staging (`env/staging/values.yaml`)
- Production-like configuration
- Staging AI providers
- Moderate resource allocation
- Performance testing enabled

### Production (`env/prod/values.yaml`)
- High availability setup
- Production AI providers (Azure OpenAI, Anthropic)
- Full resource allocation
- Enhanced monitoring and alerting

## CI/CD Pipeline

### Cloud Build Integration

The Cloud Build pipeline automatically:

1. **Lints** all Helm charts
2. **Updates** chart dependencies
3. **Packages** charts
4. **Pushes** to Artifact Registry
5. **Deploys** to dev environment (on `dev` branch)

### Branch Strategy

- `main` → Production deployments
- `staging` → Staging deployments  
- `dev` → Development deployments
- Feature branches → Manual testing

## Custom Features Roadmap

### Phase 1: Foundation ✅
- [x] Base chart organization
- [x] Environment configurations
- [x] Cloud Build pipeline
- [x] PowerShell automation

### Phase 2: SRE Enhancements (Planned)
- [ ] Custom monitoring dashboards
- [ ] Enhanced observability (Prometheus metrics)
- [ ] Custom RBAC policies
- [ ] Pod disruption budgets
- [ ] Network policies
- [ ] Backup and restore procedures

### Phase 3: Advanced Features (Future)
- [ ] Multi-cluster deployments
- [ ] GitOps integration (ArgoCD)
- [ ] Security scanning integration
- [ ] Performance optimization

## Operations

### Monitoring

```powershell
# Check deployment status
make status

# View logs
make logs

# Port forward to UI (if applicable)
kubectl port-forward -n sre-dev svc/sre-kagent-ui 8080:8080
```

### Troubleshooting

```powershell
# Describe problematic pods
kubectl describe pods -n sre-dev -l app.kubernetes.io/name=kagent

# Check events
kubectl get events -n sre-dev --sort-by='.lastTimestamp'

# Helm status
helm status sre-kagent-dev -n sre-dev
```

## Development Workflow

### Adding Custom Features

1. Create feature templates in `charts/sre-kagent-base/templates/`
2. Add configuration options to `values.yaml`
3. Update environment-specific values in `env/*/values.yaml`
4. Test locally with `make template` and `make deploy-dev`
5. Submit PR with changes

### Chart Updates

1. Update chart version in `Chart.yaml`
2. Update dependencies with `make install-deps`
3. Test changes thoroughly
4. Update documentation

## Contributing

### Code Standards
- Follow Helm best practices
- Use SRE naming conventions (`sre-*`)
- Include proper resource labels
- Document all configuration options

### Testing Requirements
- Local chart linting must pass
- Template rendering must succeed
- Dev deployment must be functional
- No regression in existing features

## Support

### Documentation
- [Helm Charts Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kagent Documentation](https://github.com/kagent-dev/kagent)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

### Troubleshooting
- Check Cloud Build logs for pipeline issues
- Verify cluster connectivity with `kubectl config current-context`
- Ensure proper RBAC permissions for service accounts

## License

This project is licensed under the same license as the underlying Kagent project.

---

**Maintainer**: SRE Team  
**Last Updated**: August 2025  
**Version**: 0.2.0
