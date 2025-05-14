@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Cursor-To-OpenAI-Nexus Interactive Deployment

:: Set colors for better UI
set "RESET=[0m"
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "MAGENTA=[95m"
set "CYAN=[96m"
set "WHITE=[97m"

:: Configuration variables
set "CONFIG_DIR=%~dp0config"
set "DATA_DIR=%~dp0data"
set "LOGS_DIR=%~dp0logs"
set "BACKUP_DIR=%~dp0backups"
set "ENV_FILE=%~dp0.env"
set "ADMIN_JSON=%DATA_DIR%\admin.json"
set "ADMIN_EXAMPLE_JSON=%DATA_DIR%\admin.example.json"
set "DOCKER_COMPOSE_FILE=%~dp0docker-compose.yaml"
set "MAX_RETRIES=3"
set "CURSOR_LOGIN_URL=https://www.cursor.com"

:: ===================================
:: Function to display header
:: ===================================
:showHeader
cls
echo %BLUE%===============================================%RESET%
echo %GREEN%    Cursor-To-OpenAI-Nexus Interactive Setup    %RESET%
echo %BLUE%===============================================%RESET%
echo.
goto :eof

:: ===================================
:: Function to check prerequisites
:: ===================================
:checkPrerequisites
call :showHeader
echo %YELLOW%Checking prerequisites...%RESET%
echo.

set "allMet=true"

:: Check Node.js
call :checkCommand "node --version" "Node.js"
if "!errorlevel!" neq "0" (
    set "allMet=false"
) else (
    for /f "tokens=1 delims=v" %%a in ('node --version') do set "nodeVersion=%%a"
    echo   %CYAN%Node.js version: !nodeVersion!%RESET%
    
    for /f "tokens=1 delims=." %%a in ("!nodeVersion!") do set "majorVersion=%%a"
    if !majorVersion! lss 16 (
        echo   %YELLOW%⚠️ Node.js version 16 or higher is recommended%RESET%
    )
)

:: Check npm
call :checkCommand "npm --version" "npm"
if "!errorlevel!" neq "0" set "allMet=false"

:: Check Git
call :checkCommand "git --version" "Git"
if "!errorlevel!" neq "0" set "allMet=false"

:: Check Docker (optional)
call :checkCommand "docker --version" "Docker (optional)"

echo.
if "%allMet%" == "false" (
    echo %YELLOW%Some prerequisites are missing. Would you like to continue anyway? (y/n)%RESET%
    set /p "continue="
    if /i not "!continue!" == "y" (
        echo %RED%Deployment aborted.%RESET%
        exit /b 1
    )
)
goto :eof

:: ===================================
:: Function to check if a command exists
:: ===================================
:checkCommand
set "command=%~1"
set "name=%~2"
%command% >nul 2>&1
if %errorlevel% equ 0 (
    echo %GREEN%✓ %name% is installed%RESET%
    exit /b 0
) else (
    echo %RED%✗ %name% is not installed%RESET%
    exit /b 1
)
goto :eof

:: ===================================
:: Function to create necessary directories
:: ===================================
:initializeDirectories
echo %YELLOW%Creating necessary directories...%RESET%
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" 2>nul
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" 2>nul
echo %GREEN%Directories created successfully.%RESET%
echo.
goto :eof

:: ===================================
:: Function to backup configuration
:: ===================================
:backupConfiguration
echo %YELLOW%Backing up existing configuration...%RESET%
set "timestamp=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "timestamp=!timestamp: =0!"
set "backupPath=%BACKUP_DIR%\backup_!timestamp!"

mkdir "%backupPath%" 2>nul

if exist "%ENV_FILE%" (
    copy "%ENV_FILE%" "%backupPath%" >nul
)

if exist "%DATA_DIR%" (
    xcopy /E /I /Y "%DATA_DIR%\*" "%backupPath%" >nul 2>&1
)

echo %GREEN%Configuration backed up to: %backupPath%%RESET%
echo.
goto :eof

