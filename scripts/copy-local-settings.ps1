# Copy Local Settings Script for CashDesk V3 (PowerShell)
# This script copies local settings templates to their target locations

param(
    [switch]$Force,
    [switch]$List,
    [string]$Specific,
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsConfig = Join-Path (Split-Path $ScriptDir -Parent) "config\local-settings\settings-mapping.json"

# Function to display usage
function Show-Usage {
    Write-Host "Usage: .\copy-local-settings.ps1 [OPTIONS]" -ForegroundColor Yellow
    Write-Host
    Write-Host "Options:" -ForegroundColor Blue
    Write-Host "  -Help           Show this help message"
    Write-Host "  -Force          Overwrite existing local settings files"
    Write-Host "  -List           List all available settings templates"
    Write-Host "  -Specific <name> Copy settings for specific service"
    Write-Host
    Write-Host "Examples:" -ForegroundColor Blue
    Write-Host "  .\copy-local-settings.ps1                           # Copy missing local settings"
    Write-Host "  .\copy-local-settings.ps1 -Force                    # Overwrite all local settings"
    Write-Host "  .\copy-local-settings.ps1 -List                     # List available templates"
    Write-Host "  .\copy-local-settings.ps1 -Specific CashDesk.Web    # Copy only Web service settings"
}

# Function to list available templates
function Show-Templates {
    Write-Host "Available local settings templates:" -ForegroundColor Blue
    Write-Host
    
    if (!(Test-Path $SettingsConfig)) {
        Write-Host "Error: Settings configuration file not found!" -ForegroundColor Red
        exit 1
    }
    
    $Settings = Get-Content $SettingsConfig | ConvertFrom-Json
    
    foreach ($Mapping in $Settings.settingsMapping) {
        Write-Host "  $($Mapping.templateFile) → $($Mapping.targetPath)"
    }
    
    Write-Host
    Write-Host "Use -Specific with the service name (e.g., CashDesk.Web) to copy specific settings" -ForegroundColor Yellow
}

# Function to copy settings
function Copy-Settings {
    param(
        [bool]$ForceOverwrite,
        [string]$SpecificService
    )
    
    if (!(Test-Path $SettingsConfig)) {
        Write-Host "Error: Settings configuration file not found!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Copying local settings templates..." -ForegroundColor Blue
    Write-Host
    
    $Settings = Get-Content $SettingsConfig | ConvertFrom-Json
    $Mappings = $Settings.settingsMapping
    
    if ($SpecificService) {
        $Mappings = $Mappings | Where-Object { $_.targetPath -like "*$SpecificService*" }
        if ($Mappings.Count -eq 0) {
            Write-Host "No settings found for service: $SpecificService" -ForegroundColor Yellow
            exit 1
        }
    }
    
    $Copied = 0
    $Skipped = 0
    $Failed = 0
    
    foreach ($Mapping in $Mappings) {
        $TemplatePath = Join-Path (Split-Path $ScriptDir -Parent) "config\local-settings\$($Mapping.templateFile)"
        
        if (!(Test-Path $TemplatePath)) {
            Write-Host "  ⚠ Template $($Mapping.templateFile) not found, skipping..." -ForegroundColor Yellow
            $Failed++
            continue
        }
        
        # Check if target file already exists
        if ((Test-Path $Mapping.targetPath) -and (-not $ForceOverwrite)) {
            Write-Host "  ⚠ $($Mapping.targetPath) already exists, skipping (use -Force to overwrite)" -ForegroundColor Yellow
            $Skipped++
            continue
        }
        
        # Check if target directory exists
        $TargetDir = Split-Path $Mapping.targetPath -Parent
        if (!(Test-Path $TargetDir)) {
            Write-Host "  ⚠ Target directory $TargetDir not found, skipping $($Mapping.description)" -ForegroundColor Yellow
            $Failed++
            continue
        }
        
        # Copy template to target location
        try {
            Copy-Item $TemplatePath $Mapping.targetPath -Force
            if ((Test-Path $Mapping.targetPath) -and $ForceOverwrite) {
                Write-Host "  ✓ $($Mapping.description) (overwritten)" -ForegroundColor Cyan
            }
            else {
                Write-Host "  ✓ $($Mapping.description)" -ForegroundColor Green
            }
            $Copied++
        }
        catch {
            Write-Host "  ✗ Failed to copy $($Mapping.description)" -ForegroundColor Red
            $Failed++
        }
    }
    
    # Display summary
    Write-Host
    Write-Host "Summary:" -ForegroundColor Blue
    Write-Host "  Copied: $Copied" -ForegroundColor Green
    Write-Host "  Skipped: $Skipped" -ForegroundColor Yellow
    
    if ($Failed -gt 0) {
        Write-Host "  Failed: $Failed" -ForegroundColor Red
    }
    
    if ($Copied -gt 0) {
        Write-Host "`n✓ Local settings copied successfully!" -ForegroundColor Green
        Write-Host "Note: You can now customize these files for your local development environment." -ForegroundColor Blue
    }
    elseif (($Skipped -gt 0) -and ($Failed -eq 0)) {
        Write-Host "`nAll local settings files already exist. Use -Force to overwrite." -ForegroundColor Yellow
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    if ($List) {
        Show-Templates
        exit 0
    }
    
    Copy-Settings -ForceOverwrite $Force -SpecificService $Specific
}

# Run main function
Main