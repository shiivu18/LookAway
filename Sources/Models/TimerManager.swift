import Foundation
import AppKit
import Combine

public enum AppTimerState: Equatable {
    case working
    case breakActive
    case paused
    case idlePaused
    case systemPaused(reason: String)
    
    public var displayText: String {
        switch self {
        case .working: return "Working"
        case .breakActive: return "Eye Break Active"
        case .paused: return "Paused"
        case .idlePaused: return "Paused (Away)"
        case .systemPaused(let reason): return "Paused (\(reason))"
        }
    }
}

public final class TimerManager: ObservableObject {
    public static let shared = TimerManager()

    @Published public private(set) var state: AppTimerState = .working
    @Published public private(set) var timeRemainingWork: Int = 1200 // 20 min
    @Published public private(set) var timeRemainingBreak: Int = 20
    @Published public private(set) var breakTotalDuration: Int = 20
    @Published public private(set) var isPausedManually: Bool = false
    @Published public private(set) var isIdle: Bool = false
    @Published public private(set) var isScreenLocked: Bool = false
    @Published public private(set) var isSleeping: Bool = false

    // Delegates / callbacks for UI synchronization
    public var onShowAlert: ((_ durationSeconds: Int) -> Void)?
    public var onDismissAlert: (() -> Void)?

    private var tickerTimer: Timer?
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.timeRemainingWork = settings.workIntervalSeconds
        self.timeRemainingBreak = settings.breakIntervalSeconds
        self.breakTotalDuration = settings.breakIntervalSeconds

        setupNotificationObservers()
        setupSettingsObservers()
        startTicker()
    }

    deinit {
        tickerTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Setup Observers

    private func setupNotificationObservers() {
        // Sleep & Wake
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Screen Lock & Unlock
        let distCenter = DistributedNotificationCenter.default()
        distCenter.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        distCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    private func setupSettingsObservers() {
        settings.$workIntervalMinutes
            .dropFirst()
            .sink { [weak self] newMinutes in
                guard let self = self else { return }
                if self.state == .working {
                    self.timeRemainingWork = min(self.timeRemainingWork, Int(newMinutes * 60))
                }
            }
            .store(in: &cancellables)

        settings.$breakDurationSeconds
            .dropFirst()
            .sink { [weak self] newSeconds in
                guard let self = self else { return }
                if self.state == .breakActive {
                    self.breakTotalDuration = Int(newSeconds)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Notification Handlers

    @objc private func handleWillSleep() {
        DispatchQueue.main.async {
            self.isSleeping = true
            self.updateState()
        }
    }

    @objc private func handleDidWake() {
        DispatchQueue.main.async {
            self.isSleeping = false
            self.updateState()
        }
    }

    @objc private func handleScreenLocked() {
        DispatchQueue.main.async {
            self.isScreenLocked = true
            self.updateState()
        }
    }

    @objc private func handleScreenUnlocked() {
        DispatchQueue.main.async {
            self.isScreenLocked = false
            self.updateState()
        }
    }

    // MARK: - Ticker Loop

    private func startTicker() {
        tickerTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.tickerTimer = timer
    }

    private func tick() {
        // Check Idle status
        if settings.idlePauseEnabled {
            let currentlyIdle = IdleDetector.isUserIdle(thresholdSeconds: settings.idleThresholdSeconds)
            if currentlyIdle != isIdle {
                isIdle = currentlyIdle
                updateState()
            }
        } else if isIdle {
            isIdle = false
            updateState()
        }

        // If paused by user or system/idle, don't count down
        guard shouldRunTimer() else { return }

        switch state {
        case .working:
            if timeRemainingWork > 0 {
                timeRemainingWork -= 1
            }
            if timeRemainingWork <= 0 {
                triggerBreak()
            }

        case .breakActive:
            if timeRemainingBreak > 0 {
                timeRemainingBreak -= 1
            }
            if timeRemainingBreak <= 0 {
                finishBreak()
            }

        case .paused, .idlePaused, .systemPaused:
            break
        }
    }

    private func shouldRunTimer() -> Bool {
        if isPausedManually { return false }
        if settings.pauseOnSleepAndLock && (isSleeping || isScreenLocked) { return false }
        if settings.idlePauseEnabled && isIdle && state != .breakActive { return false }
        return true
    }

    private func updateState() {
        if isPausedManually {
            state = .paused
            return
        }
        if settings.pauseOnSleepAndLock {
            if isSleeping {
                state = .systemPaused(reason: "Mac Asleep")
                return
            }
            if isScreenLocked {
                state = .systemPaused(reason: "Screen Locked")
                return
            }
        }
        if settings.idlePauseEnabled && isIdle && state != .breakActive {
            state = .idlePaused
            return
        }

        // Active state
        if timeRemainingBreak > 0 && (state == .breakActive || onShowAlert != nil) {
            // Keep breakActive if currently in break
            if state != .breakActive && state != .working {
                state = .breakActive
            }
        } else {
            state = .working
        }
    }

    // MARK: - Actions

    public func triggerBreak(isManual: Bool = false) {
        breakTotalDuration = max(5, settings.breakIntervalSeconds)
        timeRemainingBreak = breakTotalDuration
        state = .breakActive

        SoundManager.shared.playAlertSound()
        onShowAlert?(breakTotalDuration)
    }

    public func finishBreak() {
        SoundManager.shared.playCompletionSound()
        onDismissAlert?()
        resetWorkTimer()
    }

    public func skipBreak() {
        if state == .breakActive {
            onDismissAlert?()
        }
        resetWorkTimer()
    }

    public func resetWorkTimer() {
        timeRemainingWork = max(60, settings.workIntervalSeconds)
        timeRemainingBreak = settings.breakIntervalSeconds
        breakTotalDuration = settings.breakIntervalSeconds
        state = isPausedManually ? .paused : .working
    }

    public func togglePause() {
        isPausedManually.toggle()
        if isPausedManually {
            state = .paused
        } else {
            updateState()
        }
    }

    public func takeBreakNow() {
        triggerBreak(isManual: true)
    }

    public func testAlert() {
        // Debug test: triggers break alert immediately with 20-second countdown
        breakTotalDuration = 20
        timeRemainingBreak = 20
        state = .breakActive
        SoundManager.shared.playAlertSound()
        onShowAlert?(20)
    }

    public var formattedWorkTimeRemaining: String {
        let minutes = timeRemainingWork / 60
        let seconds = timeRemainingWork % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var menuStatusTitle: String {
        switch state {
        case .working:
            return "Next break in \(formattedWorkTimeRemaining)"
        case .breakActive:
            return "Break in progress (\(timeRemainingBreak)s)"
        case .paused:
            return "Paused"
        case .idlePaused:
            return "Paused (Idle away)"
        case .systemPaused(let reason):
            return "Paused (\(reason))"
        }
    }
}
