import Foundation

enum SafeLog {
    static func redact(_ text: String, tokens: [String] = []) -> String {
        var result = text
        for token in tokens where !token.isEmpty {
            result = result.replacingOccurrences(of: token, with: "[redacted]")
        }
        result = redactBearerTokens(in: result)
        result = redactJSONTokens(in: result)
        return result
    }

    private static let bearerRegex = try? NSRegularExpression(
        pattern: "(?i)Bearer\\s+[A-Za-z0-9\\-._~+/=]+",
        options: []
    )

    private static let jsonTokenRegex = try? NSRegularExpression(
        pattern: "\"(token|jwt)\"\\s*:\\s*\"[^\"]*\"",
        options: [.caseInsensitive]
    )

    private static func redactBearerTokens(in text: String) -> String {
        guard let regex = bearerRegex else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Bearer [redacted]")
    }

    private static func redactJSONTokens(in text: String) -> String {
        guard let regex = jsonTokenRegex else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\"$1\":\"[redacted]\"")
    }
}
