import Foundation
import LLMRuleCore

final class LLMRefiner {
    func refine(_ text: String, completion: @escaping (String?) -> Void) {
        refineDecision(text) { decision in
            completion(decision.accepted ? decision.text : nil)
        }
    }

    func refineDecision(_ text: String, completion: @escaping (LLMCorrectionDecision) -> Void) {
        let apiKey = Preferences.shared.llmAPIKey
        let baseURL = Preferences.shared.llmBaseURL
        let model = Preferences.shared.llmModel
        let systemPrompt = LLMRulePrompt.buildSystemPrompt(
            rules: LLMRuleSettings(
                punctuationEnabled: Preferences.shared.llmPunctuationEnabled,
                sentenceBreakEnabled: Preferences.shared.llmSentenceBreakEnabled,
                fillerWordsEnabled: Preferences.shared.llmFillerWordsEnabled,
                customRules: Preferences.shared.llmCustomRules,
                mode: Preferences.shared.llmCorrectionMode,
                language: Preferences.shared.language,
                glossary: Preferences.shared.llmGlossary
            )
        )

        guard !baseURL.isEmpty, !model.isEmpty else {
            completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM 配置不完整，回退原文"))
            return
        }

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/chat/completions") else {
            completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM URL 格式错误，回退原文"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Self.setAuthorizationHeader(on: &request, apiKey: apiKey)

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
            completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM 请求序列化失败，回退原文"))
            return
        }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                AppLogger.llm.error("LLM error: \(error.localizedDescription)")
                completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM 请求失败：\(error.localizedDescription)"))
                return
            }
            if let code = (response as? HTTPURLResponse)?.statusCode, code >= 400 {
                AppLogger.llm.error("LLM HTTP error: \(code)")
                completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM HTTP \(code)，回退原文"))
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
                completion(LLMCorrectionDecision(text: text, accepted: false, reason: "LLM 响应解析失败，回退原文"))
                return
            }
            let refined = LLMOutputSanitizer.sanitize(content)
            let decision = LLMCorrectionGuard.evaluate(
                original: text,
                candidate: refined,
                mode: Preferences.shared.llmCorrectionMode
            )
            AppLogger.llm.info("LLM refined \(text.count) → \(refined.count) chars: \(decision.reason)")
            completion(decision)
        }.resume()
    }

    func testConnection(completion: @escaping (Bool, String) -> Void) {
        let apiKey = Preferences.shared.llmAPIKey
        let baseURL = Preferences.shared.llmBaseURL

        guard !baseURL.isEmpty else {
            completion(false, "Base URL 为空")
            return
        }

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/models") else {
            completion(false, "URL 格式错误")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        Self.setAuthorizationHeader(on: &request, apiKey: apiKey)

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

    static func setAuthorizationHeader(on request: inout URLRequest, apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }
}
