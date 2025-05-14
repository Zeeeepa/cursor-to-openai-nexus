# Interactive Deployment Script for Cursor-To-OpenAI-Nexus

This interactive deployment script provides a user-friendly way to set up and deploy the Cursor-To-OpenAI-Nexus service with robust error handling and fallback mechanisms.

## Features

- 🚀 **Interactive Setup**: Step-by-step guided setup process
- 🛡️ **Error Handling**: Automatic retry mechanisms for common failures
- 🔄 **Fallback Options**: Alternative deployment methods if primary method fails
- 💾 **Configuration Backup**: Automatic backup of existing configuration
- 🔐 **Secure Authentication**: Guided process for obtaining Cursor authentication token
- 📊 **Visual Feedback**: Color-coded output for better readability

## Prerequisites

Before running the script, ensure you have:

- Windows operating system
- Node.js (v16 or higher recommended)
- npm (comes with Node.js)
- Git
- Docker (recommended but optional)
- A Cursor account

## Usage

1. Open Command Prompt or PowerShell
2. Navigate to the repository directory
3. Run the script:
   ```
   interactive-deploy.bat
   ```
4. Follow the on-screen prompts

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

## Security Considerations

- Keep your Cursor token secure
- Change the default admin password
- Consider running the service behind a reverse proxy if exposing to the internet
- Regularly refresh your Cursor token for better security

