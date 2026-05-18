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

print("CoreBehaviorCheck passed")
