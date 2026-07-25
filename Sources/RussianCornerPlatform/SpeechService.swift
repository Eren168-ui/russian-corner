import AVFoundation
import Foundation

public struct SpeechVoice: Equatable, Sendable {
    public let identifier: String
    public let language: String

    public init(identifier: String, language: String) {
        self.identifier = identifier
        self.language = language
    }
}

public protocol SpeechVoiceProviding: Sendable {
    func availableVoices() -> [SpeechVoice]
}

public struct SystemSpeechVoiceProvider: SpeechVoiceProviding {
    public init() {}

    public func availableVoices() -> [SpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices().map {
            SpeechVoice(
                identifier: $0.identifier,
                language: $0.language
            )
        }
    }
}

@MainActor
public protocol SpeechSynthesizing: AnyObject {
    func speak(
        _ text: String,
        voiceIdentifier: String,
        completion: @escaping @MainActor @Sendable (
            SpeechSynthesisOutcome
        ) -> Void
    )
    func stop()
}

@MainActor
public final class SystemSpeechSynthesizer:
    NSObject,
    SpeechSynthesizing,
    AVSpeechSynthesizerDelegate
{
    private typealias Completion =
        @MainActor @Sendable (SpeechSynthesisOutcome) -> Void

    private let synthesizer: AVSpeechSynthesizer
    private var completions: [ObjectIdentifier: Completion] = [:]

    public init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    public func speak(
        _ text: String,
        voiceIdentifier: String,
        completion: @escaping @MainActor @Sendable (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(
            identifier: voiceIdentifier
        )
        completions[ObjectIdentifier(utterance)] = completion
        synthesizer.speak(utterance)
    }

    public func stop() {
        let pendingCompletions = Array(completions.values)
        completions.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        for completion in pendingCompletions {
            completion(.cancelled)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.complete(identifier, with: .finished)
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.complete(identifier, with: .cancelled)
        }
    }

    private func complete(
        _ identifier: ObjectIdentifier,
        with outcome: SpeechSynthesisOutcome
    ) {
        let completion = completions.removeValue(forKey: identifier)
        completion?(outcome)
    }
}

public enum SpeechSynthesisOutcome: Equatable, Sendable {
    case finished
    case cancelled
}

public enum SpeechVoicePolicy: Equatable, Sendable {
    case allowFallback
    case russianOnly
}

public enum SpeechServiceStatus: Equatable, Sendable {
    case russianVoice(identifier: String)
    case fallbackVoice(identifier: String, language: String)
    case unavailable
    case emptyText
}

@MainActor
public final class SpeechService {
    private let voiceProvider: any SpeechVoiceProviding
    private let synthesizer: any SpeechSynthesizing
    private var playbackGeneration: UInt = 0

    public init(
        voiceProvider: any SpeechVoiceProviding =
            SystemSpeechVoiceProvider(),
        synthesizer: any SpeechSynthesizing = SystemSpeechSynthesizer()
    ) {
        self.voiceProvider = voiceProvider
        self.synthesizer = synthesizer
    }

    public func voiceStatus() -> SpeechServiceStatus {
        let voices = voiceProvider.availableVoices()
        if let exactRussianVoice = voices.first(where: {
            $0.language.caseInsensitiveCompare("ru-RU") == .orderedSame
        }) {
            return .russianVoice(identifier: exactRussianVoice.identifier)
        }
        if let otherRussianVoice = voices.first(where: {
            $0.language.lowercased().hasPrefix("ru-")
                || $0.language.caseInsensitiveCompare("ru") == .orderedSame
        }) {
            return .russianVoice(identifier: otherRussianVoice.identifier)
        }
        if let fallbackVoice = voices.first {
            return .fallbackVoice(
                identifier: fallbackVoice.identifier,
                language: fallbackVoice.language
            )
        }
        return .unavailable
    }

    @discardableResult
    public func speak(
        _ text: String,
        voicePolicy: SpeechVoicePolicy = .allowFallback,
        completion: @escaping @MainActor @Sendable (
            SpeechSynthesisOutcome
        ) -> Void = { _ in }
    ) -> SpeechServiceStatus {
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .emptyText
        }

        let status = voiceStatus()
        switch status {
        case let .russianVoice(identifier):
            startPlayback(
                text,
                voiceIdentifier: identifier,
                completion: completion
            )
        case let .fallbackVoice(identifier, _):
            if voicePolicy == .allowFallback {
                startPlayback(
                    text,
                    voiceIdentifier: identifier,
                    completion: completion
                )
            }
        case .unavailable, .emptyText:
            break
        }
        return status
    }

    public func stop() {
        playbackGeneration &+= 1
        synthesizer.stop()
    }

    private func startPlayback(
        _ text: String,
        voiceIdentifier: String,
        completion: @escaping @MainActor @Sendable (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        let generation = playbackGeneration
        synthesizer.speak(
            text,
            voiceIdentifier: voiceIdentifier
        ) { [weak self] outcome in
            guard let self, generation == self.playbackGeneration else {
                return
            }
            completion(outcome)
        }
    }
}
