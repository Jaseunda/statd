#!/usr/bin/env python3
"""
StatD Float — Frameless Always-On-Top Floating Desktop HUD for Linux
Uses Python 3 standard library Tkinter + PTY (Zero pip dependencies).
"""

import sys
import os
import pty
import fcntl
import termios
import struct
import select
import re
import signal

try:
    import tkinter as tk
    from tkinter import font as tkfont
except ImportError:
    sys.stderr.write("statd float: python3-tk (tkinter) is required on Linux.\n")
    sys.stderr.write("Install with: sudo apt install python3-tk  (or dnf install python3-tkinter)\n")
    sys.exit(1)

# Ensure GUI display is available
if not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
    sys.stderr.write("statd float: No graphical display detected ($DISPLAY or $WAYLAND_DISPLAY).\n")
    sys.stderr.write("Floating HUD requires an active Linux desktop environment (X11 or Wayland).\n")
    sys.exit(1)

# ANSI Color Definitions
ANSI_16 = {
    30: "#606478", 90: "#606478", # Gray
    31: "#f55d6e", 91: "#f55d6e", # Red
    32: "#52e58c", 92: "#52e58c", # Green
    33: "#fad25d", 93: "#fad25d", # Yellow
    34: "#68a9f5", 94: "#68a9f5", # Blue
    35: "#df73eb", 95: "#df73eb", # Magenta / Pink
    36: "#5ce2f2", 96: "#5ce2f2", # Cyan
    37: "#f2f2f7", 97: "#f2f2f7", # White
}

