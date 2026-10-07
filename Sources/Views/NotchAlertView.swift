import SwiftUI

public enum NotchAlertType: Equatable {
    case eyeBreak
    case screenDistance
    case liveDistanceHUD

    public var isDistanceType: Bool {
        self == .screenDistance || self == .liveDistanceHUD
    }
}

public final class NotchAlertViewModel: ObservableObject {
    @Published public var isPulsing: Bool = false
    @Published public var isHoveringAction: Bool = false

    public init() {}
}

public struct NotchShape: Shape {
    public var bottomRadius: CGFloat = 22.0
    public var topRadius: CGFloat = 0.0

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let bR = min(bottomRadius, rect.height / 2, rect.width / 2)
        let tR = min(topRadius, rect.height / 2, rect.width / 2)

        // Top-left
        if tR > 0 {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + tR))
            path.addQuadCurve(to: CGPoint(x: rect.minX + tR, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        // Top-right
        if tR > 0 {
            path.addLine(to: CGPoint(x: rect.maxX - tR, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tR),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        // Bottom-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bR))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bR, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))

        // Bottom-left
        path.addLine(to: CGPoint(x: rect.minX + bR, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + bR, y: rect.maxY - bR),
                          control: CGPoint(x: rect.minX, y: rect.maxY))

        path.closeSubpath()
        return path
    }
}

public struct NotchAlertView: View {
    public var alertType: NotchAlertType
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var screenDistanceManager: ScreenDistanceManager
    public var hasPhysicalNotch: Bool
    public var notchHeight: CGFloat
    public var notchWidth: CGFloat
    public var onDismiss: () -> Void

    @ObservedObject private var viewModel: NotchAlertViewModel

    public init(
        alertType: NotchAlertType = .eyeBreak,
        timerManager: TimerManager = .shared,
        screenDistanceManager: ScreenDistanceManager = .shared,
        hasPhysicalNotch: Bool = true,
        notchHeight: CGFloat = 32.0,
        notchWidth: CGFloat = 179.0,
        viewModel: NotchAlertViewModel = NotchAlertViewModel(),
        onDismiss: @escaping () -> Void = {}
    ) {
        self.alertType = alertType
        self.timerManager = timerManager
        self.screenDistanceManager = screenDistanceManager
        self.hasPhysicalNotch = hasPhysicalNotch
        self.notchHeight = notchHeight
        self.notchWidth = notchWidth
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    private var breakProgress: Double {
        let total = max(1, Double(timerManager.breakTotalDuration))
        let remaining = Double(timerManager.timeRemainingBreak)
        return min(max(remaining / total, 0.0), 1.0)
    }

    private var distanceThemeColor: Color {
        guard screenDistanceManager.hasDetectedFace else {
            return Color.white.opacity(0.5)
        }
        switch screenDistanceManager.distanceZone {
        case .tooClose:
            return Color.orange
        case .caution:
            return Color.yellow
        case .safe:
            return Color.green
        case .far:
            return Color.cyan
        case .unknown:
            return Color.white.opacity(0.5)
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Background with notch curve & ultra-deep OLED black
            NotchShape(
                bottomRadius: 26,
                topRadius: hasPhysicalNotch ? 0 : 8
            )
            .fill(Color.black)
            .overlay(
                NotchShape(
                    bottomRadius: 26,
                    topRadius: hasPhysicalNotch ? 0 : 8
                )
                .stroke(
                    LinearGradient(
                        colors: alertType.isDistanceType ? [
                            distanceThemeColor.opacity(0.65),
                            distanceThemeColor.opacity(0.30),
                            Color.white.opacity(0.12)
                        ] : [
                            Color.white.opacity(0.12),
                            Color.teal.opacity(0.40),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color: alertType.isDistanceType
                    ? distanceThemeColor.opacity(0.40)
                    : Color.teal.opacity(0.35),
                radius: 14,
                x: 0,
                y: 6
            )

            // Content container strictly cleared below the hardware camera and microphone
            VStack(spacing: 0) {
                if hasPhysicalNotch {
                    // Physical Camera & Microphone Cutout Zone:
                    // Reserved transparent spacer so no UI element is ever obscured by the hardware bezel
                    Color.clear
                        .frame(height: notchHeight)
                }

                // Interactive UI Area — 100% visible on screen below the camera and mic
                HStack(spacing: 14) {
                // Left Icon: Animated Glowing Symbol
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (alertType.isDistanceType
                                     ? distanceThemeColor
                                     : Color.teal).opacity(0.35),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 22
                            )
                        )
                        .scaleEffect(viewModel.isPulsing ? 1.22 : 0.95)
                        .frame(width: 44, height: 44)

                    Image(systemName: leftIconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: alertType.isDistanceType
                                    ? [distanceThemeColor, distanceThemeColor.opacity(0.8)]
                                    : [Color.teal, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: (alertType.isDistanceType
                                    ? distanceThemeColor
                                    : Color.teal).opacity(0.8),
                            radius: 6,
                            x: 0,
                            y: 0
                        )
                }
                .padding(.leading, 16)

                // Middle Content
                if alertType.isDistanceType {
                    distanceContentView
                } else {
                    eyeBreakContentView
                }

                Spacer(minLength: 4)

                // Right Side Controls
                HStack(spacing: 10) {
                    if alertType.isDistanceType {
                        // Digital badge readout
                        VStack(spacing: 1) {
                            if screenDistanceManager.hasDetectedFace {
                                Text("\(screenDistanceManager.displayDistanceInches)\"")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(distanceThemeColor)
                                    .monospacedDigit()

                                Text(badgeStatusText)
                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                    .foregroundColor(distanceThemeColor)
                            } else {
                                Text("--\"")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(white: 0.5))

                                Text("WAITING")
                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(distanceThemeColor.opacity(0.16))
                        )

                        // Close / Dismiss button
                        Button(action: {
                            if alertType == .screenDistance {
                                screenDistanceManager.dismissAlertManually()
                            }
                            onDismiss()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text(alertType == .liveDistanceHUD ? "Close" : "Dismiss")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(viewModel.isHoveringAction ? .white : Color(white: 0.72))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(viewModel.isHoveringAction ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            viewModel.isHoveringAction = hovering
                        }
                        .padding(.trailing, 16)
                    } else {
                        // EyeBreak Countdown Ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 3.5)

                            Circle()
                                .trim(from: 0.0, to: CGFloat(breakProgress))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.teal, Color.mint, Color.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1.0), value: breakProgress)

                            Text("\(timerManager.timeRemainingBreak)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .frame(width: 34, height: 34)

                        // Skip button
                        Button(action: {
                            timerManager.skipBreak()
                            onDismiss()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Skip")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(viewModel.isHoveringAction ? .white : Color(white: 0.7))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(viewModel.isHoveringAction ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            viewModel.isHoveringAction = hovering
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, hasPhysicalNotch ? 4 : 8)
            .padding(.bottom, hasPhysicalNotch ? 8 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                viewModel.isPulsing = true
            }
        }
    }
}

    // MARK: - Subviews

    private var distanceContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with live distance readouts
            HStack(spacing: 6) {
                if screenDistanceManager.hasDetectedFace {
                    Text(titleText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(screenDistanceManager.displayDistanceInches)\"")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(distanceThemeColor)
                        .monospacedDigit()

                    Text("(\(screenDistanceManager.displayDistanceCm) cm)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.65))

                    Text(targetStatusText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(distanceThemeColor)
                } else {
                    Text("👤 Looking for Person")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("• Center yourself in notch view")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.65))
                }
            }

            // Calibrated Distance Meter Bar with Live Position Indicator
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track with colored ergonomic zones
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 6)

                            // Segmented gradient track: Red (<16") -> Yellow/Orange (16-20") -> Green (20-30") -> Cyan (30"+)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.red.opacity(0.85), location: 0.0),
                                            .init(color: Color.orange, location: 0.25),
                                            .init(color: Color.yellow, location: 0.38),
                                            .init(color: Color.green, location: 0.50),
                                            .init(color: Color.mint, location: 0.75),
                                            .init(color: Color.cyan, location: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 6)
                                .opacity(0.85)
                        }

                        // Target reference marker at 20 inches: (20 - 10) / (34 - 10) = 41.7%
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 11)
                            .offset(x: geo.size.width * 0.417 - 1, y: -2.5)
                            .shadow(color: .white.opacity(0.8), radius: 2)

                        // Live Glowing Position Indicator Needle / Puck
                        if screenDistanceManager.hasDetectedFace {
                            let puckX = max(4, min(geo.size.width - 12, geo.size.width * CGFloat(screenDistanceManager.distanceProgressRatio) - 5))
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(distanceThemeColor, lineWidth: 2)
                                )
                                .shadow(color: distanceThemeColor.opacity(0.9), radius: 5)
                                .offset(x: puckX, y: -2)
                                .animation(.spring(response: 0.26, dampingFraction: 0.82), value: screenDistanceManager.distanceProgressRatio)
                        }
                    }
                }
                .frame(height: 8)

                // Gauge scale markings
                HStack {
                    Text("10\" (Too Close)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color(white: 0.5))

                    Spacer()

                    Text("20\" Target (Arm's Length)")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)

                    Spacer()

                    Text("34\"+ (Safe)")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                }
            }
        }
    }

    private var eyeBreakContentView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("Look 20 feet away")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("• 20-20-20")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.teal.opacity(0.9))
            }

            Text("Rest your eyes on a distant object or horizon")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(Color(white: 0.72))
                .lineLimit(1)
        }
    }

    // MARK: - Text Helpers

    private var leftIconName: String {
        if alertType == .eyeBreak {
            return "eye.fill"
        }
        guard screenDistanceManager.hasDetectedFace else {
            return "viewfinder"
        }
        switch screenDistanceManager.distanceZone {
        case .tooClose:
            return "person.fill.viewfinder"
        case .caution:
            return "exclamationmark.circle.fill"
        case .safe:
            return "checkmark.circle.fill"
        case .far:
            return "person.fill.checkmark"
        case .unknown:
            return "viewfinder"
        }
    }

    private var titleText: String {
        if alertType == .liveDistanceHUD {
            return screenDistanceManager.isTooClose ? "⚠️ Sitting Too Close:" : "📏 Person Distance:"
        } else {
            return screenDistanceManager.isTooClose ? "⚠️ Sit Back:" : "✅ Safe Distance:"
        }
    }

    private var targetStatusText: String {
        switch screenDistanceManager.distanceZone {
        case .tooClose:
            return "• Target: 20\"+"
        case .caution:
            return "• Lean Back Slightly"
        case .safe:
            return "• Optimal Posture 👍"
        case .far:
            return "• Relaxed Distance"
        case .unknown:
            return ""
        }
    }

    private var badgeStatusText: String {
        switch screenDistanceManager.distanceZone {
        case .tooClose:
            return "TOO NEAR"
        case .caution:
            return "CAUTION"
        case .safe:
            return "SAFE ✓"
        case .far:
            return "FAR"
        case .unknown:
            return "SEARCHING"
        }
    }
}
