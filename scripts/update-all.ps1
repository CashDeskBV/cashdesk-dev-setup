# Update all repositories script for CashDesk V3 (PowerShell)
# This script pulls the latest changes from all repositories

param(
    [switch]$SkipPackageRestore,
    [switch]$SkipDockerUpdate,
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path (Split-Path $ScriptDir -Parent) "config\repositories.json"

# Function to print header
function Write-Header {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        CashDesk V3 Update All          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\update-all.ps1 [OPTIONS]" -ForegroundColor Yellow
    Write-Host
    Write-Host "Options:" -ForegroundColor Blue
    Write-Host "  -SkipPackageRestore    Skip NuGet package restoration"
    Write-Host "  -SkipDockerUpdate      Skip Docker image updates"
    Write-Host "  -Help                  Show this help message"
    Write-Host
    Write-Host "Examples:" -ForegroundColor Blue
    Write-Host "  .\update-all.ps1                    # Full update"
    Write-Host "  .\update-all.ps1 -SkipDockerUpdate  # Skip Docker updates"
}

# Function to update a repository
function Update-Repository {
    param(
        [string]$RepoName,
        [string]$Branch
    )
    
    if (!(Test-Path $RepoName)) {
        Write-Host "⚠ Repository $RepoName not found, skipping" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Updating $RepoName..." -ForegroundColor Blue
    
    Push-Location $RepoName
    
    try {
        # Check if there are uncommitted changes
        $Status = git status --porcelain
        $Stashed = $false
        
        if ($Status) {
            Write-Host "  ⚠ Repository has uncommitted changes" -ForegroundColor Yellow
            Write-Host "    Stashing changes before update..." -ForegroundColor Yellow
            git stash push -m "Auto-stash before update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $Stashed = $true
        }
        
        # Get current branch
        $CurrentBranch = git branch --show-current
        
        # Switch to target branch if different
        if ($CurrentBranch -ne $Branch) {
            Write-Host "  Switching from $CurrentBranch to $Branch..." -ForegroundColor Blue
            git checkout $Branch
        }
        
        # Pull latest changes
        git pull origin $Branch
        Write-Host "  ✓ Successfully updated $RepoName" -ForegroundColor Green
        
        # Restore stashed changes if any
        if ($Stashed) {
            Write-Host "  Restoring stashed changes..." -ForegroundColor Blue
            git stash pop
        }
        
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to update $RepoName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        Pop-Location
    }
}

# Function to restore packages for updated repositories
function Restore-Packages {
    Write-Host "`nRestoring NuGet packages for updated repositories..." -ForegroundColor Blue
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "Configuration file not found, skipping package restore" -ForegroundColor Yellow
        return
    }
    
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    $RequiredRepos = $Config.repositories | Where-Object { $_.required -eq $true }
    
    foreach ($Repo in $RequiredRepos) {
        if (Test-Path $Repo.name) {
            Write-Host "Restoring packages for $($Repo.name)..." -ForegroundColor Cyan
            Push-Location $Repo.name
            try {
                dotnet restore | Out-Null
                Write-Host "  ✓ Packages restored for $($Repo.name)" -ForegroundColor Green
            }
            catch {
                Write-Host "  ⚠ Could not restore packages for $($Repo.name)" -ForegroundColor Yellow
            }
            finally {
                Pop-Location
            }
        }
    }
}

# Function to check for Docker updates
function Update-DockerImages {
    Write-Host "`nChecking for Docker service updates..." -ForegroundColor Blue
    
    try {
        docker info | Out-Null
        Write-Host "Pulling latest Docker images..." -ForegroundColor Cyan
        
        # Update images used in docker-compose
        docker pull mcr.microsoft.com/mssql/server:2019-latest
        docker pull rabbitmq:3-management
        docker pull datalust/seq:latest
        
        Write-Host "✓ Docker images updated" -ForegroundColor Green
        Write-Host "Run 'docker-compose down && docker-compose up -d' to use updated images" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Docker not available, skipping image updates" -ForegroundColor Yellow
    }
}

# Function to display update summary
function Show-Summary {
    param(
        [int]$Successful,
        [int]$Failed
    )
    
    $Total = $Successful + $Failed
    
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Update Summary            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host
    Write-Host "Total repositories: $Total" -ForegroundColor Blue
    Write-Host "Successfully updated: $Successful" -ForegroundColor Green
    
    if ($Failed -gt 0) {
        Write-Host "Failed to update: $Failed" -ForegroundColor Red
        Write-Host "`nPlease check the failed repositories manually." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n🎉 All repositories are up to date!" -ForegroundColor Green
    }
    
    Write-Host "`nNext steps:" -ForegroundColor Blue
    Write-Host "  • Run " -NoNewline
    Write-Host ".\scripts\start-dev.ps1" -NoNewline -ForegroundColor Cyan
    Write-Host " to start development"
    Write-Host "  • Check individual repositories for any breaking changes"
    Write-Host "  • Review commit logs for important updates"
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    Write-Header
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "Error: Configuration file not found!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "This will update all CashDesk V3 repositories with the latest changes." -ForegroundColor Blue
    Write-Host "Make sure you have committed or stashed any local changes." -ForegroundColor Yellow
    Write-Host
    
    $Response = Read-Host "Continue? (y/N)"
    if ($Response -notmatch "^[Yy]$") {
        Write-Host "Update cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    $Successful = 0
    $Failed = 0
    
    # Get repository information
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    $Repos = $Config.repositories
    $TotalRepos = $Repos.Count
    
    Write-Host "`nUpdating $TotalRepos repositories..." -ForegroundColor Blue
    Write-Host
    
    # Update each repository
    foreach ($Repo in $Repos) {
        if (Update-Repository -RepoName $Repo.name -Branch $Repo.branch) {
            $Successful++
        }
        else {
            $Failed++
        }
        Write-Host
    }
    
    # Restore packages for .NET projects
    if (-not $SkipPackageRestore) {
        Restore-Packages
    }
    
    # Check for Docker updates
    if (-not $SkipDockerUpdate) {
        Update-DockerImages
    }
    
    # Display summary
    Show-Summary -Successful $Successful -Failed $Failed
    
    # Exit with error code if any updates failed
    if ($Failed -gt 0) {
        exit 1
    }
}

# Run main function
Main