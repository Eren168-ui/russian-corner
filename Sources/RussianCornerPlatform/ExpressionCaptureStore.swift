import Foundation
import RussianCornerCore

public struct ExpressionCaptureStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support
            .appendingPathComponent(
                "com.openclaw.russiancorner",
                isDirectory: true
            )
            .appendingPathComponent(
                "EnglishImportedExpressions.json"
            )
    }

    public func load() throws -> [ImportedExpression] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try JSONDecoder().decode(
            [ImportedExpression].self,
            from: Data(contentsOf: fileURL)
        )
    }

    public func save(_ expressions: [ImportedExpression]) throws {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(expressions)
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
    }

    @discardableResult
    public func append(
        _ expression: ImportedExpression
    ) throws -> ImportedExpression {
        var expressions = try load()
        expressions.removeAll { $0.id == expression.id }
        expressions.append(expression)
        try save(expressions)
        return expression
    }

    public func replace(_ expression: ImportedExpression) throws {
        var expressions = try load()
        guard let index = expressions.firstIndex(where: {
            $0.id == expression.id
        }) else {
            try append(expression)
            return
        }
        expressions[index] = expression
        try save(expressions)
    }

    public func practiceEligibleExpressions()
        throws -> [ImportedExpression]
    {
        try load().filter {
            $0.reviewStatus == .reviewed
                || $0.reviewStatus == .verified
        }
    }
}
