# 🎙️ Mutify

A tiny, always-on macOS menu bar app that mutes and unmutes your microphone
**system-wide** with a single global keyboard shortcut.

Built so you can silence yourself instantly during Zoom / Google Meet / Microsoft
Teams calls — even while screen-sharing — without ever leaving the app you're in.

![macOS](https://img.shields.io/badge/macOS-13%2B-000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)
![Size](https://img.shields.io/badge/Size-~700KB-2ea44f?style=flat-square)
![Shortcut](https://img.shields.io/badge/Default%20Shortcut-%E2%8C%98%E2%87%A50-7B61FF?style=flat-square)

> Default shortcut: **`⌘⇧0`** · Footprint: **~700 KB** · No Dock icon, no clutter.

---

## 🚀 Install in one command

> [!TIP]
> **The easiest way — no Xcode, no drag-and-drop, no Gatekeeper warnings.**

```bash
gh repo clone ankitaniket/mutify /tmp/mutify-install \
  && bash /tmp/mutify-install/install.sh
```

That's it. The mic icon will appear in your menu bar — press **`⌘⇧0`** to toggle.

<details>
<summary><b>📋 What this command does</b></summary>

1. 📥 Clones this repo into `/tmp/mutify-install`
2. 🔍 Looks up the latest release tag (`v1.0.0`, `v1.0.1`, …)
3. 📦 Downloads the latest `.dmg` from GitHub Releases via `gh`
4. 💿 Mounts the DMG
5. ✋ Quits any running Mutify
6. 📂 Copies `Mutify.app` into `/Applications`
7. 🛡️ **Strips the macOS quarantine attribute** — this is what kills the
   *"Apple cannot verify…"* / *"damaged"* warnings
8. ✅ Verifies the code signature
9. 📤 Unmounts the DMG and launches Mutify

No clicks. No drag. No "damaged". No "Apple cannot verify".

</details>

> [!IMPORTANT]
> **Prerequisites**
> - macOS **13 Ventura** or later
> - GitHub CLI installed and authenticated:
>   ```bash
>   brew install gh && gh auth login
>   ```
>
> The `gh` requirement is because this repo is currently **private**. When it
> goes public, the install command will simplify to:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/ankitaniket/mutify/main/install.sh | bash
> ```

### 📦 Manual install (DMG)

If you'd rather drag-and-drop:

1. Grab the latest **`Mutify-x.y.z.dmg`** from the [Releases page](https://github.com/ankitaniket/mutify/releases).
2. Open it → drag **Mutify.app** → **Applications** folder.
3. **Right-click** Mutify in Applications → **Open** → click **Open** in the
   Gatekeeper dialog. (Or run `xattr -dr com.apple.quarantine /Applications/Mutify.app`
   in Terminal first to skip the dialog entirely.)
4. On first toggle, click **Allow** when macOS asks for Microphone permission.

---

## 💡 Why?

Every video conferencing app has its own mute button, and they're all in
different places. When you're sharing your screen — running a demo, walking
through code, presenting slides — reaching for the in-app mute button is
awkward, slow, and visible to everyone watching.

Mutify gives you **one shortcut that works everywhere**. Press it from any app,
in any state, and your microphone is muted at the **operating system level** —
which means Zoom, Meet, Teams, the browser, and every other app instantly see
silence.

---

## ✨ Features

- 🎙️ **System-wide mute** — works regardless of which app is using the mic.
- ⌨️ **Global shortcut** — default `⌘⇧0`, fully customizable in Settings.
- 🟢 **Always-present menu bar icon** — flips between `mic.fill` and red
  `mic.slash.fill` so you always know your status at a glance.
- 🪟 **Bottom-right toast HUD** — shows "Muted" / "Unmuted" for ~1.2 s as visual
  confirmation.
- 🛡️ **Hidden from screen sharing** — the toast window has `sharingType = .none`,
  so meeting participants never see your "Muted" toasts on a shared screen.
  Only you do.
- 🚀 **Launch at login** — toggleable from Settings, uses Apple's modern
  `SMAppService` API.
- 🔁 **Stays in sync** — listens to CoreAudio property changes, so muting from
  System Settings (or unplugging your mic) updates Mutify in real time.
- 🪶 **Lightweight** — final binary is **~700 KB**. No Electron, no runtime.

---

## 🔧 How it works

The interesting question is *"how do you mute the mic across every app?"*.
The answer is **CoreAudio** — specifically, the `kAudioDevicePropertyMute`
property on the **default input device**, scoped to
`kAudioDevicePropertyScopeInput`.

```
System Default Input Device  ──[ mute = 1 ]──▶  All connected apps
        ▲                                       (Zoom, Meet, Teams, Chrome…)
        │                                       receive silence
        │
   Mutify writes
   AudioObjectSetPropertyData
```

Setting this property is equivalent to flipping the input mute switch in
**System Settings → Sound → Input** — except it happens instantly from a
keyboard shortcut. Because the mute is applied at the *device* level (not
per-app), **every application using the mic immediately reads silence**,
including conferencing apps that have their own software mute UIs. Zoom / Meet /
Teams will visually reflect the muted state too, because they listen to the
same device.

Mutify also registers two CoreAudio property listeners:

1. One on the mute property itself, so external mute changes (e.g. you click
   mute in System Settings) update the menu bar icon in real time.
2. One on `kAudioHardwarePropertyDefaultInputDevice`, so plugging in a new
   mic / headset and switching the default input automatically rebinds Mutify
   to the new device.

---

## 🏛️ Architecture

```
┌──────────────────────┐    ⌘⇧0      ┌────────────────────┐
│  KeyboardShortcuts   │────────────▶│   HotkeyManager    │
│  (Carbon hotkey)     │             └─────────┬──────────┘
└──────────────────────┘                       │ toggle()
                                               ▼
                                  ┌────────────────────────┐
                                  │ MicrophoneController   │
                                  │  (CoreAudio mute)      │◀── kAudioDevicePropertyMute
                                  │  @Published isMuted    │    listener (external changes)
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

`MicrophoneController` is the single source of truth. The status bar icon and
the HUD both subscribe to its `@Published var isMuted` via Combine, so they
always agree — including when the mute state changes from outside the app.

---

## 🧱 Tech Stack

| Layer            | Choice                                                        | Why                                                                                                |
| ---------------- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Language         | **Swift 5.9+**                                                | Apple-native, no runtime, ARC.                                                                     |
| App lifecycle    | **SwiftUI `App` + `NSApplicationDelegateAdaptor`**            | Modern entry point that still drops down to AppKit for the menu bar / HUD.                         |
| UI               | **SwiftUI** (Settings) + **AppKit** (`NSStatusItem`, HUD)     | SwiftUI for forms; AppKit for full control of the menu bar item and a click-through toast window. |
| Audio control    | **CoreAudio** (`kAudioDevicePropertyMute`)                    | OS-level device mute → every app instantly hears silence. No per-app integration needed.          |
| Global hotkey    | **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** by Sindre Sorhus | De-facto standard SPM package. Uses Carbon `RegisterEventHotKey` — no Accessibility permission.   |
| Launch at login  | **`SMAppService.mainApp`** (macOS 13+)                        | Apple's modern API. Replaces the deprecated login-helper bundle approach.                          |
| Menu-bar-only    | **`LSUIElement = YES`** in `Info.plist`                       | No Dock icon, no `⌘-Tab` entry — pure utility app.                                                 |
| Project gen      | **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**         | Reproducible `.xcodeproj` from a 30-line YAML; no `project.pbxproj` merge conflicts.               |
| Min macOS        | **13.0 Ventura**                                              | Required by `SMAppService`.                                                                        |
| Dependencies     | **1** — KeyboardShortcuts (via SPM)                           | Everything else is system frameworks. No CocoaPods, no Carthage.                                   |

> This is the canonical Apple-native stack for menu bar utilities, the same
> approach used by **Rectangle**, **Ice**, **MeetingBar**, and **Bartender**.

---

## 📁 Project structure

```
mutify/
├── README.md                        ← you are here
├── PLAN.md                          ← extended design / architecture doc
├── project.yml                      ← XcodeGen config
├── .gitignore
└── mutify/
    ├── Info.plist                   ← LSUIElement=YES, NSMicrophoneUsageDescription
    ├── Mutify.entitlements          ← com.apple.security.device.audio-input
    ├── Assets.xcassets/
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

For the per-file deep dive, see [`PLAN.md`](./PLAN.md).

---

## 🛠️ Building from source

You need **Xcode 15+** and **Homebrew**.

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Clone and generate the Xcode project
git clone https://github.com/ankitaniket/mutify.git
cd mutify
xcodegen generate

# 3. Open in Xcode and run
open Mutify.xcodeproj
# then ⌘R
```

### Or build from the command line

```bash
xcodebuild \
  -project Mutify.xcodeproj \
  -scheme Mutify \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

open build/Build/Products/Release/Mutify.app
```

The app is ad-hoc signed by default. If macOS Gatekeeper blocks the first
launch, run:

```bash
xattr -dr com.apple.quarantine build/Build/Products/Release/Mutify.app
```

---

## 🎬 First launch

1. A 🎙️ mic icon appears in your menu bar. **No Dock icon.**
2. Press `⌘⇧0` — macOS will pop a **Microphone permission** dialog. Click **Allow**.
   (Required because CoreAudio mute writes are TCC-gated.)
3. Press `⌘⇧0` again — the icon flips to red `mic.slash`, and a "Muted" toast
   fades in at the bottom-right of your screen.
4. Press it again to unmute.

**Right-click** the menu bar icon → **Settings…** to:
- Rebind the global shortcut.
- Toggle **Launch at login**.
- Quit the app.

---

## 🔐 Permissions

| Permission           | Required? | Why                                                                                               |
| -------------------- | --------- | ------------------------------------------------------------------------------------------------- |
| **Microphone**       | ✅        | macOS gates writes to CoreAudio mute on input devices behind TCC. Prompted on first toggle.       |
| **Accessibility**    | ❌        | KeyboardShortcuts uses Carbon hotkeys, which don't need Accessibility.                            |
| **Screen Recording** | ❌        | Mutify never captures your screen.                                                                |
| **Input Monitoring** | ❌        | Carbon hotkeys are scoped, not raw keystrokes.                                                    |

The app sandbox is intentionally **disabled**, because CoreAudio device-level
mute writes are blocked under the sandbox.

---

## 📜 License

Personal project. All rights reserved.

---

## 🔗 See also

- [`PLAN.md`](./PLAN.md) — extended architecture & design notes.