:: ===================================
:: Function to install dependencies
:: ===================================
:installDependencies
echo %YELLOW%Installing dependencies...%RESET%
set "retryCount=0"
set "success=false"

:retryInstall
npm install --no-fund --quiet --no-audit
if %errorlevel% equ 0 (
    echo %GREEN%Dependencies installed successfully.%RESET%
    set "success=true"
) else (
    set /a "retryCount+=1"
    if !retryCount! lss %MAX_RETRIES% (
        echo %YELLOW%Dependency installation failed. Retrying (!retryCount!/%MAX_RETRIES%)...%RESET%
        goto :retryInstall
    ) else (
        echo %RED%Failed to install dependencies after %MAX_RETRIES% attempts.%RESET%
        echo %YELLOW%Would you like to continue anyway? (y/n)%RESET%
        set /p "continue="
        if /i not "!continue!" == "y" (
            echo %RED%Deployment aborted.%RESET%
            exit /b 1
        )
    )
)
echo.
goto :eof

:: ===================================
:: Function to get API key
:: ===================================
:getApiKey
echo %MAGENTA%API Key Configuration%RESET%
echo %MAGENTA%====================%RESET%
echo.
echo %CYAN%Enter your custom API key (without sk- prefix, will be added automatically)%RESET%
echo %CYAN%Leave blank to generate a random key%RESET%
set /p "apiKey="

if "%apiKey%"=="" (
    :: Generate a random API key
    set "chars=abcdefghijklmnopqrstuvwxyz0123456789"
    set "apiKey=cursor-"
    for /L %%i in (1,1,8) do (
        set /a "rand=!random! %% 36"
        for /f %%j in ("!rand!") do set "apiKey=!apiKey!!chars:~%%j,1!"
    )
    echo %YELLOW%Using generated API key: %apiKey%%RESET%
)

:: Add sk- prefix if not present
echo %apiKey% | findstr /b "sk-" >nul
if %errorlevel% neq 0 (
    set "apiKey=sk-%apiKey%"
)
echo %GREEN%API key configured: %apiKey%%RESET%
echo.
goto :eof

:: ===================================
:: Function to get Cursor token
:: ===================================
:getCursorToken
echo %MAGENTA%Cursor Authentication%RESET%
echo %MAGENTA%====================%RESET%
echo.
echo %CYAN%How would you like to authenticate with Cursor?%RESET%
echo %CYAN%1) Manually enter token%RESET%
echo %CYAN%2) Open browser for login%RESET%
set /p "method=Enter choice (1/2): "

if "%method%" == "2" (
    echo.
    echo %YELLOW%Opening browser for Cursor login...%RESET%
    echo %YELLOW%Please log in to your Cursor account in the browser.%RESET%
    start "" "%CURSOR_LOGIN_URL%"
    echo.
    echo %YELLOW%After logging in, press any key to continue...%RESET%
    pause >nul
)

echo.
echo %YELLOW%To get your Cursor token:%RESET%
echo %YELLOW%1. Log in to Cursor at %CURSOR_LOGIN_URL% (if not already logged in)%RESET%
echo %YELLOW%2. Open browser developer tools (F12)%RESET%
echo %YELLOW%3. Go to Application tab -^> Cookies%RESET%
echo %YELLOW%4. Find and copy the 'WorkosCursorSessionToken' value%RESET%
echo.

set /p "cursorToken=Enter your Cursor token (WorkosCursorSessionToken): "

if "%cursorToken%"=="" (
    echo %RED%Cursor token is required. Let's try again.%RESET%
    goto :getCursorToken
)
echo %GREEN%Cursor token received.%RESET%
echo.
goto :eof

:: ===================================
:: Function to configure TLS proxy
:: ===================================
:configureTlsProxy
echo %MAGENTA%TLS Proxy Configuration%RESET%
echo %MAGENTA%======================%RESET%
echo.
echo %CYAN%Do you want to use TLS proxy to avoid blocks? (Recommended)%RESET%
set /p "proxyChoice=Enter choice (y/n) [y]: "

