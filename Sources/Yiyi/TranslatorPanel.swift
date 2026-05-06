import AppKit
import SwiftUI

// MARK: - Panel

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TranslatorPanel: NSObject {
    private var window: FloatingPanel?
    private let viewModel = TranslationViewModel()
    private var eventMonitor: Any?

    func present(text: String) {
        if window == nil { makeWindow() }
        viewModel.reset(source: text)
        positionNearCursor()
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
        installEscMonitor()
        Task { await viewModel.translate() }
    }

    func dismiss() {
        removeEscMonitor()
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            window.animator().alphaValue = 0
        }, completionHandler: { [weak window] in
            window?.orderOut(nil)
        })
    }

    // MARK: - Window

    private func makeWindow() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let rootView = TranslationView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.dismiss() }
        )
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        panel.contentViewController = hosting
        self.window = panel
    }

    private func positionNearCursor() {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation
        let size = window.frame.size
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        var x = mouse.x + 14
        var y = mouse.y - size.height - 14
        if x + size.width > frame.maxX { x = frame.maxX - size.width - 14 }
        if x < frame.minX { x = frame.minX + 14 }
        if y < frame.minY { y = mouse.y + 14 }
        if y + size.height > frame.maxY { y = frame.maxY - size.height - 14 }
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installEscMonitor() {
        removeEscMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - ViewModel

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var source: String = ""
    @Published var translated: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?

    func reset(source: String) {
        self.source = source
        self.translated = ""
        self.errorMessage = nil
        self.isStreaming = false
    }

    func translate() async {
        guard let key = SettingsStore.shared.apiKey, !key.isEmpty else {
            errorMessage = "请先在「设置」中填入 DeepSeek API Key"
            return
        }
        isStreaming = true
        defer { isStreaming = false }
        do {
            let client = DeepSeekClient(apiKey: key)
            try await client.streamTranslate(text: source) { [weak self] delta in
                Task { @MainActor in
                    self?.translated += delta
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct TranslationView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let onClose: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.25)
            content
        }
        .background(VisualEffect(material: .popover, blending: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 560, minHeight: 140, maxHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Circle()
                    .fill(Color(red: 1, green: 0.37, blue: 0.35))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")

            Text("译译")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.isStreaming {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 14, height: 14)
            }

            Button(action: copyResult) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("复制译文")
            .disabled(viewModel.translated.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.source)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(2)

                if let err = viewModel.errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                } else if viewModel.translated.isEmpty && viewModel.isStreaming {
                    Text("翻译中…")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(viewModel.translated)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .animation(.easeOut(duration: 0.08), value: viewModel.translated)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.never)
    }

    private func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(viewModel.translated, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}

// MARK: - VisualEffect wrapper

struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
