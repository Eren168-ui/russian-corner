import Foundation
import XCTest
@testable import RussianCornerCore

final class TrialReportBuilderTests: XCTestCase {
    func testAgainIsFailureAndHardEasyAreSuccess() {
        XCTAssertFalse(TrialGradeOutcome(grade: .again).isSuccess)
        XCTAssertTrue(TrialGradeOutcome(grade: .hard).isSuccess)
        XCTAssertTrue(TrialGradeOutcome(grade: .easy).isSuccess)
    }

    func testTrialInteractionRoundTripsWithoutLocalPaths() throws {
        let value = TrialInteraction(
            sessionID: UUID(),
            itemType: .lexeme,
            itemID: "lex-001",
            kind: .grade,
            direction: .production,
            promptLevel: .chinese,
            grade: .hard,
            responseTimeMs: 2_900,
            usedSpeech: true,
            openedDetails: false,
            practiceMode: .speaking,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(
            TrialInteraction.self,
            from: data
        )

        XCTAssertEqual(decoded, value)
        let serialized = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(serialized.contains("file://"))
        XCTAssertFalse(serialized.contains("sourcePath"))
    }

    func testReportContainsUsageCompletionTimeAndDailyCards() {
        let fixture = reportFixture()
        let report = fixture.builder.markdown(
            snapshot: fixture.snapshot,
            range: fixture.range
        )

        XCTAssertTrue(report.contains("# 俄语角落卡｜7 天试用报告"))
        XCTAssertTrue(report.contains("## 使用概览"))
        XCTAssertTrue(report.contains("使用天数：1 / 7"))
        XCTAssertTrue(report.contains("完成量：3 / 4（75%）"))
        XCTAssertTrue(report.contains("有效练习时长：10 分钟"))
        XCTAssertTrue(report.contains("### 2023-11-14"))
    }

    func testReportSeparatesRecognitionProductionAndSentenceOutput() {
        let fixture = reportFixture()
        let report = fixture.builder.markdown(
            snapshot: fixture.snapshot,
            range: fixture.range
        )

        XCTAssertTrue(report.contains("俄语识义：1 / 1（100%）"))
        XCTAssertTrue(report.contains("中文提示说俄语：1 / 2（50%）"))
        XCTAssertTrue(report.contains("场景句输出：1 / 1（100%）"))
    }

    func testReportUsesMedianOfOnlyRevealedGradedResponses() {
        let fixture = reportFixture()
        let report = fixture.builder.markdown(
            snapshot: fixture.snapshot,
            range: fixture.range
        )

        XCTAssertTrue(report.contains("评分反应时间中位数：2.5 秒"))
        XCTAssertFalse(report.contains("9.0 秒"))
    }

    func testReportContainsBacklogExitDetailSpeechReflectionAndOralSections() {
        let fixture = reportFixture()
        let report = fixture.builder.markdown(
            snapshot: fixture.snapshot,
            range: fixture.range
        )

        XCTAssertTrue(report.contains("## 复习与积压"))
        XCTAssertTrue(report.contains("期末待复习积压：2"))
        XCTAssertTrue(report.contains("完成：1 次"))
        XCTAssertTrue(report.contains("查看详情：1 / 4 张评分卡（25%）"))
        XCTAssertTrue(report.contains("主动朗读：1 / 4 张评分卡（25%）"))
        XCTAssertTrue(report.contains("## 每日反馈"))
        XCTAssertTrue(report.contains("最卡：动词搭配"))
        XCTAssertTrue(report.contains("## 口述活动"))
        XCTAssertTrue(report.contains("估算开口 42 秒"))
        XCTAssertTrue(report.contains("自评 4 / 5"))
    }

    func testReportDoesNotContainJSONAudioURLOrSourcePath() {
        let fixture = reportFixture()
        let report = fixture.builder.markdown(
            snapshot: fixture.snapshot,
            range: fixture.range
        )

        for forbidden in [
            "\"sessionID\"",
            "file:///",
            ".m4a",
            "sourcePath",
            "RussianCornerTrial.store",
        ] {
            XCTAssertFalse(report.contains(forbidden))
        }
    }

    func testEmptySevenDayPeriodStillProducesUsefulChineseReport() {
        let fixture = reportFixture()
        let empty = TrialReportSnapshot(
            sessions: [],
            interactions: [],
            reflections: [],
            oralAttempts: []
        )

        let first = fixture.builder.markdown(
            snapshot: empty,
            range: fixture.range
        )
        let second = fixture.builder.markdown(
            snapshot: empty,
            range: fixture.range
        )

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.contains("使用天数：0 / 7"))
        XCTAssertTrue(first.contains("本周期暂无评分记录"))
        XCTAssertTrue(first.contains("本周期暂无每日反馈"))
        XCTAssertTrue(first.contains("本周期尚未进行口述活动"))
    }

