import SwiftUI

/// Вход по почте: код из письма. Ссылку «Войти в «Ступени»» из письма можно тоже вставить в поле кода.
struct LoginView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var step = 0          // 0 — почта, 1 — код
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    LogoMark(size: 44)
                    VStack(alignment: .leading) {
                        Text("Вход по почте").font(.title2.bold())
                        Text(verbatim: step == 0 ? "Пришлём код из шести цифр." : "Код отправлен на \(email)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if step == 0 {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .glass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    TextField("Код или ссылка из письма", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.title3.monospacedDigit())
                        .padding(14)
                        .glass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onChange(of: code) { _, v in fillFromLink(v) }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                if let info { Text(info).font(.footnote).foregroundStyle(.secondary) }

                Button { Task { await primary() } } label: {
                    HStack {
                        if busy { ProgressView().tint(.white) }
                        Text(verbatim: step == 0 ? "Получить код" : "Войти").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
                }
                .disabled(busy)

                if step == 1 {
                    HStack {
                        Button("Отправить ещё раз") { Task { await requestCode() } }
                        Spacer()
                        Button("Другой адрес") { step = 0; code = ""; error = nil; info = nil }
                    }
                    .font(.subheadline)
                }
                Spacer()
            }
            .padding(22)
            .background(HomeBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func primary() async {
        if step == 0 { await requestCode() } else { await verify() }
    }

    private func requestCode() async {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard e.contains("@") else { error = "Введите адрес почты."; return }
        busy = true; error = nil; info = nil
        defer { busy = false }
        do {
            _ = try await API.shared.requestCode(email: e)
            email = e
            step = 1
            info = "Письмо обычно приходит за минуту. Проверьте «Спам», если его нет."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func verify() async {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { error = "Введите шесть цифр из письма."; return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let s = try await API.shared.verify(email: email, code: digits)
            await app.signedIn(s)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Вставили ссылку из письма (…?login=<почта>.<код>) — достаём из неё код.
    private func fillFromLink(_ v: String) {
        guard v.contains("login="), let r = v.range(of: "login=") else { return }
        let token = v[r.upperBound...].prefix { $0 != "&" && $0 != "#" }
        let parts = token.split(separator: ".")
        guard let last = parts.last, last.count == 6, last.allSatisfy(\.isNumber) else { return }
        code = String(last)
    }
}

struct HistoryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        app.path = []
                        dismiss()
                    } label: {
                        Label("Новый чат", systemImage: "square.and.pencil")
                    }
                }
                Section(header: Text(verbatim: app.isLoggedIn ? "Мои чаты" : "Чаты этого устройства")) {
                    if app.lessons.isEmpty {
                        Text("Пока нет чатов.").foregroundStyle(.secondary)
                    }
                    ForEach(app.lessons) { l in
                        Button {
                            app.open(l.id)
                            dismiss()
                        } label: {
                            Text(l.title?.isEmpty == false ? l.title! : "Чат")
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .onDelete { idx in
                        let ids = idx.map { app.lessons[$0].id }
                        Task {
                            for id in ids { try? await API.shared.deleteLesson(id) }
                            await app.loadLessons()
                        }
                    }
                }
                if !app.isLoggedIn {
                    Section {
                        Button("Войти, чтобы сохранять чаты") {
                            dismiss()
                            app.showLogin = true
                        }
                    }
                }
            }
            .navigationTitle("Ступени")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
            .refreshable { await app.loadLessons() }
        }
        .task { await app.loadLessons() }
    }
}

struct AccountView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Аккаунт") {
                    LabeledContent("Почта", value: app.session?.user?.email ?? "—")
                    LabeledContent("Тариф", value: tierTitle)
                }
                Section("Осталось запросов") {
                    ForEach(app.models.filter { $0.available }) { m in
                        HStack(spacing: 10) {
                            ModelIcon(vendor: m.vendor, size: 26)
                            Text(m.title)
                            Spacer()
                            Text(remainingText(m)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Link("Тарифы и баланс на сайте", destination: API.site)
                    Button("Выйти", role: .destructive) {
                        Task { await app.logout(); dismiss() }
                    }
                }
            }
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
        .task { await app.refreshSession() }
    }

    private var tierTitle: String {
        switch app.session?.limits?.tier ?? "free" {
        case "lite": return "Lite"
        case "go": return "Go"
        case "plus": return "Plus"
        case "pro": return "Pro"
        default: return "Бесплатный"
        }
    }

    private func remainingText(_ m: ModelInfo) -> String {
        guard let l = app.remaining(m.key) else { return "" }
        if l.limit == nil { return "без ограничений" }
        let period = l.period == "week" ? "в неделю" : "сегодня"
        return "\(l.remaining ?? 0) \(period)"
    }
}
