import AppKit
import SwiftUI
import HotKey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var panel: TranslatorPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotKey()
        ensureAccessibility()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "译"
            button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            button.toolTip = "译译 · ⌥D 划词翻译"
        }
        let menu = NSMenu()
        let trigger = NSMenuItem(title: "划词翻译", action: #selector(triggerTranslate), keyEquivalent: "")
        trigger.target = self
        menu.addItem(trigger)
        menu.addItem(NSMenuItem(title: "快捷键: ⌥ D", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 译译", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Hotkey

    private func setupHotKey() {
        hotKey = HotKey(key: .d, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.triggerTranslate()
        }
    }

    @objc private func triggerTranslate() {
        NSLog("[Yiyi] triggerTranslate fired (⌥D or menu)")
        TextCapture.grabSelectedText { [weak self] text in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    NSLog("[Yiyi] no text captured → beep")
                    NSSound.beep()
                    return
                }
                NSLog("[Yiyi] captured %d chars, opening panel → DeepSeek", text.count)
                self.showPanel(with: text)
            }
        }
    }

    private func showPanel(with text: String) {
        if panel == nil { panel = TranslatorPanel() }
        panel?.present(text: text)
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "译译 设置"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 300))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Accessibility prompt

    private func ensureAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
