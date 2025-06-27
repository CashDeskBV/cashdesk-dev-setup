# CashDesk V3 Troubleshooting Guide

This guide covers common issues and their solutions when working with CashDesk V3.

## Setup Issues

### "Prerequisites missing" during setup

**Problem**: Setup script reports missing tools (git, docker, dotnet, jq)

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install git docker.io dotnet-sdk-7.0 jq

# macOS with Homebrew
brew install git docker dotnet jq

# Windows
# Download installers from official websites
# - Git: https://git-scm.com/downloads
# - Docker: https://docs.docker.com/desktop/windows/
# - .NET 7.0: https://dotnet.microsoft.com/download/dotnet/7.0
```

### "Repository clone failed"

**Problem**: Cannot clone repositories due to access issues

**Solutions**:
1. **Check Git credentials**: Ensure you have access to the repositories
2. **Use SSH instead of HTTPS**: Configure SSH keys for GitHub
3. **Update repository URLs**: Check if repository URLs in `config/repositories.json` are correct
4. **Network issues**: Check firewall/proxy settings

```bash
# Test repository access
git clone <repository-url> test-clone
rm -rf test-clone
```

## Docker Issues

### "Docker is not running"

**Problem**: Docker services won't start

**Solutions**:
1. **Start Docker Desktop** (Windows/macOS)
2. **Start Docker service** (Linux):
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```
3. **Check Docker installation**:
   ```bash
   docker --version
   docker info
   ```

### "Port already in use"

**Problem**: Cannot start Docker services due to port conflicts

**Solution**:
```bash
# Check what's using the ports
sudo netstat -tulpn | grep :1433   # SQL Server
sudo netstat -tulpn | grep :5672   # RabbitMQ
sudo netstat -tulpn | grep :5341   # Seq

# Stop conflicting services or change ports in docker-compose.yml
```

### "SQL Server container won't start"

**Problem**: SQL Server container fails to start

**Solutions**:
1. **Check password requirements**: Password must meet complexity requirements
2. **Check available memory**: SQL Server needs at least 2GB RAM
3. **Accept EULA**: Ensure `ACCEPT_EULA: "Y"` is set
4. **Check logs**:
   ```bash
   docker logs sql-server-db
   ```

## .NET Service Issues

### "Service won't start - port in use"

**Problem**: Cannot start service because port is already in use

**Solutions**:
1. **Check running processes**:
   ```bash
   sudo netstat -tulpn | grep :5000   # Identity
   sudo netstat -tulpn | grep :5001   # Admin
   sudo netstat -tulpn | grep :5002   # Portal
   sudo netstat -tulpn | grep :5003   # Web
   ```
2. **Stop conflicting processes**:
   ```bash
   # Kill process by port
   sudo fuser -k 5000/tcp
   
   # Or find and kill by PID
   lsof -ti:5000 | xargs kill
   ```
3. **Use different ports**: Modify `launchSettings.json` in each service

### "Package restore fails"

**Problem**: `dotnet restore` fails with package not found

**Solutions**:
1. **Check NuGet configuration**:
   ```bash
   dotnet nuget list source
   ```
2. **Clear NuGet cache**:
   ```bash
   dotnet nuget locals all --clear
   ```
3. **Update package sources**: Check `nuget.config` file
4. **Check network/proxy**: Ensure access to NuGet.org and private feeds

### "Database connection fails"

**Problem**: Cannot connect to SQL Server database

**Solutions**:
1. **Check SQL Server container**:
   ```bash
   docker ps | grep sql-server-db
   docker logs sql-server-db
   ```
2. **Test connection**:
   ```bash
   # Using sqlcmd (if installed)
   sqlcmd -S localhost,1433 -U sa -P '<YourStrong@Passw0rd>'
   
   # Using Docker
   docker exec -it sql-server-db /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '<YourStrong@Passw0rd>'
   ```
3. **Check connection string**: Verify in `appsettings.json`
4. **Run migrations**:
   ```bash
   cd CashDesk.Web/src/CashDesk.Web.Persistence
   dotnet ef database update
   ```

### "Service dependencies not met"

**Problem**: Service fails because dependent services aren't running

**Solution**:
Use the start-dev script to ensure all dependencies are running:
```bash
./scripts/start-dev.sh
```

