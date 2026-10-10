import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var timerManager: TimerManager = .shared
    @ObservedObject var screenDistanceManager: ScreenDistanceManager = .shared

    public init() {}

    private func sensitivityDescription(_ value: Double) -> String {
        if value >= 0.48 {
            return "Relaxed (~10-12 inches)"
        } else if value <= 0.38 {
            return "Strict (~16-18 inches)"
        } else {
            return "Normal (~12-14 inches)"
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "eye.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LookAway Settings")
                        .font(.system(size: 16, weight: .bold))
                    Text("20-20-20 Rule & Screen Distance Guardian")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form Content
            ScrollView {
                VStack(spacing: 20) {
                    // Screen Distance Section (Stay Far from Screen)
                    GroupBox(label: Label("Screen Distance (Stay Far from Screen)", systemImage: "person.fill.viewfinder")) {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Warn when sitting too close to the screen", isOn: $settings.screenDistanceEnabled)

                            Text("Uses on-device Vision facial landmark tracking (Interpupillary Distance) and camera optics to accurately measure the distance to the person sitting at the screen. Frames are processed locally in-memory and never saved.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if settings.screenDistanceEnabled {
                                Divider()

                                // Live Real-Time Distance Monitor Card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Live Distance Monitor:")
                                            .font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                        if screenDistanceManager.hasDetectedFace {
                                            HStack(spacing: 4) {
                                                Circle().fill(screenDistanceManager.isTooClose ? Color.orange : Color.green).frame(width: 7, height: 7)
                                                Text(screenDistanceManager.distanceZone.title)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)
                                            }
                                        } else {
                                            Text("Waiting for person...")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        // Number badge
                                        VStack(alignment: .leading, spacing: 1) {
                                            if screenDistanceManager.hasDetectedFace {
                                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                                    Text("\(screenDistanceManager.displayDistanceInches)\"")
                                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                                        .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)
                                                        .monospacedDigit()
                                                    Text("(\(screenDistanceManager.displayDistanceCm) cm)")
                                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                                        .foregroundColor(.secondary)
                                                }
                                            } else {
                                                Text("--\"")
                                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        // Toggle Notch HUD Button
                                        Button(action: {
                                            NotchWindowController.shared.toggleLiveDistanceHUD()
                                        }) {
                                            Label("Show in Notch", systemImage: "macwindow.badge.plus")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .tint(.accentColor)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                                }

                                Divider()

                                // Sensitivity / Alert Threshold
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Alert Threshold:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(settings.targetDistanceThresholdInches))\" (\(Int(settings.targetDistanceThresholdInches * 2.54)) cm)")
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                    }

                                    Slider(value: $settings.targetDistanceThresholdInches, in: 14.0...22.0, step: 1.0)

                                    HStack(spacing: 8) {
                                        Button("Relaxed (15\")") {
                                            settings.targetDistanceThresholdInches = 15.0
                                            settings.screenDistanceSensitivity = 0.50
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.targetDistanceThresholdInches == 15.0 ? .accentColor : nil)

                                        Button("Normal (18\")") {
                                            settings.targetDistanceThresholdInches = 18.0
                                            settings.screenDistanceSensitivity = 0.42
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.targetDistanceThresholdInches == 18.0 ? .accentColor : nil)

                                        Button("Strict (20\")") {
                                            settings.targetDistanceThresholdInches = 20.0
                                            settings.screenDistanceSensitivity = 0.35
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.targetDistanceThresholdInches == 20.0 ? .accentColor : nil)
                                    }
                                }

                                Divider()

                                // Calibration Fine-Tuning Slider
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Distance Calibration:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(String(format: "%.0f%%", settings.distanceCalibrationFactor * 100))
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                        if abs(settings.distanceCalibrationFactor - 1.0) > 0.01 {
                                            Button("Reset") {
                                                settings.distanceCalibrationFactor = 1.0
                                            }
                                            .buttonStyle(.plain)
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                        }
                                    }

                                    Slider(value: $settings.distanceCalibrationFactor, in: 0.80...1.25, step: 0.02)

                                    Text("Fine-tune if your camera lens angle or sitting posture reads differently.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
            // Notch Appearance Adjuster
            GroupBox(label: Label("Notch Appearance", systemImage: "rectangle.portrait.bottomright.inset.filled")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Width Slider
                    HStack {
                        Text("Notch Width:")
                        Spacer()
                        Text("\(Int(settings.notchWidth))")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.notchWidth, in: 300...800, step: 1)

                    // Height Slider
                    HStack {
                        Text("Notch Content Height:")
                        Spacer()
                        Text("\(Int(settings.notchContentHeight))")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.notchContentHeight, in: 40...150, step: 1)

                    // Scale Slider
                    HStack {
                        Text("Element Scale:")
                        Spacer()
                        Text(String(format: "%.2f", settings.notchElementScale))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.notchElementScale, in: 0.5...2.0, step: 0.01)

                    // Vertical Offset Slider
                    HStack {
                        Text("Vertical Offset:")
                        Spacer()
                        Text(String(format: "%.0f", settings.notchVerticalOffset))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.notchVerticalOffset, in: -30...30, step: 1)

                    // Alignment Picker
                    Picker("Alignment:", selection: $settings.notchElementAlignment) {
                        Text("Centered").tag("center")
                        Text("Leading").tag("leading")
                        Text("Trailing").tag("trailing")
                        Text("Balanced").tag("balanced")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(10)
            }
                                Divider()

                                // Camera Status Row
                                HStack {
                                    Text("Camera Status:")
                                    Spacer()
                                    switch screenDistanceManager.permissionStatus {
                                     case .authorized:
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.green).frame(width: 8, height: 8)
                                            Text(screenDistanceManager.isMonitoring ? "Active & Monitoring" : "Ready")
                                                .foregroundColor(.green)
                                                .font(.subheadline)
                                        }
                                    case .notDetermined:
                                        Button("Grant Camera Access") {
                                            screenDistanceManager.requestCameraPermission { _ in }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    case .denied, .restricted:
                                        Text("Denied in System Settings")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }

                                Divider()

                                // Preview Screen Distance Alert
                                HStack {
                                    Text("Preview Alert:")
                                        .font(.subheadline)
                                    Spacer()
                                    Button(action: {
                                        screenDistanceManager.testDistanceAlert()
                                    }) {
                                        Label("Test Alert in Notch", systemImage: "exclamationmark.triangle")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(10)
                    }

                    // Timer Intervals Section
                    GroupBox(label: Label("Timers & Intervals", systemImage: "timer")) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Work interval
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Work Interval:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(settings.workIntervalMinutes)) minutes")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Slider(value: $settings.workIntervalMinutes, in: 1...60, step: 1)

                                HStack(spacing: 8) {
                                    ForEach([10, 15, 20, 30, 45], id: \.self) { mins in
                                        Button("\(mins)m") {
                                            settings.workIntervalMinutes = Double(mins)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.workIntervalMinutes == Double(mins) ? .accentColor : nil)
                                    }
                                }
                            }

                            Divider()

                            // Break duration
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Break Duration:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(settings.breakDurationSeconds)) seconds")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Slider(value: $settings.breakDurationSeconds, in: 5...60, step: 1)

                                HStack(spacing: 8) {
                                    ForEach([10, 15, 20, 30], id: \.self) { secs in
                                        Button("\(secs)s") {
                                            settings.breakDurationSeconds = Double(secs)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.breakDurationSeconds == Double(secs) ? .accentColor : nil)
                                    }
                                }
                            }
                        }
                        .padding(10)
                    }

                    // Smart Pausing Section
                    GroupBox(label: Label("Smart Pausing", systemImage: "moon.stars")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Pause when Mac sleeps or screen locks", isOn: $settings.pauseOnSleepAndLock)

                            Toggle("Pause when system is idle", isOn: $settings.idlePauseEnabled)

                            if settings.idlePauseEnabled {
                                HStack {
                                    Text("Idle threshold:")
                                    Spacer()
                                    Stepper(
                                        "\(Int(settings.idleThresholdMinutes)) min",
                                        value: $settings.idleThresholdMinutes,
                                        in: 1...30,
                                        step: 1
                                    )
                                }
                                .padding(.leading, 18)
                            }
                        }
                        .padding(10)
                    }

                    // Sound & Feedback Section
                    GroupBox(label: Label("Audio Chimes", systemImage: "speaker.wave.2")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Play sound at start & end of break", isOn: $settings.soundEnabled)

                            if settings.soundEnabled {
                                HStack {
                                    Picker("Alert Sound:", selection: $settings.soundName) {
                                        ForEach(SoundManager.availableSounds, id: \.self) { sound in
                                            Text(sound).tag(sound)
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    Button(action: {
                                        SoundManager.shared.playAlertSound(named: settings.soundName)
                                    }) {
                                        Label("Preview", systemImage: "play.circle")
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(10)
                    }

                    // System Section
                    GroupBox(label: Label("System & Testing", systemImage: "gearshape")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Launch at Login", isOn: Binding(
                                get: { settings.launchAtLogin },
                                set: { settings.setLaunchAtLogin($0) }
                            ))

                            Divider()

                            HStack {
                                Text("Test 20-20-20 Break Alert:")
                                    .font(.subheadline)
                                Spacer()
                                Button(action: {
                                    timerManager.testAlert()
                                }) {
                                    Label("Test Break Alert", systemImage: "sparkles")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                            }
                        }
                        .padding(10)
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 480, height: 640)
        .onAppear {
            settings.checkLaunchAtLoginStatus()
            screenDistanceManager.updatePermissionStatus()
        }
    }
}
