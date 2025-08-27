#Requires -Version 5.1

<#
.SYNOPSIS
    Installs kagent Helm charts with environment-specific configurations.

.DESCRIPTION
    This script installs the complete kagent platform including:
    1. Custom Resource Definitions (CRDs) via kagent-crds chart
    2. Main kagent application via kagent chart
    3. Environment-specific value overrides
    4. Proper API key configuration from environment variables

.PARAMETER Env
    The target environment: dev, stage, or prod. This determines which values 
    file is used for installation.

.PARAMETER Namespace
    The Kubernetes namespace to install kagent into. Defaults to 'kagent'.

.PARAMETER ReleaseName
    The Helm release name. Defaults to 'kagent' for main chart and 'kagent-crds' for CRDs.

.PARAMETER DryRun
    Perform a dry run without actually installing the charts.

.PARAMETER Wait
    Wait for all resources to be ready before marking the install as successful.

.PARAMETER CreateNamespace
    Create the namespace if it doesn't exist.

.PARAMETER SkipCrds
    Skip installation of CRDs chart (useful for upgrades when CRDs already exist).

.EXAMPLE
    .\Install-Kagent.ps1 -Env dev
    
.EXAMPLE
    .\Install-Kagent.ps1 -Env prod -Namespace kagent-production -Wait
    
.EXAMPLE
    .\Install-Kagent.ps1 -Env stage -DryRun
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("dev", "stage", "prod")]
    [string]$Env,
    
    [Parameter()]
    [string]$Namespace = "kagent",
    
    [Parameter()]
    [string]$ReleaseName = "kagent",
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [switch]$Wait,
    
    [Parameter()]
    [switch]$CreateNamespace,
    
    [Parameter()]
    [switch]$SkipCrds
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath = Split-Path -Parent $ScriptPath
$HelmPath = "C:\Users\AiO PC - Sam\helm.exe"

# Ensure we're in the correct directory
Set-Location $RootPath

Write-Host "=== Kagent Installation ===" -ForegroundColor Cyan
Write-Host "Environment: $Env" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow

# ==============================================================================
# STEP 1: Validate prerequisites
# ==============================================================================

Write-Host "`n[1/5] Validating prerequisites..." -ForegroundColor Yellow

# Check if kubectl is available
try {
    kubectl version --client --output=yaml | Out-Null
    Write-Host "  ✓ kubectl is available" -ForegroundColor Green
}
catch {
    throw "kubectl is not available. Please install kubectl and ensure it's in your PATH."
}

# Check if helm is available
if (-not (Test-Path $HelmPath)) {
    throw "Helm executable not found at: $HelmPath"
}

Write-Host "  ✓ Helm is available" -ForegroundColor Green

# Check for required environment values file
$valuesFile = Join-Path $RootPath "environments\values-$Env.yaml"
if (-not (Test-Path $valuesFile)) {
    throw "Environment values file not found: $valuesFile"
}

Write-Host "  ✓ Environment values file found: values-$Env.yaml" -ForegroundColor Green

# Check for required charts
$chartsToCheck = @("kagent-crds", "kagent")
foreach ($chartName in $chartsToCheck) {
    $chartPath = Join-Path $RootPath $chartName
    $chartYaml = Join-Path $chartPath "Chart.yaml"
    
    if (-not (Test-Path $chartYaml)) {
        throw "Chart not found or not built: $chartName. Please run Build-Chart.ps1 first."
    }
}

Write-Host "  ✓ Required charts are available" -ForegroundColor Green

# ==============================================================================
# STEP 2: Prepare API keys and configuration
# ==============================================================================

Write-Host "`n[2/5] Preparing API keys and configuration..." -ForegroundColor Yellow

$apiKeyArgs = @()

# Environment-specific API key preparation
switch ($Env) {
    "dev" {
        if ($Env:OPENAI_API_KEY) {
            $apiKeyArgs += "--set", "providers.openAI.apiKey=$Env:OPENAI_API_KEY"
            Write-Host "  ✓ OpenAI API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  OPENAI_API_KEY environment variable not set. Using secret reference."
        }
    }
    "stage" {
        if ($Env:ANTHROPIC_API_KEY) {
            $apiKeyArgs += "--set", "providers.anthropic.apiKey=$Env:ANTHROPIC_API_KEY"
            Write-Host "  ✓ Anthropic API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  ANTHROPIC_API_KEY environment variable not set. Using secret reference."
        }
    }
    "prod" {
        if ($Env:AZUREOPENAI_API_KEY) {
            $apiKeyArgs += "--set", "providers.azureOpenAI.apiKey=$Env:AZUREOPENAI_API_KEY"
            Write-Host "  ✓ Azure OpenAI API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  AZUREOPENAI_API_KEY environment variable not set. Using secret reference."
        }
    }
}

