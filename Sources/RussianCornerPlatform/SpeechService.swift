import AVFoundation
import Foundation
import RussianCornerCore

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

public protocol SpeechSynthesizing: AnyObject {
    func speak(
        _ text: String,
        voiceIdentifier: String,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    )
    func speak(
        _ text: String,
        voiceIdentifier: String,
        rate: Float,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    )
    func stop()
}

public extension SpeechSynthesizing {
    func speak(
        _ text: String,
        voiceIdentifier: String,
        rate: Float,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        _ = rate
        speak(
            text,
            voiceIdentifier: voiceIdentifier,
            completion: completion
        )
    }
}

public class SystemSpeechSynthesizer:
    NSObject,
    SpeechSynthesizing,
    AVSpeechSynthesizerDelegate,
    @unchecked Sendable
{
    private typealias Completion =
        (SpeechSynthesisOutcome) -> Void

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
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        speak(
            text,
            voiceIdentifier: voiceIdentifier,
            rate: AVSpeechUtteranceDefaultSpeechRate,
            completion: completion
        )
    }

    public func speak(
        _ text: String,
        voiceIdentifier: String,
        rate: Float,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(
            identifier: voiceIdentifier
        )
        utterance.rate = rate
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
    case preferredVoice(identifier: String, language: String)
    case fallbackVoice(identifier: String, language: String)
    case unavailable
    case emptyText
}

public final class SpeechService {
    private let voiceProvider: any SpeechVoiceProviding
    private let synthesizer: any SpeechSynthesizing
    private var playbackGeneration: UInt = 0

    public init(
        voiceProvider: any SpeechVoiceProviding =
            SystemSpeechVoiceProvider(),
        synthesizer: (any SpeechSynthesizing)? = nil
    ) {
        self.voiceProvider = voiceProvider
        self.synthesizer = synthesizer ?? SystemSpeechSynthesizer()
    }

    public func voiceStatus(
        language: StudyLanguage,
        allowUnrelatedFallback: Bool
    ) -> SpeechServiceStatus {
        let voices = voiceProvider.availableVoices()
        for preferredLanguage in language.preferredVoiceLanguages {
            if let preferredVoice = voices.first(where: {
                $0.language.caseInsensitiveCompare(preferredLanguage)
                    == .orderedSame
            }) {
                return .preferredVoice(
                    identifier: preferredVoice.identifier,
                    language: preferredVoice.language
                )
            }
        }
        let languageCode = language == .english ? "en" : "ru"
        if let relatedVoice = voices.first(where: {
            $0.language.lowercased().hasPrefix("\(languageCode)-")
                || $0.language.caseInsensitiveCompare(languageCode)
                    == .orderedSame
        }) {
            return .fallbackVoice(
                identifier: relatedVoice.identifier,
                language: relatedVoice.language
            )
        }
        if allowUnrelatedFallback, let fallbackVoice = voices.first {
            return .fallbackVoice(
                identifier: fallbackVoice.identifier,
                language: fallbackVoice.language
            )
        }
        return .unavailable
    }

    public func voiceStatus() -> SpeechServiceStatus {
        voiceStatus(
            language: .russian,
            allowUnrelatedFallback: true
        )
    }

    @discardableResult
    public func speak(
        _ text: String,
        language: StudyLanguage,
        playbackRate: Float = AVSpeechUtteranceDefaultSpeechRate,
        allowUnrelatedFallback: Bool = false,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void = { _ in }
    ) -> SpeechServiceStatus {
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .emptyText
        }

        let status = voiceStatus(
            language: language,
            allowUnrelatedFallback: allowUnrelatedFallback
        )
        switch status {
        case let .preferredVoice(identifier, _),
             let .fallbackVoice(identifier, _):
            startPlayback(
                text,
                voiceIdentifier: identifier,
                rate: playbackRate,
                completion: completion
            )
        case .unavailable, .emptyText:
            break
        }
        return status
    }

    @discardableResult
    public func speak(
        _ text: String,
        voicePolicy: SpeechVoicePolicy = .allowFallback,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void = { _ in }
    ) -> SpeechServiceStatus {
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .emptyText
        }

        let status = voiceStatus(
            language: .russian,
            allowUnrelatedFallback: true
        )
        switch status {
        case let .preferredVoice(identifier, _):
            startPlayback(
                text,
                voiceIdentifier: identifier,
                rate: AVSpeechUtteranceDefaultSpeechRate,
                completion: completion
            )
        case let .fallbackVoice(identifier, _):
            let isRussianVoice: Bool
            if case let .fallbackVoice(_, language) = status {
                isRussianVoice = language.lowercased().hasPrefix("ru")
            } else {
                isRussianVoice = false
            }
            if voicePolicy == .allowFallback || isRussianVoice {
                startPlayback(
                    text,
                    voiceIdentifier: identifier,
                    rate: AVSpeechUtteranceDefaultSpeechRate,
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
        rate: Float,
        completion: @escaping (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        let generation = playbackGeneration
        synthesizer.speak(
            text,
            voiceIdentifier: voiceIdentifier,
            rate: rate
        ) { [weak self] outcome in
            guard let self, generation == self.playbackGeneration else {
                return
            }
            completion(outcome)
        }
    }
}
