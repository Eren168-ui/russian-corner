import Foundation

public struct TrialReportBuilder: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func markdown(
        snapshot: TrialReportSnapshot,
        range: ClosedRange<Date>
    ) -> String {
        let sessions = snapshot.sessions
            .filter { range.contains($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
        let interactions = snapshot.interactions
            .filter { range.contains($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }
        let reflections = snapshot.reflections
            .filter { range.contains($0.day) }
            .sorted { $0.day < $1.day }
        let oralAttempts = snapshot.oralAttempts
            .filter { range.contains($0.attemptedAt) }
            .sorted { $0.attemptedAt < $1.attemptedAt }
        let graded = interactions.filter {
            $0.kind == .grade && $0.grade != nil
        }
        let periodDays = max(
            1,
            (calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: range.lowerBound),
                to: calendar.startOfDay(for: range.upperBound)
            ).day ?? 0) + 1
        )
        let usageDays = Set(
            graded.map { calendar.startOfDay(for: $0.createdAt) }
                + reflections.map {
                    calendar.startOfDay(for: $0.day)
                }
        )
        let completion = completionSummary(
            sessions: sessions,
            graded: graded
        )
        let totalDurationMs = sessions.reduce(0) {
            $0 + $1.durationMs
        }

        var lines: [String] = [
            "# 俄语角落卡｜近 7 天学习报告",
            "",
            "报告周期：\(date(range.lowerBound)) 至 \(date(range.upperBound))",
            "",
            "> 客观数据来自本地练习记录；“每日反馈”部分是你自己填写的主观感受。本报告只呈现事实，不自动生成学习建议。",
            "",
            "## 使用概览",
            "",
            "- 使用天数：\(usageDays.count) / \(periodDays)",
            "- 完成量：\(completion.completed) / \(completion.target)（\(percent(completion.completed, of: completion.target))）",
            "- 有效练习时长：\(duration(totalDurationMs))",
            "- 完整会话：\(sessions.count) 次",
            "",
        ]
        lines.append(contentsOf: dailyUsageLines(
            range: range,
            sessions: sessions,
            graded: graded,
            reflections: reflections
        ))
        lines.append(contentsOf: [
            "",
            "## 主动提取",
            "",
        ])
        if graded.isEmpty {
            lines.append("本周期暂无评分记录。")
        } else {
            lines.append(contentsOf: [
                "- 俄语识义：\(successText(for: .recognition, in: graded))",
                "- 中文提示说俄语：\(successText(for: .production, in: graded))",
                "- 场景句输出：\(successText(for: .sentenceProduction, in: graded))",
                "- 评分反应时间中位数：\(medianResponseTime(graded))",
                "- Again / Hard / Easy：\(gradeCount(.again, in: graded)) / \(gradeCount(.hard, in: graded)) / \(gradeCount(.easy, in: graded))",
            ])
        }
        lines.append(contentsOf: [
            "",
            "## 复习与积压",
            "",
            "- 新项尝试：\(sessions.reduce(0) { $0 + $1.newItemCount })",
            "- 复习项尝试：\(sessions.reduce(0) { $0 + $1.reviewItemCount })",
            "- 期末待复习积压：\(sessions.last?.remainingBacklogCount ?? 0)",
            "",
            "会话结束方式：",
        ])
        for reason in TrialSessionEndReason.allCasesForReport {
            lines.append(
                "- \(reason.titleZh)：\(sessions.filter { $0.endReason == reason }.count) 次"
            )
        }
        lines.append(contentsOf: [
            "",
            "## 使用行为",
            "",
            "- 查看详情：\(flagUsage(\.openedDetails, in: graded))",
            "- 主动朗读：\(flagUsage(\.usedSpeech, in: graded))",
            "- 主动跳到下一项：\(interactions.filter { $0.kind == .next }.count) 次",
            "- 主动揭晓答案：\(interactions.filter { $0.kind == .reveal }.count) 次",
            "",
            "## 每日反馈",
            "",
            "> 以下内容为你主动填写的原话摘要。",
            "",
        ])
        if reflections.isEmpty {
            lines.append("本周期暂无每日反馈。")
        } else {
            for reflection in reflections {
                lines.append("### \(date(reflection.day))")
                lines.append("")
                lines.append("- 最卡：\(textOrDash(reflection.mostBlocked))")
                lines.append(
                    "- 脱口而出：\(naturalSpeechText(reflection.spokeNaturally))；\(textOrDash(reflection.spokeNaturallyNote))"
                )
                lines.append(
                    "- 完成情况：\(reflection.completionReason.titleZh)；\(textOrDash(reflection.completionReasonNote))"
                )
                lines.append("")
            }
            if lines.last == "" {
                lines.removeLast()
            }
        }
        lines.append(contentsOf: [
            "",
            "## 口述活动",
            "",
        ])
        if oralAttempts.isEmpty {
            lines.append("本周期尚未进行口述活动。")
        } else {
            for attempt in oralAttempts {
                var metrics = [
                    "计时 \(duration(attempt.elapsedMs))",
                    "自评 \(attempt.selfRating) / 5",
                ]
                if let speaking = attempt.estimatedSpeakingMs {
                    metrics.insert(
                        "估算开口 \(duration(speaking))",
                        at: 1
                    )
                }
                if let pauses = attempt.longPauseCount {
                    metrics.insert("估算长停顿 \(pauses) 次", at: metrics.count - 1)
                }
                let meter = attempt.usedMicrophoneMeter
                    ? "使用麦克风活动估算，未保存音频"
                    : "仅计时与自评"
                lines.append(
                    "- \(date(attempt.attemptedAt)) · \(textOrDash(attempt.topic))：\(metrics.joined(separator: "；"))；\(meter)"
                )
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func completionSummary(
        sessions: [TrialSession],
        graded: [TrialInteraction]
    ) -> (completed: Int, target: Int) {
        let sessionsByDay = Dictionary(
            grouping: sessions,
            by: { calendar.startOfDay(for: $0.startedAt) }
        )
        let gradesByDay = Dictionary(
            grouping: graded,
            by: { calendar.startOfDay(for: $0.createdAt) }
        )
        let allDays = Set(sessionsByDay.keys).union(gradesByDay.keys)
        var completed = 0
        var target = 0
        for day in allDays {
            let successfulKeys = Set<String>(
                (gradesByDay[day] ?? []).compactMap { interaction in
                    guard interaction.grade != .again else { return nil }
                    return itemKey(interaction)
                }
            )
            let dailyTarget = sessionsByDay[day]?
                .map(\.startQueueCount)
                .max() ?? successfulKeys.count
            completed += min(successfulKeys.count, dailyTarget)
            target += dailyTarget
        }
        return (completed, target)
    }

    private func dailyUsageLines(
        range: ClosedRange<Date>,
        sessions: [TrialSession],
        graded: [TrialInteraction],
        reflections: [DailyReflection]
    ) -> [String] {
        let sessionsByDay = Dictionary(
            grouping: sessions,
            by: { calendar.startOfDay(for: $0.startedAt) }
        )
        let gradesByDay = Dictionary(
            grouping: graded,
            by: { calendar.startOfDay(for: $0.createdAt) }
        )
        let reflectionDays = Set(
            reflections.map { calendar.startOfDay(for: $0.day) }
        )
        let usedDays = Set(sessionsByDay.keys)
            .union(gradesByDay.keys)
            .union(reflectionDays)
            .sorted()
        guard !usedDays.isEmpty else {
            return ["### 每日记录", "", "本周期没有产生练习日记录。"]
        }
        var lines = ["### 每日记录", ""]
        for day in usedDays where range.contains(day) {
            let daySessions = sessionsByDay[day] ?? []
            let dayGrades = gradesByDay[day] ?? []
            let success = Set(dayGrades.compactMap {
                $0.grade == .again ? nil : itemKey($0)
            }).count
            let target = daySessions.map(\.startQueueCount).max()
                ?? success
            let time = daySessions.reduce(0) { $0 + $1.durationMs }
            lines.append("### \(date(day))")
            lines.append("")
            lines.append(
                "- 完成 \(success) / \(target)；评分 \(dayGrades.count) 次；用时 \(duration(time))"
            )
        }
        return lines
    }

    private func successText(
        for direction: TrialPromptDirection,
        in graded: [TrialInteraction]
    ) -> String {
        let matching = graded.filter { $0.direction == direction }
        let successful = matching.filter { $0.grade != .again }.count
        return "\(successful) / \(matching.count)（\(percent(successful, of: matching.count))）"
    }

    private func medianResponseTime(
        _ graded: [TrialInteraction]
    ) -> String {
        let values = graded.compactMap(\.responseTimeMs).sorted()
        guard !values.isEmpty else { return "无数据" }
        let median: Double
        if values.count.isMultiple(of: 2) {
            let upper = values.count / 2
            median = Double(values[upper - 1] + values[upper]) / 2
        } else {
            median = Double(values[values.count / 2])
        }
        return seconds(median)
    }

    private func flagUsage(
        _ keyPath: KeyPath<TrialInteraction, Bool>,
        in graded: [TrialInteraction]
    ) -> String {
        let grouped = Dictionary(grouping: graded, by: itemKey)
        let flagged = grouped.values.filter {
            $0.contains { $0[keyPath: keyPath] }
        }.count
        return "\(flagged) / \(grouped.count) 张评分卡（\(percent(flagged, of: grouped.count))）"
    }

    private func gradeCount(
        _ grade: ReviewGrade,
        in graded: [TrialInteraction]
    ) -> Int {
        graded.filter { $0.grade == grade }.count
    }

    private func itemKey(_ interaction: TrialInteraction) -> String {
        "\(interaction.itemType.rawValue):\(interaction.itemID)"
    }

    private func date(_ value: Date) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: value
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func percent(_ numerator: Int, of denominator: Int) -> String {
        guard denominator > 0 else { return "0%" }
        let value = Int(
            (Double(numerator) / Double(denominator) * 100).rounded()
        )
        return "\(value)%"
    }

    private func duration(_ milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        if totalSeconds < 60 {
            return "\(totalSeconds) 秒"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds == 0
            ? "\(minutes) 分钟"
            : "\(minutes) 分 \(seconds) 秒"
    }

    private func seconds(_ milliseconds: Double) -> String {
        let value = milliseconds / 1_000
        if value.rounded() == value {
            return String(format: "%.0f 秒", value)
        }
        return String(format: "%.1f 秒", value)
    }

    private func naturalSpeechText(_ value: Bool?) -> String {
        switch value {
        case true: "是"
        case false: "否"
        case nil: "不确定"
        }
    }

    private func textOrDash(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return singleLine.isEmpty ? "未填写" : singleLine
    }
}

private extension TrialSessionEndReason {
    static let allCasesForReport: [Self] = [
        .completed,
        .hidden,
        .quit,
        .dayChanged,
        .idle,
    ]

    var titleZh: String {
        switch self {
        case .completed: "完成"
        case .hidden: "隐藏卡片"
        case .quit: "退出应用"
        case .dayChanged: "跨日刷新"
        case .idle: "空闲超时"
        }
    }
}
