import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var app
    let lessonId: String
    @State private var lesson: Lesson?
    @State private var text = ""
    @State private var busy = false
    @State private var sendingText: String?
    @State private var error: String?
    @State private var lockedAlert = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let lesson {
                        ForEach(lesson.messages) { m in
                            MessageView(message: m).id(m.id)
                        }
                    }
                    if let sendingText {
                        MessageView(message: Message(id: -1, role: "student", text: sendingText)).id(-1)
                    }
                    if busy || lesson?.pending == true && lesson?.chatFailed != true {
                        TypingIndicator().id(-2)
                    }
                    if let err = error ?? (lesson?.chatFailed == true ? lesson?.chatError?.message : nil) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(err).font(.subheadline).foregroundStyle(.secondary)
                            if lesson?.pending == true {
                                Button("Повторить ответ") { Task { await retry() } }
                                    .buttonStyle(.bordered)
                                    .disabled(busy)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                        .id(-3)
                    }
                    Color.clear.frame(height: 4).id(-9)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: lesson?.messages.count) { _, _ in scrollDown(proxy) }
            .onChange(of: busy) { _, _ in scrollDown(proxy) }
            .safeAreaInset(edge: .bottom) {
                Composer(
                    text: $text,
                    placeholder: lesson?.isPlain == true ? "Спросите что угодно…" : "Ваш ответ или вопрос…",
                    mode: lesson?.aiMode ?? "tutor",
                    model: lesson?.model,
                    busy: busy,
                    onModel: { key in Task { await setModel(key) } },
                    onSend: { Task { await send() } }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .background(HomeBackground())
        .navigationTitle(lesson?.chatTitle ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let lesson {
                    ModeSwitch(mode: lesson.aiMode ?? "tutor", extendedLocked: !app.extendedAvailable) { key in
                        Task { await setMode(key) }
                    }
                    .frame(width: 270)
                    .scaleEffect(0.86)
                }
            }
        }
        .alert("Нужна подписка", isPresented: $lockedAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Режим «Расширенный ИИ» доступен на тарифах Plus и Pro.")
        }
        .task { await load() }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(-9, anchor: .bottom) }
    }

    private func load() async {
        do {
            lesson = try await API.shared.lesson(lessonId)
            // Новый чат: сервер ждёт первого ответа модели — запрашиваем его, как сайт.
            if lesson?.pending == true && lesson?.chatFailed != true { await retry() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func retry() async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            lesson = try await API.shared.retry(lessonId)
        } catch {
            self.error = error.localizedDescription
            if let fresh = try? await API.shared.lesson(lessonId) { lesson = fresh }
        }
    }

    private func send() async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        busy = true; error = nil
        sendingText = t
        text = ""
        defer { busy = false; sendingText = nil }
        do {
            lesson = try await API.shared.message(lessonId, text: t, requestId: UUID().uuidString)
        } catch {
            self.error = error.localizedDescription
            if let fresh = try? await API.shared.lesson(lessonId) {
                lesson = fresh
            }
            let saved = lesson?.messages.contains(where: { $0.isUser && $0.text == t }) ?? false
            if !saved { text = t }   // сообщение не дошло — возвращаем текст в поле
        }
        await app.loadLessons()
    }

    private func setMode(_ key: String) async {
        if key == "plain" && !app.extendedAvailable { lockedAlert = true; return }
        do {
            lesson = try await API.shared.setAiMode(lessonId, mode: key)
            app.showToast(key == "plain" ? "Расширенный ИИ: обычная нейросеть без правил репетитора." : "Режим репетитора.")
        } catch {
            app.showToast(error.localizedDescription)
        }
    }

    private func setModel(_ key: String) async {
        do {
            lesson = try await API.shared.setModel(lessonId, model: key)
        } catch {
            app.showToast(error.localizedDescription)
        }
    }
}

struct MessageView: View {
    let message: Message

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 48)
                MathText(message.text ?? "")
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.userBubble))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    LogoMark(size: 22)
                    Text("Ступени").font(.subheadline.weight(.semibold))
                }
                MathText(message.text ?? "")
                ForEach(Array(message.charts.enumerated()), id: \.offset) { _, chart in
                    FunctionChartView(spec: chart)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 8) {
            LogoMark(size: 22)
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle().fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(0.3 + 0.7 * abs(sin(phase + Double(i) * 0.7)))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .glass(in: Capsule())
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi }
        }
    }
}
