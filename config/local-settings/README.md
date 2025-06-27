# Local Settings Templates

This directory contains template files for `appsettings.local.json` and other local configuration files that developers need but should not be committed to git.

## How It Works

1. **Templates**: Files here serve as templates for local development settings
2. **Auto-copy**: The setup script automatically copies these to the correct locations
3. **Git-ignored**: The actual `appsettings.local.json` files are in `.gitignore`
4. **Customizable**: Developers can modify their local files without affecting others

## File Naming Convention

Template files should be named with the pattern:
```
{ProjectName}.{SettingsType}.template.json
```

Examples:
- `CashDesk.Web.appsettings.local.template.json` → `CashDesk.Web/src/CashDesk.Web.Server/appsettings.local.json`
- `CashDesk.Admin.appsettings.local.template.json` → `CashDesk.Admin/src/CashDesk.Admin.Server/appsettings.local.json`
- `CashDesk.Identity.appsettings.local.template.json` → `CashDesk.Identity/src/CashDesk.Identity.Server/appsettings.local.json`

## Template Structure

Each template should contain:
- **Development connection strings** (pointing to localhost Docker services)
- **Default logging configuration** 
- **Local service endpoints**
- **Development-specific feature flags**
- **Test credentials and keys** (non-production)

## Git Configuration

The repositories are already configured with proper `.gitignore` entries to exclude:
- `appsettings.local.json`
- `appsettings.Local.json` 
- Other local development files

This ensures that local settings files are never committed to git.

## Security Note

⚠️ **Important**: These templates should only contain development/localhost settings. Never include:
- Production connection strings
- Real API keys or secrets
- Production service endpoints
- Sensitive credentials

For production deployments, use proper secret management systems.