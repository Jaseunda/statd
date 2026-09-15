import Cocoa
import Darwin
import Foundation

// ============================================================================
// StatD Float — Frameless Always-On-Top Floating Desktop HUD for macOS
// OLED-Optimized • 60-120 FPS • Native Cocoa Swift • Detached Desktop Widget
// ============================================================================

signal(SIGHUP, SIG_IGN)

struct TerminalCell {
    var char: Character = " "
    var fg: NSColor = NSColor(white: 0.95, alpha: 1.0)
    var bg: NSColor = .clear
    var bold: Bool = false
    var dim: Bool = false
}

// OLED High-Contrast Vibrant Palette
func standardColor(_ code: Int) -> NSColor {
    switch code {
    case 30, 90: return NSColor(white: 0.52, alpha: 1.0) // Dim / Gray
    case 31, 91: return NSColor(red: 1.00, green: 0.36, blue: 0.44, alpha: 1.0) // Vivid Coral Red
    case 32, 92: return NSColor(red: 0.22, green: 0.94, blue: 0.56, alpha: 1.0) // Vibrant Neon Green
    case 33, 93: return NSColor(red: 1.00, green: 0.82, blue: 0.32, alpha: 1.0) // Warm Gold
    case 34, 94: return NSColor(red: 0.42, green: 0.72, blue: 1.00, alpha: 1.0) // Electric Blue
    case 35, 95: return NSColor(red: 0.92, green: 0.46, blue: 0.96, alpha: 1.0) // Bright Purple / Pink
    case 36, 96: return NSColor(red: 0.25, green: 0.92, blue: 0.98, alpha: 1.0) // Vibrant Cyan
    case 37, 97: return NSColor(white: 0.98, alpha: 1.0) // Crisp White
    default:     return NSColor(white: 0.95, alpha: 1.0)
    }
}

func color256(_ idx: Int) -> NSColor {
    if idx < 16 {
        return standardColor(idx < 8 ? 30 + idx : 90 + (idx - 8))
    } else if idx >= 16 && idx <= 231 {
        let n = idx - 16
        let r = CGFloat((n / 36) % 6) / 5.0
        let g = CGFloat((n / 6) % 6) / 5.0
        let b = CGFloat(n % 6) / 5.0
        return NSColor(red: max(0.08, r), green: max(0.08, g), blue: max(0.08, b), alpha: 1.0)
    } else if idx >= 232 && idx <= 255 {
        let gray = CGFloat(idx - 232) / 23.0 * 0.92 + 0.08
        return NSColor(white: gray, alpha: 1.0)
    }
    return NSColor(white: 0.95, alpha: 1.0)
}

// Split incomplete UTF-8 bytes at chunk boundaries
func splitIncompleteUTF8(_ bytes: [UInt8]) -> (complete: [UInt8], remainder: [UInt8]) {
    guard !bytes.isEmpty else { return ([], []) }
    var i = bytes.count - 1
    while i >= 0 && (bytes[i] & 0xC0) == 0x80 {
        i -= 1
    }
    if i < 0 {
        return ([], bytes)
    }
    let lead = bytes[i]
    let needed: Int
    if (lead & 0x80) == 0 { needed = 1 }
    else if (lead & 0xE0) == 0xC0 { needed = 2 }
    else if (lead & 0xF0) == 0xE0 { needed = 3 }
    else if (lead & 0xF8) == 0xF0 { needed = 4 }
    else { needed = 1 }

    let available = bytes.count - i
    if available < needed {
        return (Array(bytes[0..<i]), Array(bytes[i..<bytes.count]))
    } else {
        return (bytes, [])
    }
}

// VT100 / ANSI Virtual Terminal Grid (Strict Non-Wrapping & Bounds-Checked)
class VirtualTerminal {
    let rows: Int
    let cols: Int
    var grid: [[TerminalCell]]
    var curRow: Int = 0
    var curCol: Int = 0
    var currentFg: NSColor = NSColor(white: 0.95, alpha: 1.0)
    var currentBg: NSColor = .clear
    var currentBold: Bool = false
    var currentDim: Bool = false

