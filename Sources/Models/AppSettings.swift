import Foundation
import Combine
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Constants {
        static let minWorkIntervalMinutes = 1.0
        static let maxWorkIntervalMinutes = 120.0
        static let minBreakDurationSeconds = 5.0
        static let maxBreakDurationSeconds = 300.0
        static let minIdleThresholdMinutes = 1.0
        static let maxIdleThresholdMinutes = 60.0
        static let minScreenDistanceSensitivity = 0.0
        static let maxScreenDistanceSensitivity = 1.0
        static let minScreenDistanceWarningSeconds = 1.0
        static let maxScreenDistanceWarningSeconds = 30.0
        static let minNotchDisplaySeconds = 1.0
        static let maxNotchDisplaySeconds = 60.0
    }

    private enum Keys {
        static let workIntervalMinutes = "workIntervalMinutes"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let pauseOnSleepAndLock = "pauseOnSleepAndLock"
        static let idlePauseEnabled = "idlePauseEnabled"
        static let idleThresholdMinutes = "idleThresholdMinutes"
        static let screenDistanceEnabled = "screenDistanceEnabled"
        static let screenDistanceSensitivity = "screenDistanceSensitivity"
        static let screenDistanceWarningSeconds = "screenDistanceWarningSeconds"
        static let distanceCalibrationFactor = "distanceCalibrationFactor"
        static let targetDistanceThresholdInches = "targetDistanceThresholdInches"
        static let notchWidth = "notchWidth"
        static let notchContentHeight = "notchContentHeight"
        static let notchElementScale = "notchElementScale"
        static let notchElementAlignment = "notchElementAlignment"
        static let notchVerticalOffset = "notchVerticalOffset"
        static let notchResizeEnabled = "notchResizeEnabled"
        static let notchDisplaySeconds = "notchDisplaySeconds"
    }

    private let defaults: UserDefaults

    @Published public var workIntervalMinutes: Double {
        didSet {
            let sanitized = clamp(workIntervalMinutes, min: Constants.minWorkIntervalMinutes, max: Constants.maxWorkIntervalMinutes)
            if sanitized != workIntervalMinutes {
                workIntervalMinutes = sanitized
                return
            }
            defaults.set(workIntervalMinutes, forKey: Keys.workIntervalMinutes)
        }
    }

    @Published public var breakDurationSeconds: Double {
        didSet {
            let sanitized = clamp(breakDurationSeconds, min: Constants.minBreakDurationSeconds, max: Constants.maxBreakDurationSeconds)
            if sanitized != breakDurationSeconds {
                breakDurationSeconds = sanitized
                return
            }
            defaults.set(breakDurationSeconds, forKey: Keys.breakDurationSeconds)
        }
    }

    @Published public var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @Published public var soundName: String {
        didSet { defaults.set(soundName, forKey: Keys.soundName) }
    }

    @Published public var pauseOnSleepAndLock: Bool {
        didSet { defaults.set(pauseOnSleepAndLock, forKey: Keys.pauseOnSleepAndLock) }
    }

    @Published public var idlePauseEnabled: Bool {
        didSet { defaults.set(idlePauseEnabled, forKey: Keys.idlePauseEnabled) }
    }

    @Published public var idleThresholdMinutes: Double {
        didSet {
            let sanitized = clamp(idleThresholdMinutes, min: Constants.minIdleThresholdMinutes, max: Constants.maxIdleThresholdMinutes)
            if sanitized != idleThresholdMinutes {
                idleThresholdMinutes = sanitized
                return
            }
            defaults.set(idleThresholdMinutes, forKey: Keys.idleThresholdMinutes)
        }
    }

    @Published public var screenDistanceEnabled: Bool {
        didSet { defaults.set(screenDistanceEnabled, forKey: Keys.screenDistanceEnabled) }
    }

    @Published public var screenDistanceSensitivity: Double {
        didSet {
            let sanitized = clamp(screenDistanceSensitivity, min: Constants.minScreenDistanceSensitivity, max: Constants.maxScreenDistanceSensitivity)
            if sanitized != screenDistanceSensitivity {
                screenDistanceSensitivity = sanitized
                return
            }
            defaults.set(screenDistanceSensitivity, forKey: Keys.screenDistanceSensitivity)
            // Sync threshold inches to sensitivity preset
            if screenDistanceSensitivity >= 0.48 {
                targetDistanceThresholdInches = 15.0
            } else if screenDistanceSensitivity <= 0.38 {
                targetDistanceThresholdInches = 20.0
            } else {
                targetDistanceThresholdInches = 18.0
            }
        }
    }

    @Published public var screenDistanceWarningSeconds: Double {
        didSet {
            let sanitized = clamp(screenDistanceWarningSeconds, min: Constants.minScreenDistanceWarningSeconds, max: Constants.maxScreenDistanceWarningSeconds)
            if sanitized != screenDistanceWarningSeconds {
                screenDistanceWarningSeconds = sanitized
                return
            }
            defaults.set(screenDistanceWarningSeconds, forKey: Keys.screenDistanceWarningSeconds)
        }
    }

    @Published public var distanceCalibrationFactor: Double {
        didSet { defaults.set(distanceCalibrationFactor, forKey: Keys.distanceCalibrationFactor) }
    }

    @Published public var targetDistanceThresholdInches: Double {
        didSet { defaults.set(targetDistanceThresholdInches, forKey: Keys.targetDistanceThresholdInches) }
    }

    @Published public var notchWidth: Double {
        didSet { defaults.set(notchWidth, forKey: Keys.notchWidth) }
    }

    @Published public var notchContentHeight: Double {
        didSet { defaults.set(notchContentHeight, forKey: Keys.notchContentHeight) }
    }

    @Published public var notchElementScale: Double {
        didSet { defaults.set(notchElementScale, forKey: Keys.notchElementScale) }
    }

    @Published public var notchElementAlignment: String {
        didSet { defaults.set(notchElementAlignment, forKey: Keys.notchElementAlignment) }
    }

    @Published public var notchVerticalOffset: Double {
        didSet { defaults.set(notchVerticalOffset, forKey: Keys.notchVerticalOffset) }
    }

    @Published public var notchResizeEnabled: Bool {
        didSet { defaults.set(notchResizeEnabled, forKey: Keys.notchResizeEnabled) }
    }

    @Published public var notchDisplaySeconds: Double {
        didSet { defaults.set(notchDisplaySeconds, forKey: Keys.notchDisplaySeconds) }
    }

    @Published public var launchAtLogin: Bool = false

    public var workIntervalSeconds: Int {
        Int(workIntervalMinutes * 60)
    }

    public var breakIntervalSeconds: Int {
        Int(breakDurationSeconds)
    }

    public var idleThresholdSeconds: Double {
        idleThresholdMinutes * 60
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    public func resetNotchAppearance() {
        self.notchWidth = 500.0
        self.notchContentHeight = 74.0
        self.notchElementScale = 1.0
        self.notchElementAlignment = "balanced"
        self.notchVerticalOffset = 0.0
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Register default values
        defaults.register(defaults: [
            Keys.workIntervalMinutes: 20.0,
            Keys.breakDurationSeconds: 20.0,
            Keys.soundEnabled: true,
            Keys.soundName: "Tink",
            Keys.pauseOnSleepAndLock: true,
            Keys.idlePauseEnabled: true,
            Keys.idleThresholdMinutes: 5.0,
            Keys.screenDistanceEnabled: true,
            Keys.screenDistanceSensitivity: 0.42,
            Keys.screenDistanceWarningSeconds: 3.0,
            Keys.distanceCalibrationFactor: 1.0,
            Keys.targetDistanceThresholdInches: 18.0,
            Keys.notchWidth: 500.0,
            Keys.notchContentHeight: 74.0,
            Keys.notchElementScale: 1.0,
            Keys.notchElementAlignment: "balanced",
            Keys.notchVerticalOffset: 0.0,
            Keys.notchResizeEnabled: true,
            Keys.notchDisplaySeconds: 5.0
        ])

        self.workIntervalMinutes = defaults.double(forKey: Keys.workIntervalMinutes)
        self.breakDurationSeconds = defaults.double(forKey: Keys.breakDurationSeconds)
        self.soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        self.soundName = defaults.string(forKey: Keys.soundName) ?? "Tink"
        self.pauseOnSleepAndLock = defaults.bool(forKey: Keys.pauseOnSleepAndLock)
        self.idlePauseEnabled = defaults.bool(forKey: Keys.idlePauseEnabled)
        self.idleThresholdMinutes = defaults.double(forKey: Keys.idleThresholdMinutes)
        self.screenDistanceEnabled = defaults.bool(forKey: Keys.screenDistanceEnabled)
        self.screenDistanceSensitivity = defaults.double(forKey: Keys.screenDistanceSensitivity)
        self.screenDistanceWarningSeconds = defaults.double(forKey: Keys.screenDistanceWarningSeconds)
        self.distanceCalibrationFactor = defaults.double(forKey: Keys.distanceCalibrationFactor) > 0.0 ? defaults.double(forKey: Keys.distanceCalibrationFactor) : 1.0
        self.targetDistanceThresholdInches = defaults.double(forKey: Keys.targetDistanceThresholdInches) > 0.0 ? defaults.double(forKey: Keys.targetDistanceThresholdInches) : 18.0
        self.notchWidth = defaults.double(forKey: Keys.notchWidth) > 0.0 ? defaults.double(forKey: Keys.notchWidth) : 500.0
        self.notchContentHeight = defaults.double(forKey: Keys.notchContentHeight) > 0.0 ? defaults.double(forKey: Keys.notchContentHeight) : 74.0
        self.notchElementScale = defaults.double(forKey: Keys.notchElementScale) > 0.0 ? defaults.double(forKey: Keys.notchElementScale) : 1.0
        self.notchElementAlignment = (defaults.string(forKey: Keys.notchElementAlignment) ?? "").isEmpty ? "balanced" : defaults.string(forKey: Keys.notchElementAlignment)!
        self.notchVerticalOffset = defaults.double(forKey: Keys.notchVerticalOffset)
        self.notchResizeEnabled = defaults.bool(forKey: Keys.notchResizeEnabled)
        self.notchDisplaySeconds = defaults.double(forKey: Keys.notchDisplaySeconds) > 0.0 ? defaults.double(forKey: Keys.notchDisplaySeconds) : 5.0
        checkLaunchAtLoginStatus()
    }

    public func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                self.launchAtLogin = SMAppService.mainApp.status == .enabled
            } catch {
                print("Failed to update SMAppService launchAtLogin: \(error.localizedDescription)")
                self.launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
