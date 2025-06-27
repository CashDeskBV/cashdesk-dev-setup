# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

This is a CashDesk V3 development environment with multiple microservices. Use the following commands:

### Quick Start
- `./scripts/start-dev.sh` - Start development environment with service selection
- `./scripts/update-all.sh` - Pull latest changes from all repositories

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
1. Choose which service to work on using start-dev.sh
2. Other required services start automatically in background
3. Use `dotnet watch run` in your chosen service directory
4. Logs are saved to logs/ directory with timestamps

### Repository Structure
Each service is in its own directory with standard .NET structure:
- src/: Source code
- Tests/: Unit tests
- docker-compose.yml: Infrastructure services (root level)

See individual service CLAUDE.md files for service-specific guidance.
