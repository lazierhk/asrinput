import os

enum AppLogger {
    static let main    = Logger(subsystem: "com.asrinput.app", category: "main")
    static let hotkey  = Logger(subsystem: "com.asrinput.app", category: "hotkey")
    static let speech  = Logger(subsystem: "com.asrinput.app", category: "speech")
    static let whisper = Logger(subsystem: "com.asrinput.app", category: "whisper")
    static let llm     = Logger(subsystem: "com.asrinput.app", category: "llm")
    static let inject  = Logger(subsystem: "com.asrinput.app", category: "inject")
    static let ui      = Logger(subsystem: "com.asrinput.app", category: "ui")
}
