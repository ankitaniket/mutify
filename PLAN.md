# Mutify — Plan & Architecture

A tiny, always-on macOS menu bar app that mutes/unmutes your microphone
**system-wide** with a global keyboard shortcut (default `⌘⇧0`). Built so you can
silence yourself instantly during Zoom / Google Meet / Microsoft Teams calls,
even while screen-sharing — without hunting for the in-app mute button.

---

## 1. Goals

- **Always present** in the macOS menu bar at the top of the screen.
- **Global shortcut** (default `⌘⇧0`) toggles mic from anywhere, in any app.
- **System-wide mute** — works regardless of which app is using the mic
  (Zoom, Meet, Teams, browsers, OBS…).
- **Bottom-right toast HUD** showing "Muted" / "Unmuted" as visual feedback.
- **No sound** on toggle.
- **Launch at login**, with a toggle in the Settings window.
- **Customizable shortcut** via a Settings window.
- Lightweight, native, production-grade. Final binary ≈ 2–5 MB.

---

## 2. Tech Stack

| Layer            | Choice                                                                 | Why                                                                                                                                |
| ---------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Language         | **Swift 5.9+**                                                         | Apple-native, no runtime, ARC.                                                                                                     |
| App lifecycle    | **SwiftUI `App` + `NSApplicationDelegateAdaptor`**                     | Modern entry point, lets us still drop into AppKit for the menu bar / HUD.                                                         |
| UI               | **SwiftUI** (Settings) + **AppKit** (`NSStatusItem`, borderless HUD)   | SwiftUI is great for forms; AppKit gives full control over the menu bar item and a click-through floating window.                 |
| Audio control    | **CoreAudio** (`kAudioDevicePropertyMute` on the default input device) | Mutes the *device* at the OS level → every app instantly hears silence. No per-app integration needed. Works with Zoom/Meet/Teams. |
| Global hotkey    | **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** by Sindre Sorhus | De-facto standard SPM package for macOS hotkeys. Includes a SwiftUI shortcut recorder. Uses Carbon `RegisterEventHotKey` under the hood — **no Accessibility permission required**. |
| Launch at login  | **`SMAppService.mainApp`** (macOS 13+ Ventura)                          | Apple-sanctioned modern API. Replaces the deprecated `LSSharedFileList` / login-helper bundle approach.                            |
| Menu-bar-only    | **`LSUIElement = YES`** in `Info.plist`                                 | No Dock icon, no `⌘-Tab` entry — pure utility app.                                                                                 |
| Project gen      | **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`project.yml`)   | Reproducible `.xcodeproj` from a 30-line YAML; no merge conflicts in `project.pbxproj`.                                            |
| Min macOS        | **13.0 Ventura**                                                        | Required by `SMAppService` (modern launch-at-login API).                                                                           |
| Dependencies     | **1** — KeyboardShortcuts (via SPM)                                     | Everything else is system frameworks. No CocoaPods, no Carthage, no Electron.                                                      |

> Rationale: this is the canonical Apple-native stack for menu bar utilities, the
> same approach used by **Rectangle**, **Ice**, **MeetingBar**, and **Bartender**.

---

## 3. How It Works (the muting magic)

The interesting question is "how do you mute the mic across every app?".
The answer is **CoreAudio** — specifically, the `kAudioDevicePropertyMute`
property on the **default input device**, scoped to `kAudioDevicePropertyScopeInput`.

```
System Default Input Device  ──[ mute = 1 ]──▶  All connected apps
        ▲                                       (Zoom, Meet, Teams, Chrome…)
        │                                       receive silence
        │
   Mutify writes
   AudioObjectSetPropertyData
```

Setting this property is equivalent to flipping the input mute switch in
**System Settings → Sound → Input** — except it happens instantly and from a
keyboard shortcut. Because the mute is applied at the *device* level (not per-app),
**every application using the mic immediately reads silence**, including
conferencing apps that have their own software mute UIs. Zoom / Meet / Teams will
visually reflect the muted state as well, because they listen to the same device.

We additionally:

