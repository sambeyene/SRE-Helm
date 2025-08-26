#Requires -Version 5.1

<#
.SYNOPSIS
    Renders Chart.yaml from Chart-template.yaml by replacing ${VERSION} placeholders.

.DESCRIPTION
    This script searches for Chart-template.yaml files and generates corresponding
    Chart.yaml files by replacing ${VERSION} placeholders with the specified version.

.PARAMETER Version
    The version to use for Chart.yaml generation. If not specified, uses 
    KAGENT_CHART_VERSION environment variable or falls back to git tag.

.PARAMETER Path
    The root path to search for Chart-template.yaml files. Defaults to current directory.

.EXAMPLE
    .\Render-ChartTemplate.ps1 -Version "0.1.0"
    
.EXAMPLE
    $Env:KAGENT_CHART_VERSION = "0.2.0"
    .\Render-ChartTemplate.ps1
#>

param(
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Get-ChartVersion {
    if (-not [string]::IsNullOrEmpty($Version)) {
        return $Version
    }
    
    if (-not [string]::IsNullOrEmpty($Env:KAGENT_CHART_VERSION)) {
        return $Env:KAGENT_CHART_VERSION
    }
    
    # Try to get version from git tag
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($gitTag)) {
            Write-Host "Using git tag version: $gitTag" -ForegroundColor Green
            return $gitTag.TrimStart('v')
        }
    }
    catch {
        Write-Warning "Could not retrieve git tag: $_"
    }
    
    # Default fallback version
    $defaultVersion = "0.1.0"
    Write-Warning "No version specified, using default: $defaultVersion"
    return $defaultVersion
}

function Render-ChartTemplate {
    param(
        [string]$TemplatePath,
        [string]$ChartVersion
    )
    
    $templateDir = Split-Path -Parent $TemplatePath
    $chartYamlPath = Join-Path $templateDir "Chart.yaml"
    
    Write-Host "Processing: $TemplatePath" -ForegroundColor Cyan
    
    try {
        $templateContent = Get-Content -Path $TemplatePath -Raw -ErrorAction Stop
        
        # Replace VERSION placeholder
        $renderedContent = $templateContent -replace '\$\{VERSION\}', $ChartVersion
        
        # Replace KMCP_VERSION placeholder (use same version for now)
        $kmcpVersion = if ($Env:KMCP_VERSION) { $Env:KMCP_VERSION } else { $ChartVersion }
        $renderedContent = $renderedContent -replace '\$\{KMCP_VERSION\}', $kmcpVersion
        
        Set-Content -Path $chartYamlPath -Value $renderedContent -ErrorAction Stop
        Write-Host "  → Generated: $chartYamlPath" -ForegroundColor Green
        
        return $chartYamlPath
    }
    catch {
        Write-Error "Failed to process template ${TemplatePath}: ${_}"
        throw
    }
}

# Main execution
try {
    $chartVersion = Get-ChartVersion
    Write-Host "Using chart version: $chartVersion" -ForegroundColor Yellow
    
    # Find all Chart-template.yaml files
    $templateFiles = Get-ChildItem -Path $Path -Name "Chart-template.yaml" -Recurse
    
    if ($templateFiles.Count -eq 0) {
        Write-Warning "No Chart-template.yaml files found in $Path"
        exit 0
    }
    
    $generatedFiles = @()
    
    foreach ($templateFile in $templateFiles) {
        $fullTemplatePath = Join-Path $Path $templateFile
        $chartYaml = Render-ChartTemplate -TemplatePath $fullTemplatePath -ChartVersion $chartVersion
        $generatedFiles += $chartYaml
    }
    
    Write-Host "`nSuccessfully generated $($generatedFiles.Count) Chart.yaml file(s):" -ForegroundColor Green
    foreach ($file in $generatedFiles) {
        Write-Host "  - $file" -ForegroundColor Green
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
