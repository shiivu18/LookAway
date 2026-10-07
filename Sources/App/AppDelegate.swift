import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from quitting when settings window is closed
        NSApp.setActivationPolicy(.accessory)

        // Wire timer notifications directly to NotchWindowController
        TimerManager.shared.onShowAlert = { duration in
            NotchWindowController.shared.show(alertType: .eyeBreak, durationSeconds: duration)
        }
        TimerManager.shared.onDismissAlert = {
            if NotchWindowController.shared.currentAlertType == .eyeBreak {
                NotchWindowController.shared.dismiss()
            }
        }

        // Wire Screen Distance monitoring notifications to NotchWindowController
        ScreenDistanceManager.shared.onDistanceAlertTriggered = {
            NotchWindowController.shared.show(alertType: .screenDistance)
        }
        ScreenDistanceManager.shared.onDistanceAlertResolved = {
            if NotchWindowController.shared.currentAlertType == .screenDistance {
                NotchWindowController.shared.dismiss()
            }
        }

        // Setup menu bar controller
        MenuBarController.shared.setup()

        // Support distributed notifications for testing
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.eyebreak.triggerTestAlert"),
            object: nil,
            queue: .main
        ) { _ in
            TimerManager.shared.testAlert()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.eyebreak.triggerDistanceAlert"),
            object: nil,
            queue: .main
        ) { _ in
            ScreenDistanceManager.shared.testDistanceAlert()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.eyebreak.openSettings"),
            object: nil,
            queue: .main
        ) { _ in
            MenuBarController.shared.openSettingsAction()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.eyebreak.toggleNotchDistance"),
            object: nil,
            queue: .main
        ) { _ in
            NotchWindowController.shared.toggleLiveDistanceHUD()
        }

        // Check if launched with debug CLI flags
        if CommandLine.arguments.contains("--test-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                TimerManager.shared.testAlert()
            }
        }
        if CommandLine.arguments.contains("--test-distance-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ScreenDistanceManager.shared.testDistanceAlert()
            }
        }
        if CommandLine.arguments.contains("--show-notch-distance") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotchWindowController.shared.toggleLiveDistanceHUD()
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
