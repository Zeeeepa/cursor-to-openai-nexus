#!/usr/bin/env node

/**
 * Cursor Launch Tool
 * 
 * This script helps you select an account and launch the Cursor-to-OpenAI-Nexus service with Docker.
 * It provides options to view configured accounts, test connections, and start the service.
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync, spawn } = require('child_process');
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

// Configuration paths
const ENV_FILE = path.join(process.cwd(), '.env');
const DOCKER_COMPOSE_FILE = path.join(process.cwd(), 'docker-compose.yaml');
const DATA_DIR = path.join(process.cwd(), 'data');
const ADMIN_JSON = path.join(DATA_DIR, 'admin.json');

// Print header
function printHeader() {
  console.log(`${BLUE}=======================================`);
  console.log(`${GREEN}    Cursor-To-OpenAI-Nexus Launch    `);
  console.log(`${BLUE}=======================================`);
  console.log('');
}

// Check if a command exists
function commandExists(command) {
  try {
    const result = process.platform === 'win32'
      ? execSync(`where ${command}`, { stdio: 'ignore' })
      : execSync(`which ${command}`, { stdio: 'ignore' });
    return true;
  } catch (error) {
    return false;
  }
}

// Check prerequisites
function checkPrerequisites() {
  console.log(`${YELLOW}Checking prerequisites...${RESET}`);
  
  const prerequisites = {
    "Node.js": () => commandExists('node'),
    "npm": () => commandExists('npm'),
    "Docker": () => commandExists('docker'),
    "Git": () => commandExists('git')
  };
  
  let allMet = true;
  
  for (const [prereq, checkFn] of Object.entries(prerequisites)) {
    const check = checkFn();
    if (check) {
      console.log(`${GREEN}✓ ${prereq} is installed${RESET}`);
    } else {
      console.log(`${RED}✗ ${prereq} is not installed${RESET}`);
      allMet = false;
    }
  }
  
  // Check Node.js version
  if (commandExists('node')) {
    const nodeVersion = execSync('node --version').toString().trim().substring(1);
    console.log(`  ${YELLOW}Node.js version: ${nodeVersion}${RESET}`);
    
    // Parse version and check if it's at least 16
    const majorVersion = parseInt(nodeVersion.split('.')[0]);
    
    if (majorVersion < 16) {
      console.log(`  ${YELLOW}⚠️ Node.js version 16 or higher is recommended${RESET}`);
    }
  }
  
  return allMet;
}

// Load configuration
function loadConfig() {
  if (!fs.existsSync(ENV_FILE)) {
    console.log(`${RED}Error: .env file not found. Please run cursor-setup.js first.${RESET}`);
    return null;
  }
  
  try {
    const envConfig = dotenv.parse(fs.readFileSync(ENV_FILE));
    
    // Extract API Keys
    let apiKeys = {};
    if (envConfig.API_KEYS) {
      try {
        apiKeys = JSON.parse(envConfig.API_KEYS);
      } catch (e) {
        console.log(`${RED}Unable to parse API Keys configuration.${RESET}`);
      }
    }
    
    // Extract other settings
    const config = {
      apiKeys,
      useTlsProxy: envConfig.USE_TLS_PROXY === 'true',
      proxyPlatform: envConfig.PROXY_PLATFORM || 'auto',
      cookieRefreshMode: envConfig.COOKIE_REFRESH_MODE || 'replace',
      port: envConfig.PORT || '3010'
    };
    
    return config;
  } catch (error) {
    console.error(`${RED}Error loading configuration:${RESET}`, error.message);
    return null;
  }
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

// Display configured accounts
function displayAccounts(config) {
  const apiKeys = Object.keys(config.apiKeys);
  
  if (apiKeys.length === 0) {
    console.log(`${RED}No API Keys configured. Please run cursor-setup.js to add API Keys.${RESET}`);
    return false;
  }
  
  console.log(`${BLUE}Configured Accounts:${RESET}`);
  apiKeys.forEach((key, index) => {
    const value = config.apiKeys[key];
    const tokenPreview = typeof value === 'string' 
      ? (value.length > 10 ? `${value.substring(0, 10)}...` : value)
      : Array.isArray(value) 
        ? `${value.length} cookies` 
        : 'No token';
    
    console.log(`${index + 1}. ${key} (${tokenPreview})`);
  });
  
  return true;
}

// Test connection to Cursor API
async function testConnection(apiKey, token) {
  console.log(`${YELLOW}Testing connection for API Key: ${apiKey}...${RESET}`);
  
  try {
    // Simple test to check if the token is valid
    if (!token || (typeof token === 'string' && token.trim() === '')) {
      console.log(`${RED}No token available for testing.${RESET}`);
      return false;
    }
    
    console.log(`${GREEN}Token is available for API Key: ${apiKey}${RESET}`);
    console.log(`${YELLOW}Note: Full connection test will be performed when the service is running.${RESET}`);
    return true;
  } catch (error) {
    console.error(`${RED}Connection test failed:${RESET}`, error.message);
    return false;
  }
}

// Create admin account
async function createAdminAccount() {
  console.log(`\n${YELLOW}Setting up admin account...${RESET}`);
  
  // Check if admin.json already exists
  if (fs.existsSync(ADMIN_JSON)) {
    const overwrite = await promptWithDefault('Admin account already exists. Overwrite? (y/n)', 'n');
    if (overwrite.toLowerCase() !== 'y') {
      console.log(`${YELLOW}Keeping existing admin account${RESET}`);
      return true;
    }
  }
  
  // Now prompt for username and password
  const username = await promptWithDefault('Enter admin username', 'admin');
  const password = await promptWithDefault('Enter admin password', 'admin123');
  
  // Update admin.json
  const adminConfig = {
    "username": username,
    "password": password
  };
  
  try {
    // Ensure data directory exists
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    
    fs.writeFileSync(ADMIN_JSON, JSON.stringify(adminConfig, null, 2), 'utf8');
    console.log(`${GREEN}Admin account created successfully${RESET}`);
    return true;
  } catch (error) {
    console.error(`${RED}Error creating admin account:${RESET}`, error.message);
    return false;
  }
}

// Deploy with Docker
async function deployWithDocker() {
  console.log(`\n${YELLOW}Deploying with Docker...${RESET}`);
  
  // Check if docker-compose.yaml exists
  if (!fs.existsSync(DOCKER_COMPOSE_FILE)) {
    console.log(`${RED}docker-compose.yaml not found${RESET}`);
    return false;
  }
  
  try {
    // Build and start containers
    console.log(`${YELLOW}Building and starting containers...${RESET}`);
    execSync('docker compose up -d --build', { stdio: 'inherit' });
    
    console.log(`${GREEN}Docker deployment successful${RESET}`);
    return true;
  } catch (error) {
    console.error(`${RED}Error deploying with Docker:${RESET}`, error.message);
    return false;
  }
}

// Deploy with npm
async function deployWithNpm() {
  console.log(`\n${YELLOW}Deploying with npm...${RESET}`);
  
  try {
    // Start the application with npm
    console.log(`${YELLOW}Starting the application...${RESET}`);
    
    const npmStart = spawn('npm', ['start'], { 
      detached: true,
      stdio: 'inherit'
    });
    
    // Don't wait for the process to exit
    npmStart.unref();
    
    console.log(`${GREEN}npm deployment successful${RESET}`);
    return true;
  } catch (error) {
    console.error(`${RED}Error deploying with npm:${RESET}`, error.message);
    return false;
  }
}

// Show usage examples
function showUsageExamples(apiKey, port) {
  console.log(`\n${MAGENTA}Usage Examples${RESET}`);
  console.log(`${MAGENTA}==============${RESET}`);
  
  // Python example
  console.log(`\n${YELLOW}Python Example:${RESET}`);
  const pythonExample = `from openai import OpenAI

# Initialize the client with your API key
client = OpenAI(api_key="${apiKey}",
                base_url="http://localhost:${port}/v1")

# Make a request to Claude 3.7 Sonnet Thinking
response = client.chat.completions.create(
    model="claude-3.7-sonnet-thinking",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms."},
    ],
    stream=False
)

print(response.choices[0].message.content)`;
  console.log(pythonExample);
  
  // cURL example
  console.log(`\n${YELLOW}cURL Example:${RESET}`);
  const curlExample = `curl -X POST http://localhost:${port}/v1/chat/completions \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer ${apiKey}" \\
  -d '{
    "model": "claude-3.7-sonnet-thinking",
    "messages": [
      {
        "role": "user",
        "content": "Explain quantum computing in simple terms."
      }
    ],
    "stream": false
  }'`;
  console.log(curlExample);
  
  // Web UI
  console.log(`\n${YELLOW}Web Interface:${RESET}`);
  console.log(`Access the web interface at: http://localhost:${port}`);
  console.log(`Login with your admin credentials to manage API keys and monitor usage.`);
}

// Main function
async function main() {
  try {
    printHeader();
    
    // Check prerequisites
    const prereqsMet = checkPrerequisites();
    if (!prereqsMet) {
      const continue_ = await promptWithDefault('\nSome prerequisites are missing. Would you like to continue anyway? (y/n)', 'n');
      if (continue_.toLowerCase() !== 'y') {
        console.log(`${RED}Launch aborted${RESET}`);
        return;
      }
    }
    
    // Load configuration
    const config = loadConfig();
    if (!config) {
      console.log(`${RED}Failed to load configuration. Please run cursor-setup.js first.${RESET}`);
      return;
    }
    
    // Display configured accounts
    const hasAccounts = displayAccounts(config);
    if (!hasAccounts) {
      return;
    }
    
    // Select account to use
    const apiKeys = Object.keys(config.apiKeys);
    let selectedApiKey = apiKeys[0];
    
    if (apiKeys.length > 1) {
      const selection = await promptWithDefault(`\nSelect account to use (1-${apiKeys.length})`, '1');
      const index = parseInt(selection) - 1;
      
      if (isNaN(index) || index < 0 || index >= apiKeys.length) {
        console.log(`${RED}Invalid selection. Using the first account.${RESET}`);
      } else {
        selectedApiKey = apiKeys[index];
      }
    }
    
    console.log(`${GREEN}Selected API Key: ${selectedApiKey}${RESET}`);
    
    // Test connection
    const token = config.apiKeys[selectedApiKey];
    await testConnection(selectedApiKey, token);
    
    // Create admin account
    const adminCreated = await createAdminAccount();
    if (!adminCreated) {
      console.log(`${RED}Failed to create admin account. Launch aborted.${RESET}`);
      return;
    }
    
    // Choose deployment method
    console.log(`\n${MAGENTA}Deployment Method${RESET}`);
    console.log(`${MAGENTA}================${RESET}`);
    console.log(`1) Docker (recommended)`);
    console.log(`2) npm`);
    
    const deployMethod = await promptWithDefault('Select deployment method', '1');
    
    let deploymentSuccess = false;
    
    if (deployMethod === '2') {
      deploymentSuccess = await deployWithNpm();
    } else {
      deploymentSuccess = await deployWithDocker();
    }
    
    if (deploymentSuccess) {
      // Show usage examples
      showUsageExamples(selectedApiKey, config.port);
      
      console.log(`\n${GREEN}Deployment Complete!${RESET}`);
      console.log(`${GREEN}=====================${RESET}`);
      console.log(`${GREEN}Your Cursor-To-OpenAI-Nexus service is now running.${RESET}`);
      console.log(`${GREEN}Access the web interface at: http://localhost:${config.port}${RESET}`);
      console.log(`${GREEN}API endpoint: http://localhost:${config.port}/v1${RESET}`);
      console.log(`${GREEN}API key: ${selectedApiKey}${RESET}`);
      
      // Provide maintenance commands
      console.log(`\n${YELLOW}Maintenance Commands:${RESET}`);
      if (deployMethod === '2') {
        console.log(`- Restart service: npm start`);
        console.log(`- Refresh cookies: npm run refresh-cookies`);
        console.log(`- Force refresh cookies: npm run refresh-cookies -- --force`);
      } else {
        console.log(`- View logs: docker compose logs -f`);
        console.log(`- Restart service: docker compose restart`);
        console.log(`- Stop service: docker compose down`);
      }
    } else {
      console.log(`\n${RED}Deployment failed. Please check the logs for more information.${RESET}`);
    }
  } catch (error) {
    console.error(`\n${RED}Error during launch:${RESET}`, error.message);
  } finally {
    rl.close();
  }
}

// Run main function
main();

