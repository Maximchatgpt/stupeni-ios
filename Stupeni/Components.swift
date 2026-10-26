import SwiftUI

/// Переключатель «Репетитор / Расширенный ИИ» — стеклянная капсула со скользящей подсветкой, как на сайте.
struct ModeSwitch: View {
    var mode: String
    var extendedLocked: Bool
    var onChange: (String) -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            segment("tutor", title: "Репетитор", badge: nil)
            segment("plain", title: "Расширенный ИИ", badge: extendedLocked ? "Plus" : nil)
        }
        .padding(4)
        .glass(in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: mode)
    }

    private func segment(_ key: String, title: String, badge: String?) -> some View {
        Button {
            if key != mode { onChange(key) }
        } label: {
            HStack(spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            .foregroundStyle(key == mode ? Color.primary : Color.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                if key == mode {
                    Capsule().fill(Theme.card)
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "pill", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Меню выбора модели: иконка, название, описание, замок для недоступных — как на сайте.
struct ModelMenu: View {
    @Environment(AppState.self) private var app
    var mode: String
    var selected: String?
    var onPick: (String) -> Void

    var body: some View {
        let list = app.models(for: mode)
        let current = app.model(selected) ?? list.first
        Menu {
            if mode == "plain" {
                let groups = Array(Set(list.compactMap(\.group))).sorted()
                ForEach(groups, id: \.self) { g in
                    Section(g) { ForEach(list.filter { $0.group == g }) { item($0) } }
                }
                let rest = list.filter { $0.group == nil }
                if !rest.isEmpty { Section { ForEach(rest) { item($0) } } }
            } else {
                ForEach(list) { item($0) }
            }
        } label: {
            HStack(spacing: 7) {
                ModelIcon(vendor: current?.vendor ?? "qwen", size: 22)
                Text(current?.title ?? "Модель")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 8)
            .glass(in: Capsule(), interactive: true)
        }
    }

    @ViewBuilder
    private func item(_ m: ModelInfo) -> some View {
        Button {
            onPick(m.key)
        } label: {
            Label {
                Text(m.title + (m.key == selected ? "  ✓" : ""))
                Text(m.available ? m.summary : "Нужен тариф " + (m.requiresPlan ?? "Plus").capitalized + ". " + m.summary)
            } icon: {
                if m.available {
                    Image("model-" + m.vendor)
                } else {
                    Image(systemName: "lock.fill")
                }
            }
        }
        .disabled(!m.available)
    }
}

/// Поле ввода сообщения в стеклянной карточке: текст, модель, отправка.
struct Composer: View {
    @Binding var text: String
    var placeholder: String
    var mode: String
    var model: String?
    var busy: Bool
    var onModel: (String) -> Void
    var onSend: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...7)
                .focused($focused)
                .font(.body)
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .submitLabel(.return)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ModelMenu(mode: mode, selected: model, onPick: onModel)
                Button(action: send) {
                    ZStack {
                        Circle().fill(canSend || busy ? Theme.accent : Theme.accent.opacity(0.45))
                        if busy {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 42, height: 42)
                }
                .disabled(!canSend)
                .accessibilityLabel("Отправить сообщение")
            }
        }
        .padding(12)
        .glass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var canSend: Bool { !busy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        focused = false
        onSend()
    }
}