    private func reportFixture() -> (
        builder: TrialReportBuilder,
        snapshot: TrialReportSnapshot,
        range: ClosedRange<Date>
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_699_920_000)
        let practiceStart = Date(timeIntervalSince1970: 1_700_000_000)
        let range = start...start.addingTimeInterval(7 * 86_400 - 1)
        let sessionID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000001"
        )!
        let session = TrialSession(
            id: sessionID,
            startedAt: practiceStart,
            endedAt: practiceStart.addingTimeInterval(600),
            endReason: .completed,
            startQueueCount: 4,
            endQueueCount: 0,
            completedLexemeCount: 2,
            completedSentenceCount: 1,
            newItemCount: 2,
            reviewItemCount: 2,
            remainingBacklogCount: 2,
            exitItemType: nil,
            exitQueuePosition: nil
        )
        let interactions = [
            interaction(
                sessionID: sessionID,
                id: "lex-recognition",
                direction: .recognition,
                grade: .easy,
                responseTimeMs: 1_000,
                usedSpeech: false,
                openedDetails: false,
                at: practiceStart.addingTimeInterval(10)
            ),
            interaction(
                sessionID: sessionID,
                id: "lex-production-again",
                direction: .production,
                grade: .again,
                responseTimeMs: 2_000,
                usedSpeech: false,
                openedDetails: false,
                at: practiceStart.addingTimeInterval(20)
            ),
            interaction(
                sessionID: sessionID,
                id: "lex-production-hard",
                direction: .production,
                grade: .hard,
                responseTimeMs: 3_000,
                usedSpeech: true,
                openedDetails: false,
                at: practiceStart.addingTimeInterval(30)
            ),
            interaction(
                sessionID: sessionID,
                id: "sentence-output",
                itemType: .sentence,
                direction: .sentenceProduction,
                grade: .easy,
                responseTimeMs: 4_000,
                usedSpeech: false,
                openedDetails: true,
                at: practiceStart.addingTimeInterval(40)
            ),
            TrialInteraction(
                sessionID: sessionID,
                itemType: .lexeme,
                itemID: "ignored-reveal",
                kind: .reveal,
                direction: .production,
                promptLevel: .chinese,
                responseTimeMs: 9_000,
                usedSpeech: false,
                openedDetails: false,
                practiceMode: .quiet,
                createdAt: practiceStart.addingTimeInterval(5)
            ),
        ]
        let reflection = DailyReflection(
            day: practiceStart,
            mostBlocked: "动词搭配",
            spokeNaturally: true,
            spokeNaturallyNote: "餐厅预订句",
            completionReason: .completed,
            completionReasonNote: "",
            updatedAt: practiceStart.addingTimeInterval(700)
        )
        let oral = OralActivityAttempt(
            topic: "日常生活",
            attemptedAt: practiceStart.addingTimeInterval(800),
            elapsedMs: 60_000,
            estimatedSpeakingMs: 42_000,
            longPauseCount: 3,
            selfRating: 4,
            usedMicrophoneMeter: true
        )
        return (
            TrialReportBuilder(calendar: calendar),
            TrialReportSnapshot(
                sessions: [session],
                interactions: interactions,
                reflections: [reflection],
                oralAttempts: [oral]
            ),
            range
        )
    }

    private func interaction(
        sessionID: UUID,
        id: String,
        itemType: PracticeItemKind = .lexeme,
        direction: TrialPromptDirection,
        grade: ReviewGrade,
        responseTimeMs: Int,
        usedSpeech: Bool,
        openedDetails: Bool,
        at date: Date
    ) -> TrialInteraction {
        TrialInteraction(
            sessionID: sessionID,
            itemType: itemType,
            itemID: id,
            kind: .grade,
            direction: direction,
            promptLevel: direction == .recognition
                ? .russian : .chinese,
            grade: grade,
            responseTimeMs: responseTimeMs,
            usedSpeech: usedSpeech,
            openedDetails: openedDetails,
            practiceMode: .quiet,
            createdAt: date
        )
    }
}
