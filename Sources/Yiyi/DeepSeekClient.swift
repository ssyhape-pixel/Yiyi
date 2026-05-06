import Foundation

struct DeepSeekClient {
    let apiKey: String
    let model: String

    init(apiKey: String, model: String = "deepseek-chat") {
        self.apiKey = apiKey
        self.model = model
    }

    /// 流式翻译。onDelta 会在主线程之外被多次调用。
    func streamTranslate(text: String, onDelta: @escaping (String) -> Void) async throws {
        NSLog("[Yiyi] DeepSeek request: model=%@, %d chars, key length=%d", model, text.count, apiKey.count)
        let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 30

        let system = """
        你是一个高质量翻译引擎。规则：
        - 若输入是中文，译成自然地道的英文
        - 若输入是其他语言，译成简洁准确的中文
        - 直接输出译文，不要任何解释、前缀、引号或标注
        - 保持原文的语气和格式（换行、标点）
        """
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekError.transport("无响应")
        }
        NSLog("[Yiyi] DeepSeek HTTP status: %d", http.statusCode)
        guard http.statusCode == 200 else {
            var body = ""
            for try await line in bytes.lines { body += line; if body.count > 400 { break } }
            NSLog("[Yiyi] DeepSeek error body: %@", body)
            throw DeepSeekError.http(http.statusCode, body)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line
                .dropFirst(5)
                .trimmingCharacters(in: .whitespaces)
            if payload.isEmpty { continue }
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String,
                  !content.isEmpty else { continue }
            onDelta(content)
        }
    }
}

enum DeepSeekError: LocalizedError {
    case http(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            return "DeepSeek 返回 \(code)：\(body.prefix(200))"
        case .transport(let msg):
            return "网络错误：\(msg)"
        }
    }
}
