# Rainy Desk

Keyboard sounds for macOS 13+, in English and Traditional Chinese.

## Download 1.5.0
- [English website and installer](https://rainy-desk-sounds.shankao1008.chatgpt.site/en/)
- [中文網站與下載](https://rainy-desk-sounds.shankao1008.chatgpt.site/)
- [English ZIP on GitHub](website/downloads/RainyDesk-English-1.5.0-macOS.zip)
- [中文 ZIP on GitHub](website/downloads/RainyDesk-1.5.0-macOS.zip)

Install **1.5 once**. Future published sound packs download automatically at launch and every 6 hours while the app runs. You can also choose **Sound library → Check now**. New sounds appear without changing your selected sound or volume; downloaded sounds work offline. App feature and OS compatibility updates still need a new app version. Version 1.4 and older cannot download sound packs.

The first online pack contains the owner's two voice recordings, shared publicly with permission. New key presses restart voice playback; physical A–Z/0–9 keys use recording 2, other keys use recording 1. Fn/media keys depend on macOS events.

## Install
Quit the old app, replace it in Applications, then open 1.5. Keep only one copy/edition running. Grant Input Monitoring. This is an ad-hoc signed public beta, not Apple-notarized; macOS may require Open Anyway and re-adding the updated app's Input Monitoring permission. Never disable macOS security protections. Existing sound, volume and pause/login preferences are retained.

## Source
- `RainyDesk/`: Traditional Chinese app and Xcode project
- `RainyDesk-English/`: English app and Xcode project
- `website/`: public website, sound catalog/assets, and installers
- [SOUND-PACKS.md](SOUND-PACKS.md): publish new sounds without an app rebuild

Run `python3 Scripts/generate_sounds.py` inside each app folder before testing/building; the six procedural banks are generated locally, while the voice recordings are included. Each app folder documents its build and test commands. Tests cover key classification, held keys, audio assets, initial and later sound downloads, cache reuse, offline restoration, failed-update rollback, hash rejection and manifest validation. Builds target Intel and Apple Silicon; physical Apple Silicon, Fn and login behavior require device testing.

## Privacy
No typed text or keystroke history is saved/uploaded. Sound playback is local. Online updates request only the public catalog and WAV assets; the host sees normal network metadata such as IP address. Automatic checks can be disabled. Downloads are data-only, with HTTPS, redirect rejection, size/schema/path limits, SHA-256 and audio validation. Failed downloads retain working sounds.
