import Cocoa
import LLMRuleCore

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private weak var copyLastItem: NSMenuItem?
    private weak var pasteLastItem: NSMenuItem?

    // AppDelegate is passed in and used as direct target for menu actions
    private weak var delegate: AppDelegate?

    private let languages: [(display: String, code: String)] = [
        ("简体中文", "zh-CN"),
        ("English", "en-US"),
        ("繁體中文", "zh-TW"),
        ("日本語", "ja-JP"),
        ("한국어", "ko-KR"),
    ]

    func setup(delegate: AppDelegate) {
        self.delegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = makeIcon(recording: false)
            btn.imageScaling = .scaleProportionallyDown
        }
        buildMenu()
        statusItem.menu = menu
    }

    func setRecordingState(_ recording: Bool) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = self.makeIcon(recording: recording)
        }
    }

    private func makeIcon(recording: Bool) -> NSImage {
        let name = recording ? "mic.fill" : "mic"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        if recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            return img.withSymbolConfiguration(config) ?? img
        }
        return img
    }

    private func buildMenu() {
        menu = NSMenu()

        // Language submenu — target is AppDelegate
        let langItem = NSMenuItem(title: "识别语言", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for lang in languages {
            let item = NSMenuItem(
                title: lang.display,
                action: #selector(AppDelegate.menuSelectLanguage(_:)),
                keyEquivalent: ""
            )
            item.representedObject = lang.code
            item.target = delegate
            item.state = Preferences.shared.language == lang.code ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())

        // LLM submenu
        let llmItem = NSMenuItem(title: "LLM 优化", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()
        let llmToggle = NSMenuItem(
            title: Preferences.shared.llmEnabled ? "✓ 已启用" : "停用",
            action: #selector(AppDelegate.menuToggleLLM),
            keyEquivalent: ""
        )
        llmToggle.target = delegate
        llmMenu.addItem(llmToggle)
        let llmSettings = NSMenuItem(
            title: "LLM 设置…",
            action: #selector(AppDelegate.menuOpenSettings),
            keyEquivalent: ""
        )
        llmSettings.target = delegate
        llmMenu.addItem(llmSettings)
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(.separator())

        let copyLast = NSMenuItem(
            title: "复制上一条",
            action: #selector(AppDelegate.menuCopyLastTranscription),
            keyEquivalent: ""
        )
        copyLast.target = delegate
        copyLast.isEnabled = LastTranscriptionStore.shared.latest != nil
        menu.addItem(copyLast)
        self.copyLastItem = copyLast

        let pasteLast = NSMenuItem(
            title: "重新粘贴上一条",
            action: #selector(AppDelegate.menuPasteLastTranscription),
            keyEquivalent: ""
        )
        pasteLast.target = delegate
        pasteLast.isEnabled = LastTranscriptionStore.shared.latest != nil
        menu.addItem(pasteLast)
        self.pasteLastItem = pasteLast

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "设置…",
            action: #selector(AppDelegate.menuOpenSettings),
            keyEquivalent: ","
        )
        settings.target = delegate
        menu.addItem(settings)

        let quit = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    func rebuildMenu() {
        buildMenu()
        statusItem.menu = menu
    }

    func updateLanguageCheckmarks() {
        guard let langMenu = menu.item(at: 0)?.submenu else { return }
        let current = Preferences.shared.language
        for item in langMenu.items {
            item.state = item.representedObject as? String == current ? .on : .off
        }
    }

    func updateLastTranscriptionItems() {
        let hasLast = LastTranscriptionStore.shared.latest != nil
        copyLastItem?.isEnabled = hasLast
        pasteLastItem?.isEnabled = hasLast
    }
}
