public struct TopicSelector: Sendable {
    public init() {}

    public func select(
        dayIndex: Int,
        topics: [TopicDefinition],
        recentTopicIDs: [String],
        weaknessByTopic: [String: Double],
        manualTopicID: String?
    ) -> TopicDefinition? {
        guard !topics.isEmpty else {
            return nil
        }
        if let manualTopicID,
           let manual = topics.first(where: {
               $0.id == manualTopicID
           })
        {
            return manual
        }

        let ordered = topics.sorted {
            if $0.number == $1.number {
                return $0.id < $1.id
            }
            return $0.number < $1.number
        }
        let baseIndex = positiveModulo(dayIndex, ordered.count)
        let recent = Set(recentTopicIDs.suffix(14))
        let available = ordered.filter { !recent.contains($0.id) }
        guard !available.isEmpty else {
            return ordered[baseIndex]
        }
        let base = ordered[baseIndex]
        if !recent.contains(base.id) {
            return base
        }
        return available.max { left, right in
            let leftWeakness = weaknessByTopic[left.id, default: 0]
            let rightWeakness = weaknessByTopic[right.id, default: 0]
            if leftWeakness == rightWeakness {
                return clockwiseDistance(
                    from: baseIndex,
                    to: ordered.firstIndex(of: left) ?? 0,
                    count: ordered.count
                ) > clockwiseDistance(
                    from: baseIndex,
                    to: ordered.firstIndex(of: right) ?? 0,
                    count: ordered.count
                )
            }
            return leftWeakness < rightWeakness
        }
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let result = value % divisor
        return result >= 0 ? result : result + divisor
    }

    private func clockwiseDistance(
        from: Int,
        to: Int,
        count: Int
    ) -> Int {
        positiveModulo(to - from, count)
    }
}
