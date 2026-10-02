<div align="center">

# 👁️ LookAway

### The 20-20-20 rule, delivered by your Mac's notch.

A native macOS menu bar app that helps you build healthier screen habits with
timed eye-break reminders, a notch-style interface, and on-device screen-distance awareness.

<p>

<img src="https://img.shields.io/badge/macOS-13%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13+" />

<img src="https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />

<img src="https://img.shields.io/badge/SwiftUI-0A84FF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />

<img src="https://img.shields.io/badge/AppKit-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="AppKit" />

<img src="https://img.shields.io/badge/Privacy-On--Device-5856D6?style=for-the-badge" alt="Privacy" />

</p>

<p>

<a href="#-quick-start">Quick Start</a> ·
<a href="#-features">Features</a> ·
<a href="#-how-it-works">How It Works</a> ·
<a href="#-engineering-highlights">Engineering</a> ·
<a href="#-roadmap">Roadmap</a>

</p>

</div>

---

## 👀 Why LookAway?

Long hours in front of a screen can make it easy to forget to take regular breaks.

LookAway follows the simple **20-20-20 rule**:

> Every **20 minutes**, look at something around **20 feet away** for **20 seconds**.

Instead of relying on intrusive notifications, LookAway lives quietly in the macOS menu bar and uses a lightweight notch-style reminder when it's time for a break.

The goal is simple:

**Remind you without getting in your way.**

---

## ✨ Features

### ⏱️ 20-20-20 Eye Breaks

- Automatically tracks your work interval
- Reminds you when it's time to take a break
- Configurable work interval
- Configurable break duration
- Countdown during the break
- Automatically returns to the normal work state

---

### 🏝️ Notch-Style Break Alerts

- Native macOS `NSPanel`
- Expands from the top of the screen
- Smooth expand/collapse animation
- Designed to resemble a Dynamic-Island-style experience
- Non-activating window
- Does not steal keyboard focus
- Works without interrupting your current application

---

### 📏 Screen Distance Awareness

LookAway is designed to optionally use the Mac camera to provide **viewing-distance awareness**.

The planned distance guardian can:

- Detect your face locally
- Estimate relative viewing distance
- Warn when you're sitting too close
- Warn when you've moved too far away
- Return to a safe state when you move back into range

> This feature is intended as an awareness tool, not a medical diagnostic system.

---

### 🔒 Privacy by Design

The distance-awareness system is designed around local processing.

- Camera processing happens on-device
- No cloud computer vision
- No remote image processing
- Camera frames are not intended to be permanently stored
- Distance awareness can be disabled from Settings

---

### 💤 Smart Pause

LookAway understands that you aren't always actively using your Mac.

The timer can respond to:

- System sleep
- Screen lock
- User inactivity
- System wake
- Returning activity

This prevents your break timer from continuing to behave as if you're working while you're actually away.

---

### 🎛️ Menu Bar Experience

LookAway runs as a menu bar application.

From the menu bar you can:

- View time until the next break
- Pause reminders
- Resume reminders
- Take a break immediately
- Skip the current break
- Open Settings
- Test the break alert
- Quit the application

---

### ⚙️ Customizable Settings

Configure the experience around your workflow.

Possible settings include:

| Setting | Purpose |
|---|---|
| Work Interval | Time before a break |
| Break Duration | Length of the break |
| Sound | Enable or disable sounds |
| Pause During Idle | Pause when you're away |
| Launch at Login | Start automatically with macOS |
| Distance Awareness | Enable / disable camera-based awareness |

---

## 🎬 Screenshots

<div align="center">

| Break Alert | Distance Warning | Safe Distance | Settings |
|:---:|:---:|:---:|:---:|
| <img src="docs/assets/break.png" width="200" /> | <img src="docs/assets/too-close.png" width="200" /> | <img src="docs/assets/safe.png" width="200" /> | <img src="docs/assets/settings.png" width="200" /> |

</div>

---

## 🚀 Quick Start

### Requirements

- macOS 13 or later
- Xcode
- Swift
- Apple Silicon or Intel Mac

### Clone the repository

```bash
git clone https://github.com/shiivu18/LookAway.git
cd LookAway
