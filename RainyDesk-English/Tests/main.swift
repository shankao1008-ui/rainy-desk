import Foundation
import CoreGraphics
var count = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    guard condition() else { fatalError("FAIL: \(label)") }
    count += 1
}
check(KeyRules.classify(code: 0, flags: [], repeated: false) == .letter, "letter")
check(KeyRules.classify(code: 49, flags: [], repeated: false) == .space, "space")
check(KeyRules.classify(code: 36, flags: [], repeated: false) == .enter, "return")
check(KeyRules.classify(code: 76, flags: [], repeated: false) == .enter, "keypad enter")
check(KeyRules.classify(code: 51, flags: [], repeated: false) == .delete, "delete")
check(KeyRules.classify(code: 117, flags: [], repeated: false) == .delete, "forward delete")
check(KeyRules.classify(code: 0, flags: .maskShift, repeated: false) == .letter, "shift text")
check(KeyRules.classify(code: 0, flags: .maskAlternate, repeated: false) == .letter, "option text")
check(KeyRules.classify(code: 0, flags: .maskCommand, repeated: false) == nil, "command shortcut")
check(KeyRules.classify(code: 0, flags: .maskControl, repeated: false) == nil, "control shortcut")
check(KeyRules.classify(code: 0, flags: [], repeated: true) == nil, "repeat")
for code: Int64 in [48,53,54,55,56,57,58,59,60,61,62,63,64,96,97,98,99,100,101,102,103,104,105,106,107,109,111,113,114,115,116,118,119,120,121,122,123,124,125,126] {
    check(KeyRules.classify(code: code, flags: [], repeated: false) == nil, "silent key \(code)")
}
check(!KeyRules.allows(app: "test.app", excluded: ["test.app"]), "excluded")
check(KeyRules.allows(app: "other.app", excluded: ["test.app"]), "allowed")
check(KeyRules.allows(app: nil, excluded: ["test.app"]), "unknown")
var held = HeldKey()
held.press(code: 0, kind: .letter, now: 10)
check(held.tick(now: 10.34) == nil, "hold initial delay")
check(held.tick(now: 10.35) == .letter, "hold begins")
check(held.tick(now: 10.36) == nil, "hold throttle")
check(held.tick(now: 10.45) == .letter, "hold continues")
held.release(code: 49)
check(held.tick(now: 10.55) == .letter, "unrelated release")
held.release(code: 0)
check(held.tick(now: 20) == nil, "release stops")
held.press(code: 51, kind: .delete, now: 20)
check(held.tick(now: 21) == .delete, "held backspace")
check(held.tick(now: 21) == nil, "delayed tick does not burst")
held.clear()
check(held.tick(now: 30) == nil, "pause or focus cancellation")
held.press(code: 0, kind: .letter, now: 30)
held.press(code: 49, kind: .space, now: 30.1)
check(held.tick(now: 30.46) == .space, "newest held key")
check(SoundTheme.allCases.count == 7, "seven themes")
check(SoundTheme(rawValue: "wood") == .wood, "saved theme")
check(SoundTheme(rawValue: "unknown") == nil, "invalid saved theme")
print("Passed \(count) key-rule, hold and theme assertions.")

for code: Int64 in [0, 6, 18, 29, 82, 92] {
    check(KeyRules.classify(code: code, flags: .maskCommand, repeated: false, voice: true) == .letter, "voice alphanumeric \(code)")
}
for code: Int64 in [24, 27, 30, 33, 39, 41, 42, 43, 44, 47, 48, 49, 50, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 65, 67, 69, 75, 76, 78, 81, 122, 123] {
    check(KeyRules.classify(code: code, flags: [], repeated: false, voice: true) == .space, "voice non-alphanumeric \(code)")
}
check(KeyRules.classify(code: 0, flags: [], repeated: true, voice: true) == nil, "voice skips native repeat")
check(KeyRules.classify(code: 999, flags: [], repeated: false, voice: true) == nil, "voice ignores invalid key")
print("Passed \(count) total assertions including custom voice.")
