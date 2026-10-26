import SwiftUI
import Charts

/// Текст ответа: Markdown (жирный, курсив, списки) и формулы LaTeX между $…$,
/// переведённые в читаемую запись: дроби a/b, степени x², корни √, знаки ≤ ≥ ≠ · и т. д.
struct MathText: View {
    let source: String
    init(_ source: String) { self.source = source }

    var body: some View {
        Text(Self.render(source))
            .font(.body)
            .lineSpacing(3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func render(_ raw: String) -> AttributedString {
        var text = convertMath(raw)
        // Заголовки и списки Markdown — построчно, остальное понимает AttributedString.
        text = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var l = String(line)
            if let r = l.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                l = "**" + String(l[r.upperBound...]) + "**"
            } else if let r = l.range(of: "^\\s*[-*•]\\s+", options: .regularExpression) {
                l = "•  " + String(l[r.upperBound...])
            }
            return l
        }.joined(separator: "\n")
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: opts)) ?? AttributedString(text)
    }

    // MARK: - LaTeX → Unicode

    static func convertMath(_ s: String) -> String {
        var out = s
        for pattern in ["\\$\\$([\\s\\S]+?)\\$\\$", "\\\\\\[([\\s\\S]+?)\\\\\\]", "\\\\\\(([\\s\\S]+?)\\\\\\)", "\\$([^$\\n]+?)\\$"] {
            out = replace(out, pattern) { latex($0[1]) }
        }
        return out
    }

    /// Команды LaTeX целиком (без «\»): заменяем по имени, поэтому \le не задевает \left, а \in — \infty.
    private static let commands: [String: String] = [
        "cdot": "·", "times": "×", "div": "÷", "pm": "±", "mp": "∓",
        "leq": "≤", "le": "≤", "leqslant": "≤", "geq": "≥", "ge": "≥", "geqslant": "≥", "neq": "≠", "ne": "≠",
        "approx": "≈", "infty": "∞", "pi": "π", "alpha": "α", "beta": "β", "gamma": "γ",
        "Delta": "Δ", "delta": "δ", "lambda": "λ", "varphi": "φ", "phi": "φ",
        "Rightarrow": "⇒", "Leftrightarrow": "⇔", "rightarrow": "→", "to": "→", "implies": "⇒",
        "in": "∈", "notin": "∉", "cup": "∪", "cap": "∩", "emptyset": "∅", "varnothing": "∅",
        "angle": "∠", "degree": "°", "circ": "°", "perp": "⊥", "parallel": "∥",
        "ldots": "…", "dots": "…", "cdots": "⋯", "quad": "  ", "qquad": "    ",
        "left": "", "right": "", "displaystyle": "",
    ]

    private static let sup: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "x": "ˣ", "i": "ⁱ", "k": "ᵏ", "m": "ᵐ", "a": "ᵃ", "b": "ᵇ",
    ]
    private static let sub: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎", "a": "ₐ", "x": "ₓ", "n": "ₙ", "i": "ᵢ", "k": "ₖ", "m": "ₘ",
    ]

    private static func mapAll(_ s: String, _ table: [Character: Character]) -> String? {
        var r = ""
        for ch in s {
            guard let m = table[ch] else { return nil }
            r.append(m)
        }
        return r
    }

    private static func isSimple(_ s: String) -> Bool {
        s.range(of: "^[\\p{L}\\p{N}.]+$", options: .regularExpression) != nil
    }

    static func latex(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        for (a, b) in [("\\dfrac", "\\frac"), ("\\tfrac", "\\frac")] { s = s.replacingOccurrences(of: a, with: b) }
        s = replace(s, "\\\\(?:text|mathrm|mathbf|textbf|operatorname)\\{([^{}]*)\\}") { $0[1] }
        for _ in 0..<4 {
            s = replace(s, "\\\\frac\\{([^{}]*)\\}\\{([^{}]*)\\}") { m in
                let a = m[1], b = m[2]
                return (isSimple(a) ? a : "(" + a + ")") + "/" + (isSimple(b) ? b : "(" + b + ")")
            }
            s = replace(s, "\\\\sqrt\\[([^\\]]*)\\]\\{([^{}]*)\\}") { m in
                (mapAll(m[1], sup) ?? m[1]) + "√" + (isSimple(m[2]) ? m[2] : "(" + m[2] + ")")
            }
            s = replace(s, "\\\\sqrt\\{([^{}]*)\\}") { m in "√" + (isSimple(m[1]) ? m[1] : "(" + m[1] + ")") }
        }
        s = replace(s, "\\\\mathbb\\{([A-Z])\\}") { m in ["R": "ℝ", "Z": "ℤ", "N": "ℕ", "Q": "ℚ"][m[1]] ?? m[1] }
        s = replace(s, "\\\\([,;:!%{}])") { m in [",": " ", ";": " ", ":": " ", "!": "", "%": "%", "{": "{", "}": "}"][m[1]] ?? "" }
        s = replace(s, "\\\\([a-zA-Z]+)") { m in commands[m[1]] ?? "" }   // неизвестные команды убираем
        s = s.replacingOccurrences(of: "^°", with: "°")
        s = replace(s, "\\^\\{([^{}]*)\\}") { m in mapAll(m[1], sup) ?? "^(" + m[1] + ")" }
        s = replace(s, "\\^(.)") { m in mapAll(m[1], sup) ?? "^" + m[1] }
        s = replace(s, "_\\{([^{}]*)\\}") { m in mapAll(m[1], sub) ?? "_" + m[1] }
        s = replace(s, "_(.)") { m in mapAll(m[1], sub) ?? "_" + m[1] }
        s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        s = s.replacingOccurrences(of: "*", with: "·")   // чтобы Markdown не принял за курсив
        return s
    }

    /// Замена по регулярному выражению с функцией: groups[0] — всё совпадение, дальше группы.
    static func replace(_ s: String, _ pattern: String, _ f: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        var result = ""
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            var groups: [String] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += f(groups)
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}

