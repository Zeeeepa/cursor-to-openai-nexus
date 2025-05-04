# Cursor-To-OpenAI-Nexus Deployment Script
# Author: Codegen
# Version: 1.0.0

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Colors for better UI
$RED = [ConsoleColor]::Red
$GREEN = [ConsoleColor]::Green
$YELLOW = [ConsoleColor]::Yellow
$BLUE = [ConsoleColor]::Cyan
$MAGENTA = [ConsoleColor]::Magenta
$WHITE = [ConsoleColor]::White

# Configuration variables
$CONFIG_DIR = Join-Path $PSScriptRoot "config"
$DATA_DIR = Join-Path $PSScriptRoot "data"
$LOGS_DIR = Join-Path $PSScriptRoot "logs"
$BACKUP_DIR = Join-Path $PSScriptRoot "backups"
$ENV_FILE = Join-Path $PSScriptRoot ".env"
$ADMIN_JSON = Join-Path $DATA_DIR "admin.json"
$ADMIN_EXAMPLE_JSON = Join-Path $DATA_DIR "admin.example.json"
$DOCKER_COMPOSE_FILE = Join-Path $PSScriptRoot "docker-compose.yaml"

# Function to display header
function Show-Header {
    Clear-Host
    Write-Host "=======================================" -ForegroundColor $BLUE
    Write-Host "    Cursor-To-OpenAI-Nexus Deployer    " -ForegroundColor $GREEN
    Write-Host "=======================================" -ForegroundColor $BLUE
    Write-Host ""
}

# Function to check if a command exists
function Test-CommandExists {
    param (
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor $YELLOW
    
    $prerequisites = @{
        "Node.js" = { Test-CommandExists "node" }
        "npm" = { Test-CommandExists "npm" }
        "Docker" = { Test-CommandExists "docker" }
        "Git" = { Test-CommandExists "git" }
    }
    
    $allMet = $true
    
    foreach ($prereq in $prerequisites.Keys) {
        $check = & $prerequisites[$prereq]
        if ($check) {
            Write-Host "√ $prereq is installed" -ForegroundColor $GREEN
        } else {
            Write-Host "✗ $prereq is not installed" -ForegroundColor $RED
            $allMet = $false
        }
    }
    
    # Check Node.js version
    if (Test-CommandExists "node") {
        $nodeVersion = (node --version).Substring(1)
        Write-Host "  Node.js version: $nodeVersion" -ForegroundColor $YELLOW
        
        # Parse version and check if it's at least 16
        $versionParts = $nodeVersion.Split('.')
        $majorVersion = [int]$versionParts[0]
        
        if ($majorVersion -lt 16) {
            Write-Host "  ⚠️ Node.js version 16 or higher is recommended" -ForegroundColor $YELLOW
        }
    }
    
    return $allMet
}

# Function to create necessary directories
function Initialize-Directories {
    $directories = @($CONFIG_DIR, $DATA_DIR, $LOGS_DIR, $BACKUP_DIR)
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "Created directory: $dir" -ForegroundColor $GREEN
        }
    }
}

# Function to backup configuration
function Backup-Configuration {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $BACKUP_DIR "backup_$timestamp"
    
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    # Backup .env file if it exists
    if (Test-Path $ENV_FILE) {
        Copy-Item $ENV_FILE -Destination $backupPath
    }
    
    # Backup data directory if it exists
    if (Test-Path $DATA_DIR) {
        Copy-Item -Path "$DATA_DIR\*" -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Configuration backed up to: $backupPath" -ForegroundColor $GREEN
    return $backupPath
}

# Function to install dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..." -ForegroundColor $YELLOW
    
    try {
        npm install
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Dependencies installed successfully" -ForegroundColor $GREEN
            return $true
        } else {
            Write-Host "Failed to install dependencies" -ForegroundColor $RED
            return $false
        }
    } catch {
        Write-Host "Error installing dependencies: $_" -ForegroundColor $RED
        return $false
    }
}

