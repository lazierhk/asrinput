import Cocoa
import IOKit.hidsystem

enum MediaPlaybackController {
    static func togglePlayPause() {
        let key = Int32(NX_KEYTYPE_PLAY)
        postMediaKey(key, keyDown: true)
        postMediaKey(key, keyDown: false)
    }

    private static func postMediaKey(_ key: Int32, keyDown: Bool) {
        let flags = keyDown ? NX_KEYDOWN : NX_KEYUP
        let data = (key << 16) | (flags << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int(data),
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