# ==============================================================================
# STEP 3: Create namespace if requested
# ==============================================================================

if ($CreateNamespace) {
    Write-Host "`n[3/5] Creating namespace..." -ForegroundColor Yellow
    
    try {
        kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
        Write-Host "  ✓ Namespace '$Namespace' ready" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to create namespace: $_"
    }
} else {
    Write-Host "`n[3/5] Skipping namespace creation" -ForegroundColor Gray
}

# ==============================================================================
# STEP 4: Install CRDs chart
# ==============================================================================

if (-not $SkipCrds) {
    Write-Host "`n[4/5] Installing kagent-crds chart..." -ForegroundColor Yellow
    
    $crdsChartPath = Join-Path $RootPath "kagent-crds"
    $crdsReleaseName = "$ReleaseName-crds"
    
    $crdsArgs = @(
        "install", $crdsReleaseName, $crdsChartPath,
        "--namespace", $Namespace
    )
    
    if ($DryRun) {
        $crdsArgs += "--dry-run"
    }
    
    if ($Wait) {
        $crdsArgs += "--wait", "--timeout=300s"
    }
    
    try {
        Write-Host "  Installing CRDs with release name: $crdsReleaseName" -ForegroundColor Cyan
        & $HelmPath @crdsArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "CRDs installation failed with exit code: $LASTEXITCODE"
        }
        
        if (-not $DryRun) {
            Write-Host "  ✓ kagent-crds installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✓ kagent-crds dry-run completed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to install kagent-crds: $_"
        exit 1
    }
} else {
    Write-Host "`n[4/5] Skipping CRDs installation" -ForegroundColor Gray
}

# ==============================================================================
# STEP 5: Install main kagent chart
# ==============================================================================

Write-Host "`n[5/5] Installing kagent main chart..." -ForegroundColor Yellow

$kagentChartPath = Join-Path $RootPath "kagent"

$kagentArgs = @(
    "install", $ReleaseName, $kagentChartPath,
    "--namespace", $Namespace,
    "--values", $valuesFile
)

# Add API key arguments
$kagentArgs += $apiKeyArgs

if ($DryRun) {
    $kagentArgs += "--dry-run"
}

if ($Wait) {
    $kagentArgs += "--wait", "--timeout=600s"
}

try {
    Write-Host "  Installing main chart with release name: $ReleaseName" -ForegroundColor Cyan
    Write-Host "  Using values file: values-$Env.yaml" -ForegroundColor Cyan
    
    & $HelmPath @kagentArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Main chart installation failed with exit code: $LASTEXITCODE"
    }
    
    if (-not $DryRun) {
        Write-Host "  ✓ kagent main chart installed successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✓ kagent main chart dry-run completed successfully" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to install kagent main chart: $_"
    exit 1
}

# ==============================================================================
# Installation Summary
# ==============================================================================

Write-Host "`n🎉 Installation completed successfully!" -ForegroundColor Green

if (-not $DryRun) {
    Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
    Write-Host "  Environment: $Env" -ForegroundColor White
    Write-Host "  Namespace: $Namespace" -ForegroundColor White
    Write-Host "  Release Names: $ReleaseName, $ReleaseName-crds" -ForegroundColor White
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  - Check deployment status: kubectl get pods -n $Namespace" -ForegroundColor Cyan
    Write-Host "  - View logs: kubectl logs -n $Namespace -l app.kubernetes.io/name=kagent" -ForegroundColor Cyan
    Write-Host "  - Port forward UI: kubectl port-forward -n $Namespace svc/kagent-ui 8080:80" -ForegroundColor Cyan
    
    Write-Host "`nUseful commands:" -ForegroundColor Cyan
    Write-Host "  - Helm status: helm status $ReleaseName -n $Namespace" -ForegroundColor Cyan
    Write-Host "  - Uninstall: .\scripts\Uninstall-Kagent.ps1 -Env $Env -Namespace $Namespace" -ForegroundColor Cyan
} else {
    Write-Host "`nDry run completed. No resources were actually created." -ForegroundColor Yellow
}
