import AppKit
import Carbon

final class KeyboardMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var held = HeldKey()
    private var repeatTimer: Timer?
    var voiceEnabled = false { didSet { cancelHold() } }
    var repeatEnabled = true { didSet { if !repeatEnabled { cancelHold() } } }
    func cancelHold() { held.clear(); repeatTimer?.invalidate(); repeatTimer = nil }
    private func beginHold(code: Int64, kind: DropKind) {
        cancelHold()
        guard repeatEnabled else { return }
        held.press(code: code, kind: kind, now: ProcessInfo.processInfo.systemUptime)
        let timer = Timer(timeInterval: 0.09, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !IsSecureEventInputEnabled(), CGPreflightListenEventAccess() else { self.cancelHold(); return }
            if let kind = self.held.tick(now: ProcessInfo.processInfo.systemUptime) { self.onKey?(kind) }
        }
        timer.fireDate = Date(timeIntervalSinceNow: 0.35)
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }
    var onKey: ((DropKind) -> Void)?
    var onFailure: (() -> Void)?
    var active: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.cancelHold()
                if CGPreflightListenEventAccess(), let tap = monitor.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                } else { monitor.onFailure?() }
                return Unmanaged.passUnretained(event)
            }
            guard !IsSecureEventInputEnabled() else { monitor.cancelHold(); return Unmanaged.passUnretained(event) }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if type == .flagsChanged && monitor.voiceEnabled {
                let isDown = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(code))
                if isDown {
                    monitor.onKey?(.space)
                    monitor.beginHold(code: code, kind: .space)
                } else {
                    monitor.held.release(code: code)
                    if monitor.held.code == nil { monitor.cancelHold() }
                }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyUp {
                monitor.held.release(code: code)
                if monitor.held.code == nil { monitor.cancelHold() }
            }
            if type == .flagsChanged && (event.flags.contains(.maskCommand) || event.flags.contains(.maskControl)) { monitor.cancelHold() }
            if type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { monitor.cancelHold() }
            if type == .keyDown, let kind = KeyRules.classify(code: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, voice: monitor.voiceEnabled) {
                monitor.onKey?(kind)
                monitor.beginHold(code: code, kind: kind)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)), callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }
    func stop() {
        cancelHold()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }
    deinit { stop() }
}
