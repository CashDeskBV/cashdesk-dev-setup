# CashDesk V3 Development Guide

This guide covers the essential information for developing with CashDesk V3.

## Getting Started

### 1. Environment Setup
After running the setup script, your environment will have:
- All required repositories cloned
- Docker services running (SQL Server, RabbitMQ, Seq)
- Local development settings (`appsettings.local.json`) automatically configured
- NuGet packages restored
- Development scripts ready

**Git Repository Isolation**: Each cloned CashDesk repository maintains its own Git history. The meta repository (cashdesk-dev-setup) ignores all cloned repositories, so:
- You can commit changes in individual service repositories normally
- The meta repository only tracks setup scripts and configuration
- No conflicts between meta repository and service repositories

### 2. Daily Development Workflow

**Start Development Session:**
```bash
./scripts/start-dev.sh
```
- Choose which service you're working on
- Other required services start automatically in background
- Infrastructure services (Docker) are checked and started if needed

**Work on Your Service:**
```bash
cd CashDesk.Web/src/CashDesk.Web.Server
dotnet watch run
```

**Monitor Logs:**
- Service logs: `logs/` directory with timestamped files
- Seq dashboard: http://localhost:5341
- Individual service console output when using `dotnet watch run`

### 3. Service Dependencies

When working on one service, these others need to be running:

- **CashDesk.Web**: Requires Identity, Admin, Portal + Worker
- **CashDesk.Admin**: Requires Identity, Web, Portal + Worker
- **CashDesk.Portal**: Requires Identity, Web, Admin
- **CashDesk.Identity**: Requires Web, Admin, Portal

The start-dev script handles this automatically.

## Architecture Overview

### Service Structure
Each service follows Clean Architecture:
```
CashDesk.ServiceName/
├── src/
│   ├── CashDesk.ServiceName.Domain/          # Business logic, entities
│   ├── CashDesk.ServiceName.Application/     # Use cases, handlers
│   ├── CashDesk.ServiceName.Persistence/     # Data access, EF Core
│   ├── CashDesk.ServiceName.Server/          # API controllers, startup
│   ├── CashDesk.ServiceName.Client/          # Blazor WebAssembly
│   ├── CashDesk.ServiceName.Components/      # Shared components
│   └── CashDesk.ServiceName.Worker/          # Background jobs (if applicable)
├── Tests/                                    # Unit and integration tests
└── docker-compose.yml                       # Service-specific Docker setup
```

### Technology Stack
- **.NET 7.0** - Runtime and framework
- **ASP.NET Core** - Web API backend
- **Blazor WebAssembly** - Frontend SPA
- **Entity Framework Core** - ORM and database access
- **MediatR** - CQRS pattern implementation
- **SignalR** - Real-time communication
- **Quartz.NET** - Background job scheduling
- **MudBlazor** - UI component library
- **AutoMapper** - Object-to-object mapping
- **Serilog** - Structured logging

### External Dependencies
- **SQL Server** - Primary database
- **RabbitMQ** - Message broker for inter-service communication
- **Seq** - Centralized logging and monitoring

## Development Commands

### Building and Running
```bash
# Build entire solution
dotnet build

# Run with hot reload (for active development)
dotnet watch run

# Run without hot reload (for background services)
dotnet run

# Run tests
dotnet test

# Restore packages
dotnet restore
```

### Database Operations
```bash
# Add migration (run from persistence project)
dotnet ef migrations add MigrationName

# Update database
dotnet ef database update

# Generate SQL script
dotnet ef migrations script
```

### Docker Operations
```bash
# Start all infrastructure services
docker-compose up -d

# Stop all services
docker-compose down

# View service logs
docker-compose logs -f [service-name]

# Rebuild and restart services
docker-compose down && docker-compose up -d --build
```

## Common Tasks

### Adding a New Feature
1. **Domain Layer**: Add entities, value objects, domain services
2. **Application Layer**: Create commands/queries, handlers, DTOs
3. **Persistence Layer**: Add EF Core configurations, migrations
4. **Server Layer**: Add API controllers, configure endpoints
5. **Client Layer**: Add Blazor components, pages, services
6. **Tests**: Add unit tests for business logic

### Working with Multiple Services
1. Use the start-dev script to manage dependencies
2. Keep services loosely coupled
3. Use message bus (RabbitMQ) for async communication
4. Use HTTP APIs for synchronous communication
5. Maintain service-specific databases

### Debugging Issues
1. **Check Service Logs**: Look in `logs/` directory for timestamped logs
2. **Use Seq Dashboard**: http://localhost:5341 for centralized logging
3. **Check Docker Services**: Ensure RabbitMQ, SQL Server, Seq are running
4. **Verify Service Dependencies**: Make sure required services are running
5. **Check Database Connections**: Verify connection strings and database state

## Best Practices

### Code Organization
- Follow Clean Architecture principles
- Keep business logic in Domain layer
- Use CQRS pattern for complex operations
- Maintain clear separation of concerns

### API Design
- Follow RESTful conventions
- Use consistent HTTP status codes
- Version APIs when making breaking changes
- Document APIs with OpenAPI/Swagger

### Database
- Use migrations for schema changes
- Follow naming conventions
- Index frequently queried columns
- Use appropriate relationships and constraints

### Testing
- Write unit tests for business logic
- Use integration tests for API endpoints
- Mock external dependencies
- Maintain good test coverage

### Security
- Validate all inputs
- Use authentication and authorization
- Protect sensitive configuration
- Follow OWASP guidelines

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

## Contributing

1. Create feature branch from main
2. Follow coding standards and patterns
3. Write tests for new functionality
4. Update documentation as needed
5. Submit pull request for review