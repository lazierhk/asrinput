import Foundation
import LLMRuleCore

final class LLMRefiner {
    func refine(_ text: String, completion: @escaping (String?) -> Void) {
        let apiKey = Preferences.shared.llmAPIKey
        let baseURL = Preferences.shared.llmBaseURL
        let model = Preferences.shared.llmModel
        let systemPrompt = LLMRulePrompt.buildSystemPrompt(
            rules: LLMRuleSettings(
                punctuationEnabled: Preferences.shared.llmPunctuationEnabled,
                sentenceBreakEnabled: Preferences.shared.llmSentenceBreakEnabled,
                fillerWordsEnabled: Preferences.shared.llmFillerWordsEnabled,
                customRules: Preferences.shared.llmCustomRules
            )
        )

        guard !apiKey.isEmpty, !baseURL.isEmpty else {
            completion(nil)
            return
        }

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/chat/completions") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 512,
            "temperature": 0.1
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                AppLogger.llm.error("LLM error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                AppLogger.llm.error("LLM response parse failed")
                completion(nil)
                return
            }
            let refined = LLMOutputSanitizer.sanitize(content)
            AppLogger.llm.info("LLM refined \(text.count) → \(refined.count) chars")
            completion(refined.isEmpty ? nil : refined)
        }.resume()
    }

    func testConnection(completion: @escaping (Bool, String) -> Void) {
        let apiKey = Preferences.shared.llmAPIKey
        let baseURL = Preferences.shared.llmBaseURL

        guard !apiKey.isEmpty, !baseURL.isEmpty else {
            completion(false, "API Key 或 Base URL 为空")
            return
        }

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/models") else {
            completion(false, "URL 格式错误")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                completion(false, error.localizedDescription)
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                completion(true, "连接成功 ✓")
            } else {
                completion(false, "HTTP \(code)")
            }
        }.resume()
    }
}
