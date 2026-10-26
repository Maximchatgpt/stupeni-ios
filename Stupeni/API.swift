import Foundation

/// Клиент того же API, что использует сайт. Вход держится на cookie-сессии (как в браузере),
/// а изменяющие запросы подписываются CSRF-токеном из ответа /session.
/// Ключей нейросетей в приложении нет — только адрес сайта.
final class API {
    static let shared = API()
    static let site = URL(string: "https://stupeni.maxsim.space")!

    private let base = API.site.appendingPathComponent("api")
    private var csrf = ""
    private let http: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 180   // ответы больших моделей бывают долгими
        config.timeoutIntervalForResource = 300
        http = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { var code: String?; var message: String? }
        var error: Body?
    }

    private struct CsrfProbe: Decodable { var csrf: String? }

    private func send<T: Decodable>(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" { req.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let result: (Data, URLResponse)
        do {
            result = try await http.data(for: req)
        } catch {
            throw APIError(status: 0, code: "network", message: "Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.")
        }
        let data = result.0
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        if let env = try? decoder.decode(ErrorEnvelope.self, from: data), let e = env.error {
            throw APIError(status: status, code: e.code ?? "error", message: e.message ?? "Что-то пошло не так. Попробуйте ещё раз.")
        }
        guard (200..<300).contains(status) else {
            throw APIError(status: status, code: "http", message: "Сервер ответил с ошибкой (\(status)). Попробуйте ещё раз.")
        }
        if let probe = try? decoder.decode(CsrfProbe.self, from: data), let token = probe.csrf, !token.isEmpty {
            csrf = token
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(status: status, code: "bad_json", message: "Сервер ответил неожиданно. Обновите приложение или попробуйте позже.")
        }
    }

    // MARK: - Сессия и вход

    func session() async throws -> SessionInfo { try await send("GET", "session") }

    struct Sent: Decodable { var sent: Bool?; var resendAfter: Int?; var ttlMinutes: Int? }
    func requestCode(email: String) async throws -> Sent { try await send("POST", "auth/request-code", ["email": email]) }
    func verify(email: String, code: String) async throws -> SessionInfo { try await send("POST", "auth/verify", ["email": email, "code": code]) }

    struct Empty: Decodable {}
    func logout() async throws { let _: Empty = try await send("POST", "auth/logout", [:]) }
    func setModel(_ key: String) async throws { let _: Empty = try await send("POST", "settings", ["model": key]) }

    // MARK: - Чаты

    func lessons() async throws -> [LessonSummary] {
        let list: LessonList = try await send("GET", "lessons")
        return list.lessons
    }
    func lesson(_ id: String) async throws -> Lesson { try await send("GET", "lessons/\(id)") }

    func createLesson(text: String, mode: String, requestId: String) async throws -> Lesson {
        try await send("POST", "lessons", ["source": "custom", "condition_text": text, "request_id": requestId, "mode": mode])
    }

    func message(_ id: String, text: String, requestId: String) async throws -> Lesson {
        try await send("POST", "lessons/\(id)/message", ["text": text, "request_id": requestId, "refs": [Any]()])
    }

    func retry(_ id: String) async throws -> Lesson { try await send("POST", "lessons/\(id)/retry", ["refs": [Any]()]) }
    func setAiMode(_ id: String, mode: String) async throws -> Lesson { try await send("POST", "lessons/\(id)/ai-mode", ["mode": mode]) }
    func setModel(_ id: String, model: String) async throws -> Lesson { try await send("POST", "lessons/\(id)/model", ["model": model]) }
    func deleteLesson(_ id: String) async throws { let _: Empty = try await send("POST", "lessons/\(id)/delete", [:]) }
}
