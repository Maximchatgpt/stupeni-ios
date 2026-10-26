import SwiftUI

/// Стартовый экран: приветствие и поле для первого сообщения — как главная страница сайта.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @State private var requestId = UUID().uuidString
    @State private var lockedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ModeSwitch(mode: app.homeMode, extendedLocked: !app.extendedAvailable) { key in
                if key == "plain" && !app.extendedAvailable {
                    lockedAlert = true
                } else {
                    app.homeMode = key
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            Spacer()
            HStack(spacing: 12) {
                LogoMark(size: 40)
                Text(verbatim: app.homeMode == "plain" ? "Спросите что угодно" : "Привет! Что разберём сегодня?")
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .multilineTextAlignment(.leading)
            Spacer()

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
            Composer(
                text: $text,
                placeholder: app.homeMode == "plain" ? "Спросите что угодно…" : "Напишите сообщение или условие задачи…",
                mode: app.homeMode,
                model: homeModel,
                busy: busy,
                onModel: { key in Task { await app.pickHomeModel(key) } },
                onSend: { Task { await start() } }
            )
            .padding(.horizontal, 14)
            Text(verbatim: app.homeMode == "plain" ? "Обычная нейросеть без правил репетитора." : "Помогу разобраться в алгебре — шаг за шагом.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(HomeBackground())
        .alert("Нужна подписка", isPresented: $lockedAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Режим «Расширенный ИИ» с моделями Claude и ChatGPT доступен на тарифах Plus и Pro. Оформить тариф можно на сайте в разделе «Тарифы и баланс».")
        }
    }

    /// Модель для нового чата: выбранная в настройках, если она подходит к режиму, иначе первая доступная.
    private var homeModel: String? {
        let list = app.models(for: app.homeMode)
        if list.contains(where: { $0.key == app.currentModelKey }) { return app.currentModelKey }
        return list.first(where: { $0.available })?.key ?? list.first?.key
    }

    private func start() async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            if let m = homeModel, m != app.currentModelKey {
                try await API.shared.setModel(m)
            }
            let lesson = try await API.shared.createLesson(text: t, mode: app.homeMode, requestId: requestId)
            text = ""
            requestId = UUID().uuidString
            app.open(lesson.id)
            await app.loadLessons()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TopBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Button { app.showHistory = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .glass(in: Circle(), interactive: true)
            }
            .accessibilityLabel("Мои чаты")
            VStack(alignment: .leading, spacing: 0) {
                Text("Ступени").font(.headline)
                Text("Алгебра · 7 класс").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if app.isLoggedIn { app.showAccount = true } else { app.showLogin = true }
            } label: {
                Group {
                    if app.isLoggedIn {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 20))
                    } else {
                        Text("Войти").font(.subheadline.weight(.semibold)).padding(.horizontal, 6)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, app.isLoggedIn ? 0 : 8)
                .glass(in: Capsule(), interactive: true)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/// Мягкие цветные пятна за стеклом — чтобы Liquid Glass было что преломлять.
struct HomeBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            Circle().fill(Theme.accent.opacity(0.22)).frame(width: 420).blur(radius: 90).offset(x: 150, y: 330)
            Circle().fill(Color.purple.opacity(0.12)).frame(width: 360).blur(radius: 90).offset(x: -160, y: -260)
            Circle().fill(Theme.logoGreen.opacity(0.14)).frame(width: 300).blur(radius: 80).offset(x: -120, y: 220)
        }
        .ignoresSafeArea()
    }
}