    private var inEscape = false
    private var inCsi = false
    private var inOsc = false
    private var csiParams = ""

    init(rows: Int = 24, cols: Int = 40) {
        self.rows = rows
        self.cols = cols
        self.grid = Array(repeating: Array(repeating: TerminalCell(), count: cols), count: rows)
    }

    func reset() {
        grid = Array(repeating: Array(repeating: TerminalCell(), count: cols), count: rows)
        curRow = 0
        curCol = 0
    }

    func write(_ str: String) {
        var iter = str.makeIterator()
        while let ch = iter.next() {
            if inEscape {
                if ch == "[" {
                    inCsi = true
                    inEscape = false
                    csiParams = ""
                } else if ch == "]" {
                    inOsc = true
                    inEscape = false
                } else {
                    inEscape = false
                }
            } else if inOsc {
                if ch == "\u{07}" || ch == "\u{1b}" {
                    inOsc = false
                }
            } else if inCsi {
                if (ch >= "0" && ch <= "9") || ch == ";" || ch == "?" {
                    csiParams.append(ch)
                } else {
                    handleCsi(cmd: ch, params: csiParams)
                    inCsi = false
                    csiParams = ""
                }
            } else {
                if ch == "\u{1b}" {
                    inEscape = true
                } else if ch == "\r" {
                    curCol = 0
                } else if ch == "\n" {
                    curRow = min(rows - 1, curRow + 1)
                    curCol = 0
                } else if ch == "\t" {
                    let nextTab = ((curCol / 4) + 1) * 4
                    curCol = min(cols - 1, nextTab)
                } else if ch == "\u{08}" { // Backspace
                    curCol = max(0, curCol - 1)
                } else if ch.isASCII || (ch.unicodeScalars.first?.value ?? 0) > 127 {
                    if curRow >= 0 && curRow < rows && curCol >= 0 && curCol < cols {
                        grid[curRow][curCol] = TerminalCell(
                            char: ch,
                            fg: currentFg,
                            bg: currentBg,
                            bold: currentBold,
                            dim: currentDim
                        )
                    }
                    if curCol < cols - 1 {
                        curCol += 1
                    }
                }
            }
        }
    }

