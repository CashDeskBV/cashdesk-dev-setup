#!/bin/bash

# Copy Local Settings Script for CashDesk V3
# This script copies local settings templates to their target locations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SETTINGS_CONFIG="$SCRIPT_DIR/../config/local-settings/settings-mapping.json"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Overwrite existing local settings files"
    echo "  -l, --list          List all available settings templates"
    echo "  -s, --specific      Copy settings for specific service"
    echo
    echo "Examples:"
    echo "  $0                           # Copy missing local settings"
    echo "  $0 --force                   # Overwrite all local settings"
    echo "  $0 --list                    # List available templates"
    echo "  $0 --specific CashDesk.Web   # Copy only Web service settings"
}

# Function to list available templates
list_templates() {
    echo -e "${BLUE}Available local settings templates:${NC}"
    echo
    
    if [ ! -f "$SETTINGS_CONFIG" ]; then
        echo -e "${RED}Error: Settings configuration file not found!${NC}"
        exit 1
    fi
    
    jq -r '.settingsMapping[] | "  \(.templateFile) → \(.targetPath)"' "$SETTINGS_CONFIG"
    echo
    echo -e "${YELLOW}Use --specific with the service name (e.g., CashDesk.Web) to copy specific settings${NC}"
}

# Function to copy settings
copy_settings() {
    local force_overwrite=$1
    local specific_service=$2
    
    if [ ! -f "$SETTINGS_CONFIG" ]; then
        echo -e "${RED}Error: Settings configuration file not found!${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Copying local settings templates...${NC}"
    echo
    
    local query='.settingsMapping[]'
    if [ -n "$specific_service" ]; then
        query=".settingsMapping[] | select(.targetPath | contains(\"$specific_service\"))"
    fi
    
    local mappings=$(jq -r "$query | \"\(.templateFile)|\(.targetPath)|\(.description)\"" "$SETTINGS_CONFIG")
    
    if [ -z "$mappings" ]; then
        if [ -n "$specific_service" ]; then
            echo -e "${YELLOW}No settings found for service: $specific_service${NC}"
            exit 1
        else
            echo -e "${YELLOW}No settings mappings found${NC}"
            exit 0
        fi
    fi
    
    local copied=0
    local skipped=0
    local failed=0
    
    while IFS='|' read -r template_file target_path description; do
        local template_path="$SCRIPT_DIR/../config/local-settings/$template_file"
        
        if [ ! -f "$template_path" ]; then
            echo -e "${YELLOW}  ⚠ Template $template_file not found, skipping...${NC}"
            failed=$((failed + 1))
            continue
        fi
        
        # Check if target file already exists
        if [ -f "$target_path" ] && [ "$force_overwrite" != "true" ]; then
            echo -e "${YELLOW}  ⚠ $target_path already exists, skipping (use --force to overwrite)${NC}"
            skipped=$((skipped + 1))
            continue
        fi
        
        # Check if target directory exists (repository might not be cloned)
        local target_dir=$(dirname "$target_path")
        if [ ! -d "$target_dir" ]; then
            echo -e "${YELLOW}  ⚠ Target directory $target_dir not found, skipping $description${NC}"
            failed=$((failed + 1))
            continue
        fi
        
        # Copy template to target location
        if cp "$template_path" "$target_path"; then
            if [ -f "$target_path" ] && [ "$force_overwrite" = "true" ]; then
                echo -e "${CYAN}  ✓ $description (overwritten)${NC}"
            else
                echo -e "${GREEN}  ✓ $description${NC}"
            fi
            copied=$((copied + 1))
        else
            echo -e "${RED}  ✗ Failed to copy $description${NC}"
            failed=$((failed + 1))
        fi
    done <<< "$mappings"
    
    # Display summary
    echo
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  ${GREEN}Copied: $copied${NC}"
    echo -e "  ${YELLOW}Skipped: $skipped${NC}"
    
    if [ $failed -gt 0 ]; then
        echo -e "  ${RED}Failed: $failed${NC}"
    fi
    
    if [ $copied -gt 0 ]; then
        echo -e "\n${GREEN}✓ Local settings copied successfully!${NC}"
        echo -e "${BLUE}Note: You can now customize these files for your local development environment.${NC}"
    elif [ $skipped -gt 0 ] && [ $failed -eq 0 ]; then
        echo -e "\n${YELLOW}All local settings files already exist. Use --force to overwrite.${NC}"
    fi
}

# Main execution
main() {
    local force_overwrite=false
    local specific_service=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                force_overwrite=true
                shift
                ;;
            -l|--list)
                list_templates
                exit 0
                ;;
            -s|--specific)
                if [ -n "$2" ]; then
                    specific_service="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --specific requires a service name${NC}"
                    usage
                    exit 1
                fi
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                usage
                exit 1
                ;;
            *)
                echo -e "${RED}Unexpected argument: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
    
    copy_settings "$force_overwrite" "$specific_service"
}

# Run main function
main "$@"