import AppKit
import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers
import Carbon

final class AppModel: ObservableObject {
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); refresh(); if !enabled { cancelPreview(); audio.stop() } }
    }
    @Published var volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.35 {
        didSet { UserDefaults.standard.set(volume, forKey: "volume"); audio.setVolume(volume) }
    }
    @Published var theme = SoundTheme(rawValue: UserDefaults.standard.string(forKey: "soundTheme") ?? "") ?? .rain {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "soundTheme")
            audio.setTheme(theme)
        keyboard.voiceEnabled = theme.isVoice
            if !updatingLibrary { preview() }
        }
    }
    @Published var repeatEnabled = UserDefaults.standard.object(forKey: "repeatSound") as? Bool ?? true {
        didSet { UserDefaults.standard.set(repeatEnabled, forKey: "repeatSound"); keyboard.repeatEnabled = repeatEnabled }
    }
    @Published var availableSounds = SoundTheme.allCases
    @Published var checkingSounds = false
    @Published var soundUpdateMessage = "已下載的音效可離線使用。"
    @Published var autoSounds = UserDefaults.standard.object(forKey: "autoSounds") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoSounds, forKey: "autoSounds"); if autoSounds { checkSounds() } }
    }
    private let library = SoundLibrary()
    private var libraryTimer: Timer?
    private var libraryTask: Task<Void, Never>?
    private var updatingLibrary = false
    private var previewJobs: [DispatchWorkItem] = []
    @Published var excluded = UserDefaults.standard.stringArray(forKey: "excluded") ?? [] {
        didSet { UserDefaults.standard.set(excluded, forKey: "excluded") }
    }
    @Published var permissionMessage: String?
    @Published var authorized = false
    @Published var monitoring = false
    @Published var audioError: String?
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var loginMessage: String?
    private let audio = DropAudio()
    private let keyboard = KeyboardMonitor()
    private var frontApp: String?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var settingsWindow: NSWindow?
    private var sleeping = false

    var status: String {
        if !enabled { return "已暫停" }
        if !authorized { return "需要輸入監控權限" }
        if !monitoring { return "監聽尚未啟動，請重新檢查權限" }
        if audioError != nil { return "音訊需要處理" }
        return "已啟用 · 安全輸入時可能暫停"
    }
    init() {
        let downloaded = library.cached().map { SoundTheme(pack: $0) }
        availableSounds = SoundTheme.allCases + downloaded
        audio.register(downloaded)
        if let saved = UserDefaults.standard.string(forKey: "soundTheme"), let restored = availableSounds.first(where: { $0.rawValue == saved }) { theme = restored }
        frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        audio.setVolume(volume)
        audio.setTheme(theme)
        keyboard.voiceEnabled = theme.isVoice
        keyboard.repeatEnabled = repeatEnabled
        audio.onError = { [weak self] in self?.audioError = $0 }
        keyboard.onKey = { [weak self] kind in
            guard let self, self.enabled, !self.sleeping, KeyRules.allows(app: self.frontApp, excluded: Set(self.excluded)) else { return }
            self.audio.play(kind)
        }
        keyboard.onFailure = { [weak self] in DispatchQueue.main.async { self?.refresh() } }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.keyboard.cancelHold()
            self?.frontApp = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.cancelPreview(); self?.sleeping = true; self?.keyboard.stop(); self?.monitoring = false; self?.audio.stop()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false; self?.audio.recover(); self?.refresh()
        })
        // Low-frequency permission reconciliation, not a keyboard polling loop.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
        libraryTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { [weak self] _ in
            guard let self, self.autoSounds else { return }; self.checkSounds()
        }
        if autoSounds { checkSounds() }
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name("RainyDeskShowSettings"), object: nil, queue: .main) { [weak self] _ in self?.showSettings() })
        if ProcessInfo.processInfo.arguments.contains("--enable-login") { toggleLogin(true) }
        let isLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        if !isLogin { DispatchQueue.main.async { [weak self] in self?.showSettings() } }
    }
    func refresh() {
        authorized = CGPreflightListenEventAccess()
        if enabled && authorized && !sleeping { monitoring = keyboard.start() }
        else { keyboard.stop(); monitoring = false }
        let loginStatus = SMAppService.mainApp.status
        loginEnabled = loginStatus == .enabled
        loginNeedsApproval = loginStatus == .requiresApproval
        if loginNeedsApproval { loginMessage = "請在系統設定的登入項目中允許 Rainy Desk，下次登入即可沿用原設定。" }
    }
    func requestPermission() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        refresh()
        if !authorized { openPrivacy() }
        else { permissionMessage = "已取得權限，可以開始打字。" }
    }
    func openPrivacy() {
        permissionMessage = "請在輸入監控清單開啟 Rainy Desk。若找不到，按下方『在 Finder 顯示 App』，再用系統設定的 ＋ 加入這份 App。"
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"), NSWorkspace.shared.open(url) else {
            permissionMessage = "請手動開啟：系統設定 → 隱私權與安全性 → 輸入監控，再開啟 Rainy Desk。"
            return
        }
    }
    func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    private func cancelPreview() { previewJobs.forEach { $0.cancel() }; previewJobs.removeAll() }
    func preview() {
        cancelPreview()
        let sequence: [DropKind] = theme.isVoice ? [.space, .letter] : [.letter, .letter, .letter, .space, .letter, .delete, .enter]
        for (index, kind) in sequence.enumerated() {
            let job = DispatchWorkItem { [weak self] in self?.audio.play(kind) }
            previewJobs.append(job)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * (theme.isVoice ? 3.5 : 0.18), execute: job)
        }
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    func toggleLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
        } catch { loginMessage = "登入項目設定失敗：\(error.localizedDescription)" }
        refresh()
    }
    func addExcluded() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let id = Bundle(url: url)?.bundleIdentifier, !excluded.contains(id) { excluded.append(id) }
            }
            excluded.sort()
        }
    }
    func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path)
    }
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 660), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Rainy Desk · 雨滴書桌"
            window.contentView = NSHostingView(rootView: SettingsView(model: self))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        refresh()
    }
    func checkSounds() {
        guard !checkingSounds else { return }
        checkingSounds = true
        soundUpdateMessage = "正在檢查新音效…"
        libraryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.checkingSounds = false }
            do {
                let packs = try await self.library.sync()
                let downloaded = packs.map { SoundTheme(pack: $0) }
                self.audio.register(downloaded)
                self.availableSounds = SoundTheme.allCases + downloaded
                if let replacement = self.availableSounds.first(where: { $0.rawValue == self.theme.rawValue }), replacement != self.theme {
                    self.updatingLibrary = true; self.theme = replacement; self.updatingLibrary = false
                }
                self.soundUpdateMessage = "音效庫已更新，保留原本選擇。"
            } catch { self.soundUpdateMessage = "暫時無法更新音效，原有音效仍可使用，稍後可再試。" }
        }
    }
    func shutdown() { libraryTimer?.invalidate(); libraryTask?.cancel(); cancelPreview(); timer?.invalidate(); keyboard.stop(); audio.stop() }
}
