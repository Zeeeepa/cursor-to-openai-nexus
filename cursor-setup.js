#!/usr/bin/env node

/**
 * Cursor Setup Tool
 * 
 * This script helps you create API keys and retrieve tokens from the Cursor website.
 * It handles the initial setup process for the Cursor-to-OpenAI-Nexus service.
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');
const dotenv = require('dotenv');

// Create interactive command line interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Colors for better UI
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[36m';
const MAGENTA = '\x1b[35m';
const RESET = '\x1b[0m';

// Configuration template
const ENV_TEMPLATE = `# Server port
PORT=3010

# Log format (tiny, combined, common, dev, short)
MORGAN_FORMAT=tiny

# API Key to Cookie mapping (JSON format)
# Format: {"custom_api_key": "Cookie value"} or {"custom_api_key": ["Cookie value1", "Cookie value2"]}
API_KEYS={API_KEYS_PLACEHOLDER}

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
`;

// Print header
function printHeader() {
  console.log(`${BLUE}=======================================`);
  console.log(`${GREEN}    Cursor-To-OpenAI-Nexus Setup    `);
  console.log(`${BLUE}=======================================`);
  console.log('');
}

// Load existing configuration
function loadExistingConfig() {
  const envPath = path.join(process.cwd(), '.env');
  let existingConfig = {
    apiKeys: {},
    useTlsProxy: true,
    proxyPlatform: 'auto',
    cookieRefreshMode: 'replace'
  };
  
  if (fs.existsSync(envPath)) {
    console.log(`${YELLOW}Found existing .env configuration file. Loading existing settings as defaults.`);
    console.log(`${YELLOW}Tip: Press Enter to keep existing settings unchanged.\n${RESET}`);
    
    try {
      // Load .env file
      const envConfig = dotenv.parse(fs.readFileSync(envPath));
      
      // Extract API Keys
      if (envConfig.API_KEYS) {
        try {
          existingConfig.apiKeys = JSON.parse(envConfig.API_KEYS);
        } catch (e) {
          console.log(`${RED}Unable to parse existing API Keys configuration, will use default settings.${RESET}`);
        }
      }
      
      // Extract TLS proxy configuration
      if (envConfig.USE_TLS_PROXY !== undefined) {
        existingConfig.useTlsProxy = envConfig.USE_TLS_PROXY === 'true';
      }
      
      // Extract proxy server platform
      if (envConfig.PROXY_PLATFORM) {
        existingConfig.proxyPlatform = envConfig.PROXY_PLATFORM;
      }
      
      // Extract Cookie refresh mode
      if (envConfig.COOKIE_REFRESH_MODE) {
        existingConfig.cookieRefreshMode = envConfig.COOKIE_REFRESH_MODE;
      }
      
      console.log(`${GREEN}Successfully loaded existing configuration.${RESET}`);
    } catch (error) {
      console.error(`${RED}Error loading existing configuration:${RESET}`, error.message);
      console.log(`${YELLOW}Will use default settings.${RESET}`);
    }
  } else {
    console.log(`${YELLOW}No existing .env configuration file found. Will create a new configuration file.${RESET}`);
  }
  
  return existingConfig;
}

// Prompt user for input with default value
function promptWithDefault(question, defaultValue) {
  return new Promise((resolve) => {
    const defaultText = defaultValue ? ` [${defaultValue}]` : '';
    rl.question(`${question}${defaultText}: `, (answer) => {
      // If user just pressed Enter, use default value
      resolve(answer.trim() || defaultValue || '');
    });
  });
}

// Get Cursor authentication token
async function getCursorToken() {
  console.log(`\n${MAGENTA}Cursor Authentication`);
  console.log(`===================${RESET}`);
  
  const method = await promptWithDefault('How would you like to authenticate with Cursor?\n1) Manually enter token\n2) Open browser for login\nEnter choice (1/2)', '1');
  
  if (method === '1') {
    console.log(`\n${YELLOW}To get your Cursor token:${RESET}`);
    console.log(`${YELLOW}1. Log in to Cursor at https://www.cursor.com${RESET}`);
    console.log(`${YELLOW}2. Open browser developer tools (F12)${RESET}`);
    console.log(`${YELLOW}3. Go to Application tab -> Cookies${RESET}`);
    console.log(`${YELLOW}4. Find and copy the 'WorkosCursorSessionToken' value${RESET}`);
    
    const token = await promptWithDefault('\nEnter your Cursor token (WorkosCursorSessionToken)', '');
    return token;
  } else {
    console.log(`\n${YELLOW}Opening browser for Cursor login...${RESET}`);
    console.log(`${YELLOW}Please log in to your Cursor account in the browser.${RESET}`);
    
    // Open browser to Cursor login page
    try {
      if (process.platform === 'win32') {
        execSync('start https://www.cursor.com');
      } else if (process.platform === 'darwin') {
        execSync('open https://www.cursor.com');
      } else {
        execSync('xdg-open https://www.cursor.com');
      }
    } catch (error) {
      console.log(`${RED}Failed to open browser automatically. Please open https://www.cursor.com manually.${RESET}`);
    }
    
    await promptWithDefault('After logging in, press Enter to continue...', '');
    
    // Ask for token after login
    console.log(`\n${YELLOW}Now please get your token from the browser:${RESET}`);
    console.log(`${YELLOW}1. In the same browser window, open developer tools (F12)${RESET}`);
    console.log(`${YELLOW}2. Go to Application tab -> Cookies${RESET}`);
    console.log(`${YELLOW}3. Find and copy the 'WorkosCursorSessionToken' value${RESET}`);
    
    const token = await promptWithDefault('\nEnter your Cursor token (WorkosCursorSessionToken)', '');
    return token;
  }
}

// Collect configuration information
async function collectConfig() {
  // Load existing configuration
  const existingConfig = loadExistingConfig();
  
  const config = {
    apiKeys: {},
    useTlsProxy: existingConfig.useTlsProxy,
    proxyPlatform: existingConfig.proxyPlatform,
    cookieRefreshMode: existingConfig.cookieRefreshMode
  };

  // Handle API Keys
  const existingApiKeys = Object.keys(existingConfig.apiKeys);
  if (existingApiKeys.length > 0) {
    console.log(`\n${YELLOW}Existing API Keys:${RESET}`);
    existingApiKeys.forEach(key => console.log(`- ${key}`));
    
    const keepExistingApiKeys = await promptWithDefault('Keep existing API Keys? (y/n)', 'y');
    if (keepExistingApiKeys.toLowerCase() === 'y') {
      config.apiKeys = { ...existingConfig.apiKeys };
    }
  }

  // Ask whether to add a new API Key
  const addNewApiKey = await promptWithDefault('Add a new API Key? (y/n)', existingApiKeys.length === 0 ? 'y' : 'n');
  if (addNewApiKey.toLowerCase() === 'y') {
    const apiKey = await promptWithDefault('Enter custom API Key (without sk- prefix, will be added automatically)', '');
    if (apiKey) {
      const fullApiKey = apiKey.startsWith('sk-') ? apiKey : `sk-${apiKey}`;
      
      // Get Cursor token
      console.log(`\n${YELLOW}Now we need to get a Cursor token for this API Key.${RESET}`);
      const cursorToken = await getCursorToken();
      
      if (cursorToken) {
        config.apiKeys[fullApiKey] = cursorToken;
        console.log(`${GREEN}Successfully added API Key: ${fullApiKey}${RESET}`);
      } else {
        console.log(`${RED}No Cursor token provided. API Key will be added without a token.${RESET}`);
        config.apiKeys[fullApiKey] = '';
      }
    }
  }

  // Ask about Cookie refresh mode
  const refreshModePrompt = `Choose Cookie refresh mode [append/replace]`;
  const defaultRefreshMode = existingConfig.cookieRefreshMode || 'replace';
  config.cookieRefreshMode = await promptWithDefault(refreshModePrompt, defaultRefreshMode);

  // Explain the selected refresh mode
  if (config.cookieRefreshMode.toLowerCase() === 'replace') {
    config.cookieRefreshMode = 'replace';
    console.log(`${YELLOW}Selected replace mode: All existing cookies will be marked as invalid and replaced with new cookies.${RESET}`);
  } else {
    config.cookieRefreshMode = 'append';
    console.log(`${YELLOW}Selected append mode: Existing cookies will be kept, only new cookies will be added.${RESET}`);
  }

  // Ask about TLS proxy
  const useTlsProxyPrompt = `Use TLS proxy server? (y/n)`;
  const defaultUseTlsProxy = existingConfig.useTlsProxy ? 'y' : 'n';
  const useTlsProxyAnswer = await promptWithDefault(useTlsProxyPrompt, defaultUseTlsProxy);
  config.useTlsProxy = useTlsProxyAnswer.toLowerCase() === 'y';

  if (config.useTlsProxy) {
    // Ask about proxy server platform
    console.log(`\n${YELLOW}Proxy server platform options:${RESET}`);
    console.log(`- auto: Auto-detect current system platform`);
    console.log(`- windows_x64: Windows 64-bit`);
    console.log(`- linux_x64: Linux 64-bit`);
    console.log(`- android_arm64: Android ARM 64-bit`);
    
    const proxyPlatformPrompt = `Select proxy server platform`;
    const defaultProxyPlatform = existingConfig.proxyPlatform || 'auto';
    config.proxyPlatform = await promptWithDefault(proxyPlatformPrompt, defaultProxyPlatform);
  }

  return config;
}

// Generate configuration file
function generateEnvFile(config) {
  try {
    // Prepare API Keys
    const apiKeysJson = JSON.stringify(config.apiKeys);
    
    // Replace placeholders in template
    let envContent = ENV_TEMPLATE
      .replace('{API_KEYS_PLACEHOLDER}', apiKeysJson);
      
    // Update Cookie refresh mode
    envContent = envContent.replace('COOKIE_REFRESH_MODE=replace', `COOKIE_REFRESH_MODE=${config.cookieRefreshMode}`);
    
    // Update TLS proxy configuration
    envContent = envContent.replace('USE_TLS_PROXY=true', `USE_TLS_PROXY=${config.useTlsProxy}`);
    
    // Update proxy server platform
    envContent = envContent.replace('PROXY_PLATFORM=auto', `PROXY_PLATFORM=${config.proxyPlatform}`);
    
    // Write to .env file
    const envPath = path.join(process.cwd(), '.env');
    
    // Check if backup file exists
    const backupPath = path.join(process.cwd(), '.env.backup');
    if (fs.existsSync(envPath)) {
      // Create backup
      fs.copyFileSync(envPath, backupPath);
      console.log(`\n${GREEN}✅ Created backup of original configuration file: ${backupPath}${RESET}`);
    }
    
    fs.writeFileSync(envPath, envContent, 'utf8');
    console.log(`\n${GREEN}✅ Configuration file generated: ${envPath}${RESET}`);
    
    // Check data directory
    const dataDir = path.join(process.cwd(), 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
      console.log(`${GREEN}✅ Created data directory: ${dataDir}${RESET}`);
    }
    
    // Create admin.json if it doesn't exist
    const adminJsonPath = path.join(dataDir, 'admin.json');
    const adminExampleJsonPath = path.join(dataDir, 'admin.example.json');
    
    if (!fs.existsSync(adminJsonPath)) {
      if (fs.existsSync(adminExampleJsonPath)) {
        fs.copyFileSync(adminExampleJsonPath, adminJsonPath);
        console.log(`${GREEN}✅ Created admin.json from example${RESET}`);
      } else {
        const adminTemplate = {
          "username": "admin",
          "password": "admin123"
        };
        fs.writeFileSync(adminJsonPath, JSON.stringify(adminTemplate, null, 2), 'utf8');
        console.log(`${GREEN}✅ Created default admin.json${RESET}`);
      }
    }
    
    return true;
  } catch (error) {
    console.error(`\n${RED}❌ Error generating configuration file:${RESET}`, error.message);
    return false;
  }
}

// Main function
async function main() {
  try {
    printHeader();
    
    const config = await collectConfig();
    
    if (generateEnvFile(config)) {
      console.log(`\n${GREEN}===== Setup Complete =====${RESET}`);
      console.log(`${YELLOW}Your configuration has been saved to .env${RESET}`);
      console.log(`${YELLOW}API Keys: ${Object.keys(config.apiKeys).length} key(s) configured${RESET}`);
      console.log(`${YELLOW}TLS Proxy: ${config.useTlsProxy ? 'Enabled' : 'Disabled'}${RESET}`);
      if (config.useTlsProxy) {
        console.log(`${YELLOW}Proxy Platform: ${config.proxyPlatform}${RESET}`);
      }
      console.log(`${YELLOW}Cookie Refresh Mode: ${config.cookieRefreshMode}${RESET}`);
      
      console.log(`\n${BLUE}Next Steps:${RESET}`);
      console.log(`1. Run 'node cursor-launch.js' to select an account and launch the service`);
      console.log(`2. Access the web interface at: http://localhost:3010`);
      console.log(`3. Default admin credentials: admin / admin123`);
    }
  } catch (error) {
    console.error(`\n${RED}❌ Error during setup:${RESET}`, error.message);
  } finally {
    rl.close();
  }
}

// Run main function
main();

