#Requires -Version 5.1

<#
.SYNOPSIS
    Upgrades kagent Helm charts with environment-specific configurations.

.DESCRIPTION
    This script upgrades the kagent platform by:
    1. Optionally upgrading CRDs via kagent-crds chart
    2. Upgrading main kagent application via kagent chart
    3. Preserving existing configurations while applying new values
    4. Supporting rolling updates with proper health checks

.PARAMETER Env
    The target environment: dev, stage, or prod. This determines which values 
    file is used for the upgrade.

.PARAMETER Namespace
    The Kubernetes namespace where kagent is installed. Defaults to 'kagent'.

.PARAMETER ReleaseName
    The Helm release name. Defaults to 'kagent' for main chart and 'kagent-crds' for CRDs.

.PARAMETER DryRun
    Perform a dry run without actually upgrading the charts.

.PARAMETER Wait
    Wait for all resources to be ready before marking the upgrade as successful.

.PARAMETER SkipCrds
    Skip upgrade of CRDs chart (recommended for most upgrades as CRDs rarely change).

.PARAMETER Force
    Force the upgrade even if there are no changes detected.

.PARAMETER ResetValues
    Reset values to the ones built into the chart, don't reuse last release's values.

.EXAMPLE
    .\Upgrade-Kagent.ps1 -Env dev
    
.EXAMPLE
    .\Upgrade-Kagent.ps1 -Env prod -Wait -Force
    
.EXAMPLE
    .\Upgrade-Kagent.ps1 -Env stage -DryRun -SkipCrds
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
    [switch]$SkipCrds,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$ResetValues
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath = Split-Path -Parent $ScriptPath
$HelmPath = "C:\Users\AiO PC - Sam\helm.exe"

# Ensure we're in the correct directory
Set-Location $RootPath

Write-Host "=== Kagent Upgrade ===" -ForegroundColor Cyan
Write-Host "Environment: $Env" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow

# ==============================================================================
# STEP 1: Validate prerequisites
# ==============================================================================

Write-Host "`n[1/6] Validating prerequisites..." -ForegroundColor Yellow

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
# STEP 2: Check existing releases
# ==============================================================================

Write-Host "`n[2/6] Checking existing releases..." -ForegroundColor Yellow

try {
    $mainReleaseExists = $false
    $crdsReleaseExists = $false
    
    # Check main release
    & $HelmPath status $ReleaseName --namespace $Namespace 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $mainReleaseExists = $true
        Write-Host "  ✓ Main release '$ReleaseName' found" -ForegroundColor Green
    } else {
        Write-Warning "  Main release '$ReleaseName' not found. This will be treated as a new installation."
    }
    
    # Check CRDs release
    $crdsReleaseName = "$ReleaseName-crds"
    & $HelmPath status $crdsReleaseName --namespace $Namespace 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $crdsReleaseExists = $true
        Write-Host "  ✓ CRDs release '$crdsReleaseName' found" -ForegroundColor Green
    } else {
        Write-Warning "  CRDs release '$crdsReleaseName' not found."
    }
    
    if (-not $mainReleaseExists -and -not $crdsReleaseExists) {
        throw "No existing kagent releases found. Use Install-Kagent.ps1 for initial installation."
    }
}
catch {
    Write-Error "Failed to check existing releases: $_"
    exit 1
}

# ==============================================================================
# STEP 3: Prepare API keys and configuration
# ==============================================================================

Write-Host "`n[3/6] Preparing API keys and configuration..." -ForegroundColor Yellow

$apiKeyArgs = @()

# Environment-specific API key preparation
switch ($Env) {
    "dev" {
        if ($Env:OPENAI_API_KEY) {
            $apiKeyArgs += "--set", "providers.openAI.apiKey=$Env:OPENAI_API_KEY"
            Write-Host "  ✓ OpenAI API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  OPENAI_API_KEY environment variable not set. Using existing secret reference."
        }
    }
    "stage" {
        if ($Env:ANTHROPIC_API_KEY) {
            $apiKeyArgs += "--set", "providers.anthropic.apiKey=$Env:ANTHROPIC_API_KEY"
            Write-Host "  ✓ Anthropic API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  ANTHROPIC_API_KEY environment variable not set. Using existing secret reference."
        }
    }
    "prod" {
        if ($Env:AZUREOPENAI_API_KEY) {
            $apiKeyArgs += "--set", "providers.azureOpenAI.apiKey=$Env:AZUREOPENAI_API_KEY"
            Write-Host "  ✓ Azure OpenAI API key configured from environment" -ForegroundColor Green
        } else {
            Write-Warning "  AZUREOPENAI_API_KEY environment variable not set. Using existing secret reference."
        }
    }
}

# ==============================================================================
# STEP 4: Upgrade CRDs chart (if requested)
# ==============================================================================

