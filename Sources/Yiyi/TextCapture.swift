import AppKit

enum TextCapture {
    /// 获取当前选中文本：优先走 Accessibility API，失败则模拟 ⌘C 兜底（并恢复剪贴板）。
    static func grabSelectedText(completion: @escaping (String?) -> Void) {
        NSLog("[Yiyi] grabSelectedText: trying AX path")
        if let text = readFromAccessibility(), !text.isEmpty {
            NSLog("[Yiyi] AX path OK: %d chars", text.count)
            completion(text)
            return
        }
        NSLog("[Yiyi] AX path empty, falling back to ⌘C")
        simulateCopyAndRead(completion: completion)
    }

    // MARK: - Accessibility path

    private static func readFromAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusResult == .success, let element = focused else {
            NSLog("[Yiyi] AX: no focused element (status=%d)", focusResult.rawValue)
            return nil
        }
        // swiftlint:disable:next force_cast
        let axElement = element as! AXUIElement
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success, let s = value as? String else {
            NSLog("[Yiyi] AX: kAXSelectedTextAttribute failed (status=%d)", result.rawValue)
            return nil
        }
        return s
    }

    // MARK: - Pasteboard fallback

    private static func simulateCopyAndRead(completion: @escaping (String?) -> Void) {
        let pb = NSPasteboard.general
        let snapshot = snapshotPasteboard()
        let oldChangeCount = pb.changeCount

        postCmdC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let text: String?
            if pb.changeCount != oldChangeCount {
                text = pb.string(forType: .string)
                NSLog("[Yiyi] ⌘C fallback OK: changeCount %d→%d, %d chars", oldChangeCount, pb.changeCount, text?.count ?? 0)
            } else {
                text = nil
                NSLog("[Yiyi] ⌘C fallback FAILED: changeCount unchanged (%d). Likely Accessibility permission missing or app blocked ⌘C.", pb.changeCount)
            }
            restorePasteboard(snapshot)
            completion(text)
        }
    }

    private static func postCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 0x08
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func snapshotPasteboard() -> [NSPasteboardItem] {
        guard let items = NSPasteboard.general.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private static func restorePasteboard(_ items: [NSPasteboardItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if !items.isEmpty {
            pb.writeObjects(items)
        }
    }
}
