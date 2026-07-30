import AppKit
import Foundation
import RussianCornerCore
import RussianCornerPlatform
import UniformTypeIdentifiers

@MainActor
public final class TrialReportExporter {
    private let appModel: AppModel
    private let fileManager: FileManager

    public init(
        appModel: AppModel,
        fileManager: FileManager = .default
    ) {
        self.appModel = appModel
        self.fileManager = fileManager
    }

    public func exportLastSevenDays(
        repository: any TrialDataStoring,
        endingAt now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let end = now
        let startOfToday = calendar.startOfDay(for: end)
        guard
            let start = calendar.date(
                byAdding: .day,
                value: -6,
                to: startOfToday
            )
        else {
            appModel.transientStatus = "无法计算 7 天报告周期"
            return
        }
        do {
            let snapshot = try repository.fetchSnapshot(
                from: start,
                through: end
            )
            let markdown = TrialReportBuilder(
                calendar: calendar
            ).markdown(
                snapshot: snapshot,
                range: start...end
            )
            let panel = NSSavePanel()
            panel.title = "导出近 7 天学习报告"
            panel.prompt = "导出"
            let productName =
                appModel.language == .english
                ? "英语角落卡" : "俄语角落卡"
            panel.nameFieldStringValue =
                "\(productName)-近7天学习报告-\(date(end, calendar: calendar)).md"
            panel.allowedContentTypes = [
                UTType(filenameExtension: "md") ?? .plainText,
            ]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.directoryURL = try? fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }
            try markdown.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )
            appModel.transientStatus =
                "近 7 天学习报告已导出：\(url.lastPathComponent)"
        } catch {
            appModel.transientStatus =
                "近 7 天学习报告导出失败：\(error.localizedDescription)"
        }
    }

    private func date(
        _ value: Date,
        calendar: Calendar
    ) -> String {
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
}
