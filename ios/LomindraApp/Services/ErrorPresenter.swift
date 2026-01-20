import Foundation

enum ErrorPresenter {
    static func userMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection."
            case NSURLErrorTimedOut:
                return "The request timed out."
            case NSURLErrorNetworkConnectionLost:
                return "The network connection was lost."
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
                return "Could not reach the server."
            case NSURLErrorSecureConnectionFailed:
                return "Secure connection failed. Check the server certificate."
            default:
                break
            }
        }
        if nsError.domain == "vikunja" {
            switch nsError.code {
            case 401, 403:
                return "Authentication failed. Please sign in again."
            case 404:
                return "Vikunja API endpoint not found. Check the server URL."
            case 429:
                return "Server is busy. Try again in a moment."
            default:
                if (500...599).contains(nsError.code) {
                    return "Vikunja is having trouble. Try again later."
                }
            }
        }
        return SafeLog.redact(nsError.localizedDescription)
    }
}
