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

public enum DistanceZone: Equatable {
    case tooClose   // Closer than warning threshold (e.g. < 18")
    case caution    // Between threshold and target (18" - 20")
    case safe       // Ergonomically safe arm's length (20" - 32")
    case far        // Farther away (> 32")
    case unknown    // No person detected in frame

    public var title: String {
        switch self {
        case .tooClose: return "Too Close"
        case .caution: return "Caution"
        case .safe: return "Safe Distance"
        case .far: return "Relaxed"
        case .unknown: return "Looking for Person"
        }
    }
}

public final class ScreenDistanceManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = ScreenDistanceManager()

    @Published public private(set) var isTooClose: Bool = false
    @Published public private(set) var hasDetectedFace: Bool = false
    @Published public private(set) var distanceZone: DistanceZone = .unknown
    @Published public private(set) var currentFaceMetric: Double = 0.0 // 0.0 to 1.0 normalized
    @Published public private(set) var currentDistanceInches: Double = 24.0
    @Published public private(set) var currentDistanceCm: Double = 61.0
    @Published public private(set) var smoothedDistanceInches: Double = 24.0
    @Published public private(set) var smoothedDistanceCm: Double = 61.0
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published public private(set) var isAlertActive: Bool = false
    @Published public private(set) var isLiveHUDActive: Bool = false

    public let targetDistanceInches: Double = 20.0
    public let targetDistanceCm: Double = 50.0

    public var onDistanceAlertTriggered: (() -> Void)?
    public var onDistanceAlertResolved: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.eyebreak.cameraSession", qos: .userInitiated)
    private var lastSampleTime: TimeInterval = 0
    private var consecutiveTooCloseSeconds: Int = 0
    private var consecutiveNormalSeconds: Int = 0
    // Use a DispatchSourceTimer for simulated distance changes – safer than Foundation Timer and avoids overlapping runs
    private var simulationTimer: DispatchSourceTimer?
    // Separate timer for alert debounce/resolution to prevent overlapping alert handling
    private var alertResolutionTimer: DispatchSourceTimer?

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // Anthropometric calibration constants:
    // Adult Interpupillary Distance (IPD): standard 6.3 cm (63 mm) across adults.
    // Face width (bizygomatic): ~14.0 cm. Face height (forehead to chin): ~18.5 cm.
    // MacBook front FaceTime HD camera normalized focal length: ~0.6757 (corresponding to ~73 deg HFOV).
    private let cameraFocalLengthNorm: Double = 0.6757
    private let humanIpdCm: Double = 6.3
    private let humanFaceWidthCm: Double = 14.0
    private let humanFaceHeightCm: Double = 18.5

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
                    if self?.settings.screenDistanceEnabled == true || self?.isLiveHUDActive == true {
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
                if enabled || self.isLiveHUDActive {
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
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Prevent duplicate session starts
            guard self.captureSession?.isRunning != true else { return }

            self.setupCaptureSession()
            self.captureSession?.startRunning()

            // All UI‑related state updates must happen on the main thread
            DispatchQueue.main.async {
                self.isMonitoring = true
            }
        }
    }

    public func stopMonitoring() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Safely stop the session if it is active
            if self.captureSession?.isRunning == true {
                self.captureSession?.stopRunning()
            }
            // Reset all exported state on the main thread to keep UI consistent
            DispatchQueue.main.async {
                self.isMonitoring = false
                self.isTooClose = false
                self.hasDetectedFace = false
                self.distanceZone = .unknown
                self.currentFaceMetric = 0.0
                // Cancel any pending timers to avoid stray callbacks after stop
                self.simulationTimer?.cancel()
                self.simulationTimer = nil
                self.alertResolutionTimer?.cancel()
                self.alertResolutionTimer = nil
            }
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        // Use 640x480 for precise facial landmark detection with low power & memory
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .low
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            print("ScreenDistanceManager: No camera device found.")
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
        // High-frequency sampling (0.08s ~ 12 FPS) when notch alert or live HUD is active for silky smooth tracking.
        // Low-frequency sampling (0.8s) during background monitoring to maximize battery life.
        let minInterval: TimeInterval = (isAlertActive || isLiveHUDActive) ? 0.08 : 0.8
        let now = CACurrentMediaTime()
        guard now - lastSampleTime >= minInterval else { return }
        lastSampleTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))

        // Single Vision request detecting face bounds, orientation, and 2D landmarks
        let request = VNDetectFaceLandmarksRequest { [weak self] req, err in
            guard let self = self, err == nil else { return }
            self.processFaceResults(req.results as? [VNFaceObservation], imageWidth: width, imageHeight: height)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Accurate Distance Calculation Engine

    private func processFaceResults(_ faces: [VNFaceObservation]?, imageWidth: Double, imageHeight: Double) {
        guard let face = faces?.first else {
            // No face in view
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.hasDetectedFace = false
                self.distanceZone = .unknown
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

        // 1. Extract head pose angles (yaw and pitch) in radians
        let yaw = Double(face.yaw?.floatValue ?? 0.0)
        let pitch = Double(face.pitch?.floatValue ?? 0.0)

        // Head rotation foreshortening corrections (clamped to prevent division by near-zero)
        let cosYaw = max(0.48, cos(min(abs(yaw), 1.05)))
        let cosPitch = max(0.48, cos(min(abs(pitch), 1.05)))

        // 2. Optical parameters
        let fNorm = cameraFocalLengthNorm
        let aspectRatio: Double = (imageWidth > 0 && imageHeight > 0) ? (imageWidth / imageHeight) : (4.0 / 3.0)
        let fyNorm = fNorm * aspectRatio

        // 3. High-accuracy eye pupil separation (Interpupillary Distance)
        var zIpd: Double? = nil
        if let eyeSeparation = extractEyeDistance(from: face, aspectRatio: aspectRatio) {
            let frontalEyeSeparation = eyeSeparation / cosYaw
            if frontalEyeSeparation > 0.012 {
                zIpd = (fNorm * humanIpdCm) / frontalEyeSeparation
            }
        }

        // 4. Bounding box fallback & fusion
        let boxWidth = Double(face.boundingBox.width)
        let boxHeight = Double(face.boundingBox.height)
        let frontalBoxWidth = boxWidth / cosYaw
        let frontalBoxHeight = boxHeight / cosPitch

        let zWidth = (fNorm * humanFaceWidthCm) / max(0.035, frontalBoxWidth)
        let zHeight = (fyNorm * humanFaceHeightCm) / max(0.05, frontalBoxHeight)
        let zBox = (zWidth + zHeight) / 2.0

        // 5. Multi-cue sensor fusion:
        // When eye landmarks are detected, use 85% IPD + 15% bounding box for optimal precision.
        // Otherwise fall back completely to face dimensions.
        let rawCm: Double
        if let ipdDist = zIpd {
            rawCm = (0.85 * ipdDist) + (0.15 * zBox)
        } else {
            rawCm = zBox
        }

        // 6. User calibration factor fine-tuning
        let calFactor = max(0.65, min(1.4, settings.distanceCalibrationFactor))
        let calibratedCm = max(15.0, min(180.0, rawCm * calFactor))
        let calibratedInches = calibratedCm / 2.54

        // 7. Update state with adaptive smoothing
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hasDetectedFace = true
            self.currentFaceMetric = Double(max(boxWidth, boxHeight))
            self.currentDistanceCm = calibratedCm
            self.currentDistanceInches = calibratedInches

            // Adaptive filter: responsive when the person moves, rock-solid stable when sitting still
            let diff = abs(calibratedInches - self.smoothedDistanceInches)
            let alpha: Double = diff > 3.0 ? 0.70 : (diff > 1.0 ? 0.40 : 0.18)
            self.smoothedDistanceInches = (alpha * calibratedInches) + ((1.0 - alpha) * self.smoothedDistanceInches)
            self.smoothedDistanceCm = self.smoothedDistanceInches * 2.54

            // Determine ergonomic distance zone
            let threshold = self.settings.targetDistanceThresholdInches
            if self.smoothedDistanceInches < threshold {
                self.distanceZone = .tooClose
            } else if self.smoothedDistanceInches < self.targetDistanceInches {
                self.distanceZone = .caution
            } else if self.smoothedDistanceInches < 32.0 {
                self.distanceZone = .safe
            } else {
                self.distanceZone = .far
            }

            let tooCloseNow = self.smoothedDistanceInches < threshold

            if tooCloseNow {
                // Reset normal counter when too close persists; increment too‑close counter
                self.consecutiveNormalSeconds = 0
                self.consecutiveTooCloseSeconds += 1

                // Trigger alert only after warning threshold is met, using a dedicated debounce timer to avoid rapid re‑entrance
                if self.consecutiveTooCloseSeconds >= Int(self.settings.screenDistanceWarningSeconds) {
                    self.isTooClose = true
                    if !self.isAlertActive {
                        // Cancel any pending resolve timer before triggering a new alert
                        self.alertResolutionTimer?.cancel()
                        self.alertResolutionTimer = nil
                        self.triggerAlert()
                    }
                }
            } else {
                // Reset too‑close counter when user moves back to a safe zone
                self.consecutiveTooCloseSeconds = 0
                if self.isTooClose {
                    self.consecutiveNormalSeconds += 1
                    // Resolve alert once user stays beyond threshold for a short grace period
                    if self.smoothedDistanceInches >= (threshold + 1.5) || self.consecutiveNormalSeconds >= 2 {
                        self.isTooClose = false
                        if self.isAlertActive {
                            // Use debounce timer to prevent flickering alerts on borderline distances
                            self.alertResolutionTimer?.cancel()
                            self.alertResolutionTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                            self.alertResolutionTimer?.schedule(deadline: .now() + 1.2)
                            self.alertResolutionTimer?.setEventHandler { [weak self] in
                                guard let self = self, !self.isTooClose else { return }
                                self.resolveAlert()
                                self.alertResolutionTimer?.cancel()
                                self.alertResolutionTimer = nil
                            }
                            self.alertResolutionTimer?.resume()
                        }
                    }
                }
            }
        }
    }

    private func extractEyeDistance(from face: VNFaceObservation, aspectRatio: Double) -> Double? {
        guard let landmarks = face.landmarks else { return nil }
        let bb = face.boundingBox

        // 1. Try pupil landmarks if available
        if let lp = landmarks.leftPupil, let rp = landmarks.rightPupil,
           lp.pointCount > 0, rp.pointCount > 0 {
            let leftPt = lp.normalizedPoints[0]
            let rightPt = rp.normalizedPoints[0]

            let lx = Double(bb.origin.x) + Double(leftPt.x) * Double(bb.width)
            let ly = Double(bb.origin.y) + Double(leftPt.y) * Double(bb.height)
            let rx = Double(bb.origin.x) + Double(rightPt.x) * Double(bb.width)
            let ry = Double(bb.origin.y) + Double(rightPt.y) * Double(bb.height)

            let dx = rx - lx
            let dy = (ry - ly) / aspectRatio
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 0.01 { return dist }
        }

        // 2. Use eye region polygon centroids
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
              leftEye.pointCount > 0, rightEye.pointCount > 0 else {
            return nil
        }

        let leftPts = leftEye.normalizedPoints
        let rightPts = rightEye.normalizedPoints

        var lSumX = 0.0, lSumY = 0.0
        for pt in leftPts {
            lSumX += Double(pt.x)
            lSumY += Double(pt.y)
        }
        let lCenterX = lSumX / Double(leftEye.pointCount)
        let lCenterY = lSumY / Double(leftEye.pointCount)

        var rSumX = 0.0, rSumY = 0.0
        for pt in rightPts {
            rSumX += Double(pt.x)
            rSumY += Double(pt.y)
        }
        let rCenterX = rSumX / Double(rightEye.pointCount)
        let rCenterY = rSumY / Double(rightEye.pointCount)

        let lx = Double(bb.origin.x) + lCenterX * Double(bb.width)
        let ly = Double(bb.origin.y) + lCenterY * Double(bb.height)
        let rx = Double(bb.origin.x) + rCenterX * Double(bb.width)
        let ry = Double(bb.origin.y) + rCenterY * Double(bb.height)

        let dx = rx - lx
        let dy = (ry - ly) / aspectRatio
        let dist = sqrt(dx * dx + dy * dy)
        return dist > 0.01 ? dist : nil
    }

    // MARK: - Formatted Distance Helpers

    public var displayDistanceInches: Int {
        Int(round(smoothedDistanceInches))
    }

    public var displayDistanceCm: Int {
        Int(round(smoothedDistanceCm))
    }

    public var formattedDistanceString: String {
        return "\(displayDistanceInches)\" (\(displayDistanceCm) cm)"
    }

    public var distanceProgressRatio: Double {
        // Range 10" (close, ratio 0.0) to 34" (far, ratio 1.0)
        // 20" target is at (20 - 10) / 24 = 41.7% of the bar
        let clamped = min(max(smoothedDistanceInches, 10.0), 34.0)
        return (clamped - 10.0) / (34.0 - 10.0)
    }

    // MARK: - Live Notch HUD Controls

    public func setLiveHUDActive(_ active: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLiveHUDActive = active
            if active {
                if self.permissionStatus == .authorized {
                    self.startMonitoring()
                }
            } else if !self.isAlertActive && !self.settings.screenDistanceEnabled {
                self.stopMonitoring()
            }
        }
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
        smoothedDistanceCm = 30.0
        distanceZone = .tooClose

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
                self.smoothedDistanceCm = self.currentDistanceCm

                if simulatedInches >= 20.0 {
                    self.isTooClose = false
                    self.distanceZone = .safe
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
