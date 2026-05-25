import Cocoa
import IOKit.hidsystem

enum MediaPlaybackController {
    @discardableResult
    static func togglePlayPause() -> Bool {
        let key = Int32(NX_KEYTYPE_PLAY)
        let down = postMediaKey(key, keyDown: true)
        let up = postMediaKey(key, keyDown: false)
        return down && up
    }

    @discardableResult
    private static func postMediaKey(_ key: Int32, keyDown: Bool) -> Bool {
        let flags: Int32 = keyDown ? 0xA : 0xB
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
        ), let cgEvent = event.cgEvent else {
            return false
        }
        cgEvent.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    }
}
