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
                    Text("EyeBreak Settings")
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
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Warn when sitting too close to the screen", isOn: $settings.screenDistanceEnabled)

                            Text("Uses on-device Vision face detection to check when you're leaning closer than an arm's length (~20 inches / 50 cm). Frames are processed in-memory and never stored.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if settings.screenDistanceEnabled {
                                Divider()

                                // Sensitivity Slider & Presets
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Alert Sensitivity:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(sensitivityDescription(settings.screenDistanceSensitivity))
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                    }

                                    Slider(value: $settings.screenDistanceSensitivity, in: 0.30...0.55, step: 0.02)

                                    HStack(spacing: 8) {
                                        Button("Relaxed") {
                                            settings.screenDistanceSensitivity = 0.50
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.screenDistanceSensitivity == 0.50 ? .accentColor : nil)

                                        Button("Normal") {
                                            settings.screenDistanceSensitivity = 0.42
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.screenDistanceSensitivity == 0.42 ? .accentColor : nil)

                                        Button("Strict") {
                                            settings.screenDistanceSensitivity = 0.35
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(settings.screenDistanceSensitivity == 0.35 ? .accentColor : nil)
                                    }
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
                                        Label("Test Screen Distance Alert", systemImage: "exclamationmark.triangle")
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
