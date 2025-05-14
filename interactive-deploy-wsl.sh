#!/bin/bash

# Set colors for better UI
RESET="\033[0m"
RED="\033[91m"
GREEN="\033[92m"
YELLOW="\033[93m"
BLUE="\033[94m"
MAGENTA="\033[95m"
CYAN="\033[96m"
WHITE="\033[97m"

# Configuration variables
CONFIG_DIR="$(pwd)/config"
DATA_DIR="$(pwd)/data"
LOGS_DIR="$(pwd)/logs"
BACKUP_DIR="$(pwd)/backups"
ENV_FILE="$(pwd)/.env"
ADMIN_JSON="${DATA_DIR}/admin.json"
ADMIN_EXAMPLE_JSON="${DATA_DIR}/admin.example.json"
DOCKER_COMPOSE_FILE="$(pwd)/docker-compose.yaml"
MAX_RETRIES=3
CURSOR_LOGIN_URL="https://www.cursor.com"

# ===================================
# Function to display header
# ===================================
show_header() {
    clear
    echo -e "${BLUE}===============================================${RESET}"
    echo -e "${GREEN}    Cursor-To-OpenAI-Nexus Interactive Setup    ${RESET}"
    echo -e "${BLUE}===============================================${RESET}"
    echo
}

# ===================================
# Function to check prerequisites
# ===================================
check_prerequisites() {
    show_header
    echo -e "${YELLOW}Checking prerequisites...${RESET}"
    echo

    all_met=true

    # Check Node.js
    check_command "node --version" "Node.js"
    if [ $? -ne 0 ]; then
        all_met=false
    else
        node_version=$(node --version | cut -d 'v' -f 2)
        echo -e "  ${CYAN}Node.js version: ${node_version}${RESET}"
        
        major_version=$(echo $node_version | cut -d '.' -f 1)
        if [ $major_version -lt 16 ]; then
            echo -e "  ${YELLOW}⚠️ Node.js version 16 or higher is recommended${RESET}"
        fi
    fi

    # Check npm
    check_command "npm --version" "npm"
    if [ $? -ne 0 ]; then
        all_met=false
    fi

    # Check Git
    check_command "git --version" "Git"
    if [ $? -ne 0 ]; then
        all_met=false
    fi

    # Check Docker (optional)
    check_command "docker --version" "Docker (optional)"

    echo
    if [ "$all_met" = false ]; then
        echo -e "${YELLOW}Some prerequisites are missing. Would you like to continue anyway? (y/n)${RESET}"
        read -r continue_setup
        if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deployment aborted.${RESET}"
            exit 1
        fi
    fi
}

# ===================================
# Function to check if a command exists
# ===================================
check_command() {
    command="$1"
    name="$2"
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓ $name is installed${RESET}"
        return 0
    else
        echo -e "${RED}✗ $name is not installed${RESET}"
        return 1
    fi
}

# ===================================
# Function to create necessary directories
# ===================================
initialize_directories() {
    echo -e "${YELLOW}Creating necessary directories...${RESET}"
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOGS_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}Directories created successfully.${RESET}"
    echo
}

