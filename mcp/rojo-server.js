#!/usr/bin/env node
/**
 * MCP Server for Rojo control
 * Allows starting, stopping, and checking status of Rojo server
 */

const { spawn, execSync } = require('child_process');
const readline = require('readline');

const ROJO_PATH = '/home/struktured/.cargo/bin/rojo';
const PROJECT_DIR = '/home/struktured/projects/claws-and-paws';
const DEFAULT_PORT = 34872;

let rojoProcess = null;

// MCP Protocol handlers
const tools = {
  rojo_start: {
    description: "Start the Rojo server for live code syncing to Roblox Studio",
    inputSchema: {
      type: "object",
      properties: {
        address: {
          type: "string",
          description: "IP address to listen on (default: 0.0.0.0)",
          default: "0.0.0.0"
        },
        port: {
          type: "number",
          description: "Port to listen on (default: 34872)",
          default: 34872
        }
      }
    }
  },
  rojo_stop: {
    description: "Stop the running Rojo server",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  rojo_status: {
    description: "Check if Rojo server is running and get connection info",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  rojo_restart: {
    description: "Restart the Rojo server (stop then start)",
    inputSchema: {
      type: "object",
      properties: {
        address: {
          type: "string",
          description: "IP address to listen on (default: 0.0.0.0)",
          default: "0.0.0.0"
        }
      }
    }
  }
};

function killExistingRojo() {
  try {
    execSync('pkill -f "rojo serve"', { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

function startRojo(address = '0.0.0.0', port = DEFAULT_PORT) {
  killExistingRojo();

  // Use shell execution to properly background the process
  try {
    const cmd = `nohup ${ROJO_PATH} serve --address ${address} --port ${port} default.project.json > /tmp/rojo.log 2>&1 & echo $!`;
    const pidStr = execSync(cmd, { cwd: PROJECT_DIR, encoding: 'utf8' }).trim();
    const pid = parseInt(pidStr);

    // Give it a moment to start
    execSync('sleep 1');

    // Verify it's running
    try {
      execSync(`ps -p ${pid}`, { stdio: 'ignore' });
    } catch (e) {
      return {
        success: false,
        message: `Rojo failed to start (PID ${pid} not found)`
      };
    }

    return {
      success: true,
      pid: pid,
      address: address,
      port: port,
      message: `Rojo server started on ${address}:${port} (PID: ${pid})`
    };
  } catch (err) {
    return {
      success: false,
      message: `Failed to start Rojo: ${err.message}`
    };
  }
}

function stopRojo() {
  const killed = killExistingRojo();
  rojoProcess = null;
  return {
    success: true,
    message: killed ? "Rojo server stopped" : "No Rojo server was running"
  };
}

function getStatus() {
  try {
    const result = execSync('pgrep -f "rojo serve"', { encoding: 'utf8' });
    const pids = result.trim().split('\n').filter(p => p);

    // Check what port it's listening on
    let portInfo = '';
    try {
      const ssResult = execSync('ss -tlnp | grep 34872', { encoding: 'utf8' });
      portInfo = ssResult.trim();
    } catch (e) {
      portInfo = 'Port info unavailable';
    }

    return {
      running: true,
      pids: pids,
      portInfo: portInfo,
      message: `Rojo is running (PIDs: ${pids.join(', ')})`
    };
  } catch (e) {
    return {
      running: false,
      message: "Rojo server is not running"
    };
  }
}

// MCP Protocol implementation
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

function sendResponse(id, result) {
  const response = {
    jsonrpc: "2.0",
    id: id,
    result: result
  };
  console.log(JSON.stringify(response));
}

function sendError(id, code, message) {
  const response = {
    jsonrpc: "2.0",
    id: id,
    error: { code, message }
  };
  console.log(JSON.stringify(response));
}

rl.on('line', (line) => {
  try {
    const request = JSON.parse(line);
    const { id, method, params } = request;

    if (method === 'initialize') {
      sendResponse(id, {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: "rojo-mcp",
          version: "1.0.0"
        }
      });
    } else if (method === 'tools/list') {
      sendResponse(id, {
        tools: Object.entries(tools).map(([name, tool]) => ({
          name,
          description: tool.description,
          inputSchema: tool.inputSchema
        }))
      });
    } else if (method === 'tools/call') {
      const { name, arguments: args } = params;
      let result;

      switch (name) {
        case 'rojo_start':
          result = startRojo(args?.address || '0.0.0.0', args?.port || DEFAULT_PORT);
          break;
        case 'rojo_stop':
          result = stopRojo();
          break;
        case 'rojo_status':
          result = getStatus();
          break;
        case 'rojo_restart':
          stopRojo();
          // Small delay to ensure clean shutdown
          setTimeout(() => {
            result = startRojo(args?.address || '0.0.0.0');
          }, 500);
          result = { success: true, message: "Restarting Rojo server..." };
          break;
        default:
          sendError(id, -32601, `Unknown tool: ${name}`);
          return;
      }

      sendResponse(id, {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }]
      });
    } else if (method === 'notifications/initialized') {
      // No response needed for notifications
    } else {
      sendError(id, -32601, `Method not found: ${method}`);
    }
  } catch (e) {
    console.error('Error processing request:', e);
  }
});

// Handle clean shutdown
process.on('SIGINT', () => {
  stopRojo();
  process.exit(0);
});

process.on('SIGTERM', () => {
  stopRojo();
  process.exit(0);
});
