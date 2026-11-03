import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: Notification.Name("RainyDeskShowSettings"), object: nil)
        return true
    }
}

@main
struct RainyDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra("Rainy Desk", systemImage: model.enabled ? "drop.fill" : "drop") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "cloud.drizzle.fill").foregroundStyle(.cyan)
                    Text("Rainy Desk").font(.headline)
                    Spacer()
                    Toggle("啟用", isOn: $model.enabled).labelsHidden().toggleStyle(.switch)
                }
                Text(model.status).font(.caption).foregroundStyle(.secondary)
                HStack { Image(systemName: "speaker.wave.1"); Slider(value: $model.volume, in: 0...1); Text("\(Int(model.volume * 100))%").monospacedDigit().frame(width: 38) }
                Picker("音效", selection: $model.theme) {
                    ForEach(model.availableSounds) { theme in Text(theme.title).tag(theme) }
                }
                HStack {
                    Button("試聽一段") { model.preview() }
                    Spacer()
                    Button("設定…") { model.showSettings() }
                }
                Divider()
                Button("結束 Rainy Desk") { model.shutdown(); NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(18).frame(width: 300)
        }.menuBarExtraStyle(.window)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "cloud.drizzle.fill").font(.system(size: 36)).foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("雨滴書桌").font(.largeTitle.bold())
                        Text("讓每一次打字，落下一滴細雨。").foregroundStyle(.secondary)
                    }
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("啟用按鍵音效", isOn: $model.enabled)
                        Text(model.status).font(.caption).foregroundStyle(.secondary)
                        HStack { Text("音量"); Slider(value: $model.volume, in: 0...1); Text("\(Int(model.volume * 100))%").frame(width: 40) }
                        Picker("音效風格", selection: $model.theme) {
                            ForEach(model.availableSounds) { theme in Text(theme.title).tag(theme) }
                        }
                        Text(model.theme.detail).font(.caption).foregroundStyle(.secondary)
                        Button("試聽一段（不需要鍵盤權限）") { model.preview() }
                        if let error = model.audioError { Text(error).font(.caption).foregroundStyle(.red) }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("長按時持續發聲", isOn: $model.repeatEnabled)
                Text("按住約 0.35 秒後，約每 0.09 秒播放一次；放開即停止。不會改變文字重複或重音選字行為。")
                    .font(.caption).foregroundStyle(.secondary)
                GroupBox("音效庫") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("自動下載新音效", isOn: $model.autoSounds)
                        Text("啟動時與每 6 小時檢查。只下載音效，不傳送輸入內容；新音效會出現在選單，下載後可離線使用。").font(.caption).foregroundStyle(.secondary)
                        Button("立即檢查") { model.checkSounds() }.disabled(model.checkingSounds)
                        Text(model.soundUpdateMessage).font(.caption).foregroundStyle(.secondary)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("輸入監控") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.authorized ? "已授權" : "尚未授權", systemImage: model.authorized ? "checkmark.circle.fill" : "keyboard")
                        Text("需要此權限，才能在其他 App 按鍵時播放音效。只判斷按鍵類別，不保存或上傳輸入內容。").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if !model.authorized { Button("前往授權") { model.requestPermission() } }
                            Button("開啟系統設定") { model.openPrivacy() }
                            Button("重新檢查") { model.refresh() }
                        }
                        if let message = model.permissionMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                        Button("在 Finder 顯示 App") { model.revealApp() }
                        Text("若授權後仍未啟動，請結束並重新開啟 Rainy Desk。安全輸入期間可能不會發聲。").font(.caption2).foregroundStyle(.secondary)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("在這些 App 中靜音") {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.excluded.isEmpty { Text("尚未排除任何 App").foregroundStyle(.secondary).font(.caption) }
                        ForEach(model.excluded, id: \.self) { id in
                            HStack {
                                VStack(alignment: .leading) { Text(model.appName(id)); Text(id).font(.caption2).foregroundStyle(.secondary) }
                                Spacer()
                                Button { model.excluded.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.help("移除排除項目")
                            }
                        }
                        Button("加入應用程式…") { model.addExcluded() }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("開機登入後，繼續使用我的音效", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) }))
                Text("音效、音量與暫停狀態會自動保存。開啟後，下次登入沿用同一設定；關閉視窗不會停止音效。")
                    .font(.caption).foregroundStyle(.secondary)
                if model.loginNeedsApproval { Button("允許登入啟動…") { model.openLoginSettings() } }
                if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                Text("離線播放 · 連網更新音效 · 無按鍵紀錄 · 六種原創合成音效＋自訂人聲\n一般鍵、空白、Enter 與刪除鍵會發聲；人聲模式亦支援修飾鍵與其他按鍵；其餘音色的快捷鍵保持靜音。").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.frame(width: 520, height: 660)
    }
}