## Build and Compilation Issues

### "Build fails with missing references"

**Problem**: Build fails due to missing project references or packages

**Solutions**:
1. **Restore packages**:
   ```bash
   dotnet restore
   ```
2. **Clean and rebuild**:
   ```bash
   dotnet clean
   dotnet build
   ```
3. **Check project references**: Ensure all project-to-project references are correct
4. **Update package versions**: Check `Directory.Build.targets` for version conflicts

### "Hot reload not working"

**Problem**: `dotnet watch run` doesn't detect file changes

**Solutions**:
1. **Check file system events**: Some file systems don't support file watching
2. **Increase file watcher limits** (Linux):
   ```bash
   echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```
3. **Use polling mode**:
   ```bash
   dotnet watch run --poll
   ```

## Runtime Issues

### "Service starts but returns 500 errors"

**Problem**: Service starts but API calls return internal server errors

**Solutions**:
1. **Check service logs**: Look in `logs/` directory or use `dotnet watch run` output
2. **Check Seq dashboard**: http://localhost:5341 for detailed error logs
3. **Verify database**: Ensure database is created and migrations are applied
4. **Check configuration**: Verify `appsettings.json` settings

### "Authentication/Authorization issues"

**Problem**: Cannot authenticate or access protected endpoints

**Solutions**:
1. **Check Identity service**: Ensure CashDesk.Identity is running on port 5000
2. **Test login**:
   - Demo user: demo@cashdesk.nl / Demo123!
   - Admin user: admin@cashdesk.nl / Admin123!
3. **Check JWT configuration**: Verify token issuer/audience settings
4. **Clear browser data**: Clear cookies and local storage

### "Real-time features not working"

**Problem**: SignalR connections fail or don't receive updates

**Solutions**:
1. **Check SignalR hub configuration**: Verify hub registration and routing
2. **Check CORS settings**: Ensure client domain is allowed
3. **Test WebSocket support**: Some proxies block WebSocket connections
4. **Check network**: Firewalls may block SignalR connections

## Performance Issues

### "Slow database queries"

**Problem**: Database operations are slow

**Solutions**:
1. **Check indexes**: Ensure proper indexes on frequently queried columns
2. **Analyze query plans**: Use SQL Server Management Studio or Azure Data Studio
3. **Check database size**: Large databases may need maintenance
4. **Monitor with Seq**: Check query execution times in logs

### "High memory usage"

**Problem**: Services consume too much memory

**Solutions**:
1. **Check for memory leaks**: Monitor memory usage over time
2. **Optimize EF Core queries**: Use projections, avoid loading unnecessary data
3. **Configure garbage collection**: Adjust GC settings if needed
4. **Profile with tools**: Use dotMemory, PerfView, or similar tools

## Development Environment Issues

### "Scripts don't work on Windows"

**Problem**: Bash scripts fail on Windows

**Solution**:
Use PowerShell versions of scripts:
```powershell
.\setup-dev-environment.ps1
.\scripts\start-dev.ps1
```

### "File permission issues" (Linux/macOS)

**Problem**: Cannot execute scripts

**Solution**:
```bash
chmod +x *.sh
chmod +x scripts/*.sh
```

### "Git issues with line endings"

**Problem**: Git shows modified files due to line ending differences

**Solution**:
```bash
# Configure Git to handle line endings automatically
git config --global core.autocrlf true  # Windows
git config --global core.autocrlf input # Linux/macOS
```

## Getting Help

### Log Analysis
1. **Service logs**: Check `logs/` directory for timestamped log files
2. **Seq dashboard**: http://localhost:5341 for centralized logging
3. **Docker logs**: `docker logs <container-name>`
4. **Console output**: When using `dotnet watch run`

### Useful Commands
```bash
# Check all running services
docker ps
dotnet --list-runtimes
dotnet --list-sdks

# Network troubleshooting
netstat -tulpn | grep LISTEN
curl -I http://localhost:5000/health

# Process management
ps aux | grep dotnet
kill $(pgrep -f "dotnet run")
```

### When to Ask for Help
- Create an issue in the appropriate repository
- Include relevant logs and error messages
- Describe steps to reproduce the problem
- Mention your operating system and .NET version
- Include configuration details (without sensitive information)