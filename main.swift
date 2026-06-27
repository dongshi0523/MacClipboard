import SwiftUI
import AppKit

// MARK: - Data Model
struct ClipboardEntry: Identifiable {
    let id = UUID()
    let content: String
    let timestamp: Date

    var preview: String {
        let first = content.components(separatedBy: .newlines).first ?? ""
        return first.count > 80 ? String(first.prefix(80)) + "…" : first
    }

    var secondLine: String {
        let lines = content.components(separatedBy: .newlines)
        if lines.count > 1 {
            let second = lines[1]
            return second.count > 70 ? String(second.prefix(70)) + "…" : second
        }
        return ""
    }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }

    var charCount: Int { content.count }
}

// MARK: - Clipboard Manager
class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardEntry] = []
    @Published var lastCopiedID: UUID?
    private var lastChangeCount: Int = 0
    private var timer: Timer?

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.history.first?.content == text { return }

            let entry = ClipboardEntry(content: text, timestamp: Date())
            self.history.insert(entry, at: 0)
            if self.history.count > 200 {
                self.history.removeLast()
            }
        }
    }

    func copy(_ entry: ClipboardEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.content, forType: .string)
        lastChangeCount = pb.changeCount
        lastCopiedID = entry.id
    }

    func remove(_ entry: ClipboardEntry) {
        history.removeAll { $0.id == entry.id }
    }

    func clear() {
        history.removeAll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Custom Panels
class BallPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var ballPanel: BallPanel!
    var historyPanel: HistoryPanel?
    let manager = ClipboardManager()
    var isExpanded = false
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        manager.start()
        createBall()
        registerHotKey()

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            ballPanel.setFrameOrigin(NSPoint(x: f.maxX - 80, y: f.maxY - 80))
        }
    }

    // MARK: - Global Hotkey (⌘+Shift+V)
    func registerHotKey() {
        // Monitor global keyboard events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘+Shift+V = keyCode 9 (V), flags: .command + .shift
            let isCmdShiftV = event.keyCode == 9
                && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift]

            if isCmdShiftV {
                DispatchQueue.main.async {
                    self?.toggleHistory()
                }
            }
        }
    }

    func createBall() {
        let panel = BallPanel(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: BallView(onTap: { [weak self] in
            self?.toggleHistory()
        }))
        host.frame = NSRect(x: 0, y: 0, width: 48, height: 48)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.ballPanel = panel
        panel.orderFront(nil)
    }

    func toggleHistory() {
        isExpanded ? collapseHistory() : expandHistory()
    }

    func expandHistory() {
        guard historyPanel == nil else { return }

        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor(white: 0.1, alpha: 0.94)
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.title = ""
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.isReleasedWhenClosed = false

        if let bf = ballPanel?.frame {
            panel.setFrameOrigin(NSPoint(
                x: bf.maxX - 380,
                y: bf.minY - 520 + 48
            ))
        }

        let host = NSHostingView(rootView: HistoryView(
            manager: manager,
            onSelect: { [weak self] entry in
                self?.manager.copy(entry)
            },
            onRemove: { [weak self] entry in
                self?.manager.remove(entry)
            },
            onClear: { [weak self] in
                self?.manager.clear()
            }
        ))
        host.frame = NSRect(x: 0, y: 0, width: 380, height: 520)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.historyPanel = panel
        isExpanded = true
        panel.orderFront(nil)
    }

    func collapseHistory() {
        historyPanel?.close()
        historyPanel = nil
        isExpanded = false
    }

    func windowDidResignKey(_ notification: Notification) {
        if isExpanded { collapseHistory() }
    }
}

// MARK: - SwiftUI Views

struct BallView: View {
    var onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(hovered ? 1.0 : 0.85))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .contentShape(Circle())
            .scaleEffect(hovered ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct HistoryView: View {
    @ObservedObject var manager: ClipboardManager
    var onSelect: (ClipboardEntry) -> Void
    var onRemove: (ClipboardEntry) -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Text("剪贴板历史")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if !manager.history.isEmpty {
                    Text("\(manager.history.count) 条")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                Button(action: onClear) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .medium))
                        Text("清除全部").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(.red.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(manager.history.isEmpty)
                .opacity(manager.history.isEmpty ? 0.3 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            // List
            if manager.history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("暂无复制记录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Text("复制文本后会自动出现在这里")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.18))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(manager.history) { entry in
                            HistoryRow(
                                entry: entry,
                                isCopied: manager.lastCopiedID == entry.id,
                                onSelect: { onSelect(entry) },
                                onRemove: { onRemove(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }

            // Footer
            HStack {
                Image(systemName: "command")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.2))
                Text("⌘⇧V 唤起 · 悬浮球可拖拽")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.2))
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.white.opacity(0.03))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HistoryRow: View {
    let entry: ClipboardEntry
    let isCopied: Bool
    var onSelect: () -> Void
    var onRemove: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.preview)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !entry.secondLine.isEmpty {
                        Text(entry.secondLine)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 8) {
                        Text(entry.timeString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                        Text("\(entry.charCount) 字符")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.15))
                    }
                }

                if hovered {
                    HStack(spacing: 6) {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green.opacity(0.7))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        hovered
                            ? Color.white.opacity(0.08)
                            : isCopied
                                ? Color.green.opacity(0.04)
                                : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isCopied ? Color.green.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.2), value: isCopied)
    }
}

// MARK: - Entry Point
@main
struct MacClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
