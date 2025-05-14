# WSL2 Deployment Script for Cursor-To-OpenAI-Nexus

This interactive deployment script provides a user-friendly way to set up and deploy the Cursor-To-OpenAI-Nexus service in a WSL2 (Windows Subsystem for Linux) environment with robust error handling and fallback mechanisms.

## Features

- 🚀 **Interactive Setup**: Step-by-step guided setup process
- 🛡️ **Error Handling**: Automatic retry mechanisms for common failures
- 🔄 **Fallback Options**: Alternative deployment methods if primary method fails
- 💾 **Configuration Backup**: Automatic backup of existing configuration
- 🔐 **Secure Authentication**: Guided process for obtaining Cursor authentication token
- 📊 **Visual Feedback**: Color-coded output for better readability
- 🐧 **WSL2 Optimized**: Specifically designed for Windows Subsystem for Linux environments

## Prerequisites

Before running the script, ensure you have:

- WSL2 installed on Windows
- Ubuntu or another Linux distribution running in WSL2
- Node.js (v16 or higher recommended)
- npm (comes with Node.js)
- Git
- Docker (recommended but optional)
- A Cursor account

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Zeeeepa/cursor-to-openai-nexus.git
   cd cursor-to-openai-nexus
   ```

2. Make the script executable:
   ```bash
   chmod +x interactive-deploy-wsl.sh
   ```

3. Run the script:
   ```bash
   ./interactive-deploy-wsl.sh
   ```

## Deployment Process

The script will guide you through the following steps:

1. **Prerequisite Check**: Verifies required software is installed
2. **Directory Setup**: Creates necessary directories
3. **Configuration Backup**: Backs up any existing configuration
4. **Dependency Installation**: Installs required npm packages
5. **API Key Configuration**: Sets up your custom API key
6. **Cursor Authentication**: Helps you obtain and configure your Cursor token
7. **TLS Proxy Configuration**: Configures TLS proxy settings
8. **Admin Account Creation**: Sets up admin credentials for the web interface
9. **Deployment Method Selection**: Choose between Docker and npm deployment
10. **Service Deployment**: Deploys and starts the service
11. **Usage Examples**: Provides examples for using the service

## WSL2-Specific Features

The script includes several optimizations for WSL2:

- **Browser Integration**: Opens Windows browser for Cursor login when needed
- **Path Handling**: Properly handles WSL2 paths
- **Process Management**: Correctly manages background processes in WSL2
- **Terminal Output**: Optimized for WSL2 terminal capabilities

## Error Handling

The script includes several error handling mechanisms:

- **Automatic Retries**: Automatically retries failed operations up to 3 times
- **Deployment Fallbacks**: If Docker deployment fails, offers to try npm deployment (and vice versa)
- **Prerequisite Warnings**: Warns about missing prerequisites but allows continuing if possible
- **Configuration Backups**: Creates backups before making changes to prevent data loss

## Cursor Authentication Methods

The script offers two methods to authenticate with Cursor:

1. **Manual Token Entry**: Manually enter your Cursor token
2. **Browser-Based Login**: Opens a browser for you to log in, then guides you through extracting the token

## Maintenance

After deployment, you can use the following commands for maintenance:

### Docker Deployment
- View logs: `docker compose logs -f`
- Restart service: `docker compose restart`
- Stop service: `docker compose down`

### npm Deployment
- Restart service: `npm start`
- Refresh cookies: `npm run refresh-cookies`
- Force refresh cookies: `npm run refresh-cookies -- --force`

## Troubleshooting

If you encounter issues during deployment:

- Check the console output for specific error messages
- Verify that all prerequisites are installed correctly
- Ensure your Cursor token is valid
- Try the alternative deployment method
- Check if port 3010 is already in use by another application
- Verify WSL2 is properly configured and has network access

### Common WSL2 Issues

1. **Browser Integration**: If the browser doesn't open automatically, manually navigate to https://www.cursor.com
2. **Docker Issues**: Ensure Docker Desktop is configured to work with WSL2
3. **Permission Issues**: If you encounter permission errors, try running the script with sudo
4. **Network Issues**: If the service can't connect to the internet, check your WSL2 network configuration

## Security Considerations

- Keep your Cursor token secure
- Change the default admin password
- Consider running the service behind a reverse proxy if exposing to the internet
- Regularly refresh your Cursor token for better security

