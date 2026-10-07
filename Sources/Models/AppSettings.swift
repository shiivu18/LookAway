import Foundation
import Combine
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

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
    }

    private let defaults: UserDefaults

    @Published public var workIntervalMinutes: Double {
        didSet { defaults.set(workIntervalMinutes, forKey: Keys.workIntervalMinutes) }
    }

    @Published public var breakDurationSeconds: Double {
        didSet { defaults.set(breakDurationSeconds, forKey: Keys.breakDurationSeconds) }
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
        didSet { defaults.set(idleThresholdMinutes, forKey: Keys.idleThresholdMinutes) }
    }

    @Published public var screenDistanceEnabled: Bool {
        didSet { defaults.set(screenDistanceEnabled, forKey: Keys.screenDistanceEnabled) }
    }

    @Published public var screenDistanceSensitivity: Double {
        didSet {
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
        didSet { defaults.set(screenDistanceWarningSeconds, forKey: Keys.screenDistanceWarningSeconds) }
    }

    @Published public var distanceCalibrationFactor: Double {
        didSet { defaults.set(distanceCalibrationFactor, forKey: Keys.distanceCalibrationFactor) }
    }

    @Published public var targetDistanceThresholdInches: Double {
        didSet { defaults.set(targetDistanceThresholdInches, forKey: Keys.targetDistanceThresholdInches) }
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
            Keys.targetDistanceThresholdInches: 18.0
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

        let savedCal = defaults.double(forKey: Keys.distanceCalibrationFactor)
        self.distanceCalibrationFactor = savedCal > 0.0 ? savedCal : 1.0

        let savedThreshold = defaults.double(forKey: Keys.targetDistanceThresholdInches)
        self.targetDistanceThresholdInches = savedThreshold > 0.0 ? savedThreshold : 18.0

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
