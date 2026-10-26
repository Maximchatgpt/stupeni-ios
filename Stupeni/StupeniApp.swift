import SwiftUI

@main
struct StupeniApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            Theme.background.ignoresSafeArea()
            if app.session != nil {
                NavigationStack(path: $app.path) {
                    HomeView()
                        .navigationDestination(for: String.self) { id in
                            ChatView(lessonId: id)
                        }
                }
            } else if let err = app.bootError {
                VStack(spacing: 16) {
                    LogoMark(size: 56)
                    Text("Не удалось загрузить «Ступени»").font(.title3.bold())
                    Text(err).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Попробовать ещё раз") { Task { await app.boot() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding(32)
            } else {
                VStack(spacing: 14) {
                    LogoMark(size: 56)
                    ProgressView()
                }
            }
        }
        .overlay(alignment: .top) {
            if let t = app.toast {
                Text(t)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .glass(in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: app.toast)
        .sheet(isPresented: $app.showLogin) { LoginView() }
        .sheet(isPresented: $app.showHistory) { HistoryView() }
        .sheet(isPresented: $app.showAccount) { AccountView() }
        .task { await app.boot() }
    }
}
