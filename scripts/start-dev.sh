#!/bin/bash

# CashDesk V3 Development Environment Starter
# This script starts the required services based on what you're working on

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Create logs directory if it doesn't exist
LOGS_DIR="./logs"
mkdir -p "$LOGS_DIR"

# Get current timestamp for log files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to start a service
start_service() {
    local service_name=$1
    local service_path=$2
    local port=$3
    local log_file="${LOGS_DIR}/${service_name}_${TIMESTAMP}.log"
    
    echo -e "${BLUE}Starting ${service_name} on port ${port}...${NC}"
    
    # Check if the service directory exists
    if [ ! -d "$service_path" ]; then
        echo -e "${RED}Error: Directory $service_path not found!${NC}"
        return 1
    fi
    
    # Start the service in the background and redirect output to log file
    cd "$service_path" && dotnet run >> "$log_file" 2>&1 &
    local pid=$!
    
    # Store PID for cleanup
    echo $pid >> "${LOGS_DIR}/running_services.pid"
    
    echo -e "${GREEN}✓ ${service_name} started (PID: $pid, Log: $log_file)${NC}"
    cd - > /dev/null
}

# Function to check if docker-compose is running
check_docker_compose() {
    echo -e "${MAGENTA}Checking Docker services...${NC}"
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found!${NC}"
        return 1
    fi
    
    # Create docker-data directories if they don't exist
    mkdir -p docker-data/sqlserver/{backup,scripts}
    
    # Check if docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running! Please start Docker first.${NC}"
        exit 1
    fi
    
    # Check if our services are running
    local rabbitmq_running=$(docker ps --filter "name=rabbitmq3" --format "{{.Names}}" 2>/dev/null)
    local sqlserver_running=$(docker ps --filter "name=sql-server-db" --format "{{.Names}}" 2>/dev/null)
    local seq_running=$(docker ps --filter "name=seq" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$rabbitmq_running" ] || [ -z "$sqlserver_running" ] || [ -z "$seq_running" ]; then
        echo -e "${YELLOW}Docker services not running. Starting them now...${NC}"
        docker-compose up -d
        
        # Wait a moment for services to start
        echo -e "${YELLOW}Waiting for Docker services to be ready...${NC}"
        sleep 5
        
        echo -e "${GREEN}✓ Docker services started:${NC}"
        echo -e "  • RabbitMQ: http://localhost:15672 (guest/guest)"
        echo -e "  • SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)"
        echo -e "  • Seq: http://localhost:5341"
    else
        echo -e "${GREEN}✓ Docker services are already running${NC}"
    fi
}

# Function to stop all services
stop_all_services() {
    echo -e "\n${YELLOW}Stopping all services...${NC}"
    
    if [ -f "${LOGS_DIR}/running_services.pid" ]; then
        while read pid; do
            if kill -0 $pid 2>/dev/null; then
                kill $pid
                echo -e "${GREEN}✓ Stopped process $pid${NC}"
            fi
        done < "${LOGS_DIR}/running_services.pid"
        
        # Clean up PID file
        rm "${LOGS_DIR}/running_services.pid"
    fi
    
    # Ask if user wants to stop Docker services
    echo -e "\n${YELLOW}Do you want to stop Docker services too? (y/N)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping Docker services...${NC}"
        docker-compose down
        echo -e "${GREEN}✓ Docker services stopped${NC}"
    fi
}

# Trap to ensure services are stopped on script exit
trap stop_all_services EXIT

# Clear screen
clear

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CashDesk V3 Development Starter      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo

# Check if we're in the right directory
if [ ! -f "Directory.Build.targets" ]; then
    echo -e "${RED}Error: This script must be run from the CashDesk V3 root directory!${NC}"
    exit 1
fi

# Check and start Docker services first
check_docker_compose
echo

# Service paths
IDENTITY_PATH="CashDesk.Identity/src/CashDesk.Identity.Server"
ADMIN_PATH="CashDesk.Admin/src/CashDesk.Admin.Server"
PORTAL_PATH="CashDesk.Portal/src/CashDesk.Portal.Server"
WEB_PATH="CashDesk.Web/src/CashDesk.Web.Server"

# Display menu
echo "Which project are you working on?"
echo
echo "1) CashDesk.Web (Port 5003)"
echo "2) CashDesk.Admin (Port 5001)"
echo "3) CashDesk.Portal (Port 5002)"
echo "4) CashDesk.Identity (Port 5000)"
echo "5) Start ALL services"
echo "6) Exit"
echo

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo -e "\n${GREEN}You'll be working on CashDesk.Web${NC}"
        echo -e "${YELLOW}Starting other required services...${NC}\n"
        
        start_service "Identity" "$IDENTITY_PATH" 5000
        start_service "Admin" "$ADMIN_PATH" 5001
        start_service "Portal" "$PORTAL_PATH" 5002
        
        echo -e "\n${GREEN}All supporting services started!${NC}"
        echo -e "${YELLOW}You can now run 'dotnet watch run' in ${WEB_PATH}${NC}"
        echo -e "${YELLOW}Logs are available in the ${LOGS_DIR} directory${NC}"
        ;;
        
    2)
        echo -e "\n${GREEN}You'll be working on CashDesk.Admin${NC}"
        echo -e "${YELLOW}Starting other required services...${NC}\n"
        
        start_service "Identity" "$IDENTITY_PATH" 5000
        start_service "Web" "$WEB_PATH" 5003
        start_service "Portal" "$PORTAL_PATH" 5002
        
        echo -e "\n${GREEN}All supporting services started!${NC}"
        echo -e "${YELLOW}You can now run 'dotnet watch run' in ${ADMIN_PATH}${NC}"
        echo -e "${YELLOW}Logs are available in the ${LOGS_DIR} directory${NC}"
        ;;
        
    3)
        echo -e "\n${GREEN}You'll be working on CashDesk.Portal${NC}"
        echo -e "${YELLOW}Starting other required services...${NC}\n"
        
        start_service "Identity" "$IDENTITY_PATH" 5000
        start_service "Web" "$WEB_PATH" 5003
        start_service "Admin" "$ADMIN_PATH" 5001
        
        echo -e "\n${GREEN}All supporting services started!${NC}"
        echo -e "${YELLOW}You can now run 'dotnet watch run' in ${PORTAL_PATH}${NC}"
        echo -e "${YELLOW}Logs are available in the ${LOGS_DIR} directory${NC}"
        ;;
        
    4)
        echo -e "\n${GREEN}You'll be working on CashDesk.Identity${NC}"
        echo -e "${YELLOW}Starting other required services...${NC}\n"
        
        start_service "Web" "$WEB_PATH" 5003
        start_service "Admin" "$ADMIN_PATH" 5001
        start_service "Portal" "$PORTAL_PATH" 5002
        
        echo -e "\n${GREEN}All supporting services started!${NC}"
        echo -e "${YELLOW}You can now run 'dotnet watch run' in ${IDENTITY_PATH}${NC}"
        echo -e "${YELLOW}Logs are available in the ${LOGS_DIR} directory${NC}"
        ;;
        
    5)
        echo -e "\n${GREEN}Starting ALL services${NC}"
        echo -e "${YELLOW}Starting all services...${NC}\n"
        
        start_service "Identity" "$IDENTITY_PATH" 5000
        start_service "Admin" "$ADMIN_PATH" 5001
        start_service "Portal" "$PORTAL_PATH" 5002
        start_service "Web" "$WEB_PATH" 5003
        
        echo -e "\n${GREEN}All services started!${NC}"
        echo -e "${YELLOW}Logs are available in the ${LOGS_DIR} directory${NC}"
        ;;
        
    6)
        echo -e "${YELLOW}Exiting...${NC}"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac

# Show service URLs
echo -e "\n${BLUE}Service URLs:${NC}"
echo "• Identity: https://localhost:5000"
echo "• Admin: https://localhost:5001"
echo "• Portal: https://localhost:5002"
echo "• Web: https://localhost:5003"

echo -e "\n${BLUE}External Services:${NC}"
echo "• RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo "• SQL Server: localhost:1433 (sa/<YourStrong@Passw0rd>)"
echo "• Seq Logs: http://localhost:5341"

echo -e "\n${YELLOW}Press Ctrl+C to stop all services${NC}"

# Keep script running
while true; do
    sleep 1
done