    private func handleCsi(cmd: Character, params: String) {
        let parts = params.split(separator: ";").compactMap { Int($0) }
        switch cmd {
        case "H", "f": // Cursor position (1-based)
            if parts.isEmpty {
                curRow = 0
                curCol = 0
            } else {
                let r = max(1, parts[0]) - 1
                let c = parts.count > 1 ? max(1, parts[1]) - 1 : 0
                curRow = min(rows - 1, max(0, r))
                curCol = min(cols - 1, max(0, c))
            }
        case "J": // Erase in display
            let mode = parts.first ?? 0
            if mode == 0 {
                // Erase from cursor to bottom of screen
                if curRow >= 0 && curRow < rows {
                    let startC = max(0, min(cols - 1, curCol))
                    for c in startC..<cols {
                        grid[curRow][c] = TerminalCell()
                    }
                }
                if curRow + 1 < rows {
                    for r in (curRow + 1)..<rows {
                        for c in 0..<cols {
                            grid[r][c] = TerminalCell()
                        }
                    }
                }
            } else if mode == 1 {
                // Erase from top of screen to cursor
                if curRow > 0 {
                    for r in 0..<min(curRow, rows) {
                        for c in 0..<cols {
                            grid[r][c] = TerminalCell()
                        }
                    }
                }
                if curRow >= 0 && curRow < rows {
                    let endC = min(cols - 1, max(0, curCol))
                    for c in 0...endC {
                        grid[curRow][c] = TerminalCell()
                    }
                }
            } else if mode == 2 || mode == 3 {
                reset()
            }
        case "K": // Erase in line
            let mode = parts.first ?? 0
            if curRow >= 0 && curRow < rows {
                if mode == 0 {
                    let startC = max(0, min(cols - 1, curCol))
                    for c in startC..<cols {
                        grid[curRow][c] = TerminalCell()
                    }
                } else if mode == 1 {
                    let endC = min(cols - 1, max(0, curCol))
                    for c in 0...endC {
                        grid[curRow][c] = TerminalCell()
                    }
                } else if mode == 2 {
                    for c in 0..<cols {
                        grid[curRow][c] = TerminalCell()
                    }
                }
            }
        case "m": // SGR styling
            if parts.isEmpty {
                resetStyle()
            } else {
                var i = 0
                while i < parts.count {
                    let p = parts[i]
                    switch p {
                    case 0:
                        resetStyle()
                    case 1:
                        currentBold = true
                    case 2:
                        currentDim = true
                    case 22:
                        currentBold = false
                        currentDim = false
                    case 30...37, 90...97:
                        currentFg = standardColor(p)
                    case 38:
                        if i + 2 < parts.count && parts[i + 1] == 5 {
                            currentFg = color256(parts[i + 2])
                            i += 2
                        } else if i + 4 < parts.count && parts[i + 1] == 2 {
                            let r = CGFloat(parts[i + 2]) / 255.0
                            let g = CGFloat(parts[i + 3]) / 255.0
                            let b = CGFloat(parts[i + 4]) / 255.0
                            currentFg = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                            i += 4
                        }
                    case 39:
                        currentFg = NSColor(white: 0.95, alpha: 1.0)
                    case 40...47, 100...107:
                        currentBg = standardColor(p - 10)
                    case 48:
                        if i + 2 < parts.count && parts[i + 1] == 5 {
                            currentBg = color256(parts[i + 2])
                            i += 2
                        } else if i + 4 < parts.count && parts[i + 1] == 2 {
                            let r = CGFloat(parts[i + 2]) / 255.0
                            let g = CGFloat(parts[i + 3]) / 255.0
                            let b = CGFloat(parts[i + 4]) / 255.0
                            currentBg = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                            i += 4
                        }
                    case 49:
                        currentBg = .clear
                    default:
                        break
                    }
                    i += 1
                }
            }
        default:
            break
        }
    }

    private func resetStyle() {
        currentFg = NSColor(white: 0.95, alpha: 1.0)
        currentBg = .clear
        currentBold = false
        currentDim = false
    }

    func activeRowCount() -> Int {
        var lastUsed = -1
        for r in 0..<rows {
            var hasChar = false
            for c in 0..<cols {
                if grid[r][c].char != " " || grid[r][c].bg != .clear {
                    hasChar = true
                    break
                }
            }
            if hasChar {
                lastUsed = r
            }
        }
        return lastUsed >= 0 ? lastUsed + 1 : 1
    }

    func renderAttributedString(baseFont: NSFont, totalRows: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        let rowsToRender = min(totalRows, rows)

        for r in 0..<rowsToRender {
            let line = grid[r]
            var endCol = cols - 1
            while endCol > 0 && line[endCol].char == " " && line[endCol].bg == .clear {
                endCol -= 1
            }

            var currentCol: Int = 0
            while currentCol <= endCol {
                let cell = line[currentCol]
                var runText = String(cell.char)
                var nextCol = currentCol + 1

                while nextCol <= endCol &&
                      line[nextCol].fg == cell.fg &&
                      line[nextCol].bg == cell.bg &&
                      line[nextCol].bold == cell.bold &&
                      line[nextCol].dim == cell.dim {
                    runText.append(line[nextCol].char)
                    nextCol += 1
                }

                var attrs: [NSAttributedString.Key: Any] = [
                    .font: cell.bold ? boldFont : baseFont,
                    .foregroundColor: cell.dim ? cell.fg.withAlphaComponent(0.65) : cell.fg
                ]
                if cell.bg != .clear {
                    attrs[.backgroundColor] = cell.bg
                }

                result.append(NSAttributedString(string: runText, attributes: attrs))
                currentCol = nextCol
            }

            if r < rowsToRender - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            }
        }
        return result
    }
}