/// График функций из ответа модели — тот же формат, что рисует сайт.
struct FunctionChartView: View {
    let spec: ChartSpec

    private struct Sample: Identifiable { let id: Int; let x: Double; let y: Double }

    private var bounds: ChartBounds {
        if let b = spec.bounds, b.xMax > b.xMin, b.yMax > b.yMin { return b }
        return ChartBounds(xMin: -10, xMax: 10, yMin: -10, yMax: 10)
    }

    private func samples(_ f: ChartFunction) -> [Sample] {
        let b = bounds
        let n = 160
        let pad = (b.yMax - b.yMin) * 2
        return (0...n).compactMap { i in
            let x = b.xMin + (b.xMax - b.xMin) * Double(i) / Double(n)
            let y = f.value(at: x)
            guard y.isFinite, y > b.yMin - pad, y < b.yMax + pad else { return nil }
            return Sample(id: i, x: x, y: y)
        }
    }

    var body: some View {
        let b = bounds
        let fns = spec.functions ?? []
        VStack(alignment: .leading, spacing: 8) {
            if let title = spec.title, !title.isEmpty {
                Text(title).font(.subheadline.weight(.semibold))
            }
            Chart {
                RuleMark(x: .value("x", 0.0)).foregroundStyle(Color.secondary.opacity(0.5))
                RuleMark(y: .value("y", 0.0)).foregroundStyle(Color.secondary.opacity(0.5))
                ForEach(Array(fns.enumerated()), id: \.offset) { idx, f in
                    ForEach(samples(f)) { p in
                        LineMark(x: .value("x", p.x), y: .value("y", p.y), series: .value("Функция", f.label + " #" + String(idx)))
                            .foregroundStyle(by: .value("График", f.label))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                ForEach(Array((spec.points ?? []).enumerated()), id: \.offset) { _, p in
                    PointMark(x: .value("x", p.x), y: .value("y", p.y))
                        .foregroundStyle(Theme.accent)
                        .annotation(position: .topTrailing) {
                            if let label = p.label, !label.isEmpty {
                                Text(label).font(.caption2.weight(.semibold))
                            }
                        }
                }
            }
            .chartXScale(domain: b.xMin...b.xMax)
            .chartYScale(domain: b.yMin...b.yMax)
            .chartPlotStyle { $0.clipped() }
            .frame(height: 240)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }
}
