# statd

Not btop. Not htop. Just bash.

A flicker-free terminal stats HUD for homelabs, servers, and anything running
a Linux or Darwin kernel. No ncurses. No compiled binary. No dependencies
beyond a shell.

```
10:42:31                       up 3d 14h 22m
CPU  72%  3.20GHz  61C
████████████████░░░░
RAM  58%  9.3G/16.0G
████████████░░░░░░░░
SWP   0%  0B/0B
░░░░░░░░░░░░░░░░░░░░
DSK  34%  234.5G/512.0G
███████░░░░░░░░░░░░░
LD   45%  0.72 0.68 0.61  312p
█████████░░░░░░░░░░░
```

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

Homebrew (after first release tag):

```sh
brew tap Jaseunda/statd https://github.com/Jaseunda/statd
brew install statd
```

macOS requires Bash 4.0+. The system ships 3.2:

```sh
brew install bash
```

## Update

Update statd to the latest version at any time:

```sh
statd --update
```

Check for updates without installing:

```sh
statd --check-update
```

If managing from source:

```sh
make update
```

## Run

```sh
statd
```

### Options

| Flag | Description |
|------|-------------|
| `-u, --update` | Check for and install the latest update |
| `--check-update` | Check if an update is available without installing |
| `-c, --cores` | Start with the per-core CPU panel visible |
| `-i, --interval <sec>` | Refresh interval in seconds (default: 1) |
| `-v, --version` | Show version information |
| `-h, --help` | Show help and options |

Press `c` to toggle the per-core panel. Press `q` to quit.

## Light Setups & Zero-Install

For minimal containers (Docker, Podman, LXC), microVMs, or ephemeral remote hosts where installing libraries isn't desired, use the standalone single-file bundle:

```sh
# Generate bundle (produces dist/statd)
make bundle

# Or run directly without installing
curl -fsSL https://raw.githubusercontent.com/Jaseunda/statd/main/dist/statd | bash
```

The standalone script has all modular sensors embedded in a single file with zero external dependencies beyond standard bash and POSIX utilities.

## Configuration

All settings are environment variables. None are required.

| Variable    | Default | Description                                    |
|-------------|---------|------------------------------------------------|
| INTERVAL    | 1       | Refresh interval in seconds                    |
| SLOW_EVERY  | 30      | Seconds between disk / battery / uptime polls  |
| BAR_WIDTH   | 20      | Gradient bar width                             |
| CORE_STYLE  | spark   | Per-core style: spark, dots, seg, mini         |
| CORES_SHOWN | 0       | 1 = show per-core panel on startup             |
| LLM_PORT    | 8080    | llama-server metrics port                      |

```sh
CORE_STYLE=mini CORES_SHOWN=1 statd
```

## Platform Notes

Runs on Linux (x86, ARM, any kernel 3.0+) and macOS (Apple Silicon, Intel).

CPU temperature on macOS requires `brew install osx-cpu-temp`. Without it
the field shows `--`. Everything else works out of the box.

Per-core load on macOS shows placeholder dots — the cpuidle subsystem is
not accessible without root. Overall CPU utilization is unaffected.

Linux ARM covers Raspberry Pi, Rock Pi, ARM servers, and any device
running a Linux kernel on ARM silicon, regardless of the userspace on top.

## Performance

statd is a shell script. That is the point — and a real tradeoff.

### Bash vs compiled tools

| | statd | btop / htop |
|---|---|---|
| Language | Bash + awk | C++ / C (compiled) |
| CPU overhead per tick | ~0.1–0.5% | ~0.1% |
| Startup time | ~50ms | ~10ms |
| Sensor read method | read builtin / sysfs | direct syscall |
| Process list | no | yes |
| Mouse support | no | yes |
| Hackable without a compiler | yes | no |
| Works over slow SSH | yes | yes |
| Dependencies | bash 4+, POSIX tools | none (static binary) |

If you need a full process manager, sorting, killing processes, or mouse
interaction, use btop or htop. They are better tools for that job.

statd is for a persistent, always-on pane that shows system health at a
glance — CPU, memory, disk, load, and (optionally) an LLM process — with
nothing else on screen.

### How we get there

The hot path (every tick) is engineered to minimize forks:

- **CPU%** — reads `/proc/stat` with `read` builtin (Linux) or
  `sysctl kern.cp_time` (macOS). Both return cumulative jiffies for
  delta-based measurement. Zero forks, <5ms either way.
- **Memory** — `while read` loop directly on `/proc/meminfo` (Linux);
  single `vm_stat` call with cached page size (macOS). No awk fork.
- **Load / uptime** — `read` builtin on `/proc/loadavg`, `/proc/uptime`.
  Pure bash integer math for time formatting. Zero forks.
- **Bar rendering** — pure bash loop for filled cells; pre-built
  constant string for the empty portion (substring, no fork).
- **human()** — pure bash integer arithmetic. No awk fork.
- **Disk / battery / uptime** — slow tier, polled every 30 s (tunable).

awk is kept only where a single process reading many files beats a bash
loop: cpuidle sysfs (8+ cores x 5+ states) and swap parsing on macOS.

### Raising the interval

On very constrained hardware (old ARM single-board computers, embedded
systems) the fork budget still adds up. Use a higher interval:

```sh
INTERVAL=2 statd      # halves the fork rate
INTERVAL=5 statd      # near-zero impact, suitable for background panes
```

### When to use each

Use **statd** when you want a low-configuration, always-on terminal pane
that any sysadmin can read, modify, and pipe into other scripts — with no
binary to compile or update.

Use **btop** or **htop** when you need to inspect individual processes,
sort by memory or CPU, send signals, or interact with the system — the
compiled tools are significantly better for that.

## LLM Monitoring

If `llama-server` is running, statd reads its `/metrics` endpoint and
shows live token throughput. If the endpoint is unavailable, it falls back
to scanning for a `llama-server`, `llama-cli`, `llama-run`, or
`llama-bench` process and reports CPU and RSS directly.

## Homelab

statd is designed to live in a persistent tmux or screen pane:

```
+------------------+------------------+
| statd            | service logs     |
|                  |                  |
+------------------+------------------+
```

It does not clear the screen between frames and does not write below its
own output, so it coexists cleanly with terminal multiplexers.

For multi-host setups, SSH into each node in a separate pane and run statd.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
