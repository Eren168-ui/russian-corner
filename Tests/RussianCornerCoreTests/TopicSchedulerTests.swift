import RussianCornerCore
import XCTest

final class TopicSchedulerTests: XCTestCase {
    func testSixtyDayRotationCoversAllTopicsWithoutImmediateRepeat() {
        let topics = (1...32).map(topic)
        let selector = TopicSelector()
        var selected: [String] = []

        for offset in 0..<60 {
            let value = selector.select(
                dayIndex: 20_000 + offset,
                topics: topics,
                recentTopicIDs: Array(selected.suffix(14)),
                weaknessByTopic: [:],
                manualTopicID: nil
            )
            selected.append(value?.id ?? "")
        }

        XCTAssertEqual(Set(selected), Set(topics.map(\.id)))
        XCTAssertFalse(
            zip(selected, selected.dropFirst()).contains {
                $0 == $1
            }
        )
    }

    func testManualTopicWinsWhenItExists() {
        let topics = (1...32).map(topic)

        let selected = TopicSelector().select(
            dayIndex: 20_000,
            topics: topics,
            recentTopicIDs: [],
            weaknessByTopic: [:],
            manualTopicID: "topic-19"
        )

        XCTAssertEqual(selected?.id, "topic-19")
    }

    func testRussianCourseStartsWithUniversityInteractionTopics() {
        let topics = (1...32).map(topic)
        let selector = TopicSelector()

        let selectedIDs = (0..<4).compactMap { dayIndex in
            selector.select(
                dayIndex: dayIndex,
                topics: topics,
                recentTopicIDs: [],
                weaknessByTopic: [:],
                manualTopicID: nil
            )?.id
        }

        XCTAssertEqual(
            selectedIDs,
            ["topic-21", "topic-22", "topic-23", "topic-24"]
        )
    }

    func testEmptyTopicsReturnNil() {
        XCTAssertNil(
            TopicSelector().select(
                dayIndex: 0,
                topics: [],
                recentTopicIDs: [],
                weaknessByTopic: [:],
                manualTopicID: nil
            )
        )
    }

    private func topic(number: Int) -> TopicDefinition {
        TopicDefinition(
            id: String(format: "topic-%02d", number),
            number: number,
            titleRu: "Тема \(number)",
            titleZh: "主题 \(number)",
            sourcePath: "topic-\(number).md"
        )
    }
}
