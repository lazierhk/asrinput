public enum LLMPromptMode: String, CaseIterable {
    case plain
    case punctuation
    case terminology
    case chat
    case email
    case meeting

    public var displayName: String {
        switch self {
        case .plain: return "原样输入"
        case .punctuation: return "标点整理"
        case .terminology: return "技术术语"
        case .chat: return "聊天口语"
        case .email: return "邮件语气"
        case .meeting: return "会议纪要"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .plain:
            return "尽量保持原文，只修正明显识别错误。"
        case .punctuation:
            return "重点补全标点、断句和轻微口头禅清理，不改变原意。"
        case .terminology:
            return "优先保护和修正技术名词、英文缩写、代码相关词汇和专有名词。"
        case .chat:
            return "保持自然口语风格，适合聊天软件；不要改成正式书面语。"
        case .email:
            return "在不增减信息的前提下，让文本更适合邮件或正式消息。"
        case .meeting:
            return "在不扩写事实的前提下，让文本更适合会议记录式表达。"
        }
    }
}
