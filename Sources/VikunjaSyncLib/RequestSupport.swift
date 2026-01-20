import Foundation

struct VikunjaRetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let jitterRange: ClosedRange<Double>

    init(maxAttempts: Int = 3,
         baseDelay: TimeInterval = 0.8,
         maxDelay: TimeInterval = 6.0,
         jitterRange: ClosedRange<Double> = 0.85...1.15) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterRange = jitterRange
    }

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = pow(2.0, Double(max(0, attempt - 1)))
        let delay = min(maxDelay, baseDelay * exponent)
        let jitter = Double.random(in: jitterRange)
        return delay * jitter
    }
}

func shouldRetryVikunjaRequest(error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorNotConnectedToInternet:
            return true
        default:
            return false
        }
    }
    if nsError.domain == "vikunja" {
        if nsError.code == 429 {
            return true
        }
        if (500...599).contains(nsError.code) {
            return true
        }
    }
    return false
}

func redactSensitive(_ text: String, token: String) -> String {
    var result = text
    if !token.isEmpty {
        result = result.replacingOccurrences(of: token, with: "[redacted]")
    }
    result = redactBearerTokens(in: result)
    result = redactJSONTokens(in: result)
    return result
}

private let bearerRegex = try? NSRegularExpression(
    pattern: "(?i)Bearer\\s+[A-Za-z0-9\\-._~+/=]+",
    options: []
)
private let jsonTokenRegex = try? NSRegularExpression(
    pattern: "\"(token|jwt)\"\\s*:\\s*\"[^\"]*\"",
    options: [.caseInsensitive]
)

private func redactBearerTokens(in text: String) -> String {
    guard let regex = bearerRegex else { return text }
    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "Bearer [redacted]")
}

private func redactJSONTokens(in text: String) -> String {
    guard let regex = jsonTokenRegex else { return text }
    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\"$1\":\"[redacted]\"")
}
