# CashDesk V3 Development Environment Starter (PowerShell)
# This script starts the required services based on what you're working on

# Create logs directory if it doesn't exist
$LogsDir = "./logs"
if (!(Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

# Get current timestamp for log files
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Store running processes
$script:RunningProcesses = @()

# Function to start a service
function Start-Service {
    param(
        [string]$ServiceName,
        [string]$ServicePath,
        [int]$Port
    )
    
    $LogFile = "$LogsDir/${ServiceName}_${Timestamp}.log"
    
    Write-Host "Starting $ServiceName on port $Port..." -ForegroundColor Blue
    
    # Check if the service directory exists
    if (!(Test-Path $ServicePath)) {
        Write-Host "Error: Directory $ServicePath not found!" -ForegroundColor Red
        return
    }
    
    # Start the service
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = "dotnet"
    $ProcessInfo.Arguments = "run"
    $ProcessInfo.WorkingDirectory = (Resolve-Path $ServicePath).Path
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    
    # Set up event handlers for output redirection
    $OutputHandler = {
        if ($EventArgs.Data -ne $null) {
            Add-Content -Path $Event.MessageData -Value $EventArgs.Data
        }
    }
    
    Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action $OutputHandler -MessageData $LogFile | Out-Null
    Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action $OutputHandler -MessageData $LogFile | Out-Null
    
    $Process.Start() | Out-Null
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()
    
    $script:RunningProcesses += $Process
    
    Write-Host "✓ $ServiceName started (PID: $($Process.Id), Log: $LogFile)" -ForegroundColor Green
}

# Function to check if docker-compose is running
function Test-DockerCompose {
    Write-Host "Checking Docker services..." -ForegroundColor Magenta
    
    # Check if docker-compose.yml exists
    if (!(Test-Path "docker-compose.yml")) {
        Write-Host "Error: docker-compose.yml not found!" -ForegroundColor Red
        return $false
    }
    
    # Create docker-data directories if they don't exist
    New-Item -ItemType Directory -Path "docker-data/sqlserver/backup" -Force | Out-Null
    New-Item -ItemType Directory -Path "docker-data/sqlserver/scripts" -Force | Out-Null
    
    # Check if docker is running
    try {
        docker info | Out-Null
    }
    catch {
        Write-Host "Error: Docker is not running! Please start Docker first." -ForegroundColor Red
        exit 1
    }
    
    # Check if our services are running
    $rabbitmqRunning = docker ps --filter "name=rabbitmq3" --format "{{.Names}}" 2>$null
    $sqlserverRunning = docker ps --filter "name=sql-server-db" --format "{{.Names}}" 2>$null
    $seqRunning = docker ps --filter "name=seq" --format "{{.Names}}" 2>$null
    
    if ([string]::IsNullOrEmpty($rabbitmqRunning) -or [string]::IsNullOrEmpty($sqlserverRunning) -or [string]::IsNullOrEmpty($seqRunning)) {
        Write-Host "Docker services not running. Starting them now..." -ForegroundColor Yellow
        docker-compose up -d
        
        # Wait a moment for services to start
        Write-Host "Waiting for Docker services to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        Write-Host "✓ Docker services started:" -ForegroundColor Green
        Write-Host "  • RabbitMQ: http://localhost:15672 (guest/guest)"
        Write-Host "  • SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)"
        Write-Host "  • Seq: http://localhost:5341"
    }
    else {
        Write-Host "✓ Docker services are already running" -ForegroundColor Green
    }
    
    return $true
}

# Function to stop all services
function Stop-AllServices {
    Write-Host "`nStopping all services..." -ForegroundColor Yellow
    
    foreach ($Process in $script:RunningProcesses) {
        if (!$Process.HasExited) {
            $Process.Kill()
            Write-Host "✓ Stopped process $($Process.Id)" -ForegroundColor Green
        }
    }
    
    # Ask if user wants to stop Docker services
    $response = Read-Host "`nDo you want to stop Docker services too? (y/N)"
    if ($response -match "^[Yy]$") {
        Write-Host "Stopping Docker services..." -ForegroundColor Yellow
        docker-compose down
        Write-Host "✓ Docker services stopped" -ForegroundColor Green
    }
}

# Register cleanup on exit
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-AllServices } | Out-Null

# Clear screen
Clear-Host

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   CashDesk V3 Development Starter      ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host

# Check if we're in the right directory
if (!(Test-Path "Directory.Build.targets")) {
    Write-Host "Error: This script must be run from the CashDesk V3 root directory!" -ForegroundColor Red
    exit 1
}

# Check and start Docker services first
Test-DockerCompose | Out-Null
Write-Host

# Service paths
$IdentityPath = "CashDesk.Identity/src/CashDesk.Identity.Server"
$AdminPath = "CashDesk.Admin/src/CashDesk.Admin.Server"
$PortalPath = "CashDesk.Portal/src/CashDesk.Portal.Server"
$WebPath = "CashDesk.Web/src/CashDesk.Web.Server"

# Display menu
Write-Host "Which project are you working on?"
Write-Host
Write-Host "1) CashDesk.Web (Port 5003)"
Write-Host "2) CashDesk.Admin (Port 5001)"
Write-Host "3) CashDesk.Portal (Port 5002)"
Write-Host "4) CashDesk.Identity (Port 5000)"
Write-Host "5) Start ALL services"
Write-Host "6) Exit"
Write-Host

$choice = Read-Host "Enter your choice (1-6)"

switch ($choice) {
    "1" {
        Write-Host "`nYou'll be working on CashDesk.Web" -ForegroundColor Green
        Write-Host "Starting other required services...`n" -ForegroundColor Yellow
        
        Start-Service -ServiceName "Identity" -ServicePath $IdentityPath -Port 5000
        Start-Service -ServiceName "Admin" -ServicePath $AdminPath -Port 5001
        Start-Service -ServiceName "Portal" -ServicePath $PortalPath -Port 5002
        
        Write-Host "`nAll supporting services started!" -ForegroundColor Green
        Write-Host "You can now run 'dotnet watch run' in $WebPath" -ForegroundColor Yellow
        Write-Host "Logs are available in the $LogsDir directory" -ForegroundColor Yellow
    }
    
    "2" {
        Write-Host "`nYou'll be working on CashDesk.Admin" -ForegroundColor Green
        Write-Host "Starting other required services...`n" -ForegroundColor Yellow
        
        Start-Service -ServiceName "Identity" -ServicePath $IdentityPath -Port 5000
        Start-Service -ServiceName "Web" -ServicePath $WebPath -Port 5003
        Start-Service -ServiceName "Portal" -ServicePath $PortalPath -Port 5002
        
        Write-Host "`nAll supporting services started!" -ForegroundColor Green
        Write-Host "You can now run 'dotnet watch run' in $AdminPath" -ForegroundColor Yellow
        Write-Host "Logs are available in the $LogsDir directory" -ForegroundColor Yellow
    }
    
    "3" {
        Write-Host "`nYou'll be working on CashDesk.Portal" -ForegroundColor Green
        Write-Host "Starting other required services...`n" -ForegroundColor Yellow
        
        Start-Service -ServiceName "Identity" -ServicePath $IdentityPath -Port 5000
        Start-Service -ServiceName "Web" -ServicePath $WebPath -Port 5003
        Start-Service -ServiceName "Admin" -ServicePath $AdminPath -Port 5001
        
        Write-Host "`nAll supporting services started!" -ForegroundColor Green
        Write-Host "You can now run 'dotnet watch run' in $PortalPath" -ForegroundColor Yellow
        Write-Host "Logs are available in the $LogsDir directory" -ForegroundColor Yellow
    }
    
    "4" {
        Write-Host "`nYou'll be working on CashDesk.Identity" -ForegroundColor Green
        Write-Host "Starting other required services...`n" -ForegroundColor Yellow
        
        Start-Service -ServiceName "Web" -ServicePath $WebPath -Port 5003
        Start-Service -ServiceName "Admin" -ServicePath $AdminPath -Port 5001
        Start-Service -ServiceName "Portal" -ServicePath $PortalPath -Port 5002
        
        Write-Host "`nAll supporting services started!" -ForegroundColor Green
        Write-Host "You can now run 'dotnet watch run' in $IdentityPath" -ForegroundColor Yellow
        Write-Host "Logs are available in the $LogsDir directory" -ForegroundColor Yellow
    }
    
    "5" {
        Write-Host "`nStarting ALL services" -ForegroundColor Green
        Write-Host "Starting all services...`n" -ForegroundColor Yellow
        
        Start-Service -ServiceName "Identity" -ServicePath $IdentityPath -Port 5000
        Start-Service -ServiceName "Admin" -ServicePath $AdminPath -Port 5001
        Start-Service -ServiceName "Portal" -ServicePath $PortalPath -Port 5002
        Start-Service -ServiceName "Web" -ServicePath $WebPath -Port 5003
        
        Write-Host "`nAll services started!" -ForegroundColor Green
        Write-Host "Logs are available in the $LogsDir directory" -ForegroundColor Yellow
    }
    
    "6" {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 0
    }
    
    default {
        Write-Host "Invalid choice!" -ForegroundColor Red
        exit 1
    }
}

# Show service URLs
Write-Host "`nService URLs:" -ForegroundColor Blue
Write-Host "• Identity: https://localhost:5000"
Write-Host "• Admin: https://localhost:5001"
Write-Host "• Portal: https://localhost:5002"
Write-Host "• Web: https://localhost:5003"

Write-Host "`nExternal Services:" -ForegroundColor Blue
Write-Host "• RabbitMQ Management: http://localhost:15672 (guest/guest)"
Write-Host "• SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)"
Write-Host "• Seq Logs: http://localhost:5341"

Write-Host "`nPress Ctrl+C to stop all services" -ForegroundColor Yellow

# Keep script running
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Stop-AllServices
}