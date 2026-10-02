# EyeBreak 👁️

A native macOS menu bar app written in Swift (SwiftUI + AppKit) implementing the **20-20-20 rule**: every **20 minutes**, it reminds you to look at something **20 feet away** for **20 seconds**.

The alert expands smoothly out of the **MacBook notch area**, functioning like a native **Dynamic Island** for macOS.

---

## ✨ Features

- **Dynamic Island Notch Alert**:
  - Automatically detects the physical camera notch using `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea`.
  - Seamlessly blends with the notch geometry with continuous rounded bottom corners.
  - Fallback for external displays and notchless Macs: displays a centered pill at the top of the display.
  - Smooth spring expand/collapse animations directly out of and into the notch bezel.
- **Non-Activating Window**:
  - Borderless, transparent `NSPanel` with `.screenSaver` window level.
  - Strictly non-activating (`canBecomeKey = false`, `canBecomeMain = false`), ensuring it **never steals keyboard focus** from Xcode, terminal, games, or work.
- **Multi-Display Aware**:
  - Displays the alert on the screen currently containing the mouse cursor.
- **Smart Pause & Idle Detection**:
  - Pauses timer when the Mac sleeps (`NSWorkspace.willSleepNotification`) or screen locks (`com.apple.screenIsLocked`).
  - Automatically pauses when the user is idle for 5+ minutes (configurable) using Quartz `CGEventSource` input events, and resumes upon return.
- **Screen Distance Guardian (Stay Far from Screen)**:
  - Continuously monitors viewing distance using the FaceTime camera and Apple's on-device **Vision framework** (`VNDetectFaceRectanglesRequest`).
  - If you lean in closer than an arm's length (< 12–14 inches / 30–35 cm) for more than 3 seconds, the notch alert expands in warning amber: *"Too close to the screen • Please sit back"*.
  - When you move back to a safe distance, the alert turns green (*"Safe Distance ✓"*) and smoothly collapses back into the notch after 1.5 seconds.
  - **100% Privacy-Preserving**: Runs purely on-device using Apple Neural Engine/CPU. Frames are analyzed in memory and immediately discarded. Video is never saved, recorded, or transmitted.
  - Minimal resource usage: Samples at only 1 frame/sec when active, and turns off completely when the screen is locked, sleeping, or idle.
- **Audio Feedback**:
  - Plays soft system chimes at break start and completion (customizable sound: Tink, Glass, Hero, Ping, etc.).
- **Pure Menu Bar App**:
  - `LSUIElement = true` (no Dock icon, zero clutter).
  - Status item with live time remaining, Pause/Resume, Take break now, Skip break, and Debug test alert.
- **Native SwiftUI Settings**:
  - Screen Distance toggle, sensitivity slider (Relaxed, Normal, Strict), and camera status indicator.
  - Work interval & break duration sliders with quick presets.
  - Launch at login toggle powered by `SMAppService.mainApp`.
  - Audio chimes selection with preview.
  - One-click "Test Break Alert" and "Test Screen Distance Alert" buttons.

---

## 🛠️ Architecture & Code Structure

```
EyeBreak/
├── EyeBreak.xcodeproj      # Generated native Xcode project (XcodeGen)
├── Package.swift           # Swift Package Manager manifest
├── project.yml             # XcodeGen project specification
├── EyeBreak.app            # Compiled and signed macOS application bundle
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift          # App lifecycle, notification handlers, CLI flags
│   │   └── main.swift                 # Application entry point
│   ├── Controllers/
│   │   ├── MenuBarController.swift    # NSStatusItem, dynamic menu items, Settings window
│   │   └── NotchWindowController.swift# Non-activating NSPanel & notch expand/collapse anims
│   ├── Models/
│   │   ├── AppSettings.swift          # UserDefaults persistence & SMAppService login helper
│   │   └── TimerManager.swift         # 20-20-20 state machine, countdowns, idle/sleep/lock
│   ├── Views/
│   │   ├── NotchAlertView.swift       # Dynamic Island SwiftUI view, countdown ring & pulse
│   │   └── SettingsView.swift         # SwiftUI Settings interface with presets & audio picker
│   └── Utils/
│       ├── IdleDetector.swift         # Quartz CGEventSource idle time detection
│       ├── ScreenNotchDetector.swift  # Multi-screen & hardware notch geometry calculations
│       └── SoundManager.swift         # NSSound audio chimes manager
├── Resources/
│   ├── Info.plist                     # LSUIElement = true, macOS 13+ metadata
│   └── EyeBreak.entitlements          # App entitlements
└── scripts/
    ├── build_app.sh                   # Builds release binary, creates EyeBreak.app & signs
    ├── trigger_test_alert.swift       # CLI utility to trigger notch alert via notification
    └── verify_alert.swift             # Diagnostic tool inspecting active screen & notch metrics
```

---

## 📐 Notch Positioning Logic Explained

The positioning math is implemented in `Sources/Utils/ScreenNotchDetector.swift`:

1. **Detection**:
   - `screen.safeAreaInsets.top` indicates whether the display has a camera notch. On modern MacBooks (M1/M2/M3/M4 Pro & Air), this value is ~32.0 to 36.0 pt.
   - `screen.auxiliaryTopLeftArea` and `screen.auxiliaryTopRightArea` define the usable menu bar space on either side of the camera cutout.
2. **Width & Origin**:
   - `notchWidth = auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX` (~179 to 210 pt).
   - `notchHeight = screen.safeAreaInsets.top`.
   - Anchored at `x = screen.frame.midX - (notchWidth / 2)` and `y = screen.frame.maxY - notchHeight`.
3. **Smooth Expansion**:
   - When collapsed, the panel matches the notch dimensions.
   - When expanded, the panel increases width to `max(notchWidth + 210, 430 pt)` and drops down to `notchHeight + 64 pt`, with continuous rounded bottom corners (`bottomRadius: 24 pt`).
4. **Fallback**:
   - For external monitors or notchless Macs, `safeAreaInsets.top == 0`. The app generates a sleek top-centered Dynamic Island pill.

---

## 🚀 Building and Running

### Option 1: Double-click or Terminal Launch
The app bundle is already built and ready in the repository root:
```bash
open EyeBreak.app
```

### Option 2: Build & Package from Source
Run the provided build script:
```bash
./scripts/build_app.sh
open EyeBreak.app
```

### Option 3: Open in Xcode
Open the generated Xcode project:
```bash
open EyeBreak.xcodeproj
```
Select the `EyeBreak` target and click **Run (⌘R)**.

To regenerate the Xcode project at any time:
```bash
xcodegen generate
```

---

## 🧪 Testing the Alerts

1. **From the Menu Bar**:
   - Click the eye icon (`👁`) in your menu bar.
   - Select **"Test Break Alert"** for the 20-20-20 countdown.
   - Select **"Test Screen Distance Alert"** for the distance warning.
2. **From Settings**:
   - Open **Settings...** from the menu bar (`⌘,`).
   - Click **"Test Screen Distance Alert"** or **"Test Break Alert"**.
3. **From Terminal**:
   ```bash
   # Test 20-20-20 Eye Break alert
   ./scripts/trigger_test_alert break

   # Test Screen Distance alert
   ./scripts/trigger_test_alert distance

   # Open Settings
   ./scripts/trigger_test_alert settings
   ```
   Or launch directly with the debug flag:
   ```bash
   open EyeBreak.app --args --test-distance-alert
   ```
