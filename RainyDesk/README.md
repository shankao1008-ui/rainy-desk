# Rainy Desk 1.5

Native macOS 13+ keyboard sounds, English and Traditional Chinese editions.

Install 1.5 once to receive future sound packs without reinstalling. The app checks the public catalog at launch and every 6 hours while running. Settings offers an opt-out and Check now. New packs are added to the picker without changing the selected sound, volume, paused state or login setting. Downloaded sounds remain available offline. App features and OS compatibility fixes still need a new app version.

## Install
Move the app into Applications before opening. Run only one copy/edition. Enable Input Monitoring yourself. This beta is ad-hoc signed, not Developer ID signed or notarized; Gatekeeper may require Open Anyway. Replacing an old build may require re-adding its Input Monitoring entry.

## Sounds and privacy
Seven bundled styles, including two user-provided voice recordings approved for public distribution. Custom Voice maps physical A–Z and 0–9 keys (including numpad) to recording 2, other keys to recording 1. Modifiers are included; Fn/media events depend on macOS. New presses restart a voice clip. Other styles retain their original shortcut rules.

No keystrokes or typed text are saved/uploaded. Network requests fetch only the public catalog and sound assets; the host receives normal request metadata such as IP address. Audio playback is local. The updater never downloads or runs executable code. It enforces same-origin HTTPS, no redirects, schema/path/size limits, SHA-256 integrity and audio format/peak limits before installing. Cached packs are stored in Application Support/RainyDesk/SoundLibrary. Failed updates preserve the prior catalog.

## Build and test
```sh
python3 Scripts/generate_sounds.py
bash Scripts/test.sh
xcodebuild -project RainyDesk.xcodeproj -scheme RainyDesk -configuration Release -derivedDataPath build SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' build
```

See VALIDATION.md for checks and hardware limitations. Sound pack publication is documented in the GitHub repository's SOUND-PACKS.md.
