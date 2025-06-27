#!/bin/bash

# Update all repositories script for CashDesk V3
# This script pulls the latest changes from all repositories

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$SCRIPT_DIR/../config/repositories.json"

# Function to print header
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        CashDesk V3 Update All          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
}

# Function to update a repository
update_repo() {
    local repo_name=$1
    local branch=$2
    
    if [ ! -d "$repo_name" ]; then
        echo -e "${YELLOW}⚠ Repository $repo_name not found, skipping${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Updating $repo_name...${NC}"
    
    cd "$repo_name"
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}  ⚠ Repository has uncommitted changes${NC}"
        echo -e "${YELLOW}    Stashing changes before update...${NC}"
        git stash push -m "Auto-stash before update $(date)"
        local stashed=true
    else
        local stashed=false
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Switch to target branch if different
    if [ "$current_branch" != "$branch" ]; then
        echo -e "${BLUE}  Switching from $current_branch to $branch...${NC}"
        git checkout "$branch"
    fi
    
    # Pull latest changes
    if git pull origin "$branch"; then
        echo -e "${GREEN}  ✓ Successfully updated $repo_name${NC}"
        
        # Restore stashed changes if any
        if [ "$stashed" = true ]; then
            echo -e "${BLUE}  Restoring stashed changes...${NC}"
            git stash pop
        fi
        
        local success=true
    else
        echo -e "${RED}  ✗ Failed to update $repo_name${NC}"
        local success=false
    fi
    
    cd ..
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to restore packages for updated repositories
restore_packages() {
    echo -e "\n${BLUE}Restoring NuGet packages for updated repositories...${NC}"
    
    local repos=$(jq -r '.repositories[] | select(.required == true) | .name' "$CONFIG_FILE")
    
    while read -r repo_name; do
        if [ -d "$repo_name" ]; then
            echo -e "${CYAN}Restoring packages for $repo_name...${NC}"
            cd "$repo_name"
            if dotnet restore > /dev/null 2>&1; then
                echo -e "${GREEN}  ✓ Packages restored for $repo_name${NC}"
            else
                echo -e "${YELLOW}  ⚠ Could not restore packages for $repo_name${NC}"
            fi
            cd ..
        fi
    done <<< "$repos"
}

# Function to check for Docker updates
check_docker_updates() {
    echo -e "\n${BLUE}Checking for Docker service updates...${NC}"
    
    if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
        echo -e "${CYAN}Pulling latest Docker images...${NC}"
        
        # Update images used in docker-compose
        docker pull mcr.microsoft.com/mssql/server:2019-latest
        docker pull rabbitmq:3-management  
        docker pull datalust/seq:latest
        
        echo -e "${GREEN}✓ Docker images updated${NC}"
        echo -e "${YELLOW}Run 'docker-compose down && docker-compose up -d' to use updated images${NC}"
    else
        echo -e "${YELLOW}Docker not available, skipping image updates${NC}"
    fi
}

# Function to display update summary
display_summary() {
    local successful=$1
    local failed=$2
    local total=$((successful + failed))
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Update Summary            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}Total repositories: $total${NC}"
    echo -e "${GREEN}Successfully updated: $successful${NC}"
    
    if [ $failed -gt 0 ]; then
        echo -e "${RED}Failed to update: $failed${NC}"
        echo -e "\n${YELLOW}Please check the failed repositories manually.${NC}"
    else
        echo -e "\n${GREEN}🎉 All repositories are up to date!${NC}"
    fi
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  • Run ${CYAN}./scripts/start-dev.sh${NC} to start development"
    echo -e "  • Check individual repositories for any breaking changes"
    echo -e "  • Review commit logs for important updates"
}

# Main execution
main() {
    print_header
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found!${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}This will update all CashDesk V3 repositories with the latest changes.${NC}"
    echo -e "${YELLOW}Make sure you have committed or stashed any local changes.${NC}"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Update cancelled.${NC}"
        exit 0
    fi
    
    local successful=0
    local failed=0
    
    # Get repository information
    local repos=$(jq -r '.repositories[] | "\(.name)|\(.branch)"' "$CONFIG_FILE")
    local total_repos=$(echo "$repos" | wc -l)
    
    echo -e "\n${BLUE}Updating $total_repos repositories...${NC}"
    echo
    
    # Update each repository
    while IFS='|' read -r name branch; do
        if update_repo "$name" "$branch"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
        echo
    done <<< "$repos"
    
    # Restore packages for .NET projects
    restore_packages
    
    # Check for Docker updates
    check_docker_updates
    
    # Display summary
    display_summary $successful $failed
    
    # Exit with error code if any updates failed
    if [ $failed -gt 0 ]; then
        exit 1
    fi
}

# Run main function
main "$@"