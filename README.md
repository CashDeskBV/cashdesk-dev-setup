# CashDesk V3 Development Environment Setup

This repository contains everything needed to set up a complete CashDesk V3 development environment in minutes.

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone <this-repo-url> cashdesk-dev
   cd cashdesk-dev
   ```

2. **Run the setup script:**
   ```bash
   # Linux/macOS
   ./setup-dev-environment.sh

   # Windows
   .\setup-dev-environment.ps1
   ```

3. **Start developing:**
   ```bash
   ./scripts/start-dev.sh
   ```

## What Gets Set Up

### Repositories Cloned
- **CashDesk.Application** - Shared packages and core framework
- **CashDesk.Identity** - Authentication and authorization service
- **CashDesk.Web** - Main POS application
- **CashDesk.Admin** - Administrative interface
- **CashDesk.Portal** - Customer portal
- **CashDesk.Payments** - Payment processing service
- **CashDesk.AI** - AI-related components
- **CashDesk.Connect** - Desktop connection utility
- **CashDesk.ExternalMenuProvider** - External menu integration
- **CashDesk.Harmony** - Harmony integration service

### Infrastructure Services
- **Docker Compose** with SQL Server, RabbitMQ, and Seq
- **Persistent storage** for databases and logs
- **Shared folders** for SQL backups and scripts

### Local Development Configuration
- **Automatic local settings**: `appsettings.local.json` files distributed automatically
- **Development defaults**: Pre-configured connection strings and service endpoints
- **Git-safe**: Local settings are properly ignored by git

### Development Tools
- **Start scripts** for running services based on what you're working on
- **Docker management** with automatic service startup
- **Logging setup** with timestamped log files
- **Service dependency management**

## Prerequisites

- **Git** - For cloning repositories
- **Docker** - For infrastructure services
- **.NET 7.0 SDK** - For building and running applications
- **Node.js** (if needed for any frontend tooling)

## Repository Structure

```
cashdesk-dev/
├── setup-dev-environment.sh       # Main setup script (Linux/macOS)
├── setup-dev-environment.ps1      # Main setup script (Windows)
├── config/
│   ├── repositories.json          # Repository URLs and configuration
│   ├── docker-compose.yml         # Infrastructure services
│   └── nuget.config               # NuGet package sources
├── scripts/
│   ├── start-dev.sh               # Development environment starter
│   ├── start-dev.ps1              # Development environment starter (Windows)
│   ├── clone-repos.sh             # Repository cloning script
│   ├── clone-repos.ps1            # Repository cloning script (Windows)
│   └── update-all.sh              # Update all repositories
├── docker-data/
│   └── sqlserver/
│       ├── backup/                # SQL Server backups
│       └── scripts/               # SQL Server scripts
├── docs/
│   ├── development-guide.md       # Development guidelines
│   ├── troubleshooting.md         # Common issues and solutions
│   └── architecture-overview.md   # System architecture
├── .gitignore                     # Ignores cloned repositories
└── README.md                      # This file

# After setup, cloned repositories appear here:
├── CashDesk.Application/          # (git-ignored)
├── CashDesk.Web/                  # (git-ignored)
├── CashDesk.Admin/                # (git-ignored)
├── CashDesk.Portal/               # (git-ignored)
├── CashDesk.Identity/             # (git-ignored)
└── ... other services            # (git-ignored)
```

**Important**: The `.gitignore` file ensures that cloned CashDesk repositories maintain their own Git history and are not tracked by the meta repository.

## Usage

### Initial Setup
Run the setup script once to clone all repositories and set up the environment:
```bash
./setup-dev-environment.sh
```

### Daily Development
Use the start script to begin development on a specific service:
```bash
./scripts/start-dev.sh
```

### Update All Repositories
Pull latest changes from all repositories:
```bash
./scripts/update-all.sh
```

### Working on Specific Services
The start script will ask which service you're working on and automatically start all dependencies.

## Service URLs

After running the start script, these services will be available:

**Application Services:**
- Identity: https://localhost:5000
- Admin: https://localhost:5001  
- Portal: https://localhost:5002
- Web: https://localhost:5003
- Payments: https://localhost:5004

**Infrastructure Services:**
- RabbitMQ Management: http://localhost:15672 (guest/guest)
- SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)
- Seq Logs: http://localhost:5341

## Test Credentials

- **Demo User**: demo@cashdesk.nl / Demo123!
- **Admin User**: admin@cashdesk.nl / Admin123!

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

## Repository Setup

This `cashdesk-dev-setup` directory should be converted into its own Git repository for distribution:

```bash
# Extract this setup into its own repository
cd cashdesk-dev-setup
git init
git add .
git commit -m "Initial CashDesk V3 development environment setup"
git remote add origin <setup-repo-url>
git push -u origin main
```

Then developers can clone the setup repository directly:
```bash
git clone <setup-repo-url> cashdesk-dev
cd cashdesk-dev
./setup-dev-environment.sh
```

## Contributing

1. Make changes to the setup scripts or configuration
2. Test with a fresh environment setup
3. Update documentation as needed
4. Submit pull request

## Support

For issues with this setup repository, create an issue in this repository.
For application-specific issues, create issues in the respective application repositories.