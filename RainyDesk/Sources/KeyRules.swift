import Foundation
import CoreGraphics

enum DropKind: String, CaseIterable { case letter, space, enter, delete }

struct KeyRules {
    static func classify(code: Int64, flags: CGEventFlags, repeated: Bool, voice: Bool = false) -> DropKind? {
        if voice {
            guard !repeated, (0...127).contains(code) else { return nil }
            // Physical A-Z and digit keys, including the numeric keypad.
            let lettersAndNumbers: Set<Int64> = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,20,21,22,23,25,26,28,29,31,32,34,35,37,38,40,45,46,82,83,84,85,86,87,88,89,91,92]
            return lettersAndNumbers.contains(code) ? .letter : .space
        }
        guard !repeated, !flags.contains(.maskCommand), !flags.contains(.maskControl) else { return nil }
        switch code {
        case 49: return .space
        case 36, 76: return .enter
        case 51, 117: return .delete
        // Physical ANSI/ISO/JIS text keys and numeric keypad; no navigation or function keys.
        case 0...35, 37...47, 50, 65, 67, 69, 75, 78, 81...89, 91, 92, 93, 94, 95: return .letter
        default: return nil
        }
    }
    static func allows(app: String?, excluded: Set<String>) -> Bool {
        guard let app else { return true }
        return !excluded.contains(app)
    }
}

// Persisted identifiers are also the resource-folder names.
enum BuiltinTheme: String, CaseIterable, Identifiable {
    case rain, pebble, wood, keyboard, marimba, original, voice
    var id: String { rawValue }
    var title: String {
        switch self {
        case .voice: return "自訂人聲"
        case .rain: return "柔和細雨"
        case .pebble: return "清脆水珠"
        case .wood: return "木質輕敲"
        case .keyboard: return "柔軟鍵盤"
        case .marimba: return "小木琴"
        case .original: return "原版水滴"
        }
    }
    var detail: String {
        switch self {
        case .voice: return "A–Z 與 0–9 播放第二段；其他鍵播放第一段。快速打字會重新播放人聲。"
        case .rain: return "輕細沙沙聲，減少電子音與滑音。"
        case .pebble: return "短而清亮的水珠，尾音俐落。"
        case .wood: return "溫暖、低沉的木頭敲擊聲。"
        case .keyboard: return "低調的按鍵輕響，幾乎沒有音高。"
        case .marimba: return "五聲音階的小木琴，帶一點旋律。"
        case .original: return "第一版的合成水滴與明顯滑音。"
        }
    }
}

struct HeldKey {
    private(set) var code: Int64?
    private var kind: DropKind?
    private var nextTime: Double = 0
    mutating func press(code: Int64, kind: DropKind, now: Double) {
        self.code = code; self.kind = kind; nextTime = now + 0.35
    }
    mutating func release(code: Int64) { if self.code == code { clear() } }
    mutating func clear() { code = nil; kind = nil }
    mutating func tick(now: Double) -> DropKind? {
        guard let kind, now >= nextTime else { return nil }
        nextTime = now + 0.09 // Never catch up with a burst after a delayed callback.
        return kind
    }
}


struct SoundTheme: Hashable, Identifiable {
    let rawValue: String
    let title: String
    let detail: String
    let pack: SoundPack?
    var id: String { rawValue }
    var isVoice: Bool { pack?.mapping == "voice" || rawValue == "voice" }
    static var allCases: [SoundTheme] { BuiltinTheme.allCases.map { SoundTheme(builtin: $0) } }
    init(builtin: BuiltinTheme) { rawValue = builtin.rawValue; title = builtin.title; detail = builtin.detail; pack = nil }
    init?(rawValue: String) { guard let b = BuiltinTheme(rawValue: rawValue) else { return nil }; self.init(builtin: b) }
    init(pack: SoundPack) {
        rawValue = pack.id; self.pack = pack
        title = pack.title; detail = pack.detail
    }
    static let rain = SoundTheme(builtin: .rain)
    static let pebble = SoundTheme(builtin: .pebble)
    static let wood = SoundTheme(builtin: .wood)
    static let keyboard = SoundTheme(builtin: .keyboard)
    static let marimba = SoundTheme(builtin: .marimba)
    static let original = SoundTheme(builtin: .original)
    static let voice = SoundTheme(builtin: .voice)
}
