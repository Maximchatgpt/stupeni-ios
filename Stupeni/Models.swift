import Foundation

// Ответы API сайта stupeni.maxsim.space. Ключи приходят в snake_case — декодер переводит их в camelCase.
// Почти все поля необязательные: если сервер добавит или уберёт поле, приложение не сломается.

struct SessionInfo: Decodable {
    var csrf: String?
    var user: UserInfo?
    var settings: SettingsInfo?
    var models: [ModelInfo]?
    var extended: ExtendedInfo?
    var limits: LimitsInfo?
    var isNewUser: Bool?
}

struct UserInfo: Decodable {
    var email: String?
}

struct SettingsInfo: Decodable {
    var model: String?
}

struct ExtendedInfo: Decodable {
    var available: Bool?
}

struct LimitsInfo: Decodable {
    var tier: String?
    var models: [String: ModelLimit]?
}

struct ModelLimit: Decodable {
    var limit: Int?
    var used: Int?
    var remaining: Int?
    var extra: Int?
    var period: String?
}

struct ModelInfo: Decodable, Identifiable, Hashable {
    var key: String
    var title: String
    var requiresPlan: String?
    var available: Bool
    var extended: Bool
    var group: String?
    var id: String { key }

    /// Разработчик модели — по нему выбирается иконка.
    var vendor: String {
        let t = (title + " " + key + " " + (group ?? "")).lowercased()
        if t.contains("claude") { return "claude" }
        if t.contains("gemini") || t.contains("argon") { return "gemini" }
        if t.contains("qwen") { return "qwen" }
        return "openai"
    }

    /// Для чего модель подходит лучше всего — как на сайте.
    var summary: String {
        let t = (title + " " + key).lowercased()
        if t.contains("qwen") { return "Быстрая и экономная. Для простых вопросов, тренировки и проверки ответа." }
        if t.contains("luna") { return "Видит фото и PDF, объясняет по шагам. Основной выбор для заданий из учебника." }
        if t.contains("argon") || t.contains("gemini") { return "Сильна в математике и графиках, внимательно разбирает фото и большие PDF." }
        if t.contains("opus") { return "Самая умная Claude. Сложные рассуждения, большие документы, программирование." }
        if t.contains("sonnet") { return "Баланс ума и скорости. Тексты, учёба, разбор документов, код." }
        if t.contains("haiku") { return "Быстрая и недорогая. Короткие ответы и повседневные вопросы." }
        if t.contains("astra") { return "Флагман ChatGPT. Самые сложные задачи и глубокие рассуждения." }
        if t.contains("sol") {
            return extended
                ? "Универсальная ChatGPT: пишет, объясняет, решает задачи и разбирает фото."
                : "Сильнее в логике. Трудные задачи, доказательства и поиск ошибок в решении."
        }
        return vendor == "claude" ? "Модель Claude." : "Модель ChatGPT."
    }
}

struct LessonList: Decodable {
    var lessons: [LessonSummary]
}

struct LessonSummary: Decodable, Identifiable, Hashable {
    var id: String
    var title: String?
    var updatedAt: String?
}

struct Lesson: Decodable, Identifiable {
    var id: String
    var aiMode: String?
    var chatTitle: String?
    var chatFailed: Bool?
    var chatError: ChatError?
    var pending: Bool?
    var model: String?
    var messages: [Message]

    var isPlain: Bool { aiMode == "plain" }
}

struct ChatError: Decodable {
    var code: String?
    var message: String?
}

struct Message: Decodable, Identifiable {
    var id: Int
    var role: String
    var text: String?
    var charts: [ChartSpec] = []

    var isUser: Bool { role == "student" }

    private enum CodingKeys: String, CodingKey { case id, role, text, visual }
    private struct Visual: Decodable { var charts: [ChartSpec]? }

    init(id: Int, role: String, text: String?) {
        self.id = id; self.role = role; self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        // Графики необязательны: если формат неожиданный, сообщение всё равно покажется.
        charts = (try? c.decodeIfPresent(Visual.self, forKey: .visual))?.charts ?? []
    }
}

struct ChartSpec: Decodable, Hashable {
    var title: String?
    var functions: [ChartFunction]?
    var points: [ChartPoint]?
    var bounds: ChartBounds?
}

struct ChartFunction: Decodable, Hashable {
    var kind: String
    var a: Double?
    var b: Double?
    var c: Double?

    func value(at x: Double) -> Double {
        let a = a ?? 0, b = b ?? 0, c = c ?? 0
        switch kind {
        case "quadratic": return a * x * x + b * x + c
        case "cubic": return a * x * x * x
        default: return a * x + b
        }
    }

    var label: String {
        let a = a ?? 0, b = b ?? 0, c = c ?? 0
        func n(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%g", v) }
        func term(_ k: Double, _ s: String, first: Bool) -> String {
            if k == 0 { return "" }
            let sign = k < 0 ? (first ? "−" : " − ") : (first ? "" : " + ")
            let mag = abs(k)
            let coef = (mag == 1 && !s.isEmpty) ? "" : n(mag)
            return sign + coef + s
        }
        var out = ""
        switch kind {
        case "quadratic":
            out = term(a, "x²", first: true)
            out += term(b, "x", first: out.isEmpty)
            out += term(c, "", first: out.isEmpty)
        case "cubic":
            out = term(a, "x³", first: true)
        default:
            out = term(a, "x", first: true)
            out += term(b, "", first: out.isEmpty)
        }
        return "y = " + (out.isEmpty ? "0" : out)
    }
}

struct ChartPoint: Decodable, Hashable {
    var x: Double
    var y: Double
    var label: String?
}

struct ChartBounds: Decodable, Hashable {
    var xMin: Double
    var xMax: Double
    var yMin: Double
    var yMax: Double
}

/// Ошибка API с понятным текстом от сервера.
struct APIError: LocalizedError {
    var status: Int
    var code: String
    var message: String
    var errorDescription: String? { message }
}