# ===================================
# Function to backup configuration
# ===================================
backup_configuration() {
    echo -e "${YELLOW}Backing up existing configuration...${RESET}"
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_path="${BACKUP_DIR}/backup_${timestamp}"

    mkdir -p "$backup_path"

    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$backup_path/"
    fi

    if [ -d "$DATA_DIR" ]; then
        cp -r "$DATA_DIR"/* "$backup_path/" 2>/dev/null
    fi

    echo -e "${GREEN}Configuration backed up to: $backup_path${RESET}"
    echo
}

# ===================================
# Function to install dependencies
# ===================================
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${RESET}"
    retry_count=0
    success=false

    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        if npm install --no-fund --quiet --no-audit; then
            echo -e "${GREEN}Dependencies installed successfully.${RESET}"
            success=true
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo -e "${YELLOW}Dependency installation failed. Retrying ($retry_count/$MAX_RETRIES)...${RESET}"
            else
                echo -e "${RED}Failed to install dependencies after $MAX_RETRIES attempts.${RESET}"
                echo -e "${YELLOW}Would you like to continue anyway? (y/n)${RESET}"
                read -r continue_setup
                if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Deployment aborted.${RESET}"
                    exit 1
                fi
            fi
        fi
    done
    echo
}

# ===================================
# Function to get API key
# ===================================
get_api_key() {
    echo -e "${MAGENTA}API Key Configuration${RESET}"
    echo -e "${MAGENTA}====================${RESET}"
    echo
    echo -e "${CYAN}Enter your custom API key (without sk- prefix, will be added automatically)${RESET}"
    echo -e "${CYAN}Leave blank to generate a random key${RESET}"
    read -r api_key

    if [ -z "$api_key" ]; then
        # Generate a random API key
        api_key="cursor-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
        echo -e "${YELLOW}Using generated API key: $api_key${RESET}"
    fi

    # Add sk- prefix if not present
    if [[ ! "$api_key" =~ ^sk- ]]; then
        api_key="sk-$api_key"
    fi
    echo -e "${GREEN}API key configured: $api_key${RESET}"
    echo
}

# ===================================
# Function to get Cursor token
# ===================================
get_cursor_token() {
    echo -e "${MAGENTA}Cursor Authentication${RESET}"
    echo -e "${MAGENTA}====================${RESET}"
    echo
    echo -e "${CYAN}How would you like to authenticate with Cursor?${RESET}"
    echo -e "${CYAN}1) Manually enter token${RESET}"
    echo -e "${CYAN}2) Open browser for login${RESET}"
    read -rp "Enter choice (1/2): " method

    if [ "$method" = "2" ]; then
        echo
        echo -e "${YELLOW}Opening browser for Cursor login...${RESET}"
        echo -e "${YELLOW}Please log in to your Cursor account in the browser.${RESET}"
        
        # Check if we're in WSL and use appropriate browser command
        if grep -q Microsoft /proc/version; then
            # We're in WSL, use Windows browser
            powershell.exe -c "start $CURSOR_LOGIN_URL"
        else
            # Use default browser command
            if command -v xdg-open &>/dev/null; then
                xdg-open "$CURSOR_LOGIN_URL" &>/dev/null
            elif command -v open &>/dev/null; then
                open "$CURSOR_LOGIN_URL" &>/dev/null
            else
                echo -e "${YELLOW}Could not open browser automatically. Please open $CURSOR_LOGIN_URL manually.${RESET}"
            fi
        fi
        
        echo
        echo -e "${YELLOW}After logging in, press any key to continue...${RESET}"
        read -n 1 -s
    fi

    echo
    echo -e "${YELLOW}To get your Cursor token:${RESET}"
    echo -e "${YELLOW}1. Log in to Cursor at $CURSOR_LOGIN_URL (if not already logged in)${RESET}"
    echo -e "${YELLOW}2. Open browser developer tools (F12)${RESET}"
    echo -e "${YELLOW}3. Go to Application tab -> Cookies${RESET}"
    echo -e "${YELLOW}4. Find and copy the 'WorkosCursorSessionToken' value${RESET}"
    echo

    read -rp "Enter your Cursor token (WorkosCursorSessionToken): " cursor_token

    if [ -z "$cursor_token" ]; then
        echo -e "${RED}Cursor token is required. Let's try again.${RESET}"
        get_cursor_token
        return
    fi
    echo -e "${GREEN}Cursor token received.${RESET}"
    echo
}

# ===================================
# Function to configure TLS proxy
# ===================================
configure_tls_proxy() {
    echo -e "${MAGENTA}TLS Proxy Configuration${RESET}"
    echo -e "${MAGENTA}======================${RESET}"
    echo
    echo -e "${CYAN}Do you want to use TLS proxy to avoid blocks? (Recommended)${RESET}"
    read -rp "Enter choice (y/n) [y]: " proxy_choice

    if [[ "$proxy_choice" =~ ^[Nn]$ ]]; then
        use_tls_proxy="false"
    else
        use_tls_proxy="true"
        
        echo
        echo -e "${CYAN}Proxy Platform Options:${RESET}"
        echo -e "${CYAN}1) Auto-detect (recommended)${RESET}"
        echo -e "${CYAN}2) Windows (64-bit)${RESET}"
        echo -e "${CYAN}3) Linux (64-bit)${RESET}"
        echo -e "${CYAN}4) Android (ARM64)${RESET}"
        read -rp "Select proxy platform [1]: " platform_choice
        
        case "$platform_choice" in
            2) proxy_platform="windows_x64" ;;
            3) proxy_platform="linux_x64" ;;
            4) proxy_platform="android_arm64" ;;
            *) proxy_platform="auto" ;;
        esac
    fi
    echo -e "${GREEN}TLS proxy configuration complete.${RESET}"
    echo
}

# ===================================
# Function to create admin account
# ===================================
create_admin_account() {
    echo -e "${MAGENTA}Admin Account Configuration${RESET}"
    echo -e "${MAGENTA}=========================${RESET}"
    echo

    if [ -f "$ADMIN_JSON" ]; then
        echo -e "${YELLOW}Admin account already exists. Overwrite? (y/n)${RESET}"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Keeping existing admin account.${RESET}"
            echo
            return
        fi
    fi

    if [ ! -f "$ADMIN_JSON" ]; then
        if [ -f "$ADMIN_EXAMPLE_JSON" ]; then
            cp "$ADMIN_EXAMPLE_JSON" "$ADMIN_JSON"
        else
            echo '{"username": "admin", "password": "admin123"}' > "$ADMIN_JSON"
        fi
    fi

    read -rp "Enter admin username (default: admin): " username
    if [ -z "$username" ]; then
        username="admin"
    fi

    read -rp "Enter admin password (default: admin123): " password
    if [ -z "$password" ]; then
        password="admin123"
    fi

    echo "{\"username\": \"$username\", \"password\": \"$password\"}" > "$ADMIN_JSON"
    echo -e "${GREEN}Admin account created successfully.${RESET}"
    echo
}

# ===================================
# Function to update .env file
# ===================================
update_env_file() {
    echo -e "${YELLOW}Updating configuration...${RESET}"

    if [ ! -f "$ENV_FILE" ]; then
        cat > "$ENV_FILE" << EOL
# Server port
PORT=3010

# Log format (tiny, combined, common, dev, short)
MORGAN_FORMAT=tiny

# API Key to Cookie mapping (JSON format)
# Format: {"custom_api_key": "Cookie value"} or {"custom_api_key": ["Cookie value1", "Cookie value2"]}
API_KEYS={}

# Rotation strategy (random or round-robin or default)
ROTATION_STRATEGY=default

# Auto-refresh Cookie settings
# Enable auto-refresh Cookie (true or false)
ENABLE_AUTO_REFRESH=false

# Auto-refresh Cookie cron schedule (Cron expression)
# Default: every 6 hours
REFRESH_CRON=0 */6 * * *

# Minimum Cookie count per API Key
# Auto-refresh will be triggered when Cookie count is below this threshold
MIN_COOKIE_COUNT=3

# Cookie refresh mode
# replace: Mark all existing cookies as invalid and replace with new cookies (default)
# append: Keep existing cookies, only add new cookies
COOKIE_REFRESH_MODE=replace

# TLS proxy settings
# Whether to use TLS proxy (true or false)
USE_TLS_PROXY=true

# Proxy server platform
# Options: auto, windows_x64, linux_x64, android_arm64
# auto: Auto-detect platform
PROXY_PLATFORM=auto

# Log settings
LOG_LEVEL=INFO
LOG_FORMAT=colored
LOG_TO_FILE=true
LOG_MAX_SIZE=10
LOG_MAX_FILES=10
EOL
    fi

    # Update API_KEYS with the Cursor token
    if [ -n "$api_key" ] && [ -n "$cursor_token" ]; then
        sed -i "s|API_KEYS=\{.*\}|API_KEYS={\"$api_key\": \"$cursor_token\"}|" "$ENV_FILE"
    fi

    # Update TLS proxy settings
    sed -i "s|USE_TLS_PROXY=\(true\|false\)|USE_TLS_PROXY=$use_tls_proxy|" "$ENV_FILE"

    # Update proxy platform if specified
    if [ -n "$proxy_platform" ]; then
        sed -i "s|PROXY_PLATFORM=.*|PROXY_PLATFORM=$proxy_platform|" "$ENV_FILE"
    fi

    echo -e "${GREEN}Configuration updated successfully.${RESET}"
    echo
}

