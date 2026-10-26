import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    var session: SessionInfo?
    var bootError: String?
    var lessons: [LessonSummary] = []
    var path: [String] = []          // открытые чаты (id)
    var homeMode = "tutor"           // tutor | plain
    var showLogin = false
    var showHistory = false
    var showAccount = false
    var toast: String?

    var isLoggedIn: Bool { session?.user != nil }
    var extendedAvailable: Bool { session?.extended?.available ?? false }
    var models: [ModelInfo] { session?.models ?? [] }
    var currentModelKey: String { session?.settings?.model ?? "qwen" }

    func models(for mode: String) -> [ModelInfo] {
        models.filter { $0.extended == (mode == "plain") }
    }

    func model(_ key: String?) -> ModelInfo? {
        models.first { $0.key == key }
    }

    func remaining(_ key: String) -> ModelLimit? { session?.limits?.models?[key] }

    func boot() async {
        bootError = nil
        do {
            session = try await API.shared.session()
            await loadLessons()
        } catch {
            bootError = error.localizedDescription
        }
    }

    func refreshSession() async {
        if let s = try? await API.shared.session() { session = s }
    }

    func loadLessons() async {
        if let list = try? await API.shared.lessons() { lessons = list }
    }

    func signedIn(_ s: SessionInfo) async {
        session = s
        showToast(s.isNewUser == true ? "Аккаунт создан. Добро пожаловать!" : "Вы вошли.")
        await refreshSession()
        await loadLessons()
    }

    func logout() async {
        try? await API.shared.logout()
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        path = []
        await boot()
        showToast("Вы вышли из аккаунта.")
    }

    func pickHomeModel(_ key: String) async {
        do {
            try await API.shared.setModel(key)
            await refreshSession()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func open(_ id: String) {
        path = [id]
    }

    func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast == text { toast = nil }
        }
    }
}