// ============================================================================
// OLED HUD Container View
// ============================================================================

class HUDContainerView: NSView {
    let cornerRadius: CGFloat = 18.0

    override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = cornerRadius
        self.layer?.masksToBounds = true
        // True OLED Deep Black (#000000 with 95% alpha)
        self.layer?.backgroundColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.95).cgColor
        self.layer?.borderColor = NSColor(white: 1.0, alpha: 0.14).cgColor
        self.layer?.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

class FloatTerminalPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

// ============================================================================
// Main Application & Controller
// ============================================================================

class FloatHUDApp: NSObject, NSApplicationDelegate {
    var window: FloatTerminalPanel!
    var textView: NSTextView!
    var containerView: HUDContainerView!
    let terminalCols = 40
    let terminalRows = 24
    lazy var terminal = VirtualTerminal(rows: terminalRows, cols: terminalCols)
    let font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .medium)
    var ptyMaster: Int32 = -1
    var process: Process?
    var statdCommand: [String] = []
    var initialOpacity: CGFloat = 0.95

    var charSize: NSSize = .zero
    let paddingH: CGFloat = 16.0
    let paddingV: CGFloat = 14.0
    var currentRenderedRows: Int = 0

    init(statdArgs: [String], opacity: CGFloat = 0.95) {
        self.statdCommand = statdArgs
        self.initialOpacity = opacity
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        launchStatd()
        setupEventMonitors()
    }

    func setupWindow() {
        let sampleChar = "M" as NSString
        charSize = sampleChar.size(withAttributes: [.font: font])

        let initialRows = 16
        currentRenderedRows = initialRows

        // Provide generous text width margin (+16pt) so lines NEVER wrap
        let contentWidth = ceil(charSize.width * CGFloat(terminalCols)) + 16.0
        let winWidth = contentWidth + (paddingH * 2)
        let winHeight = ceil(charSize.height * CGFloat(initialRows)) + (paddingV * 2)

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let posX = screenRect.maxX - winWidth - 28
        let posY = screenRect.maxY - winHeight - 28

        let frame = NSRect(x: posX, y: posY, width: winWidth, height: winHeight)

        window = FloatTerminalPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.alphaValue = initialOpacity

        containerView = HUDContainerView(frame: NSRect(x: 0, y: 0, width: winWidth, height: winHeight))
        containerView.autoresizingMask = [.width, .height]

        let textRect = NSRect(x: paddingH, y: paddingV, width: contentWidth, height: winHeight - (paddingV * 2))
        textView = NSTextView(frame: textRect)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        // Crucial: strict clipping with infinite container width so lines NEVER wrap
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byClipping
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        textView.textContainerInset = .zero

        containerView.addSubview(textView)
        window.contentView = containerView
        window.makeKeyAndOrderFront(nil)
    }

    func launchStatd() {
        var master: Int32 = 0
        var slave: Int32 = 0
        var ws = winsize(ws_row: UInt16(terminalRows), ws_col: UInt16(terminalCols), ws_xpixel: 0, ws_ypixel: 0)

        guard openpty(&master, &slave, nil, nil, &ws) == 0 else {
            fputs("statd float: openpty failed\n", stderr)
            exit(1)
        }
        self.ptyMaster = master

        let proc = Process()
        let executable = statdCommand[0]
        proc.executableURL = URL(fileURLWithPath: executable)
        if statdCommand.count > 1 {
            proc.arguments = Array(statdCommand[1...])
        } else {
            proc.arguments = []
        }

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLUMNS"] = String(terminalCols)
        env["LINES"] = String(terminalRows)
        proc.environment = env

        let handle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        proc.standardInput = handle
        proc.standardOutput = handle
        proc.standardError = handle

        proc.terminationHandler = { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            fputs("statd float: failed to launch \(executable): \(error)\n", stderr)
            exit(1)
        }

        // Read PTY asynchronously with persistent UTF-8 chunk buffering
        let ptyQueue = DispatchQueue(label: "com.statd.float.ptyReader", qos: .userInteractive)
        ptyQueue.async { [weak self] in
            let bufferSize = 8192
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buf.deallocate() }

            var pendingBytes = [UInt8]()

            while true {
                let n = read(master, buf, bufferSize)
                if n <= 0 {
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                    break
                }

                let newBytes = Array(UnsafeBufferPointer(start: buf, count: n))
                let totalBytes = pendingBytes + newBytes
                let (completeBytes, remainder) = splitIncompleteUTF8(totalBytes)
                pendingBytes = remainder

                if !completeBytes.isEmpty {
                    let str = String(decoding: completeBytes, as: UTF8.self)
                    DispatchQueue.main.async {
                        self?.processTerminalData(str)
                    }
                }
            }
        }
    }

    func processTerminalData(_ str: String) {
        terminal.write(str)

        let activeRows = terminal.activeRowCount()
        let targetRows = max(2, activeRows)

        let attrStr = terminal.renderAttributedString(baseFont: font, totalRows: targetRows)
        textView.textStorage?.setAttributedString(attrStr)

        if targetRows != currentRenderedRows {
            currentRenderedRows = targetRows
            adjustWindowHeight(targetRows: targetRows)
        }
    }

    func adjustWindowHeight(targetRows: Int) {
        let neededHeight = ceil(charSize.height * CGFloat(targetRows)) + (paddingV * 2)
        var frame = window.frame
        if abs(frame.height - neededHeight) > 1.0 {
            let heightDelta = neededHeight - frame.height
            frame.origin.y -= heightDelta
            frame.size.height = neededHeight

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        }
    }

    func setupEventMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let chars = event.charactersIgnoringModifiers ?? ""
            if chars == "q" || event.keyCode == 53 { // 'q' or Escape
                self.cleanupAndExit()
                return nil
            } else if chars == "+" || chars == "=" { // Increase opacity
                self.window.alphaValue = min(1.0, self.window.alphaValue + 0.05)
                return nil
            } else if chars == "-" { // Decrease opacity
                self.window.alphaValue = max(0.2, self.window.alphaValue - 0.05)
                return nil
            }

            // Forward interactive toggle keys (f, c, g, l, n, b, s, d) to StatD
            if let firstChar = chars.utf8.first, self.ptyMaster >= 0 {
                var b = firstChar
                write(self.ptyMaster, &b, 1)
                return nil
            }

            return event
        }
    }

    func cleanupAndExit() {
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        if ptyMaster >= 0 {
            close(ptyMaster)
            ptyMaster = -1
        }
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupAndExit()
    }
}

// ============================================================================
// CLI Entrypoint
// ============================================================================

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var statdPath = "./statd"
var statdExtraArgs: [String] = []
var requestedOpacity: CGFloat = 0.95

var args = CommandLine.arguments
if args.count > 1 {
    statdPath = args[1]
}
if args.count > 2 {
    var i = 2
    while i < args.count {
        if args[i] == "--opacity" && i + 1 < args.count {
            if let val = Double(args[i + 1]) {
                requestedOpacity = CGFloat(max(0.2, min(1.0, val)))
            }
            i += 2
        } else {
            statdExtraArgs.append(args[i])
            i += 1
        }
    }
}

// Follow standard stable width (not forced fullscreen)
let fullCmd = [statdPath] + statdExtraArgs
let delegate = FloatHUDApp(statdArgs: fullCmd, opacity: requestedOpacity)
app.delegate = delegate
app.run()