def ansi256_to_hex(idx):
    if idx < 16:
        return ANSI_16.get(idx if idx >= 8 else 30 + idx, "#f2f2f7")
    if 16 <= idx <= 231:
        n = idx - 16
        r = int(((n // 36) % 6) / 5.0 * 255)
        g = int(((n // 6) % 6) / 5.0 * 255)
        b = int((n % 6) / 5.0 * 255)
        return f"#{max(20, r):02x}{max(20, g):02x}{max(20, b):02x}"
    if 232 <= idx <= 255:
        gray = int((idx - 232) / 23.0 * 220 + 20)
        return f"#{gray:02x}{gray:02x}{gray:02x}"
    return "#f2f2f7"

class VirtualTerminal:
    def __init__(self, rows=24, cols=38):
        self.rows = rows
        self.cols = cols
        self.reset()

    def reset(self):
        self.grid = [[(" ", "#f2f2f7", None, False, False) for _ in range(self.cols)] for _ in range(self.rows)]
        self.cur_row = 0
        self.cur_col = 0
        self.cur_fg = "#f2f2f7"
        self.cur_bg = None
        self.cur_bold = False
        self.cur_dim = False
        self.escape_buf = ""
        self.in_csi = False
        self.in_osc = False

    def write(self, data):
        i = 0
        n = len(data)
        while i < n:
            ch = data[i]
            if self.in_csi:
                if "0" <= ch <= "9" or ch in ";?":
                    self.escape_buf += ch
                else:
                    self._handle_csi(ch, self.escape_buf)
                    self.in_csi = False
                    self.escape_buf = ""
            elif self.in_osc:
                if ch in ("\x07", "\x1b"):
                    self.in_osc = False
            elif ch == "\x1b":
                if i + 1 < n:
                    next_ch = data[i + 1]
                    if next_ch == "[":
                        self.in_csi = True
                        self.escape_buf = ""
                        i += 1
                    elif next_ch == "]":
                        self.in_osc = True
                        i += 1
            elif ch == "\r":
                self.cur_col = 0
            elif ch == "\n":
                self.cur_row = min(self.rows - 1, self.cur_row + 1)
                self.cur_col = 0
            elif ch == "\t":
                self.cur_col = min(self.cols - 1, ((self.cur_col // 4) + 1) * 4)
            elif ch == "\b":
                self.cur_col = max(0, self.cur_col - 1)
            else:
                if 0 <= self.cur_row < self.rows and 0 <= self.cur_col < self.cols:
                    self.grid[self.cur_row][self.cur_col] = (ch, self.cur_fg, self.cur_bg, self.cur_bold, self.cur_dim)
                self.cur_col += 1
            i += 1

    def _handle_csi(self, cmd, params):
        parts = [int(p) for p in re.findall(r"\d+", params)]
        if cmd in ("H", "f"):
            r = max(1, parts[0]) - 1 if parts else 0
            c = max(1, parts[1]) - 1 if len(parts) > 1 else 0
            self.cur_row = max(0, min(self.rows - 1, r))
            self.cur_col = max(0, min(self.cols - 1, c))
        elif cmd == "J":
            mode = parts[0] if parts else 0
            if mode == 0:
                # Clear from cursor to end of screen
                if 0 <= self.cur_row < self.rows:
                    for c in range(self.cur_col, self.cols):
                        self.grid[self.cur_row][c] = (" ", "#f2f2f7", None, False, False)
                for r in range(self.cur_row + 1, self.rows):
                    for c in range(self.cols):
                        self.grid[r][c] = (" ", "#f2f2f7", None, False, False)
            elif mode == 1:
                # Clear from top of screen to cursor
                for r in range(0, self.cur_row):
                    for c in range(self.cols):
                        self.grid[r][c] = (" ", "#f2f2f7", None, False, False)
                if 0 <= self.cur_row < self.rows:
                    for c in range(0, min(self.cols, self.cur_col + 1)):
                        self.grid[self.cur_row][c] = (" ", "#f2f2f7", None, False, False)
            elif mode in (2, 3):
                self.reset()
        elif cmd == "K":
            mode = parts[0] if parts else 0
            if 0 <= self.cur_row < self.rows:
                if mode == 0:
                    for c in range(self.cur_col, self.cols):
                        self.grid[self.cur_row][c] = (" ", "#f2f2f7", None, False, False)
                elif mode == 1:
                    for c in range(0, min(self.cols, self.cur_col + 1)):
                        self.grid[self.cur_row][c] = (" ", "#f2f2f7", None, False, False)
                elif mode == 2:
                    for c in range(self.cols):
                        self.grid[self.cur_row][c] = (" ", "#f2f2f7", None, False, False)
        elif cmd == "m":
            if not parts:
                self._reset_style()
                return
            idx = 0
            while idx < len(parts):
                p = parts[idx]
                if p == 0:
                    self._reset_style()
                elif p == 1:
                    self.cur_bold = True
                elif p == 2:
                    self.cur_dim = True
                elif p == 22:
                    self.cur_bold = False
                    self.cur_dim = False
                elif p in ANSI_16:
                    self.cur_fg = ANSI_16[p]
                elif p == 38:
                    if idx + 2 < len(parts) and parts[idx + 1] == 5:
                        self.cur_fg = ansi256_to_hex(parts[idx + 2])
                        idx += 2
                    elif idx + 4 < len(parts) and parts[idx + 1] == 2:
                        r, g, b = parts[idx + 2], parts[idx + 3], parts[idx + 4]
                        self.cur_fg = f"#{r:02x}{g:02x}{b:02x}"
                        idx += 4
                elif p == 39:
                    self.cur_fg = "#f2f2f7"
                elif 40 <= p <= 47 or 100 <= p <= 107:
                    fg_equivalent = p - 10 if p <= 47 else p - 10
                    self.cur_bg = ANSI_16.get(fg_equivalent, None)
                elif p == 48:
                    if idx + 2 < len(parts) and parts[idx + 1] == 5:
                        self.cur_bg = ansi256_to_hex(parts[idx + 2])
                        idx += 2
                    elif idx + 4 < len(parts) and parts[idx + 1] == 2:
                        r, g, b = parts[idx + 2], parts[idx + 3], parts[idx + 4]
                        self.cur_bg = f"#{r:02x}{g:02x}{b:02x}"
                        idx += 4
                elif p == 49:
                    self.cur_bg = None
                idx += 1

    def _reset_style(self):
        self.cur_fg = "#f2f2f7"
        self.cur_bg = None
        self.cur_bold = False
        self.cur_dim = False

    def active_row_count(self):
        last_used = -1
        for r in range(self.rows):
            for c in range(self.cols):
                if self.grid[r][c][0] != " " or self.grid[r][c][2] is not None:
                    last_used = r
                    break
        return max(1, last_used + 1)

class FloatHUDApp:
    def __init__(self, cmd, opacity=0.96):
        self.cmd = cmd
        self.opacity = opacity
        self.rows = 24
        self.cols = 38
        self.vt = VirtualTerminal(self.rows, self.cols)
        self.root = tk.Tk()
        self.pty_master = None
        self.child_pid = None
        self._drag_start_x = 0
        self._drag_start_y = 0
        self.current_rendered_rows = 0

        self.setup_ui()
        self.spawn_statd()
        self.schedule_pty_read()

    def setup_ui(self):
        self.root.title("StatD Float")
        self.root.overrideredirect(True)
        try:
            self.root.wm_attributes("-topmost", True)
        except Exception:
            pass
        try:
            self.root.wm_attributes("-alpha", self.opacity)
        except Exception:
            pass

        font_families = tkfont.families()
        chosen_font = "DejaVu Sans Mono"
        for candidate in ["JetBrains Mono", "SF Mono", "Fira Code", "DejaVu Sans Mono", "monospace"]:
            if candidate in font_families:
                chosen_font = candidate
                break

        self.font_normal = tkfont.Font(family=chosen_font, size=10, weight="normal")
        self.font_bold = tkfont.Font(family=chosen_font, size=10, weight="bold")

        bg_color = "#1c1d27"
        self.root.configure(bg="#2d2f3d", highlightthickness=1, highlightbackground="#3d4059")

        self.container = tk.Frame(self.root, bg=bg_color, padx=14, pady=12)
        self.container.pack(fill=tk.BOTH, expand=True, padx=1, pady=1)

        self.text_widget = tk.Text(
            self.container,
            bg=bg_color,
            fg="#f2f2f7",
            font=self.font_normal,
            wrap=tk.NONE,
            relief=tk.FLAT,
            borderwidth=0,
            highlightthickness=0,
            cursor="arrow",
            takefocus=1
        )
        self.text_widget.pack(fill=tk.BOTH, expand=True)
        self.text_widget.configure(state=tk.DISABLED)

        for widget in (self.root, self.container, self.text_widget):
            widget.bind("<Button-1>", self.on_drag_start)
            widget.bind("<B1-Motion>", self.on_drag_motion)
            widget.bind("<Key>", self.on_key_press)

        self.char_w = self.font_normal.measure("M")
        self.char_h = self.font_normal.metrics("linespace")
        self.win_w = (self.char_w * self.cols) + 32
        init_rows = 10
        self.current_rendered_rows = init_rows
        win_h = (self.char_h * init_rows) + 26

        screen_w = self.root.winfo_screenwidth()
        pos_x = max(20, screen_w - self.win_w - 40)
        pos_y = 40
        self.root.geometry(f"{self.win_w}x{win_h}+{pos_x}+{pos_y}")

    def on_drag_start(self, event):
        self._drag_start_x = event.x_root - self.root.winfo_x()
        self._drag_start_y = event.y_root - self.root.winfo_y()

    def on_drag_motion(self, event):
        x = event.x_root - self._drag_start_x
        y = event.y_root - self._drag_start_y
        self.root.geometry(f"+{x}+{y}")

    def on_key_press(self, event):
        keysym = event.keysym.lower()
        if keysym in ("q", "escape"):
            self.quit()
            return
        elif event.char in ("+", "="):
            self.opacity = min(1.0, self.opacity + 0.05)
            try:
                self.root.wm_attributes("-alpha", self.opacity)
            except Exception:
                pass
            return
        elif event.char == "-":
            self.opacity = max(0.2, self.opacity - 0.05)
            try:
                self.root.wm_attributes("-alpha", self.opacity)
            except Exception:
                pass
            return

        if event.char and self.pty_master is not None:
            try:
                os.write(self.pty_master, event.char.encode("utf-8"))
            except Exception:
                pass

    def spawn_statd(self):
        master, slave = pty.openpty()
        ws = struct.pack("HHHH", self.rows, self.cols, 0, 0)
        fcntl.ioctl(slave, termios.TIOCSWINSZ, ws)

        pid = os.fork()
        if pid == 0:
            os.close(master)
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            os.dup2(slave, 0)
            os.dup2(slave, 1)
            os.dup2(slave, 2)
            if slave > 2:
                os.close(slave)

            env = os.environ.copy()
            env["TERM"] = "xterm-256color"
            env["COLUMNS"] = str(self.cols)
            env["LINES"] = str(self.rows)
            try:
                os.execvpe(self.cmd[0], self.cmd, env)
            except Exception as err:
                sys.stderr.write(f"statd float: failed to exec {self.cmd[0]}: {err}\n")
                os._exit(1)

        os.close(slave)
        self.pty_master = master
        self.child_pid = pid
        fl = fcntl.fcntl(master, fcntl.F_GETFL)
        fcntl.fcntl(master, fcntl.F_SETFL, fl | os.O_NONBLOCK)

    def schedule_pty_read(self):
        if self.pty_master is not None:
            try:
                r, _, _ = select.select([self.pty_master], [], [], 0)
                if r:
                    chunk = os.read(self.pty_master, 8192)
                    if chunk:
                        text = chunk.decode("utf-8", errors="replace")
                        self.vt.write(text)
                        self.render()
                    else:
                        self.quit()
                        return
            except OSError:
                pass

        self.root.after(16, self.schedule_pty_read)

    def render(self):
        total_rows = max(2, self.vt.active_row_count())

        self.text_widget.configure(state=tk.NORMAL)
        self.text_widget.delete("1.0", tk.END)

        for r in range(total_rows):
            line = self.vt.grid[r]
            end_c = self.cols - 1
            while end_c > 0 and line[end_c][0] == " " and line[end_c][2] is None:
                end_c -= 1

            c = 0
            while c <= end_c:
                char, fg, bg, bold, dim = line[c]
                run_text = char
                nc = c + 1
                while nc <= end_c and line[nc][1:] == (fg, bg, bold, dim):
                    run_text += line[nc][0]
                    nc += 1

                tag_name = f"t_{fg}_{bg}_{bold}_{dim}".replace("#", "")
                if tag_name not in self.text_widget.tag_names():
                    cfg = {"foreground": fg}
                    if bg:
                        cfg["background"] = bg
                    cfg["font"] = self.font_bold if bold else self.font_normal
                    self.text_widget.tag_configure(tag_name, **cfg)

                self.text_widget.insert(tk.END, run_text, tag_name)
                c = nc

            if r < total_rows - 1:
                self.text_widget.insert(tk.END, "\n")

        self.text_widget.configure(state=tk.DISABLED)

        # Dynamic height adjustment
        if total_rows != self.current_rendered_rows:
            self.current_rendered_rows = total_rows
            needed_h = (self.char_h * total_rows) + 26
            cur_x = self.root.winfo_x()
            cur_y = self.root.winfo_y()
            self.root.geometry(f"{self.win_w}x{needed_h}+{cur_x}+{cur_y}")

    def quit(self):
        if self.child_pid:
            try:
                os.kill(self.child_pid, signal.SIGTERM)
            except Exception:
                pass
        if self.pty_master:
            try:
                os.close(self.pty_master)
            except Exception:
                pass
        self.root.destroy()
        sys.exit(0)

    def run(self):
        self.root.mainloop()

def main():
    statd_bin = "./statd"
    extra_args = []
    opacity = 0.96

    args = sys.argv[1:]
    if args:
        statd_bin = args[0]
        i = 1
        while i < len(args):
            if args[i] == "--opacity" and i + 1 < len(args):
                try:
                    opacity = float(args[i + 1])
                except ValueError:
                    pass
                i += 2
            else:
                extra_args.append(args[i])
                i += 1

    full_cmd = [statd_bin]
    if "-f" not in extra_args and "--full" not in extra_args and "--no-full" not in extra_args:
        full_cmd.append("-f")
    full_cmd.extend([a for a in extra_args if a != "--no-full"])

    app = FloatHUDApp(full_cmd, opacity=opacity)
    app.run()

if __name__ == "__main__":
    main()
