import AVFoundation
import Foundation

public struct SpeechActivitySummary:
    Codable,
    Equatable,
    Sendable
{
    public let elapsedMs: Int
    public let estimatedSpeakingMs: Int
    public let longPauseCount: Int
    public let usedMicrophoneMeter: Bool

    public init(
        elapsedMs: Int,
        estimatedSpeakingMs: Int,
        longPauseCount: Int,
        usedMicrophoneMeter: Bool
    ) {
        self.elapsedMs = max(0, elapsedMs)
        self.estimatedSpeakingMs = max(0, estimatedSpeakingMs)
        self.longPauseCount = max(0, longPauseCount)
        self.usedMicrophoneMeter = usedMicrophoneMeter
    }
}

public struct SpeechActivityAccumulator: Sendable {
    public let thresholdDecibels: Double
    public let longPauseThreshold: TimeInterval

    private var elapsed: TimeInterval = 0
    private var speaking: TimeInterval = 0
    private var currentSilence: TimeInterval = 0
    private var pauses = 0
    private var hasSpoken = false
    private var finishedSummary: SpeechActivitySummary?

    public init(
        ambientDecibels: Double,
        longPauseThreshold: TimeInterval = 1.2
    ) {
        let proposed = ambientDecibels.isFinite
            ? ambientDecibels + 10 : -40
        thresholdDecibels = min(max(proposed, -45), -20)
        self.longPauseThreshold = max(0, longPauseThreshold)
    }

    public mutating func ingest(
        decibels: Double,
        duration: TimeInterval
    ) {
        guard
            finishedSummary == nil,
            decibels.isFinite,
            duration.isFinite,
            duration > 0
        else {
            return
        }
        elapsed += duration
        if decibels >= thresholdDecibels {
            if hasSpoken, currentSilence >= longPauseThreshold {
                pauses += 1
            }
            currentSilence = 0
            speaking += duration
            hasSpoken = true
        } else if hasSpoken {
            currentSilence += duration
        }
    }

    public mutating func finish() -> SpeechActivitySummary {
        if let finishedSummary {
            return finishedSummary
        }
        if hasSpoken, currentSilence >= longPauseThreshold {
            pauses += 1
        }
        let summary = SpeechActivitySummary(
            elapsedMs: Self.milliseconds(elapsed),
            estimatedSpeakingMs: Self.milliseconds(speaking),
            longPauseCount: pauses,
            usedMicrophoneMeter: true
        )
        finishedSummary = summary
        return summary
    }

    private static func milliseconds(_ value: TimeInterval) -> Int {
        max(0, Int((value * 1_000).rounded()))
    }
}

public enum SpeechActivityFallbackReason:
    Equatable,
    Sendable
{
    case permissionDenied
    case unavailable
    case engineFailed(String)
}

public enum SpeechActivityStartResult: Equatable, Sendable {
    case started
    case timerOnly(SpeechActivityFallbackReason)

    public var usesMicrophoneMeter: Bool {
        self == .started
    }

    public var fallbackReason: SpeechActivityFallbackReason? {
        guard case .timerOnly(let reason) = self else { return nil }
        return reason
    }
}

public enum MicrophonePermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case undetermined
    case unavailable
}

public protocol MicrophonePermissionProviding: Sendable {
    func currentStatus() -> MicrophonePermissionStatus
    func requestPermission() async -> MicrophonePermissionStatus
}

public struct SystemMicrophonePermissionProvider:
    MicrophonePermissionProviding
{
    public init() {}

    public func currentStatus() -> MicrophonePermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .granted
        case .denied, .restricted:
            .denied
        case .notDetermined:
            .undetermined
        @unknown default:
            .unavailable
        }
    }

    public func requestPermission() async -> MicrophonePermissionStatus {
        guard currentStatus() == .undetermined else {
            return currentStatus()
        }
        return await AVCaptureDevice.requestAccess(for: .audio)
            ? .granted : .denied
    }
}

public protocol SpeechActivityMonitoring: AnyObject {
    var isMonitoring: Bool { get }
    func start() async -> SpeechActivityStartResult
    func stop() -> SpeechActivitySummary?
}

private final class SpeechActivityBox: @unchecked Sendable {
    private let lock = NSLock()
    private var calibrationDuration: TimeInterval = 0
    private var calibrationEnergy = 0.0
    private var accumulator: SpeechActivityAccumulator?

    func ingest(decibels: Double, duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        if accumulator == nil {
            calibrationDuration += duration
            calibrationEnergy += decibels * duration
            guard calibrationDuration >= 1 else { return }
            let ambient = calibrationEnergy / calibrationDuration
            accumulator = SpeechActivityAccumulator(
                ambientDecibels: ambient
            )
            return
        }
        accumulator?.ingest(
            decibels: decibels,
            duration: duration
        )
    }

    func finish() -> SpeechActivitySummary {
        lock.lock()
        defer { lock.unlock() }
        if accumulator == nil {
            let ambient = calibrationDuration > 0
                ? calibrationEnergy / calibrationDuration
                : -50
            accumulator = SpeechActivityAccumulator(
                ambientDecibels: ambient
            )
        }
        return accumulator!.finish()
    }
}

public final class SpeechActivityMonitor: SpeechActivityMonitoring {
    public private(set) var isMonitoring = false

    private let permissionProvider:
        any MicrophonePermissionProviding
    private var engine: AVAudioEngine?
    private var activityBox: SpeechActivityBox?

    public init(
        permissionProvider: any MicrophonePermissionProviding =
            SystemMicrophonePermissionProvider()
    ) {
        self.permissionProvider = permissionProvider
    }

    public func start() async -> SpeechActivityStartResult {
        _ = stop()
        var permission = permissionProvider.currentStatus()
        if permission == .undetermined {
            permission = await permissionProvider.requestPermission()
        }
        switch permission {
        case .granted:
            break
        case .denied, .undetermined:
            return .timerOnly(.permissionDenied)
        case .unavailable:
            return .timerOnly(.unavailable)
        }

        let newEngine = AVAudioEngine()
        let input = newEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard
            format.sampleRate > 0,
            format.channelCount > 0
        else {
            return .timerOnly(.unavailable)
        }
        let box = SpeechActivityBox()
        input.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: format
        ) { buffer, _ in
            guard
                let channel = buffer.floatChannelData?[0],
                buffer.frameLength > 0
            else {
                return
            }
            let frames = Int(buffer.frameLength)
            var sum = 0.0
            for index in 0..<frames {
                let sample = Double(channel[index])
                sum += sample * sample
            }
            let rms = sqrt(sum / Double(frames))
            let decibels = max(-80, 20 * log10(max(rms, 0.000_1)))
            let duration =
                Double(buffer.frameLength) / format.sampleRate
            box.ingest(decibels: decibels, duration: duration)
        }
        do {
            newEngine.prepare()
            try newEngine.start()
            engine = newEngine
            activityBox = box
            isMonitoring = true
            return .started
        } catch {
            input.removeTap(onBus: 0)
            newEngine.stop()
            return .timerOnly(.engineFailed(error.localizedDescription))
        }
    }

    public func stop() -> SpeechActivitySummary? {
        guard let engine else {
            isMonitoring = false
            return nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        isMonitoring = false
        let summary = activityBox?.finish()
        activityBox = nil
        return summary
    }
}
