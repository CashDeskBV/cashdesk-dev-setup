#!/bin/bash

# CashDesk V3 Development Environment Setup Script
# This script sets up a complete development environment for CashDesk V3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Configuration
REPOS_CONFIG="$SCRIPT_DIR/config/repositories.json"
WORKSPACE_DIR="$SCRIPT_DIR"

# Function to print header
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                CashDesk V3 Development Setup                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    # Check Git
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # Check .NET
    if ! command -v dotnet &> /dev/null; then
        missing_tools+=("dotnet")
    else
        # Check .NET version
        local dotnet_version=$(dotnet --version)
        if [[ ! "$dotnet_version" =~ ^7\. ]]; then
            echo -e "${YELLOW}Warning: .NET 7.0 is recommended, found version $dotnet_version${NC}"
        fi
    fi
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install the missing tools and run this script again.${NC}"
        echo
        echo -e "${BLUE}Installation commands:${NC}"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "git")
                    echo "  Git: https://git-scm.com/downloads"
                    ;;
                "docker")
                    echo "  Docker: https://docs.docker.com/get-docker/"
                    ;;
                "dotnet")
                    echo "  .NET 7.0: https://dotnet.microsoft.com/download/dotnet/7.0"
                    ;;
                "jq")
                    echo "  jq: sudo apt-get install jq  # Ubuntu/Debian"
                    echo "      brew install jq          # macOS"
                    ;;
            esac
        done
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites are installed${NC}"
}

# Function to clone repositories
clone_repositories() {
    echo -e "\n${BLUE}Cloning repositories...${NC}"
    
    if [ ! -f "$REPOS_CONFIG" ]; then
        echo -e "${RED}Error: repositories.json not found!${NC}"
        exit 1
    fi
    
    local repos=$(jq -r '.repositories[] | "\(.name)|\(.url)|\(.branch)|\(.required)"' "$REPOS_CONFIG")
    local total_repos=$(echo "$repos" | wc -l)
    local current=0
    
    while IFS='|' read -r name url branch required; do
        current=$((current + 1))
        echo -e "\n${CYAN}[$current/$total_repos] Cloning $name...${NC}"
        
        if [ -d "$name" ]; then
            echo -e "${YELLOW}  Directory $name already exists, skipping clone${NC}"
            echo -e "${BLUE}  Pulling latest changes...${NC}"
            cd "$name"
            git pull origin "$branch" || echo -e "${YELLOW}  Warning: Could not pull latest changes${NC}"
            cd ..
        else
            if git clone -b "$branch" "$url" "$name"; then
                echo -e "${GREEN}  ✓ Successfully cloned $name${NC}"
            else
                if [ "$required" = "true" ]; then
                    echo -e "${RED}  ✗ Failed to clone required repository $name${NC}"
                    exit 1
                else
                    echo -e "${YELLOW}  ⚠ Failed to clone optional repository $name${NC}"
                fi
            fi
        fi
    done <<< "$repos"
    
    echo -e "\n${GREEN}Repository cloning completed!${NC}"
}

# Function to setup Docker environment
setup_docker() {
    echo -e "\n${BLUE}Setting up Docker environment...${NC}"
    
    # Create docker-data directories
    mkdir -p docker-data/sqlserver/{backup,scripts}
    echo -e "${GREEN}✓ Created docker-data directories${NC}"
    
    # Copy docker-compose.yml to root
    if [ -f "config/docker-compose.yml" ]; then
        cp config/docker-compose.yml docker-compose.yml
        echo -e "${GREEN}✓ Docker Compose configuration ready${NC}"
    fi
    
    # Check if Docker is running
    if docker info > /dev/null 2>&1; then
        echo -e "${BLUE}Starting Docker services...${NC}"
        docker-compose up -d
        
        # Wait for services to be ready
        echo -e "${YELLOW}Waiting for services to start...${NC}"
        sleep 10
        
        echo -e "${GREEN}✓ Docker services started${NC}"
        echo -e "${BLUE}  • RabbitMQ Management: http://localhost:15672 (guest/guest)${NC}"
        echo -e "${BLUE}  • SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)${NC}"
        echo -e "${BLUE}  • Seq Logs: http://localhost:5341${NC}"
    else
        echo -e "${YELLOW}Docker is not running. Please start Docker and run 'docker-compose up -d' manually.${NC}"
    fi
}

