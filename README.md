# statd

A minimal, flicker-free system stats HUD for your terminal.

No heavy frameworks. No compiling. Just launch and go.

<p align="center">
  <img src="assets/statd.png" alt="statd" width="100%">
</p>

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Jaseunda/statd/main/install.sh | bash
```

Or from source:

```sh
git clone https://github.com/Jaseunda/statd.git
cd statd
make install PREFIX=~/.local
```

> **macOS Note:** Requires modern Bash (`brew install bash`). The installer will guide you through this automatically.

## Run

```sh
statd
```

### Keyboard Shortcuts

While running, you can press any of these keys anytime:

| Key | Action |
|-----|--------|
| `c` | Toggle per-core CPU panel |
| `l` | Toggle Load average (`LD`) |
| `b` | Toggle Battery (`BAT`) |
| `s` | Toggle Swap (`SWP`) |
| `d` | Toggle Disk (`DSK`) |
| `q` | Quit |

## Customizing Views

Turn off views you don't need with the `config` command:

```sh
# Turn off load average (LD)
statd config disable ld

# Turn off battery (BAT)
statd config disable bat

# Turn any view back on
statd config enable ld
statd config enable bat

# See your current settings
statd config
```

You can also hide views on the fly with command-line flags:

```sh
statd --no-ld           # Run without load average
statd --no-bat          # Run without battery
statd --no-ld --no-bat  # Run without load average or battery
```

## Plugins (Optional Features)

StatD keeps the terminal HUD minimal and bloat-free, but allows adding extra features via on-demand plugins:

```sh
# List plugins
statd plugins

# Install the streaming API plugin
statd install api
```

### Streaming API Plugin (`statd api`)

Expose real-time metrics over an ultra-low CPU HTTP server with JSON and Server-Sent Events (SSE):

```sh
# Start API server on http://localhost:8080
statd api

# Run as background daemon
statd api --daemon --port 8080
statd api status
statd api stop

# Query snapshot via curl or script
curl http://localhost:8080/stats
```

Connect web dashboards and custom interfaces in real-time with zero polling:

```javascript
const sse = new EventSource("http://localhost:8080/stream");
sse.onmessage = (e) => {
  const stats = JSON.parse(e.data);
  console.log(`CPU: ${stats.cpu.percent}% | RAM: ${stats.memory.percent}%`);
};
```

## Update

Update to the latest version at any time:

```sh
statd --update
```

Check for updates without installing:

```sh
statd --check-update
```

## Zero-Install (Light Setups)

For temporary containers (Docker, LXC) or servers where you don't want to install anything, run the standalone single-file bundle directly:

```sh
curl -fsSL https://raw.githubusercontent.com/Jaseunda/statd/main/dist/statd | bash
```

## Options

| Command / Flag | Description |
|----------------|-------------|
| `install <name>` | Install a plugin (e.g. `statd install api`) |
| `plugins` | List available and installed plugins |
| `api [options]` | Start the streaming API server (after `install api`) |
| `-u, --update` | Update statd to latest version |
| `--check-update` | Check for updates |
| `--config [cmd]` | Manage view toggles (`statd config`) |
| `--no-ld` | Hide load average row |
| `--no-bat` | Hide battery row |
| `--no-swp` | Hide swap row |
| `--no-dsk` | Hide disk row |
| `-c, --cores` | Start with per-core CPU panel shown |
| `-i, --interval <sec>` | Refresh speed in seconds (default: 1) |
| `-v, --version` | Show version |
| `-h, --help` | Show all options |

## License

MIT. See [LICENSE](LICENSE).
