#Requires -Version 5.1

<#
.SYNOPSIS
    Uninstalls kagent Helm charts with optional CRD cleanup.

.DESCRIPTION
    This script safely uninstalls the kagent platform by:
    1. Uninstalling main kagent application via kagent chart
    2. Optionally uninstalling CRDs via kagent-crds chart
    3. Providing safeguards against accidental production data loss
    4. Cleaning up associated resources and secrets

.PARAMETER Env
    The target environment: dev, stage, or prod. Used for confirmation prompts.

.PARAMETER Namespace
    The Kubernetes namespace where kagent is installed. Defaults to 'kagent'.

.PARAMETER ReleaseName
    The Helm release name. Defaults to 'kagent' for main chart and 'kagent-crds' for CRDs.

.PARAMETER IncludeCrds
    Also uninstall the CRDs chart. WARNING: This will remove all custom resources.

.PARAMETER Force
    Skip confirmation prompts. Use with caution, especially in production.

.PARAMETER KeepHistory
    Keep Helm release history for potential rollback.

.PARAMETER DryRun
    Show what would be uninstalled without actually removing anything.

.EXAMPLE
    .\Uninstall-Kagent.ps1 -Env dev
    
.EXAMPLE
    .\Uninstall-Kagent.ps1 -Env prod -IncludeCrds -Force
    
.EXAMPLE
    .\Uninstall-Kagent.ps1 -Env stage -DryRun
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
    [switch]$IncludeCrds,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$KeepHistory,
    
    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath = Split-Path -Parent $ScriptPath
$HelmPath = "C:\Users\AiO PC - Sam\helm.exe"

# Ensure we're in the correct directory
Set-Location $RootPath

Write-Host "=== Kagent Uninstall ===" -ForegroundColor Cyan
Write-Host "Environment: $Env" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes will be made)" -ForegroundColor Blue
}

# ==============================================================================
# STEP 1: Safety checks and confirmations
# ==============================================================================

Write-Host "`n[1/5] Safety checks and confirmations..." -ForegroundColor Yellow

# Check if helm is available
if (-not (Test-Path $HelmPath)) {
    throw "Helm executable not found at: $HelmPath"
}

Write-Host "  ✓ Helm is available" -ForegroundColor Green

# Environment-specific safety warnings
if ($Env -eq "prod" -and -not $Force) {
    Write-Host "`n⚠️  PRODUCTION ENVIRONMENT WARNING ⚠️" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "You are about to uninstall kagent from PRODUCTION environment!" -ForegroundColor Red
    Write-Host "This action will:" -ForegroundColor Red
    Write-Host "  - Stop all kagent services" -ForegroundColor Red
    Write-Host "  - Remove all kagent deployments and data" -ForegroundColor Red
    if ($IncludeCrds) {
        Write-Host "  - DELETE ALL CUSTOM RESOURCES (CRDs included)" -ForegroundColor Red
    }
    
    $confirmation = Read-Host "`nType 'DELETE PRODUCTION' to confirm"
    if ($confirmation -ne "DELETE PRODUCTION") {
        Write-Host "Uninstall cancelled." -ForegroundColor Green
        exit 0
    }
} elseif (($Env -eq "stage" -or $Env -eq "dev") -and -not $Force) {
    Write-Host "`n⚠️  Confirmation required for $Env environment" -ForegroundColor Yellow
    Write-Host "This will uninstall kagent from the $Env environment." -ForegroundColor Yellow
    if ($IncludeCrds) {
        Write-Host "CRDs will also be removed, deleting all custom resources." -ForegroundColor Yellow
    }
    
    $confirmation = Read-Host "Continue? (y/N)"
    if ($confirmation -notlike "y*") {
        Write-Host "Uninstall cancelled." -ForegroundColor Green
        exit 0
    }
}

if ($Force) {
    Write-Host "  ⚠️  Force mode enabled - skipping confirmations" -ForegroundColor Yellow
}

# ==============================================================================
# STEP 2: Check existing releases
# ==============================================================================