1. Register a CoreAudio property listener so external mute changes (e.g. you
   click mute in System Settings) update our menu bar icon in real time.
2. Register a listener on `kAudioHardwarePropertyDefaultInputDevice` so if you
   plug in a new mic / headset and macOS switches the default, we re-bind to the
   new device automatically.

---

## 4. Architecture

```
┌──────────────────────┐    ⌘⇧0      ┌────────────────────┐
│  KeyboardShortcuts   │────────────▶│   HotkeyManager    │
│  (Carbon hotkey)     │             └─────────┬──────────┘
└──────────────────────┘                       │ toggle()
                                               ▼
                                  ┌────────────────────────┐
                                  │ MicrophoneController   │
                                  │  (CoreAudio mute)      │◀─── kAudioDevicePropertyMute
                                  │  @Published isMuted    │     listener (external changes)
                                  └────┬───────────────┬───┘
                                       │               │
                              isMuted  │               │ isMuted
                                       ▼               ▼
                          ┌────────────────────┐  ┌────────────────────┐
                          │ StatusBarController│  │   HUDController    │
                          │  (NSStatusItem,    │  │   (toast window    │
                          │   icon + menu)     │  │    bottom-right)   │
                          └────────────────────┘  └────────────────────┘

  ┌─────────────────────┐
  │   SettingsView      │  Recorder ──▶ KeyboardShortcuts.Name.toggleMute
  │   (SwiftUI form)    │  Toggle ────▶ LaunchAtLogin (SMAppService)
  └─────────────────────┘
```

`MicrophoneController` is the single source of truth. The status bar icon and the
HUD both subscribe to its `@Published var isMuted` via Combine, so they always
agree — including when the mute state changes from outside the app.

---

## 5. File Map

```
mutify/
├── PLAN.md                          ← this file
├── project.yml                      ← XcodeGen config
├── .gitignore
└── mutify/
    ├── Info.plist                   ← LSUIElement=YES, NSMicrophoneUsageDescription
    ├── Mutify.entitlements          ← com.apple.security.device.audio-input
    ├── Assets.xcassets/
    │   ├── AppIcon.appiconset/
    │   └── AccentColor.colorset/
    │
    ├── MutifyApp.swift              ← @main, SwiftUI App + AppDelegate adaptor + Settings scene
    ├── AppDelegate.swift            ← bootstraps controllers on launch
    │
    ├── Audio/
    │   └── MicrophoneController.swift  ← CoreAudio mute get/set + listeners (the heart)
    │
    ├── Hotkey/
    │   ├── KeyboardShortcuts+Names.swift ← .toggleMute name w/ default ⌘⇧0
    │   └── HotkeyManager.swift           ← wires hotkey → toggle() → HUD
    │
    ├── UI/
    │   ├── StatusBarController.swift     ← NSStatusItem icon + right-click menu
    │   ├── HUDWindow.swift               ← borderless NSWindow + SwiftUI capsule view
    │   ├── HUDController.swift           ← show("Muted"/"Unmuted"), fade in/out, position
    │   └── SettingsView.swift            ← shortcut recorder + launch-at-login toggle
    │
    └── System/
        └── LaunchAtLogin.swift           ← SMAppService.mainApp wrapper
```

### File-by-file responsibilities

| File                              | Responsibility                                                                                                  |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `MutifyApp.swift`                 | Declares the `@main` SwiftUI app, attaches `AppDelegate`, exposes the `Settings` scene.                         |
| `AppDelegate.swift`               | On launch: instantiates `MicrophoneController`, `HUDController`, `StatusBarController`, and registers the hotkey. |
| `MicrophoneController.swift`      | All CoreAudio plumbing: read/write mute, default-device tracking, two property listeners, `@Published isMuted`. |
| `KeyboardShortcuts+Names.swift`   | Defines the `.toggleMute` shortcut name and its default key combo (`⌘⇧0`).                                       |
| `HotkeyManager.swift`             | Registers a `KeyboardShortcuts.onKeyDown` callback that toggles the mic and shows the HUD.                       |
| `StatusBarController.swift`       | Owns the always-visible `NSStatusItem`. Left-click toggles, right-click opens menu. Mirrors mute state via icon. |
| `HUDWindow.swift`                 | Borderless click-through `NSWindow` at `.statusBar` level. `sharingType = .none` so screen captures hide it.    |
| `HUDController.swift`             | Singleton that shows/dismisses the toast bottom-right of the active screen with fade animation (≈1.2 s).        |
| `SettingsView.swift`              | SwiftUI form with the shortcut recorder, launch-at-login toggle, quit button.                                   |
| `LaunchAtLogin.swift`             | Tiny enum wrapper around `SMAppService.mainApp.register()` / `unregister()`.                                    |