# ===================================
# Function to choose deployment method
# ===================================
choose_deployment_method() {
    echo -e "${MAGENTA}Deployment Method${RESET}"
    echo -e "${MAGENTA}================${RESET}"
    echo
    echo -e "${CYAN}1) Docker (recommended)${RESET}"
    echo -e "${CYAN}2) npm${RESET}"
    read -rp "Select deployment method [1]: " deploy_method

    if [ "$deploy_method" = "2" ]; then
        deployment_type="npm"
    else
        deployment_type="docker"
    fi
    echo
}

# ===================================
# Function to deploy with Docker
# ===================================
deploy_with_docker() {
    echo -e "${YELLOW}Deploying with Docker...${RESET}"

    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${RED}docker-compose.yaml not found.${RESET}"
        exit 1
    fi

    retry_count=0
    success=false

    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        if docker compose up -d --build; then
            echo -e "${GREEN}Docker deployment successful.${RESET}"
            success=true
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo -e "${YELLOW}Docker deployment failed. Retrying ($retry_count/$MAX_RETRIES)...${RESET}"
            else
                echo -e "${RED}Docker deployment failed after $MAX_RETRIES attempts.${RESET}"
                echo -e "${YELLOW}Would you like to try npm deployment instead? (y/n)${RESET}"
                read -r fallback
                if [[ "$fallback" =~ ^[Yy]$ ]]; then
                    deploy_with_npm
                    return $?
                else
                    echo -e "${RED}Deployment aborted.${RESET}"
                    exit 1
                fi
            fi
        fi
    done
    echo
}

