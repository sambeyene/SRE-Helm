#Requires -Version 5.1

<#
.SYNOPSIS
    Builds kagent Helm charts with proper templating, linting, and dependency management.

.DESCRIPTION
    This script performs the complete build process for kagent Helm charts:
    1. Renders Chart.yaml from Chart-template.yaml files
    2. Updates chart dependencies
    3. Lints the charts for best practices
    4. Packages the charts for distribution

.PARAMETER Version
    The chart version to use. If not specified, uses KAGENT_CHART_VERSION environment 
    variable or falls back to git tag.

.PARAMETER SkipLint
    Skip the Helm lint step during build.

.PARAMETER SkipPackage
    Skip the chart packaging step.

.PARAMETER CleanPackages
    Remove existing chart packages before building.

.EXAMPLE
    .\Build-Chart.ps1 -Version "0.2.0"
    
.EXAMPLE
    .\Build-Chart.ps1 -SkipLint -CleanPackages
#>

param(
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [switch]$SkipLint,
    
    [Parameter()]
    [switch]$SkipPackage,
    
    [Parameter()]
    [switch]$CleanPackages
)

$ErrorActionPreference = "Stop"
$ScriptPath = $PSScriptRoot
$RootPath = Split-Path -Parent $ScriptPath
$HelmPath = "C:\Users\AiO PC - Sam\helm.exe"

# Ensure we're in the correct directory
Set-Location $RootPath

Write-Host "=== Kagent Helm Chart Build ===" -ForegroundColor Cyan
Write-Host "Root Path: $RootPath" -ForegroundColor Gray

# ==============================================================================
# STEP 1: Clean packages if requested
# ==============================================================================

if ($CleanPackages) {
    Write-Host "`n[1/6] Cleaning existing chart packages..." -ForegroundColor Yellow
    $packagesPath = Join-Path $RootPath "packages"
    if (Test-Path $packagesPath) {
        Remove-Item -Path $packagesPath -Recurse -Force
        Write-Host "  checkmark Removed existing packages directory" -ForegroundColor Green
    }
    
    # Clean chart dependencies
    $chartPaths = @("kagent", "kagent-crds")
    foreach ($chartPath in $chartPaths) {
        $chartsDir = Join-Path $RootPath "$chartPath\charts"
        if (Test-Path $chartsDir) {
            Remove-Item -Path $chartsDir -Recurse -Force
            Write-Host "  checkmark Cleaned dependencies for $chartPath" -ForegroundColor Green
        }
    }
} else {
    Write-Host "`n[1/6] Skipping package cleanup" -ForegroundColor Gray
}

# ==============================================================================
# STEP 2: Render Chart templates
# ==============================================================================

Write-Host "`n[2/6] Rendering Chart.yaml from templates..." -ForegroundColor Yellow

$templateScript = Join-Path $RootPath "tools\Render-ChartTemplate.ps1"
if (-not (Test-Path $templateScript)) {
    throw "Chart template renderer not found: $templateScript"
}

try {
    if ($Version) {
        & $templateScript -Version $Version
    } else {
        & $templateScript
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Chart template rendering failed with exit code: $LASTEXITCODE"
    }
    
    Write-Host "  checkmark Chart templates rendered successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to render chart templates: $_"
    exit 1
}

# ==============================================================================
# STEP 3: Update chart dependencies
# ==============================================================================

Write-Host "`n[3/6] Updating chart dependencies..." -ForegroundColor Yellow

$chartsWithDependencies = @("kagent")  # kagent-crds typically doesn't have file dependencies

foreach ($chartName in $chartsWithDependencies) {
    $chartPath = Join-Path $RootPath $chartName
    
    if (-not (Test-Path $chartPath)) {
        Write-Warning "Chart directory not found: $chartPath"
        continue
    }
    
    Write-Host "  Updating dependencies for $chartName..." -ForegroundColor Cyan
    
    try {
        & $HelmPath dependency update $chartPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "Helm dependency update failed with exit code: $LASTEXITCODE"
        }
        
        Write-Host "  checkmark Dependencies updated for $chartName" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to update dependencies for $chartName : $_"
        exit 1
    }
}

