#!/bin/bash

# Repository cloning script for CashDesk V3
# This script can be used to clone or update individual repositories

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$SCRIPT_DIR/../config/repositories.json"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS] [REPOSITORY_NAME]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --list          List all available repositories"
    echo "  -a, --all           Clone/update all repositories"
    echo "  -r, --required      Clone/update only required repositories"
    echo "  -u, --update        Update existing repositories (git pull)"
    echo
    echo "Examples:"
    echo "  $0 --list                    # List all repositories"
    echo "  $0 --all                     # Clone all repositories"
    echo "  $0 --required                # Clone only required repositories"
    echo "  $0 CashDesk.Web              # Clone specific repository"
    echo "  $0 --update CashDesk.Web     # Update specific repository"
}

# Function to list repositories
list_repos() {
    echo -e "${BLUE}Available repositories:${NC}"
    echo
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found!${NC}"
        exit 1
    fi
    
    jq -r '.repositories[] | "\(.name) - \(.description) (\(if .required then "Required" else "Optional" end))"' "$CONFIG_FILE" | while read -r line; do
        if [[ $line == *"Required"* ]]; then
            echo -e "  ${GREEN}$line${NC}"
        else
            echo -e "  ${YELLOW}$line${NC}"
        fi
    done
}

# Function to clone or update a repository
clone_repo() {
    local name=$1
    local url=$2
    local branch=$3
    local update_only=$4
    
    if [ -d "$name" ]; then
        if [ "$update_only" = "true" ]; then
            echo -e "${BLUE}Updating $name...${NC}"
            cd "$name"
            if git pull origin "$branch"; then
                echo -e "${GREEN}✓ Updated $name${NC}"
            else
                echo -e "${RED}✗ Failed to update $name${NC}"
                return 1
            fi
            cd ..
        else
            echo -e "${YELLOW}Repository $name already exists${NC}"
            read -p "Update it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd "$name"
                git pull origin "$branch"
                cd ..
            fi
        fi
    else
        if [ "$update_only" = "true" ]; then
            echo -e "${YELLOW}Repository $name does not exist, skipping update${NC}"
            return 0
        fi
        
        echo -e "${BLUE}Cloning $name...${NC}"
        if git clone -b "$branch" "$url" "$name"; then
            echo -e "${GREEN}✓ Successfully cloned $name${NC}"
        else
            echo -e "${RED}✗ Failed to clone $name${NC}"
            return 1
        fi
    fi
}

# Function to process repositories
process_repos() {
    local filter=$1
    local update_only=$2
    local specific_repo=$3
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found!${NC}"
        exit 1
    fi
    
    local query
    case $filter in
        "all")
            query='.repositories[]'
            ;;
        "required")
            query='.repositories[] | select(.required == true)'
            ;;
        "specific")
            query=".repositories[] | select(.name == \"$specific_repo\")"
            ;;
    esac
    
    local repos=$(jq -r "$query | \"\(.name)|\(.url)|\(.branch)\"" "$CONFIG_FILE")
    
    if [ -z "$repos" ]; then
        if [ "$filter" = "specific" ]; then
            echo -e "${RED}Repository '$specific_repo' not found in configuration${NC}"
            exit 1
        else
            echo -e "${YELLOW}No repositories found matching filter '$filter'${NC}"
            exit 0
        fi
    fi
    
    while IFS='|' read -r name url branch; do
        clone_repo "$name" "$url" "$branch" "$update_only"
    done <<< "$repos"
}

# Main execution
main() {
    local action=""
    local update_only=false
    local specific_repo=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_repos
                exit 0
                ;;
            -a|--all)
                action="all"
                shift
                ;;
            -r|--required)
                action="required"
                shift
                ;;
            -u|--update)
                update_only=true
                shift
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                exit 1
                ;;
            *)
                specific_repo="$1"
                action="specific"
                shift
                ;;
        esac
    done
    
    # Default action if none specified
    if [ -z "$action" ]; then
        echo -e "${YELLOW}No action specified. Use --help for usage information.${NC}"
        usage
        exit 1
    fi
    
    # Process repositories based on action
    process_repos "$action" "$update_only" "$specific_repo"
    
    echo -e "\n${GREEN}Repository operations completed!${NC}"
}

# Run main function
main "$@"