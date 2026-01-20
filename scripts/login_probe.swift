import Foundation

struct LoginResponse: Decodable {
    let token: String
}

func normalizeBase(_ value: String) -> String {
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

func login(apiBase: String, username: String, password: String) async throws -> String {
    let payloads: [[String: Any]] = [
        ["username": username, "password": password],
        ["user": username, "password": password],
        ["login": username, "password": password]
    ]
    var lastError: Error?
    for payload in payloads {
        do {
            let data = try await request(apiBase: apiBase, method: "POST", path: "/login", token: nil, body: payload)
            if let response = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                return response.token
            }
            if let token = tokenFromJSON(data) {
                return token
            }
            lastError = NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected login response"])
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

func createToken(apiBase: String, jwt: String) async throws -> String {
    let payload = ["title": "iOS Sync"]
    let attempts: [(method: String, path: String)] = [
        ("PUT", "/tokens"),
        ("POST", "/user/token")
    ]
    var lastError: Error?
    for attempt in attempts {
        do {
            let data = try await request(apiBase: apiBase, method: attempt.method, path: attempt.path, token: jwt, body: payload)
            if let response = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                return response.token
            }
            if let token = tokenFromJSON(data) {
                return token
            }
            lastError = NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token was not returned by API"])
        } catch {
            lastError = error
        }
    }
    throw lastError ?? NSError(domain: "vikunja", code: 2, userInfo: [NSLocalizedDescriptionKey: "Token creation failed"])
}

func request(apiBase: String, method: String, path: String, token: String?, body: [String: Any]?) async throws -> Data {
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
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let message = String(data: data, encoding: .utf8) ?? ""
        throw NSError(domain: "vikunja", code: status, userInfo: [NSLocalizedDescriptionKey: "Bad response: \(message)"])
    }
    return data
}

func tokenFromJSON(_ data: Data) -> String? {
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

let env = ProcessInfo.processInfo.environment
guard let base = env["VIKUNJA_API_BASE"], !base.isEmpty else {
    fputs("Error: Missing VIKUNJA_API_BASE\n", stderr)
    exit(1)
}
guard let username = env["VIKUNJA_USERNAME"], !username.isEmpty else {
    fputs("Error: Missing VIKUNJA_USERNAME\n", stderr)
    exit(1)
}
guard let password = env["VIKUNJA_PASSWORD"], !password.isEmpty else {
    fputs("Error: Missing VIKUNJA_PASSWORD\n", stderr)
    exit(1)
}

let apiBase = normalizeBase(base)
let semaphore = DispatchSemaphore(value: 0)
var result: Result<String, Error> = .failure(NSError(domain: "probe", code: 2))
Task {
    do {
        let jwt = try await login(apiBase: apiBase, username: username, password: password)
        let token = try await createToken(apiBase: apiBase, jwt: jwt)
        result = .success(token)
    } catch {
        result = .failure(error)
    }
    semaphore.signal()
}
semaphore.wait()
switch result {
case .success(let token):
    print("Login succeeded. Token length: \(token.count)")
case .failure(let error):
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
