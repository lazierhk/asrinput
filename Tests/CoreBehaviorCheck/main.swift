import Foundation
import LLMRuleCore
import OverlayHUDCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let defaultPrompt = LLMRulePrompt.buildSystemPrompt(
    rules: LLMRuleSettings(
        punctuationEnabled: true,
        sentenceBreakEnabled: true,
        fillerWordsEnabled: true,
        customRules: ""
    )
)

require(defaultPrompt.contains("只修正明显错误"), "keeps conservative baseline")
require(defaultPrompt.contains("补全明显缺失的标点"), "includes punctuation rule by default")
require(defaultPrompt.contains("拆分过长的句子"), "includes sentence break rule by default")
require(defaultPrompt.contains("删除明显无意义的口头填充词"), "includes filler-word rule by default")

let selectivePrompt = LLMRulePrompt.buildSystemPrompt(
    rules: LLMRuleSettings(
        punctuationEnabled: true,
        sentenceBreakEnabled: false,
        fillerWordsEnabled: false,
        customRules: "公司名 Acme 不要改成艾克米"
    )
)

require(selectivePrompt.contains("补全明显缺失的标点"), "keeps enabled punctuation rule")
require(!selectivePrompt.contains("拆分过长的句子"), "omits disabled sentence break rule")
require(!selectivePrompt.contains("删除明显无意义的口头填充词"), "omits disabled filler-word rule")
require(selectivePrompt.contains("公司名 Acme 不要改成艾克米"), "includes trimmed custom rules")
require(defaultPrompt.contains("不要输出思考过程"), "prompt forbids chain-of-thought output")
require(defaultPrompt.contains("严格保守"), "prompt includes default correction mode")
require(defaultPrompt.contains("URL、邮箱、数字"), "prompt protects structured tokens")

let leakedThinkingOutput = """
Here's a thinking process:

1. Analyze User Input:
   - Input: "你好啊，你好啊，我想知道明天是什么天气。"
   - Task: Post-process speech-to-text output.

Final decision: Output exactly the input text.
Output: 你好啊，你好啊，我想知道明天是什么天气。
"""

require(
    LLMOutputSanitizer.sanitize(leakedThinkingOutput) == "你好啊，你好啊，我想知道明天是什么天气。",
    "extracts final text from leaked thinking process"
)

let thinkTagOutput = """
<think>
The input is already correct.
</think>
你好啊，你好啊，我想知道明天是什么天气。
"""

require(
    LLMOutputSanitizer.sanitize(thinkTagOutput) == "你好啊，你好啊，我想知道明天是什么天气。",
    "removes think tags"
)

require(
    LLMOutputSanitizer.sanitize("你好啊，你好啊，我想知道明天是什么天气。")
        == "你好啊，你好啊，我想知道明天是什么天气。",
    "keeps clean output unchanged"
)

let glossary = """
Python = 配森, 派森
JSON = 杰森
ASRInput = ASR input, asr input
"""
let entries = LLMCorrectionGlossary.parse(glossary)
require(entries.count == 3, "parses glossary entries")
require(entries[0].canonical == "Python", "keeps glossary canonical term")
require(entries[0].aliases == ["配森", "派森"], "parses glossary aliases")
require(entries[2].canonical == "ASRInput", "parses arrow canonical term")
require(entries[2].aliases == ["ASR input", "asr input"], "parses arrow aliases")

let glossaryPrompt = LLMRulePrompt.buildSystemPrompt(
    rules: LLMRuleSettings(
        punctuationEnabled: true,
        sentenceBreakEnabled: true,
        fillerWordsEnabled: true,
        customRules: "",
        mode: .terminologyFocused,
        language: "zh-CN",
        glossary: glossary
    )
)
require(glossaryPrompt.contains("术语优先"), "prompt includes selected correction mode")
require(glossaryPrompt.contains("Python：配森、派森"), "prompt includes glossary section")

require(
    WordReplacementService.apply(to: "我用配森处理杰森数据。", glossary: glossary) == "我用Python处理JSON数据。",
    "applies glossary word replacements before injection"
)

require(
    WordReplacementService.apply(to: "ASR input 已启动。", glossary: glossary) == "ASRInput 已启动。",
    "applies arrow-format aliases"
)

require(
    WordReplacementService.apply(to: "没有匹配项", glossary: "") == "没有匹配项",
    "keeps text unchanged when glossary is empty"
)

let overlappingGlossary = """
Kubernetes = 酷伯内提斯, 酷伯
"""
require(
    WordReplacementService.apply(to: "酷伯内提斯 集群", glossary: overlappingGlossary) == "Kubernetes 集群",
    "prefers longer aliases before shorter overlapping aliases"
)

let acceptedDecision = LLMCorrectionGuard.evaluate(
    original: "我用配森处理杰森数据。",
    candidate: "我用 Python 处理 JSON 数据。",
    mode: .terminologyFocused
)
require(acceptedDecision.accepted, "accepts safe terminology correction")
require(acceptedDecision.text.contains("Python"), "returns accepted correction text")

