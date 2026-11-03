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
                    Toggle("Enable", isOn: $model.enabled).labelsHidden().toggleStyle(.switch)
                }
                Text(model.status).font(.caption).foregroundStyle(.secondary)
                HStack { Image(systemName: "speaker.wave.1"); Slider(value: $model.volume, in: 0...1); Text("\(Int(model.volume * 100))%").monospacedDigit().frame(width: 38) }
                Picker("Sound", selection: $model.theme) {
                    ForEach(model.availableSounds) { theme in Text(theme.title).tag(theme) }
                }
                HStack {
                    Button("Preview sounds") { model.preview() }
                    Spacer()
                    Button("Settings…") { model.showSettings() }
                }
                Divider()
                Button("Quit Rainy Desk") { model.shutdown(); NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(18).frame(width: 340)
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
                        Text("Rainy Desk").font(.largeTitle.bold())
                        Text("A little sound for every keystroke.").foregroundStyle(.secondary)
                    }
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable keyboard sounds", isOn: $model.enabled)
                        Text(model.status).font(.caption).foregroundStyle(.secondary)
                        HStack { Text("Volume"); Slider(value: $model.volume, in: 0...1); Text("\(Int(model.volume * 100))%").frame(width: 40) }
                        Picker("Sound style", selection: $model.theme) {
                            ForEach(model.availableSounds) { theme in Text(theme.title).tag(theme) }
                        }
                        Text(model.theme.detail).font(.caption).foregroundStyle(.secondary)
                        Button("Preview sounds (no permission needed)") { model.preview() }
                        if let error = model.audioError { Text(error).font(.caption).foregroundStyle(.red) }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("Repeat sounds while holding a key", isOn: $model.repeatEnabled)
                Text("Hold a key for about 0.35 seconds to repeat sounds. Release to stop. This does not change text repetition or accent menus.")
                    .font(.caption).foregroundStyle(.secondary)
                GroupBox("Sound library") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Automatically download new sounds", isOn: $model.autoSounds)
                        Text("Checks at launch and every 6 hours. Only sound files are downloaded; no typing data is sent. New sounds appear in the menu and work offline.").font(.caption).foregroundStyle(.secondary)
                        Button("Check now") { model.checkSounds() }.disabled(model.checkingSounds)
                        Text(model.soundUpdateMessage).font(.caption).foregroundStyle(.secondary)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Input Monitoring") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.authorized ? "Allowed" : "Not allowed", systemImage: model.authorized ? "checkmark.circle.fill" : "keyboard")
                        Text("This permission lets keyboard sounds work in other apps. Typed text is never saved or uploaded.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if !model.authorized { Button("Grant access") { model.requestPermission() } }
                            Button("System Settings") { model.openPrivacy() }
                            Button("Recheck") { model.refresh() }
                        }
                        if let message = model.permissionMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                        Button("Show App in Finder") { model.revealApp() }
                        Text("If permission does not take effect, quit and reopen Rainy Desk English. Sounds may pause during secure input.").font(.caption2).foregroundStyle(.secondary)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Mute in these apps") {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.excluded.isEmpty { Text("No apps excluded").foregroundStyle(.secondary).font(.caption) }
                        ForEach(model.excluded, id: \.self) { id in
                            HStack {
                                VStack(alignment: .leading) { Text(model.appName(id)); Text(id).font(.caption2).foregroundStyle(.secondary) }
                                Spacer()
                                Button { model.excluded.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.help("Remove exclusion")
                            }
                        }
                        Button("Add app…") { model.addExcluded() }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) }))
                Text("Your sound, volume and paused state are saved automatically. Enable this to restore them after login. Closing this window keeps sounds running.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.loginNeedsApproval { Button("Allow launch at login…") { model.openLoginSettings() } }
                if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                Text("Offline playback · Online sound updates · No keystroke logs · Six original sound styles + Custom Voice\nText keys, Space, Return and Delete play sounds. Custom Voice also plays on modifiers and other keys. Other styles keep shortcuts silent.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.frame(width: 560, height: 660)
    }
}
