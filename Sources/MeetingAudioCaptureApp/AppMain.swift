import AppKit
import Foundation
import MeetingAudioCaptureCore

@main
enum MeetingAudioCaptureApp {
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@available(macOS 15.0, *)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let engine = MeetingRecordingEngine()

    private var selectedMode: RecordingMode = .onlineMeeting
    private var selectedMicrophoneID: String?
    private var recorderState: RecorderState = .idle
    private var latestFiles: [URL] = []
    private var statusRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureEngineCallbacks()
        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopStatusRefreshTimer()
    }

    private func configureStatusItem() {
        setStatusTitle("REC")
        statusItem.button?.toolTip = "MeetingAudioCapture"
    }

    private func setStatusTitle(_ title: String) {
        statusItem.button?.title = title

        let font = statusItem.button?.font ?? NSFont.menuBarFont(ofSize: 0)
        let width = (title as NSString).size(withAttributes: [NSAttributedString.Key.font: font]).width
        statusItem.length = max(44, ceil(width) + 24)
    }

    private func configureEngineCallbacks() {
        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.recorderState = state
                self?.updateStatusTitle()
                self?.syncStatusRefreshTimer()
                self?.rebuildMenu()
            }
        }

        engine.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.showAlert(title: "録音エラー", message: error.localizedDescription)
            }
        }

        engine.onFinished = { [weak self] files in
            DispatchQueue.main.async {
                self?.latestFiles = files
                self?.showAlert(
                    title: "録音を保存しました",
                    message: files.isEmpty ? "保存されたファイルはありません。" : files.map(\.lastPathComponent).joined(separator: "\n")
                )
            }
        }
    }

    private func updateStatusTitle() {
        switch recorderState {
        case .recording(_, let startedAt):
            let elapsed = RecordingElapsedTimeFormatter.string(startedAt: startedAt)
            setStatusTitle("REC \(elapsed)")
        case .stopping:
            setStatusTitle("停止中")
        case .failed:
            setStatusTitle("ERR")
        case .idle:
            setStatusTitle("REC")
        }
    }

    private func syncStatusRefreshTimer() {
        guard case .recording = recorderState else {
            stopStatusRefreshTimer()
            return
        }

        guard statusRefreshTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            self.updateStatusTitle()
            self.rebuildMenu()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusRefreshTimer = timer
    }

    private func stopStatusRefreshTimer() {
        statusRefreshTimer?.invalidate()
        statusRefreshTimer = nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(NSMenuItem.separator())

        let startStopTitle = isRecording ? "録音停止" : "録音開始"
        menu.addItem(NSMenuItem(title: startStopTitle, action: #selector(toggleRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        let modeMenuItem = NSMenuItem(title: "録音モード", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in RecordingMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.state = selectedMode == mode ? .on : .off
            item.isEnabled = !isRecording
            modeMenu.addItem(item)
        }
        modeMenuItem.submenu = modeMenu
        menu.addItem(modeMenuItem)

        let microphoneMenuItem = NSMenuItem(title: "マイク", action: nil, keyEquivalent: "")
        let microphoneMenu = NSMenu()
        for device in MicrophoneDeviceProvider.availableInputDevices() {
            let item = NSMenuItem(title: device.name, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
            item.representedObject = device.id
            item.state = selectedMicrophoneID == device.id ? .on : .off
            item.isEnabled = !isRecording
            microphoneMenu.addItem(item)
        }
        microphoneMenuItem.submenu = microphoneMenu
        menu.addItem(microphoneMenuItem)

        let hint = NSMenuItem(title: "ASR品質重視ならイヤホン推奨", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Downloadsを開く", action: #selector(openDownloads), keyEquivalent: "o"))
        if !latestFiles.isEmpty {
            menu.addItem(NSMenuItem(title: "最後の保存ファイルを表示", action: #selector(revealLatestFile), keyEquivalent: "f"))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private var isRecording: Bool {
        if case .recording = recorderState {
            return true
        }
        if case .stopping = recorderState {
            return true
        }
        return false
    }

    private var statusText: String {
        switch recorderState {
        case .idle:
            return "待機中: \(selectedMode.displayName)"
        case .recording(let mode, let startedAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            let elapsed = RecordingElapsedTimeFormatter.string(startedAt: startedAt)
            return "録音中: \(mode.displayName) / 開始 \(formatter.string(from: startedAt)) / 経過 \(elapsed)"
        case .stopping:
            return "録音停止中..."
        case .failed(let message):
            return "エラー: \(message)"
        }
    }

    @objc private func toggleRecording() {
        if isRecording {
            Task {
                await engine.stop()
            }
            return
        }

        Task {
            do {
                try await ensurePermissions(for: selectedMode)
                try await engine.start(mode: selectedMode, microphoneDeviceID: selectedMicrophoneID)
            } catch {
                showAlert(title: "録音を開始できません", message: error.localizedDescription)
            }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = RecordingMode(rawValue: rawValue) else {
            return
        }
        selectedMode = mode
        rebuildMenu()
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        selectedMicrophoneID = sender.representedObject as? String
        rebuildMenu()
    }

    @objc private func openDownloads() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        NSWorkspace.shared.open(downloads)
    }

    @objc private func revealLatestFile() {
        guard let latest = latestFiles.last else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([latest])
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func ensurePermissions(for mode: RecordingMode) async throws {
        switch PermissionService.microphoneStatus() {
        case .authorized:
            break
        case .notDetermined:
            let granted = await PermissionService.requestMicrophoneAccess()
            guard granted else {
                throw RecorderError.permissionDenied("マイク権限が許可されていません。")
            }
        case .denied, .restricted, .unknown:
            throw RecorderError.permissionDenied("システム設定でマイク権限を許可してください。")
        }

        guard mode.capturesSystemAudio else {
            return
        }

        if PermissionService.screenCaptureStatus() == .authorized {
            return
        }

        let granted = PermissionService.requestScreenCaptureAccess()
        guard granted || PermissionService.screenCaptureStatus() == .authorized else {
            throw RecorderError.permissionDenied("システム設定で画面収録権限を許可し、必要に応じてアプリを再起動してください。")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
