# StatD API Plugin (`statd-api`)

Ultra-low CPU HTTP JSON & Server-Sent Events (SSE) streaming API for StatD.

Expose live system metrics so you can build custom web dashboards, raycast extensions, desktop widgets, or mobile apps on top of StatD with near-zero CPU footprint.

---

## Installation

Install the plugin via StatD:

```sh
statd install api
```

Or run directly from source:

```sh
./plugins/api/statd-api
```

---

## Quickstart

Start the API server on default port `8080`:

```sh
statd api
```

Or start in the background as a daemon:

```sh
statd api --daemon --port 8080
```

Check status or stop:

```sh
statd api status
statd api stop
```

---

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/stats` | Instantaneous system metrics snapshot (JSON) |
| `GET` | `/stream` | Server-Sent Events (SSE) live real-time metrics stream (1 evt/sec) |
| `GET` | `/health` | Health check (`{"status":"ok"}`) |
| `GET` | `/` | API overview and endpoints list |

All endpoints include permissive CORS headers (`Access-Control-Allow-Origin: *`) allowing direct browser connections from any origin.

---

## Examples

### 1. Querying JSON Snapshot (`GET /stats`)

```sh
curl http://127.0.0.1:8080/stats
```

Example JSON response:
```json
{
  "timestamp": "2026-09-14T03:56:21Z",
  "uptime": "22h 36m",
  "cpu": {
    "percent": 9,
    "freq": "4.80GHz",
    "temp": "38C",
    "cores": 10
  },
  "memory": {
    "total_bytes": 34359738368,
    "used_bytes": 23539974144,
    "percent": 68
  },
  "swap": {
    "total_bytes": 16106127360,
    "used_bytes": 14905108480,
    "percent": 92
  },
  "disk": {
    "total_bytes": 494384795648,
    "used_bytes": 335007055872,
    "percent": 67
  },
  "load": {
    "l1": "7.88",
    "l5": "6.28",
    "l15": "5.16"
  },
  "battery": {
    "percent": 80,
    "status": "AC attached"
  }
}
```

### 2. Live Browser Dashboard (JavaScript SSE)

In your HTML/JavaScript web app:

```javascript
const source = new EventSource('http://localhost:8080/stream');

source.onmessage = (event) => {
  const stats = JSON.parse(event.data);
  console.log(`CPU: ${stats.cpu.percent}% | RAM: ${stats.memory.percent}%`);
  // Update your DOM charts, gauges, or text here!
};

source.onerror = (err) => {
  console.error("Connection lost, retrying...", err);
};
```

### 3. CLI Single-Shot Output

```sh
statd api --once
```

Pipe directly into `jq`:

```sh
statd api --once | jq '.cpu.percent'
```

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-p, --port <port>` | Port to bind | `8080` (or `$STATD_API_PORT`) |
| `-H, --host <host>` | Host to bind (`0.0.0.0` for all interfaces) | `127.0.0.1` |
| `-i, --interval <s>` | SSE streaming interval in seconds | `1` |
| `-d, --daemon` | Run in background | `false` |
| `-o, --once` | Output single JSON snapshot to stdout and exit | `false` |
| `-h, --help` | Show help | |