Write-Host "`n[2/5] Checking existing releases..." -ForegroundColor Yellow

$mainReleaseExists = $false
$crdsReleaseExists = $false

try {
    # Check main release
    & $HelmPath status $ReleaseName --namespace $Namespace 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $mainReleaseExists = $true
        Write-Host "  ✓ Main release '$ReleaseName' found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Main release '$ReleaseName' not found" -ForegroundColor Yellow
    }
    
    # Check CRDs release
    $crdsReleaseName = "$ReleaseName-crds"
    & $HelmPath status $crdsReleaseName --namespace $Namespace 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $crdsReleaseExists = $true
        Write-Host "  ✓ CRDs release '$crdsReleaseName' found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  CRDs release '$crdsReleaseName' not found" -ForegroundColor Yellow
    }
    
    if (-not $mainReleaseExists -and -not $crdsReleaseExists) {
        Write-Host "`n✓ No kagent releases found to uninstall." -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Warning "Failed to check existing releases: $_"
}

# ==============================================================================
# STEP 3: Pre-uninstall backup information
# ==============================================================================

if (-not $DryRun -and $mainReleaseExists) {
    Write-Host "`n[3/5] Gathering release information..." -ForegroundColor Yellow
    
    try {
        # Get current release info for potential recovery
        Write-Host "  Gathering release information for potential recovery..." -ForegroundColor Cyan
        
        $releaseInfo = & $HelmPath get values $ReleaseName --namespace $Namespace --output json 2>$null
        if ($LASTEXITCODE -eq 0 -and $releaseInfo) {
            $backupFile = "kagent-${Env}-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $releaseInfo | Out-File -FilePath $backupFile -Encoding UTF8
            Write-Host "  ✓ Release values backed up to: $backupFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "  Could not backup release information: $_"
    }
} else {
    Write-Host "`n[3/5] Skipping backup (dry-run or no main release)" -ForegroundColor Gray
}

# ==============================================================================
# STEP 4: Uninstall main kagent chart
# ==============================================================================

if ($mainReleaseExists) {
    Write-Host "`n[4/5] Uninstalling kagent main chart..." -ForegroundColor Yellow
    
    $uninstallArgs = @(
        "uninstall", $ReleaseName,
        "--namespace", $Namespace
    )
    
    if ($DryRun) {
        $uninstallArgs += "--dry-run"
    }
    
    if (-not $KeepHistory) {
        $uninstallArgs += "--no-hooks"  # Skip hooks to ensure clean removal
    }
    
    try {
        Write-Host "  Uninstalling main chart with release name: $ReleaseName" -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Would execute: helm $($uninstallArgs -join ' ')" -ForegroundColor Blue
        } else {
            & $HelmPath @uninstallArgs
            
            if ($LASTEXITCODE -ne 0) {
                throw "Main chart uninstall failed with exit code: $LASTEXITCODE"
            }
        }
        
        if (-not $DryRun) {
            Write-Host "  ✓ kagent main chart uninstalled successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✓ kagent main chart uninstall dry-run completed" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to uninstall kagent main chart: $_"
        exit 1
    }
} else {
    Write-Host "`n[4/5] Skipping main chart uninstall (not found)" -ForegroundColor Gray
}

# ==============================================================================
# STEP 5: Uninstall CRDs chart (if requested)
# ==============================================================================

if ($IncludeCrds -and $crdsReleaseExists) {
    Write-Host "`n[5/5] Uninstalling kagent-crds chart..." -ForegroundColor Yellow
    Write-Host "  ⚠️  WARNING: This will delete all custom resources!" -ForegroundColor Red
    
    $crdsReleaseName = "$ReleaseName-crds"
    
    $crdsUninstallArgs = @(
        "uninstall", $crdsReleaseName,
        "--namespace", $Namespace
    )
    
    if ($DryRun) {
        $crdsUninstallArgs += "--dry-run"
    }
    
    if (-not $KeepHistory) {
        $crdsUninstallArgs += "--no-hooks"
    }
    
    try {
        Write-Host "  Uninstalling CRDs with release name: $crdsReleaseName" -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Would execute: helm $($crdsUninstallArgs -join ' ')" -ForegroundColor Blue
        } else {
            & $HelmPath @crdsUninstallArgs
            
            if ($LASTEXITCODE -ne 0) {
                throw "CRDs uninstall failed with exit code: $LASTEXITCODE"
            }
        }
        
        if (-not $DryRun) {
            Write-Host "  ✓ kagent-crds uninstalled successfully" -ForegroundColor Green
            Write-Host "  ⚠️  All custom resources have been deleted" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ kagent-crds uninstall dry-run completed" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to uninstall kagent-crds: $_"
        exit 1
    }
} elseif ($IncludeCrds -and -not $crdsReleaseExists) {
    Write-Host "`n[5/5] CRDs uninstall requested but release not found" -ForegroundColor Gray
} else {
    Write-Host "`n[5/5] Skipping CRDs uninstall (not requested)" -ForegroundColor Gray
    if ($crdsReleaseExists) {
        Write-Host "  Note: CRDs release still exists. Use -IncludeCrds to remove it." -ForegroundColor Yellow
    }
}

# ==============================================================================
# Post-uninstall cleanup and summary
# ==============================================================================

if (-not $DryRun) {
    Write-Host "`nPost-uninstall cleanup..." -ForegroundColor Yellow
    
    try {
        # Wait a moment for resources to be cleaned up
        Start-Sleep -Seconds 3
        
        # Check for remaining resources
        Write-Host "  Checking for remaining resources..." -ForegroundColor Cyan
        $remainingPods = kubectl get pods -n $Namespace -l "app.kubernetes.io/instance=$ReleaseName" --ignore-not-found=true --no-headers 2>$null
        
        if ($remainingPods) {
            Write-Warning "  Some pods may still be terminating. This is normal and should resolve shortly."
        } else {
            Write-Host "  ✓ All pods have been removed" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "  Could not verify cleanup status: $_"
    }
}

# ==============================================================================
# Uninstall Summary
# ==============================================================================

Write-Host "`n🗑️ Uninstall completed!" -ForegroundColor Green

if (-not $DryRun) {
    Write-Host "`nUninstall Summary:" -ForegroundColor Cyan
    Write-Host "  Environment: $Env" -ForegroundColor White
    Write-Host "  Namespace: $Namespace" -ForegroundColor White
    
    if ($mainReleaseExists) {
        Write-Host "  ✓ Main release '$ReleaseName' removed" -ForegroundColor Green
    }
    
    if ($IncludeCrds -and $crdsReleaseExists) {
        Write-Host "  ✓ CRDs release '$ReleaseName-crds' removed" -ForegroundColor Green
        Write-Host "  ⚠️  All custom resources deleted" -ForegroundColor Yellow
    }
    
    Write-Host "`nCleanup suggestions:" -ForegroundColor Cyan
    Write-Host "  - Check for remaining resources: kubectl get all -n $Namespace" -ForegroundColor Cyan
    Write-Host "  - Remove namespace if empty: kubectl delete namespace $Namespace" -ForegroundColor Cyan
    
    if ($IncludeCrds) {
        Write-Host "  - Verify CRD removal: kubectl get crd | grep kagent" -ForegroundColor Cyan
    }
    
    Write-Host "`nRecovery information:" -ForegroundColor Cyan
    Write-Host "  - Reinstall: .\scripts\Install-Kagent.ps1 -Env $Env" -ForegroundColor Cyan
    
    if ((Test-Path "*backup*.json")) {
        $backupFiles = Get-ChildItem -Filter "*backup*.json" | Select-Object -First 1
        Write-Host "  - Values backup: $($backupFiles.Name)" -ForegroundColor Cyan
    }
    
} else {
    Write-Host "`nDry run completed. No resources were actually removed." -ForegroundColor Yellow
    Write-Host "Add -Force to execute the uninstall operation." -ForegroundColor Yellow
}
