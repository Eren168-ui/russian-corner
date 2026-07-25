import AVFoundation
import Foundation

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

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .granted : .denied
    }
}

@MainActor
public protocol RecordingEngine: AnyObject {
    var isRecording: Bool { get }
    func record() -> Bool
    func stop()
}

@MainActor
public protocol RecordingEngineFactory {
    func makeEngine(outputURL: URL) throws -> any RecordingEngine
}

@MainActor
private final class AVAudioRecorderEngine: RecordingEngine {
    private let recorder: AVAudioRecorder

    init(recorder: AVAudioRecorder) {
        self.recorder = recorder
    }

    var isRecording: Bool {
        recorder.isRecording
    }

    func record() -> Bool {
        recorder.record()
    }

    func stop() {
        recorder.stop()
    }
}

public struct AVAudioRecorderFactory: RecordingEngineFactory {
    public init() {}

    public func makeEngine(outputURL: URL) throws -> any RecordingEngine {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(
            url: outputURL,
            settings: settings
        )
        recorder.prepareToRecord()
        return AVAudioRecorderEngine(recorder: recorder)
    }
}

public enum RecordingStartResult: Equatable, Sendable {
    case started(URL)
    case permissionDenied
    case permissionUndetermined
    case unavailable
    case failed(String)

    public var startedURL: URL? {
        guard case let .started(url) = self else {
            return nil
        }
        return url
    }
}

public enum RecordingServiceError: Error, Equatable, Sendable {
    case noTemporaryRecording
    case recordingInProgress
    case destinationAlreadyExists
}

@MainActor
public final class RecordingService {
    private let permissionProvider: any MicrophonePermissionProviding
    private let engineFactory: any RecordingEngineFactory
    private let temporaryDirectory: URL
    private var engine: (any RecordingEngine)?

    public private(set) var temporaryRecordingURL: URL?

    public var isRecording: Bool {
        engine?.isRecording ?? false
    }

    public init(
        permissionProvider: any MicrophonePermissionProviding =
            SystemMicrophonePermissionProvider(),
        engineFactory: any RecordingEngineFactory = AVAudioRecorderFactory(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.permissionProvider = permissionProvider
        self.engineFactory = engineFactory
        self.temporaryDirectory = temporaryDirectory
    }

    deinit {
        if let temporaryRecordingURL {
            try? FileManager.default.removeItem(at: temporaryRecordingURL)
        }
    }

    public func permissionStatus() -> MicrophonePermissionStatus {
        permissionProvider.currentStatus()
    }

    public func requestPermission() async -> MicrophonePermissionStatus {
        await permissionProvider.requestPermission()
    }

    public func start() async -> RecordingStartResult {
        switch permissionProvider.currentStatus() {
        case .granted:
            break
        case .denied:
            return .permissionDenied
        case .undetermined:
            return .permissionUndetermined
        case .unavailable:
            return .unavailable
        }

        discard()
        let outputURL = temporaryDirectory
            .appendingPathComponent("russian-corner-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        do {
            let newEngine = try engineFactory.makeEngine(outputURL: outputURL)
            guard newEngine.record() else {
                try? FileManager.default.removeItem(at: outputURL)
                return .failed("Audio recorder did not start.")
            }
            engine = newEngine
            temporaryRecordingURL = outputURL
            return .started(outputURL)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            return .failed(error.localizedDescription)
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
    }

    public func discard() {
        stop()
        if let temporaryRecordingURL {
            try? FileManager.default.removeItem(at: temporaryRecordingURL)
        }
        temporaryRecordingURL = nil
    }

    @discardableResult
    public func save(to destinationURL: URL) throws -> URL {
        guard !isRecording else {
            throw RecordingServiceError.recordingInProgress
        }
        guard let temporaryRecordingURL else {
            throw RecordingServiceError.noTemporaryRecording
        }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw RecordingServiceError.destinationAlreadyExists
        }

        try FileManager.default.copyItem(
            at: temporaryRecordingURL,
            to: destinationURL
        )
        try FileManager.default.removeItem(at: temporaryRecordingURL)
        self.temporaryRecordingURL = nil
        return destinationURL
    }
}
