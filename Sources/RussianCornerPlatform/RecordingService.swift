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

public enum RecordingSaveOutcome: Equatable, Sendable {
    case saved(
        destinationURL: URL,
        temporaryCleanupPending: Bool
    )
}

@MainActor
public protocol RecordingManaging: AnyObject {
    var isRecording: Bool { get }
    var temporaryRecordingURL: URL? { get }
    func permissionStatus() -> MicrophonePermissionStatus
    func requestPermission() async -> MicrophonePermissionStatus
    func start() async -> RecordingStartResult
    func stop()
    func discard() throws
    func save(to destinationURL: URL) throws -> RecordingSaveOutcome
}

@MainActor
public protocol RecordingFileManaging {
    func fileExists(at url: URL) -> Bool
    func removeItem(at url: URL) throws
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws
}

public struct SystemRecordingFileManager: RecordingFileManaging {
    public init() {}

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func copyItem(
        at sourceURL: URL,
        to destinationURL: URL
    ) throws {
        try FileManager.default.copyItem(
            at: sourceURL,
            to: destinationURL
        )
    }
}

@MainActor
public final class RecordingService {
    private let permissionProvider: any MicrophonePermissionProviding
    private let engineFactory: any RecordingEngineFactory
    private let fileManager: any RecordingFileManaging
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
        fileManager: any RecordingFileManaging =
            SystemRecordingFileManager(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.permissionProvider = permissionProvider
        self.engineFactory = engineFactory
        self.fileManager = fileManager
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

        do {
            try discard()
        } catch {
            return .failed(error.localizedDescription)
        }
        let outputURL = temporaryDirectory
            .appendingPathComponent("russian-corner-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        temporaryRecordingURL = outputURL

        do {
            let newEngine = try engineFactory.makeEngine(outputURL: outputURL)
            guard newEngine.record() else {
                newEngine.stop()
                return startFailure(
                    message: "Audio recorder did not start."
                )
            }
            engine = newEngine
            return .started(outputURL)
        } catch {
            return startFailure(message: error.localizedDescription)
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
    }

    public func discard() throws {
        stop()
        guard let temporaryRecordingURL else {
            return
        }
        if fileManager.fileExists(at: temporaryRecordingURL) {
            try fileManager.removeItem(at: temporaryRecordingURL)
        }
        self.temporaryRecordingURL = nil
    }

    @discardableResult
    public func save(
        to destinationURL: URL
    ) throws -> RecordingSaveOutcome {
        guard !isRecording else {
            throw RecordingServiceError.recordingInProgress
        }
        guard let temporaryRecordingURL else {
            throw RecordingServiceError.noTemporaryRecording
        }
        guard !fileManager.fileExists(at: destinationURL) else {
            throw RecordingServiceError.destinationAlreadyExists
        }

        try fileManager.copyItem(
            at: temporaryRecordingURL,
            to: destinationURL
        )

        do {
            if fileManager.fileExists(at: temporaryRecordingURL) {
                try fileManager.removeItem(at: temporaryRecordingURL)
            }
            self.temporaryRecordingURL = nil
            return .saved(
                destinationURL: destinationURL,
                temporaryCleanupPending: false
            )
        } catch {
            return .saved(
                destinationURL: destinationURL,
                temporaryCleanupPending: true
            )
        }
    }

    private func startFailure(message: String) -> RecordingStartResult {
        let startMessage = "Recording failed to start: \(message)"
        guard let temporaryRecordingURL else {
            return .failed(startMessage)
        }

        do {
            if fileManager.fileExists(at: temporaryRecordingURL) {
                try fileManager.removeItem(at: temporaryRecordingURL)
            }
            self.temporaryRecordingURL = nil
            return .failed(startMessage)
        } catch {
            return .failed(
                "\(startMessage) Cleanup failed: \(error.localizedDescription)"
            )
        }
    }
}

extension RecordingService: RecordingManaging {}
