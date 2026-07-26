import Foundation
import XCTest

@testable import RussianCornerPlatform

final class SpeechActivityMonitorTests: XCTestCase {
    func testFramesAboveThresholdAccumulateSpeakingDuration() {
        var accumulator = SpeechActivityAccumulator(
            ambientDecibels: -50
        )

        accumulator.ingest(decibels: -30, duration: 0.4)
        accumulator.ingest(decibels: -25, duration: 0.6)
        accumulator.ingest(decibels: -55, duration: 0.2)
        let summary = accumulator.finish()

        XCTAssertEqual(summary.elapsedMs, 1_200)
        XCTAssertEqual(summary.estimatedSpeakingMs, 1_000)
    }

    func testSilenceLongerThanThresholdCountsOnePause() {
        var accumulator = SpeechActivityAccumulator(
            ambientDecibels: -50
        )

        accumulator.ingest(decibels: -25, duration: 0.5)
        accumulator.ingest(decibels: -55, duration: 1.3)
        accumulator.ingest(decibels: -25, duration: 0.5)

        XCTAssertEqual(accumulator.finish().longPauseCount, 1)
    }

    func testShortSilenceDoesNotCountAsLongPause() {
        var accumulator = SpeechActivityAccumulator(
            ambientDecibels: -50
        )

        accumulator.ingest(decibels: -25, duration: 0.5)
        accumulator.ingest(decibels: -55, duration: 1.1)
        accumulator.ingest(decibels: -25, duration: 0.5)

        XCTAssertEqual(accumulator.finish().longPauseCount, 0)
    }

    func testStopFlushesFinalSegmentExactlyOnce() {
        var accumulator = SpeechActivityAccumulator(
            ambientDecibels: -50
        )
        accumulator.ingest(decibels: -25, duration: 0.5)
        accumulator.ingest(decibels: -55, duration: 1.5)

        let first = accumulator.finish()
        let second = accumulator.finish()

        XCTAssertEqual(first.longPauseCount, 1)
        XCTAssertEqual(second, first)
    }

    @MainActor
    func testDeniedPermissionProducesTimerOnlyFallback() async {
        let monitor = SpeechActivityMonitor(
            permissionProvider: FixedSpeechPermissionProvider(
                status: .denied
            )
        )
        let result = await monitor.start()

        XCTAssertFalse(result.usesMicrophoneMeter)
        XCTAssertEqual(result.fallbackReason, .permissionDenied)
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testSpeechSummaryContainsNoAudioDataOrFileURL() throws {
        let summary = SpeechActivitySummary(
            elapsedMs: 60_000,
            estimatedSpeakingMs: 42_000,
            longPauseCount: 3,
            usedMicrophoneMeter: true
        )
        let data = try JSONEncoder().encode(summary)
        let serialized = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(serialized.contains("file://"))
        XCTAssertFalse(serialized.contains(".m4a"))
        XCTAssertFalse(serialized.contains("audio"))
        XCTAssertFalse(serialized.contains("url"))
    }

    func testThresholdUsesAmbientPlusTenAndClampsToSafeRange() {
        XCTAssertEqual(
            SpeechActivityAccumulator(ambientDecibels: -60)
                .thresholdDecibels,
            -45
        )
        XCTAssertEqual(
            SpeechActivityAccumulator(ambientDecibels: -35)
                .thresholdDecibels,
            -25
        )
        XCTAssertEqual(
            SpeechActivityAccumulator(ambientDecibels: -10)
                .thresholdDecibels,
            -20
        )
    }
}

private struct FixedSpeechPermissionProvider:
    MicrophonePermissionProviding
{
    let status: MicrophonePermissionStatus

    func currentStatus() -> MicrophonePermissionStatus {
        status
    }

    func requestPermission() async -> MicrophonePermissionStatus {
        status
    }
}