# Function to get Cursor authentication token
function Get-CursorToken {
    Write-Host "`nCursor Authentication" -ForegroundColor $MAGENTA
    Write-Host "===================" -ForegroundColor $MAGENTA
    
    $method = Read-Host "How would you like to authenticate with Cursor?`n1) Manually enter token`n2) Open browser for login`nEnter choice (1/2)"
    
    if ($method -eq "1") {
        Write-Host "`nTo get your Cursor token:" -ForegroundColor $YELLOW
        Write-Host "1. Log in to Cursor at https://www.cursor.com" -ForegroundColor $YELLOW
        Write-Host "2. Open browser developer tools (F12)" -ForegroundColor $YELLOW
        Write-Host "3. Go to Application tab -> Cookies" -ForegroundColor $YELLOW
        Write-Host "4. Find and copy the 'WorkosCursorSessionToken' value" -ForegroundColor $YELLOW
        
        $token = Read-Host "`nEnter your Cursor token (WorkosCursorSessionToken)"
        return $token
    } else {
        Write-Host "`nOpening browser for Cursor login..." -ForegroundColor $YELLOW
        Write-Host "Please log in to your Cursor account in the browser." -ForegroundColor $YELLOW
        
        # Open browser to Cursor login page
        Start-Process "https://www.cursor.com"
        
        Write-Host "After logging in, press any key to continue..." -ForegroundColor $YELLOW
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Ask for token after login
        Write-Host "`nNow please get your token from the browser:" -ForegroundColor $YELLOW
        Write-Host "1. In the same browser window, open developer tools (F12)" -ForegroundColor $YELLOW
        Write-Host "2. Go to Application tab -> Cookies" -ForegroundColor $YELLOW
        Write-Host "3. Find and copy the 'WorkosCursorSessionToken' value" -ForegroundColor $YELLOW
        
        $token = Read-Host "`nEnter your Cursor token (WorkosCursorSessionToken)"
        return $token
    }
}

# Function to create admin account
function Create-AdminAccount {
    Write-Host "`nCreating admin account..." -ForegroundColor $YELLOW
    
    # Check if admin.json already exists
    if (Test-Path $ADMIN_JSON) {
        $overwrite = Read-Host "Admin account already exists. Overwrite? (y/n)"
        if ($overwrite -ne "y") {
            Write-Host "Keeping existing admin account" -ForegroundColor $YELLOW
            return $true
        }
    }
    
    # Create admin.json from example if it doesn't exist
    if (-not (Test-Path $ADMIN_JSON) -and (Test-Path $ADMIN_EXAMPLE_JSON)) {
        Copy-Item $ADMIN_EXAMPLE_JSON -Destination $ADMIN_JSON
    }
    
    # If admin.json still doesn't exist, create it
    if (-not (Test-Path $ADMIN_JSON)) {
        $adminTemplate = @{
            "username" = "admin"
            "password" = "admin123"
        } | ConvertTo-Json
        
        Set-Content -Path $ADMIN_JSON -Value $adminTemplate
    }
    
    # Now prompt for username and password
    $username = Read-Host "Enter admin username (default: admin)"
    if ([string]::IsNullOrWhiteSpace($username)) {
        $username = "admin"
    }
    
    $password = Read-Host "Enter admin password (default: admin123)"
    if ([string]::IsNullOrWhiteSpace($password)) {
        $password = "admin123"
    }
    
    # Update admin.json
    $adminConfig = @{
        "username" = $username
        "password" = $password
    } | ConvertTo-Json
    
    Set-Content -Path $ADMIN_JSON -Value $adminConfig
    
    Write-Host "Admin account created successfully" -ForegroundColor $GREEN
    return $true
}

# Function to create or update .env file
function Update-EnvFile {
    param (
        [string]$CursorToken,
        [string]$ApiKey,
        [bool]$UseTlsProxy,
        [string]$ProxyPlatform
    )
    
    Write-Host "`nUpdating configuration..." -ForegroundColor $YELLOW
    
    # Check if .env already exists
    $envExists = Test-Path $ENV_FILE
    $envContent = ""
    
    if ($envExists) {
        $envContent = Get-Content $ENV_FILE -Raw
    } else {
        # Create basic .env template
        $envContent = @"
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
"@
    }
    
    # Update API_KEYS with the Cursor token
    if (-not [string]::IsNullOrWhiteSpace($ApiKey) -and -not [string]::IsNullOrWhiteSpace($CursorToken)) {
        $apiKeyJson = "{`"$ApiKey`": `"$CursorToken`"}"
        $envContent = $envContent -replace 'API_KEYS=\{.*\}', "API_KEYS=$apiKeyJson"
    }
    
    # Update TLS proxy settings
    $tlsProxyValue = if ($UseTlsProxy) { "true" } else { "false" }
    $envContent = $envContent -replace 'USE_TLS_PROXY=(true|false)', "USE_TLS_PROXY=$tlsProxyValue"
    
    # Update proxy platform if specified
    if (-not [string]::IsNullOrWhiteSpace($ProxyPlatform)) {
        $envContent = $envContent -replace 'PROXY_PLATFORM=.*', "PROXY_PLATFORM=$ProxyPlatform"
    }
    
    # Write updated content to .env file
    Set-Content -Path $ENV_FILE -Value $envContent
    
    Write-Host "Configuration updated successfully" -ForegroundColor $GREEN
    return $true
}