if /i "%proxyChoice%" == "n" (
    set "useTlsProxy=false"
) else (
    set "useTlsProxy=true"
    
    echo.
    echo %CYAN%Proxy Platform Options:%RESET%
    echo %CYAN%1) Auto-detect (recommended)%RESET%
    echo %CYAN%2) Windows (64-bit)%RESET%
    echo %CYAN%3) Linux (64-bit)%RESET%
    echo %CYAN%4) Android (ARM64)%RESET%
    set /p "platformChoice=Select proxy platform [1]: "
    
    if "%platformChoice%" == "2" (
        set "proxyPlatform=windows_x64"
    ) else if "%platformChoice%" == "3" (
        set "proxyPlatform=linux_x64"
    ) else if "%platformChoice%" == "4" (
        set "proxyPlatform=android_arm64"
    ) else (
        set "proxyPlatform=auto"
    )
)
echo %GREEN%TLS proxy configuration complete.%RESET%
echo.
goto :eof

:: ===================================
:: Function to create admin account
:: ===================================
:createAdminAccount
echo %MAGENTA%Admin Account Configuration%RESET%
echo %MAGENTA%=========================%RESET%
echo.

if exist "%ADMIN_JSON%" (
    echo %YELLOW%Admin account already exists. Overwrite? (y/n)%RESET%
    set /p "overwrite="
    if /i not "%overwrite%" == "y" (
        echo %YELLOW%Keeping existing admin account.%RESET%
        goto :adminAccountEnd
    )
)

if not exist "%ADMIN_JSON%" (
    if exist "%ADMIN_EXAMPLE_JSON%" (
        copy "%ADMIN_EXAMPLE_JSON%" "%ADMIN_JSON%" >nul
    ) else (
        echo {"username": "admin", "password": "admin123"} > "%ADMIN_JSON%"
    )
)

set /p "username=Enter admin username (default: admin): "
if "%username%"=="" set "username=admin"

set /p "password=Enter admin password (default: admin123): "
if "%password%"=="" set "password=admin123"

echo {"username": "%username%", "password": "%password%"} > "%ADMIN_JSON%"
echo %GREEN%Admin account created successfully.%RESET%

:adminAccountEnd
echo.
goto :eof

:: ===================================
:: Function to update .env file
:: ===================================
:updateEnvFile
echo %YELLOW%Updating configuration...%RESET%

set "envExists="
if exist "%ENV_FILE%" set "envExists=true"

if not defined envExists (
    echo # Server port> "%ENV_FILE%"
    echo PORT=3010>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Log format (tiny, combined, common, dev, short)>> "%ENV_FILE%"
    echo MORGAN_FORMAT=tiny>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # API Key to Cookie mapping (JSON format)>> "%ENV_FILE%"
    echo # Format: {"custom_api_key": "Cookie value"} or {"custom_api_key": ["Cookie value1", "Cookie value2"]}>> "%ENV_FILE%"
    echo API_KEYS={}>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Rotation strategy (random or round-robin or default)>> "%ENV_FILE%"
    echo ROTATION_STRATEGY=default>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Auto-refresh Cookie settings>> "%ENV_FILE%"
    echo # Enable auto-refresh Cookie (true or false)>> "%ENV_FILE%"
    echo ENABLE_AUTO_REFRESH=false>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Auto-refresh Cookie cron schedule (Cron expression)>> "%ENV_FILE%"
    echo # Default: every 6 hours>> "%ENV_FILE%"
    echo REFRESH_CRON=0 */6 * * *>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Minimum Cookie count per API Key>> "%ENV_FILE%"
    echo # Auto-refresh will be triggered when Cookie count is below this threshold>> "%ENV_FILE%"
    echo MIN_COOKIE_COUNT=3>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Cookie refresh mode>> "%ENV_FILE%"
    echo # replace: Mark all existing cookies as invalid and replace with new cookies (default)>> "%ENV_FILE%"
    echo # append: Keep existing cookies, only add new cookies>> "%ENV_FILE%"
    echo COOKIE_REFRESH_MODE=replace>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # TLS proxy settings>> "%ENV_FILE%"
    echo # Whether to use TLS proxy (true or false)>> "%ENV_FILE%"
    echo USE_TLS_PROXY=true>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Proxy server platform>> "%ENV_FILE%"
    echo # Options: auto, windows_x64, linux_x64, android_arm64>> "%ENV_FILE%"
    echo # auto: Auto-detect platform>> "%ENV_FILE%"
    echo PROXY_PLATFORM=auto>> "%ENV_FILE%"
    echo.>> "%ENV_FILE%"
    echo # Log settings>> "%ENV_FILE%"
    echo LOG_LEVEL=INFO>> "%ENV_FILE%"
    echo LOG_FORMAT=colored>> "%ENV_FILE%"
    echo LOG_TO_FILE=true>> "%ENV_FILE%"
    echo LOG_MAX_SIZE=10>> "%ENV_FILE%"
    echo LOG_MAX_FILES=10>> "%ENV_FILE%"
)

