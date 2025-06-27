# CashDesk V3 Development Environment Setup Script (PowerShell)
# This script sets up a complete development environment for CashDesk V3

param(
    [switch]$SkipDocker,
    [switch]$RequiredOnly,
    [switch]$Help
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReposConfig = Join-Path $ScriptDir "config\repositories.json"
$WorkspaceDir = $ScriptDir

# Function to print header
function Write-Header {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                CashDesk V3 Development Setup                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\setup-dev-environment.ps1 [OPTIONS]" -ForegroundColor Yellow
    Write-Host
    Write-Host "Options:" -ForegroundColor Blue
    Write-Host "  -SkipDocker      Skip Docker service setup"
    Write-Host "  -RequiredOnly    Clone only required repositories"
    Write-Host "  -Help            Show this help message"
    Write-Host
    Write-Host "Examples:" -ForegroundColor Blue
    Write-Host "  .\setup-dev-environment.ps1                # Full setup"
    Write-Host "  .\setup-dev-environment.ps1 -RequiredOnly  # Required repos only"
    Write-Host "  .\setup-dev-environment.ps1 -SkipDocker    # Skip Docker setup"
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue
    
    $MissingTools = @()
    
    # Check Git
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        $MissingTools += "git"
    }
    
    # Check Docker
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        $MissingTools += "docker"
    }
    
    # Check .NET
    if (!(Get-Command dotnet -ErrorAction SilentlyContinue)) {
        $MissingTools += "dotnet"
    } else {
        # Check .NET version
        $DotnetVersion = (dotnet --version)
        if (-not $DotnetVersion.StartsWith("7.")) {
            Write-Host "Warning: .NET 7.0 is recommended, found version $DotnetVersion" -ForegroundColor Yellow
        }
    }
    
    if ($MissingTools.Count -gt 0) {
        Write-Host "Missing required tools: $($MissingTools -join ', ')" -ForegroundColor Red
        Write-Host "Please install the missing tools and run this script again." -ForegroundColor Yellow
        Write-Host
        Write-Host "Installation links:" -ForegroundColor Blue
        foreach ($Tool in $MissingTools) {
            switch ($Tool) {
                "git" { Write-Host "  Git: https://git-scm.com/downloads" }
                "docker" { Write-Host "  Docker: https://docs.docker.com/desktop/windows/" }
                "dotnet" { Write-Host "  .NET 7.0: https://dotnet.microsoft.com/download/dotnet/7.0" }
            }
        }
        exit 1
    }
    
    Write-Host "✓ All prerequisites are installed" -ForegroundColor Green
}

# Function to clone repositories
function Invoke-RepositoryCloning {
    param([bool]$RequiredOnly)
    
    Write-Host "`nCloning repositories..." -ForegroundColor Blue
    
    if (!(Test-Path $ReposConfig)) {
        Write-Host "Error: repositories.json not found!" -ForegroundColor Red
        exit 1
    }
    
    $Config = Get-Content $ReposConfig | ConvertFrom-Json
    $Repos = $Config.repositories
    
    if ($RequiredOnly) {
        $Repos = $Repos | Where-Object { $_.required -eq $true }
        Write-Host "Cloning only required repositories..." -ForegroundColor Yellow
    }
    
    $TotalRepos = $Repos.Count
    $Current = 0
    $Successful = 0
    $Failed = 0
    
    foreach ($Repo in $Repos) {
        $Current++
        Write-Host "`n[$Current/$TotalRepos] Cloning $($Repo.name)..." -ForegroundColor Cyan
        
        if (Test-Path $Repo.name) {
            Write-Host "  Directory $($Repo.name) already exists, skipping clone" -ForegroundColor Yellow
            Write-Host "  Pulling latest changes..." -ForegroundColor Blue
            Push-Location $Repo.name
            try {
                git pull origin $Repo.branch | Out-Null
                Write-Host "  ✓ Updated $($Repo.name)" -ForegroundColor Green
                $Successful++
            }
            catch {
                Write-Host "  ⚠ Could not pull latest changes" -ForegroundColor Yellow
            }
            Pop-Location
        }
        else {
            try {
                git clone -b $Repo.branch $Repo.url $Repo.name | Out-Null
                if (Test-Path $Repo.name) {
                    Write-Host "  ✓ Successfully cloned $($Repo.name)" -ForegroundColor Green
                    $Successful++
                }
                else {
                    throw "Clone appeared to succeed but directory not found"
                }
            }
            catch {
                if ($Repo.required) {
                    Write-Host "  ✗ Failed to clone required repository $($Repo.name)" -ForegroundColor Red
                    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
                    exit 1
                }
                else {
                    Write-Host "  ⚠ Failed to clone optional repository $($Repo.name)" -ForegroundColor Yellow
                    $Failed++
                }
            }
        }
    }
    
    Write-Host "`nRepository cloning completed!" -ForegroundColor Green
    Write-Host "Successfully processed: $Successful" -ForegroundColor Green
    if ($Failed -gt 0) {
        Write-Host "Failed (optional): $Failed" -ForegroundColor Yellow
    }
}

