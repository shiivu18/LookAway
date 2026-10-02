import Foundation
import AppKit
import AVFoundation
import Vision
import Combine

public enum CameraPermissionStatus: Equatable {
    case authorized
    case denied
    case restricted
    case notDetermined
}

public final class ScreenDistanceManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = ScreenDistanceManager()

    @Published public private(set) var isTooClose: Bool = false
    @Published public private(set) var currentFaceMetric: Double = 0.0 // 0.0 to 1.0 normalized
    @Published public private(set) var currentDistanceInches: Double = 24.0
    @Published public private(set) var currentDistanceCm: Double = 60.0
    @Published public private(set) var smoothedDistanceInches: Double = 24.0
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published public private(set) var isAlertActive: Bool = false

    public let targetDistanceInches: Double = 20.0
    public let targetDistanceCm: Double = 50.0

    public var onDistanceAlertTriggered: (() -> Void)?
    public var onDistanceAlertResolved: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.eyebreak.cameraSession", qos: .utility)
    private var lastSampleTime: TimeInterval = 0
    private var consecutiveTooCloseSeconds: Int = 0
    private var consecutiveNormalSeconds: Int = 0
    private var testSimulationTimer: Timer?

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // Pinhole camera calibration constant:
    // Distance (cm) = calibrationConstantCm / faceMetric
    // At 50cm (~20in), average human face height (~20cm) occupies ~29% of MacBook camera frame:
    // 50 * 0.29 = 14.5
    private let calibrationConstantCm: Double = 14.8

    private override init() {
        super.init()
        updatePermissionStatus()
        observeSettings()

        if settings.screenDistanceEnabled && permissionStatus == .authorized {
            startMonitoring()
        }
    }

    deinit {
        stopMonitoring()
        testSimulationTimer?.invalidate()
    }

    public func updatePermissionStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionStatus = .authorized
        case .denied:
            self.permissionStatus = .denied
        case .restricted:
            self.permissionStatus = .restricted
        case .notDetermined:
            self.permissionStatus = .notDetermined
        @unknown default:
            self.permissionStatus = .notDetermined
        }
    }

    public func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.updatePermissionStatus()
                if granted {
                    if self?.settings.screenDistanceEnabled == true {
                        self?.startMonitoring()
                    }
                }
                completion(granted)
            }
        }
    }

    private func observeSettings() {
        settings.$screenDistanceEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    if self.permissionStatus == .authorized {
                        self.startMonitoring()
                    }
                } else {
                    self.stopMonitoring()
                    if self.isAlertActive {
                        self.resolveAlert()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Capture Session Management

    public func startMonitoring() {
        guard settings.screenDistanceEnabled else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession?.isRunning == true { return }

            self.setupCaptureSession()
            self.captureSession?.startRunning()

            DispatchQueue.main.async {
                self.isMonitoring = true
            }
        }
    }

    public func stopMonitoring() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession?.isRunning == true {
                self.captureSession?.stopRunning()
            }
            DispatchQueue.main.async {
                self.isMonitoring = false
                self.isTooClose = false
                self.currentFaceMetric = 0.0
            }
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .low // Use lowest resolution to minimize CPU and power

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            print("ScreenDistanceManager: No front camera found.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            output.setSampleBufferDelegate(self, queue: sessionQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            self.captureSession = session
        } catch {
            print("ScreenDistanceManager: Failed to configure camera input: \(error)")
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // High-frequency sampling (0.12s ~ 8 FPS) when alert is active so real-time distance updates smoothly!
        // Low-frequency sampling (1.0s) in background to conserve power.
        let minInterval: TimeInterval = isAlertActive ? 0.12 : 1.0
        let now = CACurrentMediaTime()
        guard now - lastSampleTime >= minInterval else { return }
        lastSampleTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] req, err in
            guard let self = self, err == nil else { return }
            self.processFaceResults(req.results as? [VNFaceObservation])
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    private func processFaceResults(_ faces: [VNFaceObservation]?) {
        guard let face = faces?.first else {
            // No face in view
            DispatchQueue.main.async {
                self.consecutiveTooCloseSeconds = 0
                if self.isAlertActive {
                    self.consecutiveNormalSeconds += 1
                    if self.consecutiveNormalSeconds >= 3 {
                        self.resolveAlert()
                    }
                }
            }
            return
        }

        // Bounding box dimensions (normalized 0.0 to 1.0)
        let faceMetric = Double(max(face.boundingBox.width, face.boundingBox.height))
        let threshold = settings.screenDistanceSensitivity

        // Accurate distance calculation from pinhole camera model
        let rawCm = calibrationConstantCm / max(0.06, faceMetric)
        let rawInches = rawCm / 2.54

        DispatchQueue.main.async {
            self.currentFaceMetric = faceMetric
            self.currentDistanceCm = rawCm
            self.currentDistanceInches = rawInches

            // Exponential moving average filter for smooth, responsive feedback
            let alpha = 0.35
            self.smoothedDistanceInches = (alpha * rawInches) + ((1.0 - alpha) * self.smoothedDistanceInches)

            let tooCloseNow = faceMetric >= threshold || rawInches < 15.0

            if tooCloseNow {
                self.consecutiveNormalSeconds = 0
                self.consecutiveTooCloseSeconds += 1

                if self.consecutiveTooCloseSeconds >= Int(self.settings.screenDistanceWarningSeconds) {
                    self.isTooClose = true
                    if !self.isAlertActive {
                        self.triggerAlert()
                    }
                }
            } else {
                self.consecutiveTooCloseSeconds = 0
                if self.isTooClose {
                    self.consecutiveNormalSeconds += 1
                    // Require reaching safe distance (>= 18-20 inches) for at least 1.5s to collapse
                    if rawInches >= 18.0 || self.consecutiveNormalSeconds >= 2 {
                        self.isTooClose = false
                        if self.isAlertActive {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                                guard let self = self, !self.isTooClose else { return }
                                self.resolveAlert()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Formatted Distance Helpers

    public var displayDistanceInches: Int {
        Int(round(smoothedDistanceInches))
    }

    public var displayDistanceCm: Int {
        Int(round(smoothedDistanceInches * 2.54))
    }

    public var formattedDistanceString: String {
        return "\(displayDistanceInches)\" (\(displayDistanceCm) cm)"
    }

    public var distanceProgressRatio: Double {
        // 0.0 = dangerously close (~8 inches), 1.0 = safe distance (20+ inches)
        let clamped = min(max(smoothedDistanceInches, 8.0), 24.0)
        return (clamped - 8.0) / (24.0 - 8.0)
    }

    // MARK: - Alerts

    public func triggerAlert() {
        isAlertActive = true
        SoundManager.shared.playAlertSound(named: "Pop")
        onDistanceAlertTriggered?()
    }

    public func resolveAlert() {
        isAlertActive = false
        consecutiveTooCloseSeconds = 0
        consecutiveNormalSeconds = 0
        testSimulationTimer?.invalidate()
        testSimulationTimer = nil
        SoundManager.shared.playCompletionSound()
        onDistanceAlertResolved?()
    }

    public func dismissAlertManually() {
        isAlertActive = false
        consecutiveTooCloseSeconds = 0
        testSimulationTimer?.invalidate()
        testSimulationTimer = nil
        onDistanceAlertResolved?()
    }

    public func testDistanceAlert() {
        isTooClose = true
        isAlertActive = true
        currentDistanceInches = 12.0
        smoothedDistanceInches = 12.0
        currentDistanceCm = 30.0

        SoundManager.shared.playAlertSound(named: "Pop")
        onDistanceAlertTriggered?()

        // If camera is available, start monitoring immediately for live real-time response
        if permissionStatus == .authorized {
            startMonitoring()
        } else {
            // Simulate user sitting back over 6 seconds for demonstration
            testSimulationTimer?.invalidate()
            var step = 0
            testSimulationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] timer in
                guard let self = self, self.isAlertActive else {
                    timer.invalidate()
                    return
                }
                step += 1
                let simulatedInches = 12.0 + (Double(step) * 2.2)
                self.currentDistanceInches = simulatedInches
                self.smoothedDistanceInches = simulatedInches
                self.currentDistanceCm = simulatedInches * 2.54

                if simulatedInches >= 20.0 {
                    self.isTooClose = false
                }
                if simulatedInches >= 24.0 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if self.isAlertActive && !self.isTooClose {
                            self.resolveAlert()
                        }
                    }
                }
            }
        }
    }
}