:: Update API_KEYS with the Cursor token
if defined apiKey if defined cursorToken (
    powershell -Command "(Get-Content '%ENV_FILE%') -replace 'API_KEYS=\{.*\}', 'API_KEYS={\""%apiKey%\"": \""%cursorToken%\""}' | Set-Content '%ENV_FILE%'"
)

:: Update TLS proxy settings
powershell -Command "(Get-Content '%ENV_FILE%') -replace 'USE_TLS_PROXY=(true|false)', 'USE_TLS_PROXY=%useTlsProxy%' | Set-Content '%ENV_FILE%'"

:: Update proxy platform if specified
if defined proxyPlatform (
    powershell -Command "(Get-Content '%ENV_FILE%') -replace 'PROXY_PLATFORM=.*', 'PROXY_PLATFORM=%proxyPlatform%' | Set-Content '%ENV_FILE%'"
)

echo %GREEN%Configuration updated successfully.%RESET%
echo.
goto :eof

:: ===================================
:: Function to choose deployment method
:: ===================================
:chooseDeploymentMethod
echo %MAGENTA%Deployment Method%RESET%
echo %MAGENTA%================%RESET%
echo.
echo %CYAN%1) Docker (recommended)%RESET%
echo %CYAN%2) npm%RESET%
set /p "deployMethod=Select deployment method [1]: "

if "%deployMethod%" == "2" (
    set "deploymentType=npm"
) else (
    set "deploymentType=docker"
)
echo.
goto :eof

:: ===================================
:: Function to deploy with Docker
:: ===================================
:deployWithDocker
echo %YELLOW%Deploying with Docker...%RESET%

if not exist "%DOCKER_COMPOSE_FILE%" (
    echo %RED%docker-compose.yaml not found.%RESET%
    exit /b 1
)

set "retryCount=0"
set "success=false"

:retryDockerDeploy
docker compose up -d --build
if %errorlevel% equ 0 (
    echo %GREEN%Docker deployment successful.%RESET%
    set "success=true"
) else (
    set /a "retryCount+=1"
    if !retryCount! lss %MAX_RETRIES% (
        echo %YELLOW%Docker deployment failed. Retrying (!retryCount!/%MAX_RETRIES%)...%RESET%
        goto :retryDockerDeploy
    ) else (
        echo %RED%Docker deployment failed after %MAX_RETRIES% attempts.%RESET%
        echo %YELLOW%Would you like to try npm deployment instead? (y/n)%RESET%
        set /p "fallback="
        if /i "%fallback%" == "y" (
            call :deployWithNpm
            exit /b !errorlevel!
        ) else (
            echo %RED%Deployment aborted.%RESET%
            exit /b 1
        )
    )
)
echo.
goto :eof

:: ===================================
:: Function to deploy with npm
:: ===================================
:deployWithNpm
echo %YELLOW%Deploying with npm...%RESET%

set "retryCount=0"
set "success=false"

