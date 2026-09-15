# StatD Complete Menus & CLI Interface Audit

This document catalogs **every menu, banner, interactive screen, and CLI output** across StatD.
Use this reference to review, align styling, and plan a cohesive visual revamp.

---

## Table of Contents
1. [Core HUD (`statd`)](#1-core-hud-statd)
2. [Main Help Manual (`statd --help`)](#2-main-help-manual-statd---help)
3. [About & Diagnostics Screen (`statd about`)](#3-about--diagnostics-screen-statd-about)
4. [Update & Self-Updater (`statd update`)](#4-update--self-updater-statd-update)
5. [Guided Installer (`install.sh`)](#5-guided-installer-installsh)
6. [Configuration Manager (`statd config`)](#6-configuration-manager-statd-config)
7. [Plugin Manager (`statd plugins`)](#7-plugin-manager-statd-plugins)
8. [Interactive Theme Selector (`statd theme`)](#8-interactive-theme-selector-statd-theme)
9. [Theme CLI Tools (`statd theme list | status | preview`)](#9-theme-cli-tools-statd-theme-list--status--preview)
10. [API Server Plugin (`statd api`)](#10-api-server-plugin-statd-api)
11. [MCP AI Plugin (`statd mcp`)](#11-mcp-ai-plugin-statd-mcp)
12. [Demo Suite (`test/demo.sh`)](#12-demo-suite-testdemosh)
13. [Revamp Opportunities & Styling Standards](#13-revamp-opportunities--styling-standards)

---

## 1. Core HUD (`statd`)

### Active View (Standard Compact — 36 cols)
```text
13:45:10                up 14d 06h 12m
CPU  26%                  4.05GHz  34C
█████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
c ▂▂▃▃▄▄▄▅▅▆▆▂▂▃▃▄▄▄▅▅▆▆▂▂▃  ▂▂▂▂▃
GPU  83%          402.62G/512.00G  42C
███████████████████████████████░░░░░░░
RAM  83%               427.50G/512.00G
███████████████████████████████░░░░░░░
SWP   0%                     0B/64.00G
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
DSK  29%                 / 2.34T/8.00T
███████████░░░░░░░░░░░░░░░░░░░░░░░░░░░
LD   11%           3.84 3.42 2.95  96p
████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### Hotkeys Available:
| Key | Action |
|---|---|
| `c` | Toggle per-core CPU panel |
| `g` | Toggle GPU row |
| `f`, `w` | Toggle full-width stretch (`-f`) |
| `l` | Toggle load average row (LD) |
| `b` | Toggle battery row (BAT) |
| `s` | Toggle swap row (SWP) |
| `d` | Toggle disk row (DSK) |
| `q` | Quit |

---

## 2. Main Help Manual (`statd --help`)

### Current Output:
```text
statd 1.1.0 — terminal system stats HUD
https://github.com/Jaseunda/statd

Usage:
  statd [options]
  statd about
  statd config [command]
  statd install <plugin>
  statd update [plugin|all]
  statd plugins [command]
  statd <plugin> [options]

Options:
  -f, --full             Stretch to fill terminal width (auto on mini displays)
  -a, --about            Show system info, versions, and one-click updater
  -u, --update           Check for and install the latest update
  --check-update         Check if an update is available without installing
  --config [cmd]         Manage view toggles and settings (or: statd config)
  --no-cpu, --no-gpu     Hide CPU or GPU rows
  --no-ram, --no-swp     Hide RAM or swap rows
  --no-dsk, --no-ld      Hide disk or load average rows
  --no-bat, --no-llm     Hide battery or LLM inference rows
  -c, --cores            Start with per-core CPU sparklines visible
  -i, --interval <sec>   Refresh interval in seconds (default: 1)
  -v, --version          Print version and exit
  -h, --help             Show this help message

Interactive Controls:
  c          Toggle per-core CPU sparklines
  g          Toggle GPU row
  f, w       Toggle full-width stretch
  l          Toggle load average row (LD)
  b          Toggle battery row (BAT)
  s          Toggle swap row (SWP)
  d          Toggle disk row (DSK)
  q          Quit HUD

Plugin Commands:
  statd install <name>        Install an official plugin (e.g. api, theme)
  statd remove <name>         Uninstall an installed plugin
  statd plugins               List available and installed plugins
  statd plugins update [name] Update installed plugin (or all plugins)
  statd api [options]         Start HTTP metrics API server
  statd theme [options]       Manage color themes & palette
  statd mcp [options]         Model Context Protocol server for AI

Config Commands:
  statd config                 Show current view settings
  statd config disable <view>  Turn off view (cpu, gpu, ram, swp, dsk, ld)
  statd config enable <view>   Turn on view
  statd config edit            Edit configuration in $EDITOR
  statd config reset           Reset configuration to defaults
```

---

## 3. About & Diagnostics Screen (`statd about`)

### Interactive TUI Screen (Clean Borderless Header):
```text
  statd v1.1.0 — terminal system stats HUD
  https://github.com/Jaseunda/statd

  CORE & SYSTEM
  ─────────────────────────────────────────────────────────────
  StatD Core     v1.1.0  ● up to date
  Platform       macOS 15.3.1 (arm64) · Bash 5.2.37
  Terminal       xterm-256color (89x28)
  Config         ~/.config/statd/statd.conf

  PLUGINS
  ─────────────────────────────────────────────────────────────
  ●  theme      v1.0.0  ● up to date
     Color themes & custom palette manager

  ●  api        v1.0.0  ● up to date
     Lightweight HTTP JSON & SSE metrics streaming API

  ●  mcp        v1.0.0  ● up to date
     Model Context Protocol server for AI coding assistants

  ─────────────────────────────────────────────────────────────
  Commands:
    u  Update all (core + plugins)
    t  Open Theme Selector (statd theme)
    c  View configuration (statd config)
    q  Back to terminal
```

---

## 4. Update & Self-Updater (`statd update`)

### When running in Git repository:
```text
statd update (current version: 1.1.0)

  +  Git repository detected at: /Users/mac/Development/StatD
  +  Pulling latest changes from remote...

  statd updated successfully via git.
```

### When running installed binary:
```text
statd update (current version: 1.1.0)

  Fetching latest installer from GitHub...
  +  Updating installation at ~/.local ...
  +  Updated /Users/mac/.local/bin/statd
  +  Updated libraries in /Users/mac/.local/lib/statd
  statd updated successfully to v1.1.0!
```

---

## 5. Guided Installer (`install.sh`)

### CLI Banner & Prompt:
```text
  statd — terminal system stats HUD
  https://github.com/Jaseunda/statd

  Install location
  +  Using prefix: /Users/mac/.local
  +  Binary directory: /Users/mac/.local/bin
  +  Library directory: /Users/mac/.local/lib/statd

  Checking environment
  +  OS: macOS (arm64)
  +  Shell: /opt/homebrew/bin/bash (5.2.37)
  +  Download tool: curl

  Installing statd
  +  Extracting archive...
  +  Installed /Users/mac/.local/bin/statd
  +  Installed libraries to /Users/mac/.local/lib/statd/

  Installation complete!
  To launch:
    statd
```

---

## 6. Configuration Manager (`statd config`)

### Current Output (`statd config`):
```text
statd configuration
Config file: /Users/mac/.config/statd/statd.conf

Views:
  CPU: on    GPU: on    RAM: on    SWP: on
  DSK: on    LD:  on    BAT: on    LLM: off

Display:
  Full Width: off (auto on <= 50 cols)

Commands:
  statd config disable <view>   (turn off view: ld, bat, swp, dsk, cpu, gpu, ram, full)
  statd config enable <view>    (turn on view: ld, bat, swp, dsk, cpu, gpu, ram, full)
  statd config set <KEY> <VAL>  (set any setting, e.g. INTERVAL 2)
  statd config edit             (open in editor)
  statd config reset            (reset to defaults)
```

---

## 7. Plugin Manager (`statd plugins`)

### Current Output:
```text
statd plugins — extensible add-on manager
Install directory: /Users/mac/.local/lib/statd/plugins

Installed:
  ● theme     v1.0.0   Color themes & custom palette manager
  ● api       v1.0.0   Lightweight HTTP JSON & SSE metrics streaming API
  ● mcp       v1.0.0   Model Context Protocol server for AI coding assistants

Available:
  (all 3 official plugins installed)

Commands:
  statd install <name>          Install an official plugin
  statd remove <name>           Uninstall a plugin
  statd plugins update [name]   Update installed plugin(s)
```

---

## 8. Interactive Theme Selector (`statd theme`)

### Interactive TUI Screen (Clean Borderless Header, Zero Spillage):
```text
  StatD Theme Selector
  ↑/↓ or j/k to browse  ·  Enter to apply  ·  q to exit

    default     — Standard StatD (Green, Cyan, Magenta)
    cyberpunk   — Night City (Amber, Cyan, Hot Pink)
    nord        — Arctic frost blue & polar night
    dracula     — Dark fantasy (Purple, Cyan, Emerald)
  ▸ synthwave [active] — 80s retro neon (Hot Pink, Neon Cyan)
    sakura      — Japanese cherry blossom (Pink, Blush)
    matrix      — Pure terminal lime & dark green
    glacier     — Crystalline arctic ice (Glacier, Frost)

  ┌─ Live Preview: synthwave ───────────────────────────────────┐
  │ CPU  █████████████░░░░░░░░░░░░░   52%  (purple)             │
  │ GPU  ███████████████████░░░░░░░   74%  (cyan)               │
  │ RAM  ███████████████░░░░░░░░░░░   61%  (mag)                │
  │ SWP  ███████░░░░░░░░░░░░░░░░░░░   28%  (purple)             │
  │ DSK  ██████████████░░░░░░░░░░░░   56%  (cyan)               │
  │ LD   █████████████████░░░░░░░░░   68%  (mag)                │
  └─────────────────────────────────────────────────────────────┘
```

---

## 9. Theme CLI Tools (`statd theme list | status | preview`)

### `statd theme status`
```text
Current Theme: synthwave

Metric Color Assignments:
  CPU: purple  [preset]
  GPU: cyan    [preset]
  RAM: mag     [preset]
  SWP: purple  [preset]
  DSK: cyan    [preset]
  LD:  mag     [preset]

Preview:
  statd theme preview synthwave
```

### `statd theme list` (Sample Entry)
```text
  synthwave   80s retro neon (Hot Pink, Neon Cyan)
  CPU █████████  GPU █████████  RAM █████████  SWP █████████
```

---

## 10. API Server Plugin (`statd api`)

### Help Banner:
```text
statd-api 1.0.0 — HTTP metrics streaming API server

Usage:
  statd api start [--port 8080] [--host 127.0.0.1]
  statd api status
  statd api stop

Endpoints:
  GET /metrics    JSON snapshot of instantaneous hardware metrics
  GET /stream     Server-Sent Events (SSE) live real-time stream (1/sec)
  GET /health     Health check and uptime status
```

---

## 11. MCP AI Plugin (`statd mcp`)

### Help Banner:
```text
statd-mcp 1.0.0 — Model Context Protocol server for StatD

Usage:
  statd mcp serve               Start stdio MCP server for Claude/Cursor/Windsurf
  statd mcp status              Verify local sensors & JSON serialization
  statd mcp install             Auto-configure Claude Desktop or Cursor MCP config

Available Tools:
  statd_get_metrics             Get instant system stats snapshot
  statd_get_process_summary     Get top CPU/RAM processes
  statd_get_theme_info          Get active theme and palette
```

---

## 12. Demo Suite (`test/demo.sh`)

### Available Demos & Commands:
```bash
./test/demo_m3_ultra.sh -c -l     # Apple M3 Ultra (512GB RAM, Tokyo & Sakura)
./test/demo_h100.sh -c -l         # AI Supercluster (4x H100, Lava & Matrix)
./test/demo_homelab.sh -c -l      # Homelab / Proxmox (4 ZFS Pools, Amber & Ocean)
./test/demo_webserver.sh -c -l    # Cloud Web Server VPS (Forest Green)
./test/demo_bot.sh -c -l          # Discord/Telegram Bot (Amethyst Purple)
```

---

## 13. Revamp Status & Adopted Styling Standards

### Implemented Styling Standards:
1. **Clean Borderless Headers (Adopted & Implemented)**:
   - `statd --help`: ANSI color-coded (bold title, cyan flags, dim descriptions, 2-column layout).
   - `statd about`: Clean borderless header matching `--help`, followed by blue section headers and dim separator rules.
   - `statd theme`: Clean borderless header with dim navigation hints; preview retains clean compact frame.
   - `statd config` & `statd plugins`: Clean, consistent plain text and dot indicators.

2. **Standardized Bullet & Cursor Characters**:
   - Active / Status indicator: `●` (Green for up to date, Yellow for updates available)
   - Selection cursor: `▸` (Cyan)
   - Informational logs: `+` (Cyan/Green)
   - Warning logs: `!` (Yellow)
   - Error logs: `x` (Red)

3. **Width Clamping & Zero-Wrap Rule (Implemented)**:
   - Descriptions in `statd theme` are clamped to fit strictly within 64 columns (`max_desc_w=$(( 64 - pfx_w ))`).
   - Zero horizontal overflow or line wrapping on compact terminals (34–80 columns).
