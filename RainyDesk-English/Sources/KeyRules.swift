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
        case .voice: return "Custom Voice"
        case .rain: return "Soft Rain"
        case .pebble: return "Clear Droplets"
        case .wood: return "Wooden Taps"
        case .keyboard: return "Soft Keyboard"
        case .marimba: return "Marimba"
        case .original: return "Original Drops"
        }
    }
    var detail: String {
        switch self {
        case .voice: return "A–Z and 0–9: recording 2. Other keys: recording 1. Fast typing restarts the voice."
        case .rain: return "A gentle patter with less pitch and no sweeping tones."
        case .pebble: return "Bright, short droplets with a clean finish."
        case .wood: return "Warm, low wooden taps."
        case .keyboard: return "Subtle key clicks with almost no pitch."
        case .marimba: return "Soft marimba notes from a pentatonic scale."
        case .original: return "The original synthesized drops with a pronounced pitch sweep."
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
        title = pack.titleEN; detail = pack.detailEN
    }
    static let rain = SoundTheme(builtin: .rain)
    static let pebble = SoundTheme(builtin: .pebble)
    static let wood = SoundTheme(builtin: .wood)
    static let keyboard = SoundTheme(builtin: .keyboard)
    static let marimba = SoundTheme(builtin: .marimba)
    static let original = SoundTheme(builtin: .original)
    static let voice = SoundTheme(builtin: .voice)
}
