# StatD MCP Plugin (`statd-mcp`)

Official **Model Context Protocol (MCP)** server for StatD.

Expose live system telemetry, hardware metrics, and local LLM (`llama.cpp` / Ollama) performance directly to AI coding assistants (**Claude Desktop**, **Cursor**, **Antigravity**, **Windsurf**, **Zed**) over standard JSON-RPC 2.0 `stdio`.

Zero external pip dependencies — runs on standard Python 3.

---

## What AI Assistants Can Do With StatD MCP

When an AI assistant has access to StatD MCP, it can actively monitor and diagnose your development machine or remote server:

* **Automated Bottleneck Analysis**: Ask *"Why is my build hanging?"* and the AI checks CPU load, thermal throttling, and RAM saturation.
* **Local LLM Performance Tracking**: Ask *"How fast is my local model generating?"* and the AI inspects tokens/sec, prompt evaluation speed, and KV cache usage.
* **Hardware & System Telemetry**: Ask *"How much free memory and disk do I have?"* without running noisy shell commands.

---

## Installation

Install the plugin via StatD:

```sh
statd install mcp
```

Or run directly from source:

```sh
./plugins/mcp/statd-mcp
```

---

## Configuration

### 1. Claude Desktop

Add `statd` to your Claude Desktop configuration file:

* **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
* **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
* **Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "statd": {
      "command": "statd",
      "args": ["mcp"]
    }
  }
}
```

*(If `statd` is not in your global `PATH`, use the absolute path to `statd-mcp`)*:

```json
{
  "mcpServers": {
    "statd": {
      "command": "/Users/yourname/.config/statd/plugins/mcp/statd-mcp"
    }
  }
}
```

---

### 2. Cursor

1. Open **Cursor Settings** (`Cmd+,` or `Ctrl+,`).
2. Navigate to **Features** > **MCP Servers**.
3. Click **+ Add New MCP Server**:
   * **Name**: `statd`
   * **Type**: `stdio`
   * **Command**: `statd mcp`

---

### 3. Antigravity / Gemini IDE

Add to your workspace or global `mcp_config.json`:

```json
{
  "mcpServers": {
    "statd": {
      "command": "statd",
      "args": ["mcp"]
    }
  }
}
```

---

### 4. Windsurf

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "statd": {
      "command": "statd",
      "args": ["mcp"]
    }
  }
}
```

---

## Tools Exposed to AI

| Tool | Description |
| :--- | :--- |
| `statd_get_metrics` | Instantaneous real-time system metrics (CPU load, memory, swap, disk, temperature, battery, GPU). |
| `statd_get_llm_metrics` | Telemetry on active local LLMs (`llama.cpp`, Ollama): tokens/sec, KV cache ratio, process PID, RSS memory. |
| `statd_get_system_info` | Host hardware specifications, OS name/version, kernel, CPU architecture, core count, and uptime. |
| `statd_diagnose_bottlenecks` | Automated system analysis detecting thermal throttling, memory pressure, swap thrashing, or high load. |

---

## Resources Exposed to AI

* `statd://system/metrics` — Live system metrics snapshot in JSON.
* `statd://system/diagnostics` — Automated system health and bottleneck assessment.

---

## CLI Testing

You can test the MCP server locally without launching an AI client:

```sh
# Run built-in test suite
statd mcp --test

# Or test with the official MCP Inspector
npx @modelcontextprotocol/inspector statd mcp
```
