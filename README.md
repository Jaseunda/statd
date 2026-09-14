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

## Run

```sh
statd
```

Press `c` to toggle the per-core panel. Press `q` to quit.

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
