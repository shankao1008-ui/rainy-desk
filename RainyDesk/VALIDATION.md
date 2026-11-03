# 驗證紀錄

環境：本機 Xcode 26.3 / Swift 6.2.4，macOS SDK 26.2，deployment target macOS 13。

已完成：
- Xcode Release 編譯成功（本機 x86_64 架構）。
- 54 個按鍵／快捷鍵／長按／App 排除規則斷言通過。
- 19 個音效通過 PCM 格式、非靜音、峰值不削波與起訖淡化檢查。
- 專案與 Info.plist 解析成功。
- 交付 App 通過 codesign --verify --deep --strict。
- 已透過 macOS 啟動 App，並確認程序持續執行；尚未進行 UI 視覺驗證或授權後實際按鍵測試。

完整編譯曾遇到磁碟空間不足，改用 implicit modules 後成功。沒有清除使用者其他檔案。

尚需真人實機驗證：輸入監控授權後的跨 App 發聲、主觀音色與延遲、裝置切換、睡眠喚醒、登入啟動、安全輸入與不同鍵盤／輸入法。尚未驗證 Apple Silicon 執行；原始碼可在該架構重新建置。沒有宣稱已完成這些驗證。

這是本機 ad-hoc 簽署開發版，尚未以 Developer ID 簽署及公證。

## 音效選擇與長按更新

新增六種可保存的音效風格與可取消的整段試聽。長按改用 keyDown/keyUp 狀態搭配 0.35 秒起始延遲及 0.09 秒播放間隔；原生重複事件仍忽略，以免雙重發聲。釋放、快捷鍵、焦點切換與安全輸入會取消長按。

需手動確認：六種風格主觀音色、長按字母／空白／Backspace、鬆開即停止、切換 App／暫停時停止，以及重音選字期間的行為。

更新驗證：Release 編譯成功，67 項按鍵／長按／音效選擇斷言通過，114 個 WAV 峰值與格式檢查通過；App 內含完整六套素材，交付 App 通過 codesign 嚴格檢查。已替換原路徑的 App 並重新啟動。

## 1.2.0：恢復入口與音量

檢查發現舊程序已退出，未找到 Rainy Desk 崩潰報告，因此退出原因尚未確認。重新啟動後程序恢復。增加 Dock 圖示、每次啟動顯示設定、Dock 重開設定，以及關閉最後視窗仍持續執行的 delegate 行為。

提高單聲部增益至前版六倍，對所有活躍節點共同衰減，1–8 個聲部的理論合成峰值不超過 0.72（音量 100%）。完成計算檢查、Release 編譯及 codesign 嚴格驗證。實際音量與介面行為仍請使用者試用。

權限按鈕修正：尚未授權時，請求後直接開啟輸入監控設定，提供持續可見的引導與 Finder 顯示 App 按鈕。已通過 Release 編譯和簽署驗證，重新部署啟動；授權開關需由使用者操作，尚未替使用者驗證開關狀態。

## 1.3.0：公開測試版與登入延續

已完成 arm64 + x86_64 Universal Release 編譯、codesign 嚴格驗證與 ZIP 解壓檢查。登入啟動以 SMAppService 註冊，當前使用者已註冊成功（系統狀態 1 = enabled）。登入時不主動彈出設定；手動啟動仍顯示。偏好沿用既有 UserDefaults 鍵值，啟動不會覆寫音色、音量或暫停狀態。

目前使用者的固定安裝位置在 ~/Applications/Rainy Desk.app。Apple Silicon 已交叉編譯但未實機執行；未實際重新開機驗證。公開包仍未經 Developer ID 簽署、公證，需要使用者自行允許首次開啟與輸入監控。


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
