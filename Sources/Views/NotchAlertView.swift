import SwiftUI

public enum NotchAlertType: Equatable {
    case eyeBreak
    case screenDistance
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
    public var onDismiss: () -> Void

    @ObservedObject private var viewModel: NotchAlertViewModel

    public init(
        alertType: NotchAlertType = .eyeBreak,
        timerManager: TimerManager = .shared,
        screenDistanceManager: ScreenDistanceManager = .shared,
        hasPhysicalNotch: Bool = true,
        viewModel: NotchAlertViewModel = NotchAlertViewModel(),
        onDismiss: @escaping () -> Void = {}
    ) {
        self.alertType = alertType
        self.timerManager = timerManager
        self.screenDistanceManager = screenDistanceManager
        self.hasPhysicalNotch = hasPhysicalNotch
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    private var breakProgress: Double {
        let total = max(1, Double(timerManager.breakTotalDuration))
        let remaining = Double(timerManager.timeRemainingBreak)
        return min(max(remaining / total, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Background with notch curve & ultra-deep OLED black
            NotchShape(
                bottomRadius: 24,
                topRadius: hasPhysicalNotch ? 0 : 6
            )
            .fill(Color.black)
            .overlay(
                NotchShape(
                    bottomRadius: 24,
                    topRadius: hasPhysicalNotch ? 0 : 6
                )
                .stroke(
                    LinearGradient(
                        colors: alertType == .screenDistance ? (
                            screenDistanceManager.isTooClose
                            ? [Color.orange.opacity(0.55), Color.red.opacity(0.35), Color.white.opacity(0.12)]
                            : [Color.green.opacity(0.55), Color.mint.opacity(0.35), Color.white.opacity(0.12)]
                        ) : [
                            Color.white.opacity(0.12),
                            Color.teal.opacity(0.25),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color: alertType == .screenDistance
                    ? (screenDistanceManager.isTooClose ? Color.orange.opacity(0.4) : Color.green.opacity(0.35))
                    : Color.black.opacity(0.65),
                radius: 14,
                x: 0,
                y: 6
            )

            // Content container
            HStack(spacing: 14) {
                // Left Icon: Animated Glowing Symbol
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (alertType == .screenDistance
                                     ? (screenDistanceManager.isTooClose ? Color.orange : Color.green)
                                     : Color.teal).opacity(0.35),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 22
                            )
                        )
                        .scaleEffect(viewModel.isPulsing ? 1.25 : 0.95)
                        .frame(width: 44, height: 44)

                    Image(systemName: alertType == .screenDistance
                          ? (screenDistanceManager.isTooClose ? "person.fill.viewfinder" : "checkmark.circle.fill")
                          : "eye.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: alertType == .screenDistance
                                    ? (screenDistanceManager.isTooClose ? [Color.orange, Color.yellow] : [Color.green, Color.mint])
                                    : [Color.teal, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: (alertType == .screenDistance
                                    ? (screenDistanceManager.isTooClose ? Color.orange : Color.green)
                                    : Color.teal).opacity(0.8),
                            radius: 6,
                            x: 0,
                            y: 0
                        )
                }
                .padding(.leading, 16)

                // Middle Content
                if alertType == .screenDistance {
                    // Real-time Screen Distance View with Live Distance Meter
                    VStack(alignment: .leading, spacing: 4) {
                        // Title with live numbers
                        HStack(spacing: 6) {
                            Text(screenDistanceManager.isTooClose ? "Sit Back:" : "Safe Distance:")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("\(screenDistanceManager.displayDistanceInches)\"")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)
                                .monospacedDigit()

                            Text("(\(screenDistanceManager.displayDistanceCm) cm)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.65))

                            Text(screenDistanceManager.isTooClose ? "• Target: 20\"+" : "• Perfect 👍")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(screenDistanceManager.isTooClose ? .orange.opacity(0.9) : .green)
                        }

                        // Live Real-Time Distance Meter Bar
                        VStack(spacing: 3) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 6)

                                    // Dynamic filled track
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.red,
                                                    Color.orange,
                                                    Color.yellow,
                                                    Color.green
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: max(8, geo.size.width * CGFloat(screenDistanceManager.distanceProgressRatio)),
                                            height: 6
                                        )
                                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: screenDistanceManager.distanceProgressRatio)

                                    // Target marker at 20 inches (~75% of 8"->24" range)
                                    Rectangle()
                                        .fill(Color.white.opacity(0.7))
                                        .frame(width: 2, height: 10)
                                        .offset(x: geo.size.width * 0.75 - 1, y: -2)
                                }
                            }
                            .frame(height: 8)

                            // Gauge scale labels
                            HStack {
                                Text("8\" (Too Close)")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))

                                Spacer()

                                Text("Arm's Length (20\"+)")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)

                                Spacer()

                                Text("24\"+ (Safe)")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                    }
                } else {
                    // EyeBreak 20-20-20 View
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

                Spacer(minLength: 4)

                // Right Side Controls
                HStack(spacing: 10) {
                    if alertType == .screenDistance {
                        // Digital badge readout
                        VStack(spacing: 1) {
                            Text("\(screenDistanceManager.displayDistanceInches)\"")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)
                                .monospacedDigit()

                            Text(screenDistanceManager.isTooClose ? "TOO NEAR" : "SAFE ✓")
                                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                .foregroundColor(screenDistanceManager.isTooClose ? .orange : .green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill((screenDistanceManager.isTooClose ? Color.orange : Color.green).opacity(0.16))
                        )

                        // Dismiss button
                        Button(action: {
                            screenDistanceManager.dismissAlertManually()
                            onDismiss()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Dismiss")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(viewModel.isHoveringAction ? .white : Color(white: 0.7))
                            .padding(.horizontal, 8)
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
            .padding(.top, hasPhysicalNotch ? 6 : 2)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                viewModel.isPulsing = true
            }
        }
    }
}
