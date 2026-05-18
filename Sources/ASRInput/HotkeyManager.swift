import Cocoa
import Carbon

struct HotkeyConfig: Codable {
    enum Kind: String, Codable {
        case fn
        case regularKey
    }

    var kind: Kind
    var keyCode: Int
    var modifiers: UInt64   // CGEventFlags.rawValue

    static let defaultConfig = HotkeyConfig(kind: .fn, keyCode: 63, modifiers: 0)

    var displayString: String {
        switch kind {
        case .fn:
            return "Fn"
        case .regularKey:
            var parts: [String] = []
            let flags = CGEventFlags(rawValue: modifiers)
            if flags.contains(.maskControl)  { parts.append("⌃") }
            if flags.contains(.maskAlternate){ parts.append("⌥") }
            if flags.contains(.maskShift)    { parts.append("⇧") }
            if flags.contains(.maskCommand)  { parts.append("⌘") }
            if keyCode == 0, modifiers != 0 { return parts.joined() }
            if let name = keyCodeName(keyCode) { parts.append(name) }
            return parts.joined()
        }
    }

    private func keyCodeName(_ code: Int) -> String? {
        let map: [Int: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        if let name = map[code] { return name }
        // Use key name from system
        if let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let data = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) {
            let layout = unsafeBitCast(data, to: CFData.self)
            let layoutPtr = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            UCKeyTranslate(layoutPtr, UInt16(code), UInt16(kUCKeyActionDown), 0,
                           UInt32(LMGetKbdType()), 0,
                           &deadKeyState, 4, &length, &chars)
            if length > 0 {
                return String(chars[0..<length].map { Character(Unicode.Scalar($0)!) }).uppercased()
            }
        }
        return nil
    }
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyDidStart()
    func hotkeyDidStop()
}

final class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?

    private(set) var isRecording = false
    private var config: HotkeyConfig
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var prevFnDown = false

    init(config: HotkeyConfig = Preferences.shared.hotkeyConfig) {
        self.config = config
    }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                manager.handle(proxy: proxy, type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            AppLogger.hotkey.error("CGEvent.tapCreate failed — check Accessibility permission")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLogger.hotkey.info("HotkeyManager started, config: \(self.config.displayString)")
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        self.tap = nil
        self.runLoopSource = nil
    }

    func resetRecordingState() {
        isRecording = false
    }

    func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        prevFnDown = false
        AppLogger.hotkey.info("Hotkey updated: \(newConfig.displayString)")
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) {
        // Re-enable tap if disabled by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        switch config.kind {
        case .fn:
            guard type == .flagsChanged else { return }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == 63 else { return }
            let fnBit: UInt64 = 0x800000
            let isFnDown = event.flags.rawValue & fnBit != 0
            if isFnDown && !prevFnDown {
                prevFnDown = true
                DispatchQueue.main.async { self.toggle() }
            } else if !isFnDown {
                prevFnDown = false
            }

        case .regularKey:
            guard type == .keyDown else { return }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == Int64(config.keyCode) else { return }
            let requiredMods = CGEventFlags(rawValue: config.modifiers)
            let actualMods = event.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
            guard actualMods == requiredMods else { return }
            DispatchQueue.main.async { self.toggle() }
        }
    }

    private func toggle() {
        if isRecording {
            isRecording = false
            delegate?.hotkeyDidStop()
        } else {
            isRecording = true
            delegate?.hotkeyDidStart()
        }
    }
}