let protectedURLDecision = LLMCorrectionGuard.evaluate(
    original: "接口是 https://example.com/v1 价格是 120 元。",
    candidate: "接口已经配置好了，价格是一百二十元。",
    mode: .strict
)
require(!protectedURLDecision.accepted, "rejects correction that drops protected URL and number")
require(protectedURLDecision.text.contains("https://example.com/v1"), "falls back to original when protected token is lost")

let overRewriteDecision = LLMCorrectionGuard.evaluate(
    original: "明天开会。",
    candidate: "我们计划在明天召开一次重要会议，并提前准备完整材料。",
    mode: .strict
)
require(!overRewriteDecision.accepted, "rejects excessive rewrite")

let explanationDecision = LLMCorrectionGuard.evaluate(
    original: "这个文本正确。",
    candidate: "修正说明：原文没有问题。\n这个文本正确。",
    mode: .strict
)
require(!explanationDecision.accepted, "rejects explanatory model output")

let hudMetrics = OverlayHUDMetrics()
let minHUDTextWidth = OverlayHUDLayout.textWidth(naturalWidth: 20, metrics: hudMetrics)
let expandedHUDTextWidth = OverlayHUDLayout.textWidth(naturalWidth: 360, metrics: hudMetrics)
let cappedHUDTextWidth = OverlayHUDLayout.textWidth(naturalWidth: 2_000, metrics: hudMetrics)

require(minHUDTextWidth == hudMetrics.minTextWidth, "keeps minimum capsule text width")
require(expandedHUDTextWidth > minHUDTextWidth, "expands capsule as text grows")
require(cappedHUDTextWidth == hudMetrics.maxTextWidth, "caps capsule text width")
require(
    OverlayHUDLayout.panelWidth(textWidth: expandedHUDTextWidth, metrics: hudMetrics)
        > OverlayHUDLayout.panelWidth(textWidth: minHUDTextWidth, metrics: hudMetrics),
    "panel width grows with text width"
)

require(
    TranscriptionPostProcessing.injectionText(rawText: " \n\t ", refinedText: nil) == nil,
    "does not inject empty transcription text"
)

require(
    TranscriptionPostProcessing.injectionText(rawText: " 原始识别文本 ", refinedText: nil) == "原始识别文本",
    "falls back to trimmed raw transcription when refinement is unavailable"
)

require(
    TranscriptionPostProcessing.injectionText(rawText: " 原始识别文本 ", refinedText: " 优化后文本 ") == "优化后文本",
    "uses trimmed refined text as final injection text"
)

require(
    TranscriptionPostProcessing.injectionText(rawText: " 原始识别文本 ", refinedText: " \n ") == "原始识别文本",
    "falls back to raw transcription when refinement is blank"
)

require(
    ClipboardPasteSession.shouldRestoreClipboard(
        currentText: "要粘贴的文本",
        currentSessionID: "session-a",
        expectedText: "要粘贴的文本",
        expectedSessionID: "session-a"
    ),
    "restores clipboard when pasteboard still belongs to the current paste session"
)

require(
    !ClipboardPasteSession.shouldRestoreClipboard(
        currentText: "用户刚复制的新内容",
        currentSessionID: "session-a",
        expectedText: "要粘贴的文本",
        expectedSessionID: "session-a"
    ),
    "skips clipboard restore when user changes clipboard text after injection"
)

require(
    !ClipboardPasteSession.shouldRestoreClipboard(
        currentText: "要粘贴的文本",
        currentSessionID: "session-b",
        expectedText: "要粘贴的文本",
        expectedSessionID: "session-a"
    ),
    "skips clipboard restore when paste session marker changed"
)

let lastStore = LastTranscriptionStore()
require(lastStore.latest == nil, "starts with no last transcription")
require(
    !lastStore.save(
        LastTranscription(
            rawText: "",
            processedText: "",
            finalText: " \n ",
            language: "zh-CN",
            backend: "apple"
        )
    ),
    "does not save blank final transcription text"
)
require(lastStore.latest == nil, "blank save does not create last transcription")

let firstTranscription = LastTranscription(
    rawText: "配森",
    processedText: "Python",
    finalText: "Python",
    language: "zh-CN",
    backend: "apple",
    timestamp: Date(timeIntervalSince1970: 1)
)
require(lastStore.save(firstTranscription), "saves nonblank last transcription")
require(lastStore.latest == firstTranscription, "returns saved last transcription")

let secondTranscription = LastTranscription(
    rawText: "杰森",
    processedText: "JSON",
    finalText: "JSON",
    language: "zh-CN",
    backend: "whisper",
    timestamp: Date(timeIntervalSince1970: 2)
)
require(lastStore.save(secondTranscription), "overwrites last transcription")
require(lastStore.latest == secondTranscription, "returns newest last transcription")
lastStore.clear()
require(lastStore.latest == nil, "clears last transcription")

print("CoreBehaviorCheck passed")
