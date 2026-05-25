public enum ClipboardPasteSession {
    public static func shouldRestoreClipboard(
        currentText: String?,
        currentSessionID: String?,
        expectedText: String,
        expectedSessionID: String
    ) -> Bool {
        currentText == expectedText && currentSessionID == expectedSessionID
    }
}
