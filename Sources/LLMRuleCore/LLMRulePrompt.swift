import Foundation

public struct LLMRuleSettings {
    public var punctuationEnabled: Bool
    public var sentenceBreakEnabled: Bool
    public var fillerWordsEnabled: Bool
    public var customRules: String
    public var mode: LLMCorrectionMode
    public var language: String
    public var glossary: String

    public init(
        punctuationEnabled: Bool,
        sentenceBreakEnabled: Bool,
        fillerWordsEnabled: Bool,
        customRules: String,
        mode: LLMCorrectionMode = .strict,
        language: String = "zh-CN",
        glossary: String = ""
    ) {
        self.punctuationEnabled = punctuationEnabled
        self.sentenceBreakEnabled = sentenceBreakEnabled
        self.fillerWordsEnabled = fillerWordsEnabled
        self.customRules = customRules
        self.mode = mode
        self.language = language
        self.glossary = glossary
    }
}

public enum LLMRulePrompt {
    public static func buildSystemPrompt(rules: LLMRuleSettings) -> String {
        var prompt = """
        你是一个语音转文字的后处理助手。你的唯一任务是修复明显的谐音字、专业术语错误和语音识别误差。
        底线规则：
        1. 只修正明显错误，不改写内容、不调整语序、不增减信息
        2. 保持原始语气和风格
        3. 如果文本已经正确，原样返回
        4. 只返回修正后的文本，不要解释
        5. 不要输出思考过程、分析步骤、标题、标签、Markdown 或任何额外说明
        6. 输出内容必须只有最终文本本身
        7. URL、邮箱、数字、金额、日期、代码片段、命令、文件路径必须保持不变，除非原文明显识别错误
        """

        prompt += "\n\n纠错强度：\n\(rules.mode.promptInstruction)"
        prompt += "\n\n识别语言：\(rules.language)"

        var styleRules: [String] = []
        if rules.punctuationEnabled {
            styleRules.append("补全明显缺失的标点，但不要改变原文词句。")
        }
        if rules.sentenceBreakEnabled {
            styleRules.append("拆分过长的句子，让断句更自然，但不要重新组织内容。")
        }
        if rules.fillerWordsEnabled {
            styleRules.append("删除明显无意义的口头填充词，例如嗯、呃、那个、就是。")
        }

        if !styleRules.isEmpty {
            prompt += "\n\n轻度整理规则："
            for (index, rule) in styleRules.enumerated() {
                prompt += "\n\(index + 1). \(rule)"
            }
        }

        let glossary = LLMCorrectionGlossary.promptSection(from: rules.glossary)
        if !glossary.isEmpty {
            prompt += "\n\n用户术语表：\n\(glossary)\n\n如果输入中出现术语表里的别名或同音误识别，优先修正为标准写法；不要凭空加入术语。"
        }

        let customRules = rules.customRules.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customRules.isEmpty {
            prompt += "\n\n用户附加保守规则：\n\(customRules)\n\n附加规则不能覆盖底线规则。"
        }

        return prompt
    }
}