:retryNpmDeploy
start "Cursor-To-OpenAI-Nexus" cmd /c "npm start"
if %errorlevel% equ 0 (
    echo %GREEN%npm deployment successful.%RESET%
    set "success=true"
) else (
    set /a "retryCount+=1"
    if !retryCount! lss %MAX_RETRIES% (
        echo %YELLOW%npm deployment failed. Retrying (!retryCount!/%MAX_RETRIES%)...%RESET%
        goto :retryNpmDeploy
    ) else (
        echo %RED%npm deployment failed after %MAX_RETRIES% attempts.%RESET%
        echo %YELLOW%Would you like to try Docker deployment instead? (y/n)%RESET%
        set /p "fallback="
        if /i "%fallback%" == "y" (
            call :deployWithDocker
            exit /b !errorlevel!
        ) else (
            echo %RED%Deployment aborted.%RESET%
            exit /b 1
        )
    )
)
echo.
goto :eof

:: ===================================
:: Function to show usage examples
:: ===================================
:showUsageExamples
echo %MAGENTA%Usage Examples%RESET%
echo %MAGENTA%=============%RESET%
echo.

echo %CYAN%Python Example:%RESET%
echo from openai import OpenAI
echo.
echo # Initialize the client with your API key
echo client = OpenAI(api_key="%apiKey%",
echo                base_url="http://localhost:3010/v1")
echo.
echo # Make a request to Claude 3.7 Sonnet Thinking
echo response = client.chat.completions.create(
echo     model="claude-3.7-sonnet-thinking",
echo     messages=[
echo         {"role": "user", "content": "Explain quantum computing in simple terms."},
echo     ],
echo     stream=False
echo )
echo.
echo print(response.choices[0].message.content)
echo.

echo %CYAN%cURL Example:%RESET%
echo curl -X POST http://localhost:3010/v1/chat/completions \
echo   -H "Content-Type: application/json" \
echo   -H "Authorization: Bearer %apiKey%" \
echo   -d '{
echo     "model": "claude-3.7-sonnet-thinking",
echo     "messages": [
echo       {
echo         "role": "user",
echo         "content": "Explain quantum computing in simple terms."
echo       }
echo     ],
echo     "stream": false
echo   }'
echo.

echo %CYAN%Web Interface:%RESET%
echo Access the web interface at: http://localhost:3010
echo Login with your admin credentials to manage API keys and monitor usage.
echo.
goto :eof

:: ===================================
:: Main deployment function
:: ===================================
:startDeployment
call :showHeader
call :checkPrerequisites
call :initializeDirectories
call :backupConfiguration
call :installDependencies
call :getApiKey
call :getCursorToken
call :configureTlsProxy
call :createAdminAccount
call :updateEnvFile
call :chooseDeploymentMethod

if "%deploymentType%" == "docker" (
    call :deployWithDocker
) else (
    call :deployWithNpm
)

if "%success%" == "true" (
    call :showUsageExamples
    
    echo %GREEN%Deployment Complete!%RESET%
    echo %GREEN%=====================%RESET%
    echo %GREEN%Your Cursor-To-OpenAI-Nexus service is now running.%RESET%
    echo %GREEN%Access the web interface at: http://localhost:3010%RESET%
    echo %GREEN%API endpoint: http://localhost:3010/v1%RESET%
    echo %GREEN%API key: %apiKey%%RESET%
    
    echo.
    echo %YELLOW%Maintenance Commands:%RESET%
    if "%deploymentType%" == "npm" (
        echo %CYAN%- Restart service: npm start%RESET%
        echo %CYAN%- Refresh cookies: npm run refresh-cookies%RESET%
        echo %CYAN%- Force refresh cookies: npm run refresh-cookies -- --force%RESET%
    ) else (
        echo %CYAN%- View logs: docker compose logs -f%RESET%
        echo %CYAN%- Restart service: docker compose restart%RESET%
        echo %CYAN%- Stop service: docker compose down%RESET%
    )
) else (
    echo %RED%Deployment failed. Please check the logs for more information.%RESET%
    exit /b 1
)
goto :eof

:: ===================================
:: Start the deployment process
:: ===================================
:main
call :startDeployment
pause
exit /b 0

