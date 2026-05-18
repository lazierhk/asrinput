import Foundation

public enum LLMCorrectionMode: String, CaseIterable, Codable {
    case strict
    case lightCleanup
    case terminologyFocused

    public var displayName: String {
        switch self {
        case .strict:
            return "严格保守"
        case .lightCleanup:
            return "轻度整理"
        case .terminologyFocused:
            return "术语优先"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .strict:
            return "严格保守：只修正非常明显的语音识别错误；不确定时必须原样返回。"
        case .lightCleanup:
            return "轻度整理：可以修正明显识别错误、补全必要标点和自然断句，但不能润色、概括或重写。"
        case .terminologyFocused:
            return "术语优先：优先根据用户术语表修正技术词、产品名、人名和公司名；其他内容保持保守。"
        }
    }
}
