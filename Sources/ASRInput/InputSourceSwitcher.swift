import Carbon

final class InputSourceSwitcher {
    private var savedSource: TISInputSource?

    func switchToASCIIIfNeeded() -> Bool {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        let isASCII = getProperty(current, kTISPropertyInputSourceIsASCIICapable) as? Bool ?? false
        if isASCII { return false }

        savedSource = current
        if let asciiSource = findASCIISource() {
            TISSelectInputSource(asciiSource)
        }
        return true
    }

    func restoreIfNeeded() {
        guard let source = savedSource else { return }
        TISSelectInputSource(source)
        savedSource = nil
    }

    private func findASCIISource() -> TISInputSource? {
        let props = [kTISPropertyInputSourceIsASCIICapable: true,
                     kTISPropertyInputSourceIsEnabled: true] as CFDictionary
        guard let list = TISCreateInputSourceList(props, false)?.takeRetainedValue() as? [TISInputSource],
              let first = list.first
        else { return nil }
        return first
    }

    private func getProperty(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        TISGetInputSourceProperty(source, key).map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }
    }
}