# Function to setup Docker environment
function Set-DockerEnvironment {
    Write-Host "`nSetting up Docker environment..." -ForegroundColor Blue
    
    # Create docker-data directories
    $DockerDataPath = Join-Path $WorkspaceDir "docker-data\sqlserver"
    New-Item -ItemType Directory -Path "$DockerDataPath\backup" -Force | Out-Null
    New-Item -ItemType Directory -Path "$DockerDataPath\scripts" -Force | Out-Null
    Write-Host "✓ Created docker-data directories" -ForegroundColor Green
    
    # Copy docker-compose.yml to root
    $DockerComposeSource = Join-Path $ScriptDir "config\docker-compose.yml"
    if (Test-Path $DockerComposeSource) {
        Copy-Item $DockerComposeSource "docker-compose.yml"
        Write-Host "✓ Docker Compose configuration ready" -ForegroundColor Green
    }
    
    # Check if Docker is running
    try {
        docker info | Out-Null
        Write-Host "Starting Docker services..." -ForegroundColor Blue
        docker-compose up -d
        
        # Wait for services to be ready
        Write-Host "Waiting for services to start..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        Write-Host "✓ Docker services started" -ForegroundColor Green
        Write-Host "  • RabbitMQ Management: http://localhost:15672 (guest/guest)" -ForegroundColor Blue
        Write-Host "  • SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)" -ForegroundColor Blue
        Write-Host "  • Seq Logs: http://localhost:5341" -ForegroundColor Blue
    }
    catch {
        Write-Host "Docker is not running. Please start Docker and run 'docker-compose up -d' manually." -ForegroundColor Yellow
    }
}

# Function to copy local settings templates
function Copy-LocalSettings {
    Write-Host "`nSetting up local configuration files..." -ForegroundColor Blue
    
    $SettingsConfig = Join-Path $ScriptDir "config\local-settings\settings-mapping.json"
    
    if (!(Test-Path $SettingsConfig)) {
        Write-Host "No local settings configuration found, skipping..." -ForegroundColor Yellow
        return
    }
    
    $Settings = Get-Content $SettingsConfig | ConvertFrom-Json
    $Copied = 0
    $Skipped = 0
    $Failed = 0
    
    foreach ($Mapping in $Settings.settingsMapping) {
        $TemplatePath = Join-Path $ScriptDir "config\local-settings\$($Mapping.templateFile)"
        
        if (!(Test-Path $TemplatePath)) {
            Write-Host "  ⚠ Template $($Mapping.templateFile) not found, skipping..." -ForegroundColor Yellow
            $Failed++
            continue
        }
        
        # Check if target file already exists
        if (Test-Path $Mapping.targetPath) {
            Write-Host "  ⚠ $($Mapping.targetPath) already exists, skipping to preserve local changes" -ForegroundColor Yellow
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
            Copy-Item $TemplatePath $Mapping.targetPath
            Write-Host "  ✓ $($Mapping.description)" -ForegroundColor Green
            $Copied++
        }
        catch {
            Write-Host "  ✗ Failed to copy $($Mapping.description)" -ForegroundColor Red
            $Failed++
        }
    }
    
    Write-Host "✓ Local settings configuration completed" -ForegroundColor Green
    Write-Host "  Note: Existing appsettings.local.json files were preserved" -ForegroundColor Blue
}

# Function to restore NuGet packages
function Restore-Packages {
    Write-Host "`nRestoring NuGet packages..." -ForegroundColor Blue
    
    # Copy nuget.config if it exists
    $NugetConfigSource = Join-Path $ScriptDir "config\nuget.config"
    if (Test-Path $NugetConfigSource) {
        Copy-Item $NugetConfigSource "nuget.config"
        Write-Host "✓ NuGet configuration copied" -ForegroundColor Green
    }
    
    if (!(Test-Path $ReposConfig)) {
        Write-Host "Configuration file not found, skipping package restore" -ForegroundColor Yellow
        return
    }
    
    $Config = Get-Content $ReposConfig | ConvertFrom-Json
    $RequiredRepos = $Config.repositories | Where-Object { $_.required -eq $true }
    
    foreach ($Repo in $RequiredRepos) {
        if (Test-Path $Repo.name) {
            Write-Host "Restoring packages for $($Repo.name)..." -ForegroundColor Cyan
            Push-Location $Repo.name
            try {
                dotnet restore | Out-Null
                Write-Host "  ✓ $($Repo.name) packages restored" -ForegroundColor Green
            }
            catch {
                Write-Host "  ⚠ Could not restore packages for $($Repo.name)" -ForegroundColor Yellow
            }
            Pop-Location
        }
    }
}

