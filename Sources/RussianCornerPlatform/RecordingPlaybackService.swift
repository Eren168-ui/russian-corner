import AVFoundation
import Foundation

public enum RecordingPlaybackResult: Equatable, Sendable {
  case playing(URL)
  case failed(String)
}

@MainActor
public protocol RecordingPlaying: AnyObject {
  var isPlaying: Bool { get }
  func play(url: URL) -> RecordingPlaybackResult
  func stop()
}

@MainActor
public final class RecordingPlaybackService: RecordingPlaying {
  private var player: AVAudioPlayer?

  public init() {}

  public var isPlaying: Bool {
    player?.isPlaying ?? false
  }

  public func play(url: URL) -> RecordingPlaybackResult {
    do {
      let newPlayer = try AVAudioPlayer(contentsOf: url)
      newPlayer.prepareToPlay()
      guard newPlayer.play() else {
        return .failed("Audio player did not start.")
      }
      player = newPlayer
      return .playing(url)
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  public func stop() {
    player?.stop()
    player = nil
  }
}