# ==============================================================================
# STEP 4: Lint charts
# ==============================================================================

if (-not $SkipLint) {
    Write-Host "`n[4/6] Linting charts..." -ForegroundColor Yellow
    
    $chartsToLint = @("kagent-crds", "kagent")
    
    foreach ($chartName in $chartsToLint) {
        $chartPath = Join-Path $RootPath $chartName
        
        if (-not (Test-Path $chartPath)) {
            Write-Warning "Chart directory not found: $chartPath"
            continue
        }
        
        Write-Host "  Linting $chartName..." -ForegroundColor Cyan
        
        try {
            & $HelmPath lint $chartPath
            
            if ($LASTEXITCODE -ne 0) {
                throw "Helm lint failed with exit code: $LASTEXITCODE"
            }
            
            Write-Host "  checkmark $chartName passed lint checks" -ForegroundColor Green
        }
        catch {
            Write-Error "Chart linting failed for $chartName : $_"
            exit 1
        }
    }
} else {
    Write-Host "`n[4/6] Skipping chart linting" -ForegroundColor Gray
}

# ==============================================================================
# STEP 5: Package charts
# ==============================================================================

if (-not $SkipPackage) {
    Write-Host "`n[5/6] Packaging charts..." -ForegroundColor Yellow
    
    # Create packages directory
    $packagesPath = Join-Path $RootPath "packages"
    if (-not (Test-Path $packagesPath)) {
        New-Item -ItemType Directory -Path $packagesPath -Force | Out-Null
    }
    
    $chartsToPackage = @("kagent-crds", "kagent")
    
    foreach ($chartName in $chartsToPackage) {
        $chartPath = Join-Path $RootPath $chartName
        
        if (-not (Test-Path $chartPath)) {
            Write-Warning "Chart directory not found: $chartPath"
            continue
        }
        
        Write-Host "  Packaging $chartName..." -ForegroundColor Cyan
        
        try {
            & $HelmPath package $chartPath --destination $packagesPath
            
            if ($LASTEXITCODE -ne 0) {
                throw "Helm package failed with exit code: $LASTEXITCODE"
            }
            
            Write-Host "  checkmark $chartName packaged successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Chart packaging failed for $chartName : $_"
            exit 1
        }
    }
    
    # List created packages
    $packages = Get-ChildItem -Path $packagesPath -Filter "*.tgz"
    if ($packages) {
        Write-Host "`n  Created packages:" -ForegroundColor Green
        foreach ($package in $packages) {
            $size = [math]::Round($package.Length / 1KB, 1)
            Write-Host "    - $($package.Name) ($size KB)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "`n[5/6] Skipping chart packaging" -ForegroundColor Gray
}

# ==============================================================================
# STEP 6: Build summary
# ==============================================================================

Write-Host "`n[6/6] Build Summary" -ForegroundColor Yellow

$chartYamlFiles = Get-ChildItem -Path $RootPath -Name "Chart.yaml" -Recurse
Write-Host "  checkmark Generated Chart.yaml files: $($chartYamlFiles.Count)" -ForegroundColor Green

if (-not $SkipLint) {
    Write-Host "  checkmark All charts passed lint checks" -ForegroundColor Green
}

if (-not $SkipPackage) {
    $packagesPath = Join-Path $RootPath "packages"
    if (Test-Path $packagesPath) {
        $packageCount = (Get-ChildItem -Path $packagesPath -Filter "*.tgz").Count
        Write-Host "  checkmark Packaged charts: $packageCount" -ForegroundColor Green
    }
}

Write-Host "`nBuild completed successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  - Test charts with: .\scripts\Install-Kagent.ps1 -Env dev" -ForegroundColor Cyan
Write-Host "  - Publish packages to registry if needed" -ForegroundColor Cyan
