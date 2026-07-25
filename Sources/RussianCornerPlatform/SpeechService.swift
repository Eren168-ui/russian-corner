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
    func speak(_ text: String, voiceIdentifier: String)
    func stop()
}

@MainActor
public final class SystemSpeechSynthesizer: SpeechSynthesizing {
    private let synthesizer: AVSpeechSynthesizer

    public init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
    }

    public func speak(_ text: String, voiceIdentifier: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(
            identifier: voiceIdentifier
        )
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
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
    public func speak(_ text: String) -> SpeechServiceStatus {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .emptyText
        }

        let status = voiceStatus()
        switch status {
        case let .russianVoice(identifier):
            synthesizer.speak(text, voiceIdentifier: identifier)
        case let .fallbackVoice(identifier, _):
            synthesizer.speak(text, voiceIdentifier: identifier)
        case .unavailable, .emptyText:
            break
        }
        return status
    }

    public func stop() {
        synthesizer.stop()
    }
}
