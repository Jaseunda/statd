# statd

A minimal, flicker-free system stats HUD for your terminal.

No heavy frameworks. No compiling. Just launch and go.

```text
11:05:45             up 21h 46m
CPU  15%                 --  --
████░░░░░░░░░░░░░░░░░░░░░░░░░░░
RAM  57%          18.36G/32.00G
█████████████████░░░░░░░░░░░░░░
SWP  94%          14.12G/15.00G
█████████████████████████████░░
DSK  67%        311.35G/460.43G
████████████████████░░░░░░░░░░░
LD   54%  5.41 4.61 3.95  1155p
████████████████░░░░░░░░░░░░░░░
BAT  80%  AC (not charging)
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

| Flag | Description |
|------|-------------|
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
