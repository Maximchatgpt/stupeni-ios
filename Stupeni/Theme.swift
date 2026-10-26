import SwiftUI
import UIKit

enum Theme {
    /// Оранжевый акцент сайта (кнопка отправки, микрофон, «Plus»).
    static let accent = Color(red: 1.0, green: 0.435, blue: 0.173)
    /// Тёплый светлый фон сайта; в тёмной теме — почти чёрный.
    static let background = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
            : UIColor(red: 0.969, green: 0.965, blue: 0.953, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
            : UIColor.white
    })
    static let userBubble = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.16, blue: 0.09, alpha: 1)
            : UIColor(red: 1.0, green: 0.937, blue: 0.898, alpha: 1)
    })
    static let logoGreen = Color(red: 0.50, green: 0.88, blue: 0.66)
    static let logoDark = Color(red: 0.12, green: 0.16, blue: 0.14)
}

extension View {
    /// Liquid Glass на iOS 26 (собранном Xcode 26); на более старых системах — обычное размытие.
    @ViewBuilder
    func glass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
        #endif
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var g = Glass.regular
    if let tint { g = g.tint(tint) }
    if interactive { g = g.interactive() }
    return g
}
#endif

/// Фирменный знак «Ступеней»: тёмная плитка с зелёными ступеньками.
struct LogoMark: View {
    var size: CGFloat = 36
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Theme.logoDark)
            .frame(width: size, height: size)
            .overlay(
                StepsShape()
                    .stroke(Theme.logoGreen, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.24)
            )
    }
}

struct StepsShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.33, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.33, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.66, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.66, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

/// Иконка модели — те же картинки, что на сайте.
struct ModelIcon: View {
    var vendor: String
    var size: CGFloat = 24
    var body: some View {
        Image("model-" + vendor)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(Circle().fill(Color(white: 0.94)))
            .clipShape(Circle())
    }
}
