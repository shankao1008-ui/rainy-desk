English edition: all app-authored interface text translated, separate bundle identity, no changes to the installed Chinese edition. Build results recorded after validation.

Validated: Release builds for x86_64 and arm64, strict code-signature verification, 67 key-rule/hold/theme assertions, ZIP integrity, and all app-authored Swift strings checked for untranslated Chinese. English web routes, installer download, guide and audio preview assets returned HTTP 200 in local preview; JavaScript syntax check passed.

Not verified: physical Apple Silicon hardware, fresh-machine Gatekeeper/Input Monitoring approval, English native UI visual inspection, and reboot behavior. The existing installed Chinese app was not modified or restarted.


## 1.4.0 Custom Voice verification — 2026-11-02
- Both languages: 108 key-rule/hold/theme assertions and 118 WAV asset checks passed.
- Release builds succeeded for x86_64 + arm64; ad-hoc signatures verified.
- ZIP integrity, version, exact voice resource inclusion, both website languages and asset/download references verified.
- Browser: both new preview buttons entered playing state and switched selection correctly.
- Recordings normalized to peak 0.60, mono 44.1 kHz PCM16, edge silence trimmed, short edge fades. Recording 1: 2.747 s; recording 2: 2.200 s.
- Physical modifier/Fn, keyboard playback, subjective sound quality, restart/login and Apple Silicon hardware have not been retested. Secure-input guard remains active.
- New key presses retrigger one voice, intentionally interrupting the previous clip. Existing themes retain their behavior.
- No Developer ID signature/notarization; no installed app or system privacy permissions changed.


## 1.5 verification
- Dynamic sound options with preserved selection; built-in identifiers unchanged.
- Automated integration checks: initial download, later new sound, offline/cache restoration, cache reuse, failed-update rollback, hash rejection, removed-pack retention and downgrade protection.
- Manifest rejects invalid paths, duplicate IDs, unsupported schema and built-in ID collisions.
- Physical keyboard, modifier/Fn and login/restart behavior still require user testing.
