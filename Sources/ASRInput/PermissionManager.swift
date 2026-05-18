import AVFoundation
import Speech
import AppKit

final class PermissionManager {
    static func requestAll(completion: @escaping (Bool) -> Void) {
        requestMicrophone { micOK in
            guard micOK else { completion(false); return }
            requestSpeech { speechOK in
                completion(speechOK)
            }
        }
    }

    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            DispatchQueue.main.async {
                showPermissionAlert(
                    title: "麦克风权限",
                    message: "请在系统设置 → 隐私与安全性 → 麦克风中允许 ASRInput。"
                )
                completion(false)
            }
        }
    }

    static func requestSpeech(completion: @escaping (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { completion(status == .authorized) }
            }
        default:
            DispatchQueue.main.async {
                showPermissionAlert(
                    title: "语音识别权限",
                    message: "请在系统设置 → 隐私与安全性 → 语音识别中允许 ASRInput。"
                )
                completion(false)
            }
        }
    }

    static func checkAccessibility(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static func showPermissionAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }
}
