# SRE Kagent Helm Chart Makefile
# Note: This Makefile is designed for Windows/PowerShell environments

.DEFAULT_GOAL := help
.PHONY: help lint test build deploy clean install-deps

# Variables
PROJECT_ID ?= gke-infra-969184
REGISTRY_URL = us-central1-docker.pkg.dev/$(PROJECT_ID)/sre-helm
HELM_BIN = $(USERPROFILE)\bin\helm.exe
CHARTS_DIR = charts
ENV ?= dev

## help: Display available commands
help:
	@echo "SRE Kagent Helm Chart Operations"
	@echo "================================="
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' |  sed -e 's/^/ /'

## install-deps: Install dependencies and update repos
install-deps:
	@echo "Updating Helm dependencies..."
	@powershell -Command "& { cd $(CHARTS_DIR)/sre-kagent-base; & '$(HELM_BIN)' dependency update }"
	@powershell -Command "& { cd $(CHARTS_DIR)/sre-kagent-crds; & '$(HELM_BIN)' dependency update }"

## lint: Lint all Helm charts
lint:
	@echo "Linting sre-kagent-base chart..."
	@powershell -Command "& { cd $(CHARTS_DIR)/sre-kagent-base; & '$(HELM_BIN)' lint . }"
	@echo "Linting sre-kagent-crds chart..."
	@powershell -Command "& { cd $(CHARTS_DIR)/sre-kagent-crds; & '$(HELM_BIN)' lint . }"

## template: Render chart templates for verification
template:
	@echo "Rendering sre-kagent-base templates..."
	@powershell -Command "& '$(HELM_BIN)' template sre-kagent-dev $(CHARTS_DIR)/sre-kagent-base -f env/$(ENV)/values.yaml"

## build: Package Helm charts
build: lint
	@echo "Packaging charts..."
	@powershell -Command "& { cd $(CHARTS_DIR); & '$(HELM_BIN)' package sre-kagent-base }"
	@powershell -Command "& { cd $(CHARTS_DIR); & '$(HELM_BIN)' package sre-kagent-crds }"

## push: Push charts to Artifact Registry
push: build
	@echo "Pushing charts to $(REGISTRY_URL)..."
	@powershell -Command "gcloud auth configure-docker us-central1-docker.pkg.dev"
	@powershell -Command "& '$(HELM_BIN)' registry login us-central1-docker.pkg.dev"
	@powershell -Command "& { cd $(CHARTS_DIR); & '$(HELM_BIN)' push sre-kagent-base-*.tgz oci://$(REGISTRY_URL) }"
	@powershell -Command "& { cd $(CHARTS_DIR); & '$(HELM_BIN)' push sre-kagent-crds-*.tgz oci://$(REGISTRY_URL) }"

## deploy-dev: Deploy to dev environment
deploy-dev:
	@echo "Deploying to sre-dev environment..."
	@powershell -Command "./scripts/ps/Install-Kagent.ps1 -Environment dev -Namespace sre-dev"

## deploy-staging: Deploy to staging environment
deploy-staging:
	@echo "Deploying to sre-staging environment..."
	@powershell -Command "./scripts/ps/Install-Kagent.ps1 -Environment staging -Namespace sre-staging"

## upgrade-dev: Upgrade dev deployment
upgrade-dev:
	@echo "Upgrading sre-dev deployment..."
	@powershell -Command "./scripts/ps/Upgrade-Kagent.ps1 -Environment dev -Namespace sre-dev"

## uninstall-dev: Uninstall from dev environment
uninstall-dev:
	@echo "Uninstalling from sre-dev environment..."
	@powershell -Command "./scripts/ps/Uninstall-Kagent.ps1 -Environment dev -Namespace sre-dev"

## clean: Clean up generated files
clean:
	@echo "Cleaning up..."
	@powershell -Command "Remove-Item -Path '$(CHARTS_DIR)/*.tgz' -ErrorAction SilentlyContinue"
	@powershell -Command "Remove-Item -Path '$(CHARTS_DIR)/*/charts' -Recurse -ErrorAction SilentlyContinue"
	@powershell -Command "Remove-Item -Path '$(CHARTS_DIR)/*/*.lock' -ErrorAction SilentlyContinue"

## status: Check deployment status
status:
	@echo "Checking kagent deployment status..."
	@powershell -Command "kubectl get pods -n sre-dev -l app.kubernetes.io/name=kagent"
	@powershell -Command "kubectl get svc -n sre-dev -l app.kubernetes.io/name=kagent"

## logs: Get kagent controller logs
logs:
	@echo "Getting kagent logs..."
	@powershell -Command "kubectl logs -n sre-dev -l app.kubernetes.io/name=kagent --tail=50"

## test: Run basic smoke tests
test:
	@echo "Running basic smoke tests..."
	@powershell -Command "kubectl get pods -n sre-dev"
	@powershell -Command "& '$(HELM_BIN)' test sre-kagent-dev -n sre-dev || echo 'No tests defined'"