# Function to copy local settings templates
copy_local_settings() {
    echo -e "\n${BLUE}Setting up local configuration files...${NC}"
    
    local settings_config="$SCRIPT_DIR/config/local-settings/settings-mapping.json"
    
    if [ ! -f "$settings_config" ]; then
        echo -e "${YELLOW}No local settings configuration found, skipping...${NC}"
        return 0
    fi
    
    local mappings=$(jq -r '.settingsMapping[] | "\(.templateFile)|\(.targetPath)|\(.description)"' "$settings_config")
    
    while IFS='|' read -r template_file target_path description; do
        local template_path="$SCRIPT_DIR/config/local-settings/$template_file"
        
        if [ ! -f "$template_path" ]; then
            echo -e "${YELLOW}  ⚠ Template $template_file not found, skipping...${NC}"
            continue
        fi
        
        # Check if target file already exists
        if [ -f "$target_path" ]; then
            echo -e "${YELLOW}  ⚠ $target_path already exists, skipping to preserve local changes${NC}"
            continue
        fi
        
        # Check if target directory exists (repository might not be cloned)
        local target_dir=$(dirname "$target_path")
        if [ ! -d "$target_dir" ]; then
            echo -e "${YELLOW}  ⚠ Target directory $target_dir not found, skipping $description${NC}"
            continue
        fi
        
        # Copy template to target location
        if cp "$template_path" "$target_path"; then
            echo -e "${GREEN}  ✓ $description${NC}"
        else
            echo -e "${RED}  ✗ Failed to copy $description${NC}"
        fi
    done <<< "$mappings"
    
    echo -e "${GREEN}✓ Local settings configuration completed${NC}"
    echo -e "${BLUE}  Note: Existing appsettings.local.json files were preserved${NC}"
}

# Function to restore NuGet packages
restore_packages() {
    echo -e "\n${BLUE}Restoring NuGet packages...${NC}"
    
    # Copy nuget.config if it exists
    if [ -f "config/nuget.config" ]; then
        cp config/nuget.config nuget.config
        echo -e "${GREEN}✓ NuGet configuration copied${NC}"
    fi
    
    local repos=$(jq -r '.repositories[] | select(.required == true) | .name' "$REPOS_CONFIG")
    
    while read -r repo_name; do
        if [ -d "$repo_name" ]; then
            echo -e "${CYAN}Restoring packages for $repo_name...${NC}"
            cd "$repo_name"
            if dotnet restore > /dev/null 2>&1; then
                echo -e "${GREEN}  ✓ $repo_name packages restored${NC}"
            else
                echo -e "${YELLOW}  ⚠ Could not restore packages for $repo_name${NC}"
            fi
            cd ..
        fi
    done <<< "$repos"
}

# Function to copy development scripts
setup_scripts() {
    echo -e "\n${BLUE}Setting up development scripts...${NC}"
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    echo -e "${GREEN}✓ Development scripts ready${NC}"
}

# Function to create CLAUDE.md
create_claude_md() {
    echo -e "\n${BLUE}Creating CLAUDE.md for AI assistance...${NC}"
    
    cat > CLAUDE.md << 'EOF'
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
EOF

    echo -e "${GREEN}✓ CLAUDE.md created${NC}"
}

# Function to display completion message
display_completion() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete!                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}🚀 Your CashDesk V3 development environment is ready!${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Start developing: ${CYAN}./scripts/start-dev.sh${NC}"
    echo -e "  2. Choose which service you want to work on"
    echo -e "  3. Use ${CYAN}dotnet watch run${NC} in your chosen service directory"
    echo
    echo -e "${BLUE}Available services:${NC}"
    echo -e "  • Identity: https://localhost:5000"
    echo -e "  • Admin: https://localhost:5001"
    echo -e "  • Portal: https://localhost:5002" 
    echo -e "  • Web: https://localhost:5003"
    echo
    echo -e "${BLUE}Infrastructure:${NC}"
    echo -e "  • RabbitMQ: http://localhost:15672 (guest/guest)"
    echo -e "  • SQL Server: localhost:1433"
    echo -e "  • Seq Logs: http://localhost:5341"
    echo
    echo -e "${YELLOW}Test credentials:${NC}"
    echo -e "  • Demo: demo@cashdesk.nl / Demo123!"
    echo -e "  • Admin: admin@cashdesk.nl / Admin123!"
    echo
}

# Main execution
main() {
    print_header
    
    echo -e "${BLUE}This script will set up a complete CashDesk V3 development environment.${NC}"
    echo -e "${BLUE}It will clone repositories, set up Docker services, and prepare development tools.${NC}"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled.${NC}"
        exit 0
    fi
    
    check_prerequisites
    clone_repositories
    setup_docker
    copy_local_settings
    restore_packages
    setup_scripts
    create_claude_md
    display_completion
}

# Run main function
main "$@"