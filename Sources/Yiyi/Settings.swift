import Foundation
import SwiftUI
import Security

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let account = "com.yiyi.deepseek.apikey"
    private let service = "com.yiyi.app"

    @Published var apiKeyInput: String = ""
    private var cachedKey: String?

    init() {
        let initial = readKeychain()
        cachedKey = initial
        apiKeyInput = initial ?? ""
    }

    var apiKey: String? {
        if let cachedKey { return cachedKey }
        let fetched = readKeychain()
        cachedKey = fetched
        return fetched
    }

    private func readKeychain() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = trimmed.data(using: .utf8) ?? Data()
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        SecItemDelete(q as CFDictionary)
        if trimmed.isEmpty {
            cachedKey = nil
            return
        }
        var attr = q
        attr[kSecValueData as String] = data
        SecItemAdd(attr as CFDictionary, nil)
        cachedKey = trimmed
    }
}

struct SettingsView: View {
    @StateObject private var store = SettingsStore.shared
    @State private var savedAt: Date?

    var body: some View {
        Form {
            Section {
                SecureField("sk-...", text: $store.apiKeyInput)
                Text("在 [platform.deepseek.com](https://platform.deepseek.com) 申请 API Key。密钥存放于系统 Keychain。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("DeepSeek API Key")
            }

            Section {
                LabeledContent("触发翻译") {
                    Text("⌥ D").font(.system(.body, design: .monospaced))
                }
                LabeledContent("关闭面板") {
                    Text("Esc").font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("快捷键")
            }

            Section {
                Text("首次使用请在「系统设置 → 隐私与安全性 → 辅助功能」中为 译译 打勾，才能读取选中文本。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("使用说明")
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                if let savedAt, Date().timeIntervalSince(savedAt) < 2 {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
                Spacer()
                Button("保存") {
                    store.setAPIKey(store.apiKeyInput)
                    savedAt = Date()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.bar)
        }
        .frame(width: 440, height: 360)
    }
}
