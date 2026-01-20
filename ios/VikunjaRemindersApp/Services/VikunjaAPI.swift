import Foundation

struct VikunjaProject: Identifiable, Hashable, Decodable {
    let id: Int
    let title: String
}

final class VikunjaAPI {
    private let apiBase: String
    private let session: URLSession

    init(apiBase: String) {
        self.apiBase = VikunjaAPI.normalizeBase(apiBase)
        let delegate = InsecureSessionDelegate()
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    func login(username: String, password: String) async throws -> String {
        let payloads: [[String: Any]] = [
            ["username": username, "password": password],
            ["user": username, "password": password],
            ["login": username, "password": password]
        ]
        var lastError: Error?
        for payload in payloads {
            do {
                let data = try await request(method: "POST", path: "/login", token: nil, body: payload)
                if let response = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                    return response.token
                }
                if let token = tokenFromJSON(data) {
                    return token
                }
                lastError = NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected login response: \(responseSnippet(data))"])
                continue
            } catch {
                lastError = error
                let message = (error as NSError).localizedDescription
                if !message.contains("Struct is invalid") && !message.contains("Invalid Data") {
                    throw error
                }
            }
        }
        throw lastError ?? NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Login failed"])
    }

    func createAPIToken(jwt: String, title: String) async throws -> String {
        let payload = ["title": title]
        let attempts: [(method: String, path: String)] = [
            ("PUT", "/tokens"),
            ("POST", "/user/token")
        ]
        var lastError: Error?
        for attempt in attempts {
            do {
                let data = try await request(method: attempt.method, path: attempt.path, token: jwt, body: payload)
                if let response = try? JSONDecoder().decode(APITokenResponse.self, from: data),
                   let token = response.token {
                    return token
                }
                if let token = tokenFromJSON(data) {
                    return token
                }
                lastError = NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token was not returned by API: \(responseSnippet(data))"])
            } catch {
                lastError = error
            }
        }
        throw lastError ?? NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token creation failed"])
    }

    func fetchProjects(token: String) async throws -> [VikunjaProject] {
        let data = try await request(method: "GET", path: "/projects", token: token, body: nil)
        if let projects = try? JSONDecoder().decode([VikunjaProject].self, from: data) {
            return projects
        }
        if let response = try? JSONDecoder().decode(ProjectsResponse.self, from: data) {
            return response.projects ?? response.data ?? response.results ?? []
        }
        throw NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected projects response: \(responseSnippet(data))"])
    }

    private func request(method: String, path: String, token: String?, body: [String: Any]?) async throws -> Data {
        let url = URL(string: "\(apiBase)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "vikunja", code: status, userInfo: [NSLocalizedDescriptionKey: "Bad response: \(message)"])
        }
        return data
    }

    static func normalizeBase(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix("/api/v1") {
            return trimmed
        }
        if trimmed.hasSuffix("/api") {
            return "\(trimmed)/v1"
        }
        return "\(trimmed)/api/v1"
    }

    private func tokenFromJSON(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let token = json["token"] as? String {
            return token
        }
        if let token = json["jwt"] as? String {
            return token
        }
        return nil
    }

    private func responseSnippet(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return "non-text response"
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 200)
        return "\(trimmed[..<index])…"
    }
}

private struct TokenResponse: Decodable {
    let token: String
}

private struct APITokenResponse: Decodable {
    let id: Int
    let title: String
    let token: String?
}

private struct ProjectsResponse: Decodable {
    let projects: [VikunjaProject]?
    let data: [VikunjaProject]?
    let results: [VikunjaProject]?
}

private final class InsecureSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    private func handle(challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