# ===================================
# Function to deploy with npm
# ===================================
deploy_with_npm() {
    echo -e "${YELLOW}Deploying with npm...${RESET}"

    retry_count=0
    success=false

    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        # Start the application in the background
        npm start &
        npm_pid=$!
        
        # Wait a moment to see if it starts successfully
        sleep 3
        
        if kill -0 $npm_pid 2>/dev/null; then
            echo -e "${GREEN}npm deployment successful.${RESET}"
            success=true
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo -e "${YELLOW}npm deployment failed. Retrying ($retry_count/$MAX_RETRIES)...${RESET}"
            else
                echo -e "${RED}npm deployment failed after $MAX_RETRIES attempts.${RESET}"
                echo -e "${YELLOW}Would you like to try Docker deployment instead? (y/n)${RESET}"
                read -r fallback
                if [[ "$fallback" =~ ^[Yy]$ ]]; then
                    deploy_with_docker
                    return $?
                else
                    echo -e "${RED}Deployment aborted.${RESET}"
                    exit 1
                fi
            fi
        fi
    done
    echo
}

# ===================================
# Function to show usage examples
# ===================================
show_usage_examples() {
    echo -e "${MAGENTA}Usage Examples${RESET}"
    echo -e "${MAGENTA}=============${RESET}"
    echo

    echo -e "${CYAN}Python Example:${RESET}"
    echo "from openai import OpenAI"
    echo
    echo "# Initialize the client with your API key"
    echo "client = OpenAI(api_key=\"$api_key\","
    echo "               base_url=\"http://localhost:3010/v1\")"
    echo
    echo "# Make a request to Claude 3.7 Sonnet Thinking"
    echo "response = client.chat.completions.create("
    echo "    model=\"claude-3.7-sonnet-thinking\","
    echo "    messages=["
    echo "        {\"role\": \"user\", \"content\": \"Explain quantum computing in simple terms.\"},"
    echo "    ],"
    echo "    stream=False"
    echo ")"
    echo
    echo "print(response.choices[0].message.content)"
    echo

    echo -e "${CYAN}cURL Example:${RESET}"
    echo "curl -X POST http://localhost:3010/v1/chat/completions \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -H \"Authorization: Bearer $api_key\" \\"
    echo "  -d '{"
    echo "    \"model\": \"claude-3.7-sonnet-thinking\","
    echo "    \"messages\": ["
    echo "      {"
    echo "        \"role\": \"user\","
    echo "        \"content\": \"Explain quantum computing in simple terms.\""
    echo "      }"
    echo "    ],"
    echo "    \"stream\": false"
    echo "  }'"
    echo

    echo -e "${CYAN}Web Interface:${RESET}"
    echo "Access the web interface at: http://localhost:3010"
    echo "Login with your admin credentials to manage API keys and monitor usage."
    echo
}

# ===================================
# Main deployment function
# ===================================
start_deployment() {
    show_header
    check_prerequisites
    initialize_directories
    backup_configuration
    install_dependencies
    get_api_key
    get_cursor_token
    configure_tls_proxy
    create_admin_account
    update_env_file
    choose_deployment_method

    if [ "$deployment_type" = "docker" ]; then
        deploy_with_docker
    else
        deploy_with_npm
    fi

    if [ "$success" = true ]; then
        show_usage_examples
        
        echo -e "${GREEN}Deployment Complete!${RESET}"
        echo -e "${GREEN}=====================${RESET}"
        echo -e "${GREEN}Your Cursor-To-OpenAI-Nexus service is now running.${RESET}"
        echo -e "${GREEN}Access the web interface at: http://localhost:3010${RESET}"
        echo -e "${GREEN}API endpoint: http://localhost:3010/v1${RESET}"
        echo -e "${GREEN}API key: $api_key${RESET}"
        
        echo
        echo -e "${YELLOW}Maintenance Commands:${RESET}"
        if [ "$deployment_type" = "npm" ]; then
            echo -e "${CYAN}- Restart service: npm start${RESET}"
            echo -e "${CYAN}- Refresh cookies: npm run refresh-cookies${RESET}"
            echo -e "${CYAN}- Force refresh cookies: npm run refresh-cookies -- --force${RESET}"
        else
            echo -e "${CYAN}- View logs: docker compose logs -f${RESET}"
            echo -e "${CYAN}- Restart service: docker compose restart${RESET}"
            echo -e "${CYAN}- Stop service: docker compose down${RESET}"
        fi
    else
        echo -e "${RED}Deployment failed. Please check the logs for more information.${RESET}"
        exit 1
    fi
}

# ===================================
# Start the deployment process
# ===================================
start_deployment
echo -e "${YELLOW}Press any key to exit...${RESET}"
read -n 1 -s
exit 0

