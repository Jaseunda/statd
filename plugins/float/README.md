# statd-float

Frameless, always-on-top floating desktop HUD for [StatD](https://github.com/Jaseunda/statd).

Renders a borderless, raw, hardware-accelerated desktop widget without window titlebars, headers, or traffic lights (`● ● ●`). Floats above code editors, full-screen apps, and browser windows with buttery smooth 60–120 FPS rendering and zero external package dependencies.

## Features

- 🪟 **Frameless & Raw**: Zero window chrome, no headers, no traffic light buttons. Just a clean, sleek glass HUD card with 18px rounded corners and native drop shadows.
- 🖱️ **Draggable Anywhere**: Click and drag anywhere on the window background to reposition on any display.
- 📌 **Always-On-Top**: Stays pinned above IDEs, terminals, browsers, and full-screen workspaces.
- ⚡ **60–120 FPS Performance**: Hardware-accelerated refresh with ProMotion 120Hz support on macOS Apple Silicon.
- 📏 **Dynamic Height**: Height automatically and smoothly adapts to the exact active content rows (CPU, GPU, RAM, SWP, DSK, NET, BAT, Cores).
- 🎨 **Full-Width by Default**: Clean edge-to-edge bar aesthetic matching your active StatD theme.
- 🛡️ **Zero Package Dependencies**:
  - **macOS**: Built with native Swift Cocoa / AppKit (`NSPanel`, `Process`, `PTY`).
  - **Linux**: Built with Python 3 standard library `tkinter` + `pty`.
- 🖥️ **GUI Session Detection**: Requires an active graphical desktop (macOS Quartz, Linux X11/Wayland); exits cleanly with informative error in headless/SSH environments.

## Install

```sh
statd install float
```

*(or run directly in repo: `statd float`)*

## Usage

```sh
# Launch floating HUD (full-width by default)
statd float

# Launch with custom opacity (0.2 to 1.0)
statd float --opacity 0.85

# Check if graphical desktop environment is ready
statd float --check

# Pass through any StatD options (e.g. per-core sparklines or custom interval)
statd float -c -i 0.5
```

## Interactive Controls (HUD Focused)

| Action / Key | Function |
|---|---|
| **Click & Drag** | Move HUD window anywhere on screen |
| `+` / `=` | Increase window opacity |
| `-` | Decrease window opacity |
| `c` | Toggle per-core CPU sparklines / dots |
| `g` | Toggle GPU row |
| `n` | Toggle network throughput row |
| `l` | Toggle load average row |
| `s` | Toggle swap row |
| `d` | Toggle disk row |
| `b` | Toggle battery row |
| `f` / `w` | Toggle full-width bar stretch |
| `q` / `Esc` | Close floating HUD |

## System Requirements

- **macOS**: macOS 11+ with Command Line Tools (`swiftc`).
- **Linux**: Python 3 with `tkinter` (`sudo apt install python3-tk` / `sudo dnf install python3-tkinter`) on an active X11 or Wayland session.
