# Repository cloning script for CashDesk V3 (PowerShell)
# This script can be used to clone or update individual repositories

param(
    [switch]$List,
    [switch]$All,
    [switch]$Required,
    [switch]$Update,
    [string]$Specific,
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path (Split-Path $ScriptDir -Parent) "config\repositories.json"

# Function to display usage
function Show-Usage {
    Write-Host "Usage: .\clone-repos.ps1 [OPTIONS] [REPOSITORY_NAME]" -ForegroundColor Yellow
    Write-Host
    Write-Host "Options:" -ForegroundColor Blue
    Write-Host "  -Help           Show this help message"
    Write-Host "  -List           List all available repositories"
    Write-Host "  -All            Clone/update all repositories"
    Write-Host "  -Required       Clone/update only required repositories"
    Write-Host "  -Update         Update existing repositories (git pull)"
    Write-Host "  -Specific <name> Clone/update specific repository"
    Write-Host
    Write-Host "Examples:" -ForegroundColor Blue
    Write-Host "  .\clone-repos.ps1 -List                    # List all repositories"
    Write-Host "  .\clone-repos.ps1 -All                     # Clone all repositories"
    Write-Host "  .\clone-repos.ps1 -Required                # Clone only required repositories"
    Write-Host "  .\clone-repos.ps1 -Specific CashDesk.Web   # Clone specific repository"
    Write-Host "  .\clone-repos.ps1 -Update -Specific CashDesk.Web # Update specific repository"
}

# Function to list repositories
function Show-Repositories {
    Write-Host "Available repositories:" -ForegroundColor Blue
    Write-Host
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "Error: Configuration file not found!" -ForegroundColor Red
        exit 1
    }
    
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    
    foreach ($Repo in $Config.repositories) {
        $Status = if ($Repo.required) { "Required" } else { "Optional" }
        $Color = if ($Repo.required) { "Green" } else { "Yellow" }
        Write-Host "  $($Repo.name) - $($Repo.description) ($Status)" -ForegroundColor $Color
    }
}

# Function to clone or update a repository
function Invoke-RepoOperation {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Branch,
        [bool]$UpdateOnly
    )
    
    if (Test-Path $Name) {
        if ($UpdateOnly) {
            Write-Host "Updating $Name..." -ForegroundColor Blue
            Push-Location $Name
            try {
                git pull origin $Branch
                Write-Host "✓ Updated $Name" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Host "✗ Failed to update $Name" -ForegroundColor Red
                return $false
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Host "Repository $Name already exists" -ForegroundColor Yellow
            $Response = Read-Host "Update it? (y/N)"
            if ($Response -match "^[Yy]$") {
                Push-Location $Name
                git pull origin $Branch
                Pop-Location
            }
        }
    }
    else {
        if ($UpdateOnly) {
            Write-Host "Repository $Name does not exist, skipping update" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "Cloning $Name..." -ForegroundColor Blue
        try {
            git clone -b $Branch $Url $Name
            Write-Host "✓ Successfully cloned $Name" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "✗ Failed to clone $Name" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Function to process repositories
function Invoke-ProcessRepos {
    param(
        [string]$Filter,
        [bool]$UpdateOnly,
        [string]$SpecificRepo
    )
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "Error: Configuration file not found!" -ForegroundColor Red
        exit 1
    }
    
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    $Repos = $Config.repositories
    
    switch ($Filter) {
        "all" {
            # Use all repositories
        }
        "required" {
            $Repos = $Repos | Where-Object { $_.required -eq $true }
        }
        "specific" {
            $Repos = $Repos | Where-Object { $_.name -eq $SpecificRepo }
            if ($Repos.Count -eq 0) {
                Write-Host "Repository '$SpecificRepo' not found in configuration" -ForegroundColor Red
                exit 1
            }
        }
    }
    
    if ($Repos.Count -eq 0) {
        Write-Host "No repositories found matching filter '$Filter'" -ForegroundColor Yellow
        exit 0
    }
    
    foreach ($Repo in $Repos) {
        Invoke-RepoOperation -Name $Repo.name -Url $Repo.url -Branch $Repo.branch -UpdateOnly $UpdateOnly
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    if ($List) {
        Show-Repositories
        exit 0
    }
    
    $Action = ""
    $SpecificRepo = $Specific
    
    if ($All) {
        $Action = "all"
    }
    elseif ($Required) {
        $Action = "required"
    }
    elseif ($SpecificRepo) {
        $Action = "specific"
    }
    else {
        Write-Host "No action specified. Use -Help for usage information." -ForegroundColor Yellow
        Show-Usage
        exit 1
    }
    
    # Process repositories based on action
    Invoke-ProcessRepos -Filter $Action -UpdateOnly $Update -SpecificRepo $SpecificRepo
    
    Write-Host "`nRepository operations completed!" -ForegroundColor Green
}

# Run main function
Main