# Function to deploy with Docker
function Deploy-WithDocker {
    Write-Host "`nDeploying with Docker..." -ForegroundColor $YELLOW
    
    # Check if docker-compose.yaml exists
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Host "docker-compose.yaml not found" -ForegroundColor $RED
        return $false
    }
    
    try {
        # Build and start containers
        docker compose up -d --build
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker deployment successful" -ForegroundColor $GREEN
            Write-Host "Service is running at: http://localhost:3010" -ForegroundColor $GREEN
            return $true
        } else {
            Write-Host "Docker deployment failed" -ForegroundColor $RED
            return $false
        }
    } catch {
        Write-Host "Error deploying with Docker: $_" -ForegroundColor $RED
        return $false
    }
}

# Function to deploy with npm
function Deploy-WithNpm {
    Write-Host "`nDeploying with npm..." -ForegroundColor $YELLOW
    
    try {
        # Start the application with npm
        Start-Process -FilePath "npm" -ArgumentList "start" -NoNewWindow
        
        Write-Host "npm deployment successful" -ForegroundColor $GREEN
        Write-Host "Service is running at: http://localhost:3010" -ForegroundColor $GREEN
        return $true
    } catch {
        Write-Host "Error deploying with npm: $_" -ForegroundColor $RED
        return $false
    }
}

# Function to show usage examples
function Show-UsageExamples {
    param (
        [string]$ApiKey
    )
    
    Write-Host "`nUsage Examples" -ForegroundColor $MAGENTA
    Write-Host "==============" -ForegroundColor $MAGENTA
    
    # Python example - using PowerShell here-string syntax
    Write-Host "`nPython Example:" -ForegroundColor $YELLOW
    $pythonExample = @"
from openai import OpenAI

# Initialize the client with your API key
client = OpenAI(api_key="$ApiKey",
                base_url="http://localhost:3010/v1")

# Make a request to Claude 3.7 Sonnet Thinking
response = client.chat.completions.create(
    model="claude-3.7-sonnet-thinking",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms."},
    ],
    stream=False
)

print(response.choices[0].message.content)
"@
    Write-Host $pythonExample -ForegroundColor $WHITE
    
    # cURL example
    Write-Host "`ncURL Example:" -ForegroundColor $YELLOW
    $curlExample = @"
curl -X POST http://localhost:3010/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ApiKey" \
  -d '{
    "model": "claude-3.7-sonnet-thinking",
    "messages": [
      {
        "role": "user",
        "content": "Explain quantum computing in simple terms."
      }
    ],
    "stream": false
  }'
"@
    Write-Host $curlExample -ForegroundColor $WHITE
    
    # Web UI
    Write-Host "`nWeb Interface:" -ForegroundColor $YELLOW
    Write-Host "Access the web interface at: http://localhost:3010" -ForegroundColor $WHITE
    Write-Host "Login with your admin credentials to manage API keys and monitor usage." -ForegroundColor $WHITE
}