if (-not $SkipCrds -and $crdsReleaseExists) {
    Write-Host "`n[4/6] Upgrading kagent-crds chart..." -ForegroundColor Yellow
    
    $crdsChartPath = Join-Path $RootPath "kagent-crds"
    $crdsReleaseName = "$ReleaseName-crds"
    
    $crdsArgs = @(
        "upgrade", $crdsReleaseName, $crdsChartPath,
        "--namespace", $Namespace
    )
    
    if ($DryRun) {
        $crdsArgs += "--dry-run"
    }
    
    if ($Wait) {
        $crdsArgs += "--wait", "--timeout=300s"
    }
    
    if ($Force) {
        $crdsArgs += "--force"
    }
    
    if ($ResetValues) {
        $crdsArgs += "--reset-values"
    }
    
    try {
        Write-Host "  Upgrading CRDs with release name: $crdsReleaseName" -ForegroundColor Cyan
        & $HelmPath @crdsArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "CRDs upgrade failed with exit code: $LASTEXITCODE"
        }
        
        if (-not $DryRun) {
            Write-Host "  ✓ kagent-crds upgraded successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✓ kagent-crds upgrade dry-run completed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to upgrade kagent-crds: $_"
        exit 1
    }
} elseif (-not $SkipCrds -and -not $crdsReleaseExists) {
    Write-Host "`n[4/6] Installing kagent-crds chart (first-time)..." -ForegroundColor Yellow
    
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
            Write-Host "  ✓ kagent-crds install dry-run completed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to install kagent-crds: $_"
        exit 1
    }
} else {
    Write-Host "`n[4/6] Skipping CRDs upgrade" -ForegroundColor Gray
}

# ==============================================================================
# STEP 5: Upgrade main kagent chart
# ==============================================================================

Write-Host "`n[5/6] Upgrading kagent main chart..." -ForegroundColor Yellow

$kagentChartPath = Join-Path $RootPath "kagent"

if ($mainReleaseExists) {
    $operation = "upgrade"
    $kagentArgs = @(
        "upgrade", $ReleaseName, $kagentChartPath,
        "--namespace", $Namespace,
        "--values", $valuesFile
    )
} else {
    $operation = "install"
    $kagentArgs = @(
        "install", $ReleaseName, $kagentChartPath,
        "--namespace", $Namespace,
        "--values", $valuesFile
    )
}

# Add API key arguments
$kagentArgs += $apiKeyArgs

if ($DryRun) {
    $kagentArgs += "--dry-run"
}

if ($Wait) {
    $kagentArgs += "--wait", "--timeout=600s"
}

if ($Force -and $mainReleaseExists) {
    $kagentArgs += "--force"
}

if ($ResetValues -and $mainReleaseExists) {
    $kagentArgs += "--reset-values"
}

try {
    Write-Host "  ${operation}ing main chart with release name: $ReleaseName" -ForegroundColor Cyan
    Write-Host "  Using values file: values-$Env.yaml" -ForegroundColor Cyan
    
    & $HelmPath @kagentArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Main chart $operation failed with exit code: $LASTEXITCODE"
    }
    
    if (-not $DryRun) {
        Write-Host "  ✓ kagent main chart ${operation}d successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✓ kagent main chart $operation dry-run completed successfully" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to $operation kagent main chart: $_"
    exit 1
}

# ==============================================================================
# STEP 6: Post-upgrade verification
# ==============================================================================

if (-not $DryRun) {
    Write-Host "`n[6/6] Post-upgrade verification..." -ForegroundColor Yellow
    
    try {
        # Wait a moment for resources to be updated
        Start-Sleep -Seconds 5
        
        # Check pod status
        Write-Host "  Checking pod status..." -ForegroundColor Cyan
        $pods = kubectl get pods -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName" -o json | ConvertFrom-Json
        
        if ($pods.items) {
            $runningPods = ($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
            $totalPods = $pods.items.Count
            Write-Host "  ✓ Pods status: $runningPods/$totalPods running" -ForegroundColor Green
            
            if ($runningPods -lt $totalPods) {
                Write-Warning "  Some pods are not yet running. Check with: kubectl get pods -n $Namespace"
            }
        } else {
            Write-Warning "  No pods found. This might be normal if using external dependencies."
        }
    }
    catch {
        Write-Warning "  Could not verify pod status: $_"
    }
} else {
    Write-Host "`n[6/6] Skipping post-upgrade verification (dry-run mode)" -ForegroundColor Gray
}

# ==============================================================================
# Upgrade Summary
# ==============================================================================

Write-Host "`n🎉 Upgrade completed successfully!" -ForegroundColor Green

if (-not $DryRun) {
    Write-Host "`nUpgrade Summary:" -ForegroundColor Cyan
    Write-Host "  Environment: $Env" -ForegroundColor White
    Write-Host "  Namespace: $Namespace" -ForegroundColor White
    Write-Host "  Release Names: $ReleaseName, $ReleaseName-crds" -ForegroundColor White
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  - Monitor deployment: kubectl get pods -n $Namespace -w" -ForegroundColor Cyan
    Write-Host "  - Check logs: kubectl logs -n $Namespace -l app.kubernetes.io/name=kagent -f" -ForegroundColor Cyan
    Write-Host "  - Verify functionality: kubectl port-forward -n $Namespace svc/kagent-ui 8080:80" -ForegroundColor Cyan
    
    Write-Host "`nUseful commands:" -ForegroundColor Cyan
    Write-Host "  - Helm status: helm status $ReleaseName -n $Namespace" -ForegroundColor Cyan
    Write-Host "  - Rollback if needed: helm rollback $ReleaseName -n $Namespace" -ForegroundColor Cyan
} else {
    Write-Host "`nDry run completed. No resources were actually modified." -ForegroundColor Yellow
}
