# Cursor-To-OpenAI-Nexus Deployment Guide

This guide explains how to deploy the Cursor-To-OpenAI-Nexus service using the automated deployment script.

## Overview

Cursor-To-OpenAI-Nexus is a service that allows you to use Cursor AI models (including Claude 3.7 Sonnet Thinking) through an OpenAI-compatible API. This means you can use your favorite OpenAI client libraries and tools with Cursor's powerful models.

## Prerequisites

Before deploying, ensure you have the following:

- **Node.js** (v16 or higher)
- **npm** (comes with Node.js)
- **Docker** (recommended for deployment)
- **Git** (for version control)
- **A Cursor account** (to obtain authentication token)

## Deployment Options

The deployment script offers two deployment methods:

1. **Docker** (recommended): Runs the service in isolated containers
2. **npm**: Runs the service directly on your system

## Automated Deployment

### Quick Start

1. Run the deployment script:
   ```
   ./deploy.bat
   ```
   or
   ```
   powershell -ExecutionPolicy Bypass -File deploy.ps1
   ```

2. Follow the interactive prompts to:
   - Enter your custom API key
   - Authenticate with Cursor (browser-based or manual token entry)
   - Configure TLS proxy settings (recommended to avoid blocks)
   - Create an admin account
   - Choose your deployment method

3. After deployment, the service will be available at:
   - Web interface: http://localhost:3010
   - API endpoint: http://localhost:3010/v1

### Deployment Process Details

The deployment script performs the following steps:

1. **Prerequisite Check**: Verifies that required software is installed
2. **Directory Initialization**: Creates necessary directories
3. **Configuration Backup**: Backs up any existing configuration
4. **Dependency Installation**: Installs required npm packages
5. **API Key Configuration**: Sets up your custom API key
6. **Cursor Authentication**: Obtains your Cursor session token
7. **TLS Proxy Configuration**: Sets up TLS proxy to avoid blocks
8. **Admin Account Creation**: Creates an account for the web interface
9. **Environment Configuration**: Updates the .env file with your settings
10. **Service Deployment**: Deploys using Docker or npm
11. **Usage Examples**: Provides examples for using the service

## Authentication Methods

The script offers two methods to authenticate with Cursor:

1. **Browser-based**: Opens a browser for you to log in to Cursor, then guides you to extract the token
2. **Manual entry**: You provide the token manually (useful if you already have it)

To manually obtain your Cursor token:
1. Log in to Cursor at https://www.cursor.com
2. Open browser developer tools (F12)
3. Go to Application tab → Cookies
4. Find and copy the 'WorkosCursorSessionToken' value

## TLS Proxy

The TLS proxy helps avoid blocks when making requests to Cursor's API. It's recommended to enable this feature.

The script supports multiple platforms:
- Windows (64-bit)
- Linux (64-bit)
- Android (ARM64)
- Auto-detect (recommended)

## Using the Service

After deployment, you can use the service with any OpenAI-compatible client:

### Python Example

```python
from openai import OpenAI

# Initialize the client with your API key
client = OpenAI(api_key="your_api_key",
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
```

### cURL Example

```bash
curl -X POST http://localhost:3010/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
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
```

## Maintenance

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

1. **Check logs**: Look for error messages in the console output
2. **Verify prerequisites**: Ensure all required software is installed
3. **Check Cursor token**: Make sure your Cursor authentication token is valid
4. **TLS proxy issues**: Try disabling the TLS proxy if you're having connection problems
5. **Port conflicts**: Make sure port 3010 is not in use by another application

## Security Considerations

- Keep your Cursor token secure
- Change the default admin password
- Consider running the service behind a reverse proxy if exposing to the internet
- Regularly refresh your Cursor token for better security

## Support

If you need help with deployment or using the service, please open an issue on the GitHub repository.

