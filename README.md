# 🎙️ ASRInput

> 一个轻量、安静、顺手的 macOS 菜单栏语音输入工具。<br>
> Speak once. Paste anywhere.

💡 灵感来源：[yetone/voice-input-src](https://github.com/yetone/voice-input-src)。

ASRInput 可以把你的语音转换成文字，并自动输入到当前正在使用的 App 里。它主要面向通过本机运行的大模型 ASR 模型完成语音输入，并结合本地规则或 LLM 对识别结果做保守修正；同时支持 macOS 原生 Apple Speech、OpenAI 兼容的 Whisper 接口、全局快捷键、输入设备选择、最近转写记录和 Liquid Glass 风格浮层。

---

## ✨ 功能亮点

### 🗣️ 一键语音输入

- 按下全局快捷键即可开始/停止录音。
- 默认快捷键是 `Fn`，也可以在设置里修改。
- 录音结束后自动把结果粘贴到当前文本框。
- 粘贴前会临时切换到 ASCII 输入源，减少中文输入法拦截粘贴的问题。
- 菜单栏保留最近转写记录，可快速复制或重新粘贴上一段结果。

### 🧠 多种语音识别后端

- **Apple Speech**：使用 macOS 原生 `SFSpeechRecognizer`，支持实时中间结果。
- **Whisper 兼容接口**：录制 WAV 音频并上传到你配置的 OpenAI 兼容 ASR 服务。
- 可在设置中选择指定输入设备，也可以跟随系统默认麦克风。
- 后端选择会自动保存到 macOS `UserDefaults`。

### 🌊 Liquid Glass 浮层 HUD

- 录音时显示一个置顶的 Liquid Glass 风格 HUD。
- 当前版本采用底部 Live Activity 风格小岛：左侧状态点与麦克风，中间细密波形，右侧状态文本。
- 波形会跟随声音大小变化，停顿时保留轻微呼吸动画。
- 支持“优化中”状态，用于 LLM 后处理等待阶段。
- 尊重 macOS Reduced Motion 设置，降低动画强度。

### 🪄 LLM 保守纠错

- 支持 OpenAI 兼容 Chat Completions 接口。
- 默认策略非常保守：只修正明显 ASR 错误，不改写语气、顺序和含义。
- 可选能力包括：
  - 标点清理
  - 断句优化
  - 口头禅移除
  - 纠错强度选择
  - Prompt 模式选择
  - 按前台 App 自动选择 Prompt 模式
  - 用户术语词典
  - 附加保守规则
- 内置本地质量护栏：如果模型输出为空、改动过大、丢失 URL/数字/代码片段，自动回退原文。
- 会清理模型输出里的 `<think>` 块和常见“最终答案”标签。

### 🧭 诊断与工作流辅助

- 诊断面板会显示权限、ASR 后端、实际输入设备、Whisper/LLM 连接状态和最近一次转写。
- Whisper 请求会记录音频时长、文件大小和峰值音量，方便定位“没收进去”或“设备选错”的问题。
- 可选“录音时暂停/恢复媒体播放”，适合边听资料边语音输入的场景。

### ⚙️ 菜单栏设置

- 常驻 macOS 菜单栏，不打扰当前工作流。
- 设置窗口支持快捷键、语言、ASR 后端、输入设备、Whisper 接口、LLM 参数和诊断状态。
- 内置标准 Edit 菜单，设置输入框可正常使用 `Cmd+V`、`Cmd+C`、`Cmd+A`。

---

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/lazierhk/asrinput.git
cd asrinput
```

### 2. 构建

```bash
swift build
```

### 3. 生成 App Bundle

```bash
make bundle
```

生成结果：

```text
ASRInput.app
```

### 4. 运行

```bash
make run
```

`make run` 会重新构建并重新签名 `ASRInput.app`。如果已经完成 macOS 辅助功能授权，后续 smoke test 或普通重启建议使用：

```bash
make relaunch
```

`make relaunch` 不会重建或重签，只会停止当前 ASRInput 进程并重新打开现有 bundle，可减少 macOS 权限授权反复失效的问题。

如果执行了 `make bundle`、`make run` 或 `make install`，bundle 会重新签名，macOS 可能把它视为新的辅助功能授权对象。开发调试时，如果突然无法捕获快捷键或无法粘贴，先到系统设置里重新勾选 Accessibility 权限，再用 `make relaunch` 重启现有 bundle。

### 5. 安装到 Applications

```bash
make install
```

### 6. 打包 DMG

```bash
make dmg
```

生成结果：

```text
.build/ASRInput.dmg
```

---

## 🧩 使用方式

1. 启动 ASRInput。
2. 在菜单栏确认 App 已运行。
3. 把光标放到你想输入文字的位置。
4. 按下配置好的快捷键，默认是 `Fn`。
5. 开始说话。
6. 再次按下或释放快捷键后停止录音。
7. ASRInput 会自动识别、可选纠错，并把最终文本输入到目标 App。

---

## 🔐 权限说明

首次运行时，macOS 可能会请求这些权限：

| 权限 | 用途 |
| --- | --- |
| 🎤 Microphone | 录音 |
| 🗣️ Speech Recognition | 使用 Apple Speech 识别语音 |
| 🧭 Accessibility | 捕获全局快捷键并模拟粘贴 |

如果快捷键或自动输入不工作，请打开：

```text
System Settings -> Privacy & Security -> Accessibility
```

然后启用 ASRInput。

---

## 🛠️ 常用命令

```bash
swift build                        # Debug 构建
swift build -c release             # Release 二进制构建
swift run CoreBehaviorCheck        # 运行当前行为检查
make build                         # Release 构建
make bundle                        # 构建 .app 并进行 ad-hoc 签名
make run                           # 构建、停止旧进程并启动 App
make relaunch                      # 不重建不重签，仅重启现有 App bundle
make install                       # 安装到 /Applications
make dmg                           # 生成 DMG
make clean                         # 清理生成物
```

校验 `Info.plist`：

```bash
plutil -lint Sources/ASRInput/Resources/Info.plist
```

校验安装后的签名：

```bash
codesign --verify --deep --strict --verbose=2 /Applications/ASRInput.app
```

---

## ⚙️ 配置说明

### ⌨️ 快捷键

- 默认：`Fn`
- 可在 Settings 里修改。
- 支持常见组合键，例如 Control、Option、Shift、Command。

### 🌐 识别语言

- 默认语言：`zh-CN`
- 可以从菜单栏切换语言。

### 🎚️ 输入设备

- 默认跟随 macOS 当前输入设备。
- 也可以在 Settings 里指定某个麦克风。
- 开始录音时会临时切到指定设备，录音结束或失败后恢复原来的系统默认设备。
- 诊断面板会显示当前实际使用的输入设备，方便排查“说了很久只识别出一个字”的情况。

### 🧠 Apple Speech

- 使用 macOS 原生 Speech framework。
- 支持录音过程中的实时中间文本。
- 需要 Speech Recognition 权限。

### 🔊 Whisper 后端

- 适合接入自托管 Whisper、OpenAI 兼容接口或其他 ASR 服务。
- 需要配置：
  - Base URL
  - API Key
  - Model

### 🪄 LLM 优化

LLM 优化用于识别结果后处理，而不是自由改写。它会尽量保持原意，只做低风险清理。

可配置项：

- Base URL
- API Key（本地服务不需要鉴权时可留空）
- Model
- 纠错强度：严格保守、轻度整理、术语优先
- Prompt 模式：普通转写、标点优先、术语优先、聊天、邮件、会议纪要
- 按前台 App 自动选择模式
- 标点清理
- 自动断句
- 口头禅移除
- 术语词典
- 附加保守规则
- 测试纠错预览

术语词典支持简单文本格式：

```text
Python = 配森, 派森
JSON = 杰森
ASRInput = ASR input, asr input
```

模型返回结果会先经过本地护栏检查。URL、邮箱、数字、金额、日期、代码片段等保护内容如果丢失，ASRInput 会拒绝模型输出并使用原始识别文本。

### 🕘 最近转写

- 菜单栏的“最近转写”会显示最近 10 条结果。
- 每条记录都可以复制，也可以重新粘贴到当前光标位置。
- 当前记录保存在本次运行内，重启后会清空。

### ⏯️ 媒体暂停

- 开启后，开始录音时会发送一次系统媒体播放/暂停键，结束录音后再发送一次。
- 这个能力依赖 macOS 和当前播放器对媒体键的响应，不同播放器或网页播放器行为可能不同。
- 因为它可能打断正在播放的内容，默认关闭。

---

## 🏗️ 项目结构

```text
ASRInput/
├── Sources/
│   ├── ASRInput/
│   │   ├── AppDelegate.swift          # App 生命周期和录音流程
│   │   ├── HotkeyManager.swift        # 全局快捷键 event tap
│   │   ├── SpeechTranscriber.swift    # Apple Speech 后端
│   │   ├── WhisperTranscriber.swift   # Whisper 兼容后端
│   │   ├── AudioInputDeviceManager.swift # 输入设备枚举和切换
│   │   ├── TranscriptionPipeline.swift # 转写状态和中间事件
│   │   ├── LLMRefiner.swift           # LLM 保守纠错
│   │   ├── AppPromptModeResolver.swift # 前台 App 到 Prompt 模式映射
│   │   ├── MediaPlaybackController.swift # 录音时媒体暂停/恢复
│   │   ├── TextInjector.swift         # 剪贴板粘贴注入
│   │   ├── OverlayPanel.swift         # 浮层 HUD
│   │   ├── WaveformView.swift         # 动态波形
│   │   ├── SettingsWindow.swift       # AppKit 设置界面
│   │   └── Resources/Info.plist       # Bundle 元数据和权限文案
│   ├── LLMRuleCore/
│   │   ├── LLMCorrectionGuard.swift   # LLM 输出风险护栏
│   │   ├── LLMCorrectionGlossary.swift # 用户术语词典解析
│   │   ├── LLMCorrectionMode.swift    # 纠错强度模式
│   │   ├── LLMPromptMode.swift        # Prompt 场景模式
│   │   ├── LLMRulePrompt.swift        # 保守纠错 prompt 构建
│   │   ├── LLMOutputSanitizer.swift   # LLM 输出清理
│   │   └── LastTranscriptionStore.swift # 最近转写记录
│   └── OverlayHUDCore/
│       └── OverlayHUDLayout.swift     # HUD 纯布局逻辑
├── Tests/
│   └── CoreBehaviorCheck/main.swift   # 可执行行为检查
├── scripts/
│   └── make_icon.swift                # App 图标生成
├── Makefile                           # 构建、运行、安装、DMG 自动化
├── Package.swift                      # SwiftPM 包定义
└── README.md
```

---

## 🧯 常见问题

### 快捷键无法开始录音

- 检查 Accessibility 权限。
- 授权后重启 ASRInput。
- 如果刚执行过 `make bundle`、`make run` 或 `make install`，bundle 重新签名后可能需要重新授权。
- 已授权后的普通重启优先使用 `make relaunch`，避免无意中再次重签。

### 没有声音或识别结果为空

- 检查 Microphone 权限。
- 在 Settings 里确认输入设备选对；如果不确定，先选“跟随系统默认”。
- 查看诊断面板里的“实际输入设备”和最近一次转写。
- 如果使用 Apple Speech，确认 Speech Recognition 权限已开启。

### Whisper 后端失败

- 确认接口地址可访问。
- 确认 API Key 和 Model 名称正确。
- 确认服务支持 OpenAI 兼容的 multipart audio transcription 请求。

### 文本没有自动输入

- 检查 Accessibility 权限。
- 开始录音前确认目标文本框处于聚焦状态。
- 某些密码框、银行页面或安全输入区域可能会阻止模拟粘贴。

### 媒体暂停没有生效

- 确认 Settings 里的“录音时暂停/恢复媒体播放”已经开启。
- 这个功能发送的是系统媒体键事件，播放器或网页必须支持响应媒体键。
- 如果开发环境刚重新签名过 App，也要先确认 Accessibility 权限仍然有效。

### SwiftPM 提示 `Info.plist` 未处理

`Sources/ASRInput/Resources/Info.plist` 会通过 `Package.swift` 的 linker flags 嵌入，同时 `Makefile` 会在生成 `.app` 时复制到 bundle 中。这个文件不是普通运行时资源。

---

## 🗺️ Roadmap

- ✅ 菜单栏语音输入
- ✅ Apple Speech 后端
- ✅ Whisper 兼容后端
- ✅ LLM 保守纠错
- ✅ Liquid Glass Live Activity 风格 HUD
- ✅ 输入设备选择和实际设备诊断
- ✅ 最近转写复制/重贴
- ✅ Prompt 模式和前台 App 自动模式
- ✅ Whisper/LLM 诊断面板
- ✅ 可选录音时暂停媒体播放
- 🔜 正式 XCTest 测试目标
- 🔜 设置导入/导出
- 🔜 签名和 notarization 发布流程

---

## 📄 License

当前还没有声明 License。公开分发前请补充 `LICENSE` 文件。
