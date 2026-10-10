import AppKit
import SwiftUI
import Combine

public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?

    private var statusMenuItem: NSMenuItem?
    private var pauseResumeMenuItem: NSMenuItem?
    private var skipMenuItem: NSMenuItem?
    private var notchDistanceMenuItem: NSMenuItem?

    private let timerManager = TimerManager.shared
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    public func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "LookAway") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = ""
            }
            button.toolTip = "LookAway • 20-20-20 Eye Rest"
        }

        let newMenu = NSMenu()
        newMenu.delegate = self

        // 1. Status header (time remaining)
        let statusItem = NSMenuItem(title: "LookAway: Loading...", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        newMenu.addItem(statusItem)
        self.statusMenuItem = statusItem

        newMenu.addItem(NSMenuItem.separator())

        // 2. Take Break Now
        let takeBreakItem = NSMenuItem(
            title: "Take Break Now",
            action: #selector(takeBreakAction),
            keyEquivalent: "b"
        )
        takeBreakItem.target = self
        newMenu.addItem(takeBreakItem)

        // 3. Skip This Break
        let skipItem = NSMenuItem(
            title: "Skip This Break",
            action: #selector(skipBreakAction),
            keyEquivalent: "s"
        )
        skipItem.target = self
        newMenu.addItem(skipItem)
        self.skipMenuItem = skipItem

        // 4. Pause / Resume
        let pauseItem = NSMenuItem(
            title: "Pause Timer",
            action: #selector(togglePauseAction),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        newMenu.addItem(pauseItem)
        self.pauseResumeMenuItem = pauseItem

        newMenu.addItem(NSMenuItem.separator())

        // 5. Debug: Test Break Alert
        let testAlertItem = NSMenuItem(
            title: "Test Break Alert",
            action: #selector(testAlertAction),
            keyEquivalent: "t"
        )
        testAlertItem.target = self
        newMenu.addItem(testAlertItem)

        // 6. Show / Hide Distance in Notch
        let notchDistanceItem = NSMenuItem(
            title: "Show Distance in Notch",
            action: #selector(toggleDistanceNotchAction),
            keyEquivalent: "n"
        )
        notchDistanceItem.target = self
        newMenu.addItem(notchDistanceItem)
        self.notchDistanceMenuItem = notchDistanceItem

        // 7. Debug: Test Screen Distance Alert
        let testDistanceItem = NSMenuItem(
            title: "Test Screen Distance Alert",
            action: #selector(testDistanceAlertAction),
            keyEquivalent: "d"
        )
        testDistanceItem.target = self
        newMenu.addItem(testDistanceItem)

        // 8. Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        newMenu.addItem(settingsItem)

        newMenu.addItem(NSMenuItem.separator())

        // 9. Quit
        let quitItem = NSMenuItem(
            title: "Quit LookAway",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        newMenu.addItem(quitItem)

        item.menu = newMenu
        self.menu = newMenu
        self.statusItem = item

        observeTimer()
        updateMenuContent()
    }

    private func observeTimer() {
        // Update menu bar UI whenever relevant timer state changes.
        // Break countdown needs its own publisher because the state stays .breakActive
        // while the remaining time ticks down; otherwise the menu can stale out.
        timerManager.$timeRemainingWork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuContent()
            }
            .store(in: &cancellables)

        timerManager.$timeRemainingBreak
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuContent()
            }
            .store(in: &cancellables)

        timerManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuContent()
            }
            .store(in: &cancellables)

        timerManager.$isPausedManually
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuContent()
            }
            .store(in: &cancellables)
    }

    private func updateMenuContent() {
        statusMenuItem?.title = timerManager.menuStatusTitle
        statusItem?.button?.toolTip = "LookAway: \(timerManager.menuStatusTitle)"

        let isPaused = timerManager.isPausedManually
        pauseResumeMenuItem?.title = isPaused ? "Resume Timer" : "Pause Timer"

        if timerManager.state == .breakActive {
            skipMenuItem?.title = "Skip Active Break"
            statusItem?.button?.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "LookAway Active")
        } else {
            skipMenuItem?.title = "Reset Work Timer"
            statusItem?.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "LookAway")
        }
        statusItem?.button?.image?.isTemplate = true

        if NotchWindowController.shared.isVisible && NotchWindowController.shared.currentAlertType == .liveDistanceHUD {
            notchDistanceMenuItem?.title = "Hide Distance in Notch"
        } else {
            notchDistanceMenuItem?.title = "Show Distance in Notch"
        }
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        updateMenuContent()
    }

    // MARK: - Actions

    @objc private func takeBreakAction() {
        timerManager.takeBreakNow()
    }

    @objc private func skipBreakAction() {
        timerManager.skipBreak()
    }

    @objc private func togglePauseAction() {
        timerManager.togglePause()
    }

    @objc private func testAlertAction() {
        timerManager.testAlert()
    }

    @objc private func toggleDistanceNotchAction() {
        NotchWindowController.shared.toggleLiveDistanceHUD()
    }

    @objc private func testDistanceAlertAction() {
        ScreenDistanceManager.shared.testDistanceAlert()
    }

    @objc public func openSettingsAction() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "LookAway Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