# Main deployment function
function Start-Deployment {
    Show-Header
    
    # Check prerequisites
    $prereqsMet = Test-Prerequisites
    if (-not $prereqsMet) {
        Write-Host "`nSome prerequisites are missing. Would you like to continue anyway? (y/n)" -ForegroundColor $YELLOW
        $continue = Read-Host
        if ($continue -ne "y") {
            Write-Host "Deployment aborted" -ForegroundColor $RED
            return
        }
    }
    
    # Initialize directories
    Initialize-Directories
    
    # Backup existing configuration
    $backupPath = Backup-Configuration
    
    # Install dependencies
    $depsInstalled = Install-Dependencies
    if (-not $depsInstalled) {
        Write-Host "Failed to install dependencies. Deployment aborted." -ForegroundColor $RED
        return
    }
    
    # Get API key
    $apiKey = Read-Host "`nEnter your custom API key (without sk- prefix, will be added automatically)"
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = "cursor-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
        Write-Host "Using generated API key: $apiKey" -ForegroundColor $YELLOW
    }
    
    # Add sk- prefix if not present
    if (-not $apiKey.StartsWith("sk-")) {
        $apiKey = "sk-" + $apiKey
    }
    
    # Get Cursor token
    $cursorToken = Get-CursorToken
    if ([string]::IsNullOrWhiteSpace($cursorToken)) {
        Write-Host "Cursor token is required. Deployment aborted." -ForegroundColor $RED
        return
    }
    
    # Configure TLS proxy
    $useTlsProxy = $true
    $proxyChoice = Read-Host "`nDo you want to use TLS proxy to avoid blocks? (Recommended) (y/n) [y]"
    if ($proxyChoice -eq "n") {
        $useTlsProxy = $false
    }
    
    # Configure proxy platform if TLS proxy is enabled
    $proxyPlatform = "auto"
    if ($useTlsProxy) {
        Write-Host "`nProxy Platform Options:" -ForegroundColor $YELLOW
        Write-Host "1) Auto-detect (recommended)" -ForegroundColor $WHITE
        Write-Host "2) Windows (64-bit)" -ForegroundColor $WHITE
        Write-Host "3) Linux (64-bit)" -ForegroundColor $WHITE
        Write-Host "4) Android (ARM64)" -ForegroundColor $WHITE
        
        $platformChoice = Read-Host "Select proxy platform [1]"
        
        switch ($platformChoice) {
            "2" { $proxyPlatform = "windows_x64" }
            "3" { $proxyPlatform = "linux_x64" }
            "4" { $proxyPlatform = "android_arm64" }
            default { $proxyPlatform = "auto" }
        }
    }
    
    # Create admin account
    $adminCreated = Create-AdminAccount
    if (-not $adminCreated) {
        Write-Host "Failed to create admin account. Deployment aborted." -ForegroundColor $RED
        return
    }
    
    # Update .env file
    $envUpdated = Update-EnvFile -CursorToken $cursorToken -ApiKey $apiKey -UseTlsProxy $useTlsProxy -ProxyPlatform $proxyPlatform
    if (-not $envUpdated) {
        Write-Host "Failed to update configuration. Deployment aborted." -ForegroundColor $RED
        return
    }
    
    # Choose deployment method
    Write-Host "`nDeployment Method" -ForegroundColor $MAGENTA
    Write-Host "================" -ForegroundColor $MAGENTA
    Write-Host "1) Docker (recommended)" -ForegroundColor $WHITE
    Write-Host "2) npm" -ForegroundColor $WHITE
    
    $deployMethod = Read-Host "Select deployment method [1]"
    
    $deploymentSuccess = $false
    
    if ($deployMethod -eq "2") {
        $deploymentSuccess = Deploy-WithNpm
    } else {
        $deploymentSuccess = Deploy-WithDocker
    }
    
    if ($deploymentSuccess) {
        # Show usage examples
        Show-UsageExamples -ApiKey $apiKey
        
        Write-Host "`nDeployment Complete!" -ForegroundColor $GREEN
        Write-Host "=====================" -ForegroundColor $GREEN
        Write-Host "Your Cursor-To-OpenAI-Nexus service is now running." -ForegroundColor $GREEN
        Write-Host "Access the web interface at: http://localhost:3010" -ForegroundColor $GREEN
        Write-Host "API endpoint: http://localhost:3010/v1" -ForegroundColor $GREEN
        Write-Host "API key: $apiKey" -ForegroundColor $GREEN
        
        # Provide maintenance commands
        Write-Host "`nMaintenance Commands:" -ForegroundColor $YELLOW
        if ($deployMethod -eq "2") {
            Write-Host "- Restart service: npm start" -ForegroundColor $WHITE
            Write-Host "- Refresh cookies: npm run refresh-cookies" -ForegroundColor $WHITE
            Write-Host "- Force refresh cookies: npm run refresh-cookies -- --force" -ForegroundColor $WHITE
        } else {
            Write-Host "- View logs: docker compose logs -f" -ForegroundColor $WHITE
            Write-Host "- Restart service: docker compose restart" -ForegroundColor $WHITE
            Write-Host "- Stop service: docker compose down" -ForegroundColor $WHITE
        }
    } else {
        Write-Host "`nDeployment failed. Please check the logs for more information." -ForegroundColor $RED
    }
}

# Start the deployment process
Start-Deployment

