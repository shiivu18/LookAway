import AppKit
import SwiftUI
import Combine

/// A non-activating NSPanel that floats above everything without ever stealing keyboard focus.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }
}

public final class NotchWindowController: NSObject {
    public static let shared = NotchWindowController()

    private var panel: NonActivatingPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var currentMetrics: NotchMetrics?
    private(set) var isVisible: Bool = false
    public private(set) var currentAlertType: NotchAlertType = .eyeBreak

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        observeSettings()
    }

    private func observeSettings() {
        // Geometry settings (Double values)
        Publishers.Merge3(
            settings.$notchWidth,
            settings.$notchContentHeight,
            settings.$notchVerticalOffset
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateLayoutIfVisible()
        }
        .store(in: &cancellables)

        // Scale (Double)
        settings.$notchElementScale
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLayoutIfVisible()
            }
            .store(in: &cancellables)

        // Alignment (String)
        settings.$notchElementAlignment
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLayoutIfVisible()
            }
            .store(in: &cancellables)
    }

    public func updateLayoutIfVisible() {
        guard let panel = self.panel, isVisible else { return }
        let screen = ScreenNotchDetector.targetScreen()
        let metrics = ScreenNotchDetector.metrics(for: screen)
        self.currentMetrics = metrics

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().setFrame(metrics.expandedFrame, display: true)
        }
        self.hostingView?.frame = NSRect(origin: .zero, size: metrics.expandedFrame.size)
    }

    /// Prepares or shows the notch alert window on the display containing the cursor.
    public func show(alertType: NotchAlertType = .eyeBreak, durationSeconds: Int = 20) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAlertType = alertType
            self.displayAlert(alertType: alertType)
        }
    }

    /// Toggles the live distance inspection HUD in the notch.
    public func toggleLiveDistanceHUD() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isVisible && self.currentAlertType == .liveDistanceHUD {
                self.dismiss()
            } else {
                ScreenDistanceManager.shared.setLiveHUDActive(true)
                self.show(alertType: .liveDistanceHUD)
            }
        }
    }

    /// Dismisses the notch alert with a smooth collapse animation back into the notch.
    public func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.currentAlertType == .liveDistanceHUD {
                ScreenDistanceManager.shared.setLiveHUDActive(false)
            }
            self.collapseAndHide()
        }
    }

    // MARK: - Window Management

    private func displayAlert(alertType: NotchAlertType) {
        let screen = ScreenNotchDetector.targetScreen()
        let metrics = ScreenNotchDetector.metrics(for: screen)
        self.currentMetrics = metrics

        let panel: NonActivatingPanel
        if let existing = self.panel {
            panel = existing
        } else {
            // Create panel configured to stay out of the responder chain
            let initialPanel = NonActivatingPanel(
                contentRect: metrics.collapsedFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            initialPanel.isOpaque = false
            initialPanel.backgroundColor = .clear
            initialPanel.hasShadow = false
            // High window level to render over menu bar and full-screen spaces
            initialPanel.level = .screenSaver
            initialPanel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            initialPanel.isMovable = false
            initialPanel.canHide = false
            initialPanel.hidesOnDeactivate = false
            initialPanel.isReleasedWhenClosed = false
            self.panel = initialPanel
            panel = initialPanel
        }

        // Setup or update hosting view
        let alertView = NotchAlertView(
            alertType: alertType,
            timerManager: TimerManager.shared,
            screenDistanceManager: ScreenDistanceManager.shared,
            hasPhysicalNotch: metrics.hasPhysicalNotch,
            notchHeight: metrics.notchHeight,
            notchWidth: metrics.notchWidth,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let newHostingView = NSHostingView(rootView: AnyView(alertView))
        newHostingView.frame = NSRect(origin: .zero, size: metrics.expandedFrame.size)
        panel.contentView = newHostingView
        self.hostingView = newHostingView

        if !isVisible {
            // Start from collapsed frame at notch/top
            panel.setFrame(metrics.collapsedFrame, display: false)
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()

            // Smooth expand animation downward out of the notch
            isVisible = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                // Dynamic spring-like easing curve
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                panel.animator().setFrame(metrics.expandedFrame, display: true)
                panel.animator().alphaValue = 1.0
            }
        } else {
            // Already visible, animate frame to match current screen if changed
            panel.setFrame(metrics.expandedFrame, display: true)
        }
    }

    private func collapseAndHide() {
        guard let panel = self.panel, isVisible else { return }
        isVisible = false

        let metrics = currentMetrics ?? ScreenNotchDetector.metrics(for: panel.screen ?? NSScreen.main ?? NSScreen())

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(metrics.collapsedFrame, display: true)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            // Hide window after collapsing
            guard let self = self, !self.isVisible else { return }
            self.panel?.orderOut(nil)
        })
    }
}