# Function to setup scripts
function Set-Scripts {
    Write-Host "`nSetting up development scripts..." -ForegroundColor Blue
    
    # Scripts are already in place, just ensure they're accessible
    Write-Host "✓ Development scripts ready" -ForegroundColor Green
}

# Function to create CLAUDE.md
function New-ClaudeMd {
    Write-Host "`nCreating CLAUDE.md for AI assistance..." -ForegroundColor Blue
    
    $ClaudeContent = @'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

This is a CashDesk V3 development environment with multiple microservices. Use the following commands:

### Quick Start
- `.\scripts\start-dev.ps1` - Start development environment with service selection
- `.\scripts\update-all.ps1` - Pull latest changes from all repositories (Linux/macOS only)

### Service Architecture
- **CashDesk.Identity**: Authentication (Port 5000)
- **CashDesk.Web**: Main POS (Port 5003) + Worker
- **CashDesk.Admin**: Admin Interface (Port 5001) + Worker  
- **CashDesk.Portal**: Customer Portal (Port 5002)
- **CashDesk.Payments**: Payment Processing (Port 5004)

### Infrastructure Services
- **RabbitMQ**: http://localhost:15672 (guest/guest)
- **SQL Server**: localhost:1433 (sa/<YourStrong@Passw0rd>)
- **Seq**: http://localhost:5341

### Development Workflow
1. Choose which service to work on using start-dev.ps1
2. Other required services start automatically in background
3. Use `dotnet watch run` in your chosen service directory
4. Logs are saved to logs/ directory with timestamps

### Repository Structure
Each service is in its own directory with standard .NET structure:
- src/: Source code
- Tests/: Unit tests
- docker-compose.yml: Infrastructure services (root level)

See individual service CLAUDE.md files for service-specific guidance.
'@

    Set-Content -Path "CLAUDE.md" -Value $ClaudeContent
    Write-Host "✓ CLAUDE.md created" -ForegroundColor Green
}

# Function to display completion message
function Show-Completion {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    Setup Complete!                          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host
    Write-Host "🚀 Your CashDesk V3 development environment is ready!" -ForegroundColor Blue
    Write-Host
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Start developing: " -NoNewline -ForegroundColor Yellow
    Write-Host ".\scripts\start-dev.ps1" -ForegroundColor Cyan
    Write-Host "  2. Choose which service you want to work on"
    Write-Host "  3. Use " -NoNewline
    Write-Host "dotnet watch run" -NoNewline -ForegroundColor Cyan
    Write-Host " in your chosen service directory"
    Write-Host
    Write-Host "Available services:" -ForegroundColor Blue
    Write-Host "  • Identity: https://localhost:5000"
    Write-Host "  • Admin: https://localhost:5001"
    Write-Host "  • Portal: https://localhost:5002" 
    Write-Host "  • Web: https://localhost:5003"
    Write-Host
    Write-Host "Infrastructure:" -ForegroundColor Blue
    Write-Host "  • RabbitMQ: http://localhost:15672 (guest/guest)"
    Write-Host "  • SQL Server: localhost:1433"
    Write-Host "  • Seq Logs: http://localhost:5341"
    Write-Host
    Write-Host "Test credentials:" -ForegroundColor Yellow
    Write-Host "  • Demo: demo@cashdesk.nl / Demo123!"
    Write-Host "  • Admin: admin@cashdesk.nl / Admin123!"
    Write-Host
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    Write-Header
    
    Write-Host "This script will set up a complete CashDesk V3 development environment." -ForegroundColor Blue
    Write-Host "It will clone repositories, set up Docker services, and prepare development tools." -ForegroundColor Blue
    Write-Host
    
    $Response = Read-Host "Continue? (y/N)"
    if ($Response -notmatch "^[Yy]$") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Test-Prerequisites
    Invoke-RepositoryCloning -RequiredOnly:$RequiredOnly
    
    if (-not $SkipDocker) {
        Set-DockerEnvironment
    }
    
    Copy-LocalSettings
    Restore-Packages
    Set-Scripts
    New-ClaudeMd
    Show-Completion
}

# Run main function
Main