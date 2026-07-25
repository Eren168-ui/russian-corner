public struct DailyQueueBuilder: Sendable {
    public init() {}

    public func build(
        due: [PracticeItem],
        new: [PracticeItem],
        randomReview: [PracticeItem],
        targetCount: Int,
        retryIDs: Set<String>
    ) -> [PracticeItem] {
        guard targetCount > 0 else {
            return []
        }

        let dueTarget = Int((Double(targetCount) * 0.6).rounded())
        let newTarget = Int((Double(targetCount) * 0.3).rounded(.down))
        let randomTarget = max(0, targetCount - dueTarget - newTarget)

        var seenSuccessfulIDs: Set<String> = []
        var dueCursor = 0
        var newCursor = 0
        var randomCursor = 0
        var dueItems: [PracticeItem] = []
        var newItems: [PracticeItem] = []
        var randomItems: [PracticeItem] = []

        take(
            dueTarget,
            from: due,
            cursor: &dueCursor,
            into: &dueItems,
            retryIDs: retryIDs,
            seenSuccessfulIDs: &seenSuccessfulIDs
        )
        take(
            newTarget,
            from: new,
            cursor: &newCursor,
            into: &newItems,
            retryIDs: retryIDs,
            seenSuccessfulIDs: &seenSuccessfulIDs
        )
        take(
            randomTarget,
            from: randomReview,
            cursor: &randomCursor,
            into: &randomItems,
            retryIDs: retryIDs,
            seenSuccessfulIDs: &seenSuccessfulIDs
        )

        while dueItems.count + newItems.count + randomItems.count < targetCount {
            let countBeforeBackfill =
                dueItems.count + newItems.count + randomItems.count

            take(
                targetCount - countBeforeBackfill,
                from: due,
                cursor: &dueCursor,
                into: &dueItems,
                retryIDs: retryIDs,
                seenSuccessfulIDs: &seenSuccessfulIDs
            )
            take(
                targetCount - dueItems.count - newItems.count - randomItems.count,
                from: new,
                cursor: &newCursor,
                into: &newItems,
                retryIDs: retryIDs,
                seenSuccessfulIDs: &seenSuccessfulIDs
            )
            take(
                targetCount - dueItems.count - newItems.count - randomItems.count,
                from: randomReview,
                cursor: &randomCursor,
                into: &randomItems,
                retryIDs: retryIDs,
                seenSuccessfulIDs: &seenSuccessfulIDs
            )

            let countAfterBackfill =
                dueItems.count + newItems.count + randomItems.count
            if countAfterBackfill == countBeforeBackfill {
                break
            }
        }

        return Array(
            (dueItems + newItems + randomItems).prefix(targetCount)
        )
    }

    private func take(
        _ requestedCount: Int,
        from source: [PracticeItem],
        cursor: inout Int,
        into destination: inout [PracticeItem],
        retryIDs: Set<String>,
        seenSuccessfulIDs: inout Set<String>
    ) {
        guard requestedCount > 0 else {
            return
        }

        let targetSize = destination.count + requestedCount
        while cursor < source.count && destination.count < targetSize {
            let item = source[cursor]
            cursor += 1

            if retryIDs.contains(item.id) {
                destination.append(item)
            } else if seenSuccessfulIDs.insert(item.id).inserted {
                destination.append(item)
            }
        }
    }
}