---

## 6. Permissions

| Permission               | Required? | Why                                                                                                       |
| ------------------------ | --------- | --------------------------------------------------------------------------------------------------------- |
| **Microphone**           | ✅        | macOS gates writes to CoreAudio mute properties on input devices behind TCC. Prompted on first toggle.    |
| **Accessibility**        | ❌        | KeyboardShortcuts uses Carbon `RegisterEventHotKey`, which does not require Accessibility.                |
| **Screen Recording**     | ❌        | We don't capture the screen.                                                                              |
| **Input Monitoring**     | ❌        | Not needed — Carbon hotkeys are scoped, not raw key events.                                               |

`Mutify.entitlements` declares `com.apple.security.device.audio-input`. The app
sandbox is **disabled** (`ENABLE_APP_SANDBOX: NO` in `project.yml`) because
CoreAudio device-level mute writes are blocked under the sandbox.

---

## 7. UX flow

1. You launch Mutify → mic icon appears in the menu bar; no Dock icon.
2. You hop on a Zoom / Meet / Teams call and start screen sharing.
3. Press `⌘⇧0`:
   - CoreAudio mute flips to `1` on the default input device.
   - Zoom/Meet/Teams immediately show you as muted.
   - The menu bar icon switches to `mic.slash.fill` in red.
   - A small "Muted" toast fades in at the bottom-right of your active screen
     for ~1.2 s. Because the HUD window has `sharingType = .none`, **your call
     participants do not see the toast on the shared screen** — only you do.
4. Press `⌘⇧0` again to unmute. Same flow in reverse with an "Unmuted" toast.
5. Right-click the menu bar icon → **Settings…** → rebind shortcut, toggle
   "Launch at login", or quit.

---

## 8. Building & Running

You need Xcode 15+ and Homebrew.

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Generate the Xcode project from project.yml
cd /Users/ankitaniket/Documents/Projects/mutify
xcodegen generate

# 3. Open in Xcode and run
open Mutify.xcodeproj
# then ⌘R
```

**Or build from CLI:**

```bash
xcodebuild \
  -project Mutify.xcodeproj \
  -scheme Mutify \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
open build/Build/Products/Release/Mutify.app
```

The first time you press `⌘⇧0`, macOS will prompt you to grant **Microphone**
access. Approve it.

---

## 9. Verification Checklist

- [ ] App launches with a mic icon in the menu bar; **no Dock icon**.
- [ ] Pressing `⌘⇧0` flips the icon and shows a bottom-right toast.
- [ ] System Settings → Sound → Input meter goes silent when muted.
- [ ] Zoom test call: pressing the shortcut updates Zoom's own mute indicator.
- [ ] Google Meet (Chrome): pressing the shortcut mutes you in the meeting.
- [ ] Toast appears even while screen-sharing, but is **not** visible to call participants.
- [ ] Settings window: rebinding the shortcut works; old combo no longer fires.
- [ ] Launch-at-login toggle survives reboot.
- [ ] Muting from System Settings (instead of Mutify) updates the menu bar icon.
- [ ] Plugging/unplugging an external mic re-binds to the new default device.

---

## 10. Future ideas (out of scope for v1)

- Push-to-talk mode (hold key to *un*mute).
- Per-app exceptions (e.g. always live in OBS).
- LED keyboard / Stream Deck integration via a small XPC service.
- Notarization + DMG release pipeline (`create-dmg` + `xcrun notarytool`).
