import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

/// Constrói, a partir da paleta do modo, uma lista de termos (nomes de golpes e Pokémon) com
/// suas cores. Usado para colorir o texto deixando claro qual Pokémon usa cada ataque.
struct Colorizer {
    let tokens: [(text: String, color: Color)]
    /// Cor por nome de Pokémon — usada pela marcação inline `{Golpe|Pokémon}`.
    let nameColor: [String: Color]

    /// Cor de alerta (âmbar) para avisos como "não precisa usar Encore para bufar".
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.28)

    /// Avisos sempre destacados em âmbar, independente da paleta do modo.
    private static let alerts: [String] = [
        "(não precisa usar Encore para bufar)",
        "Não precisa usar Encore para bufar"
    ]

    init(palette: [PaletteEntry]?) {
        var list: [(String, Color)] = []
        var names: [String: Color] = [:]
        for entry in palette ?? [] {
            let color = Color(hex: entry.color)
            names[entry.name] = color
            list.append((entry.name, color))
            for move in entry.moves { list.append((move, color)) }
        }
        // Avisos de alerta (âmbar) — válidos em todos os modos.
        for alert in Colorizer.alerts { list.append((alert, Colorizer.warning)) }
        // Mais longos primeiro, para casar "Water Spout" antes de qualquer subtrecho.
        tokens = list.sorted { $0.0.count > $1.0.count }
        nameColor = names
    }

    var isEmpty: Bool { tokens.isEmpty }

    /// Divide o texto em trechos coloridos (cor != nil) e neutros (nil).
    /// Suporta a marcação `{Golpe|Pokémon}`: mostra "Golpe" com a cor do Pokémon indicado,
    /// resolvendo golpes que mais de um Pokémon usa (cor certa por contexto).
    func runs(_ text: String) -> [(String, Color?)] {
        guard !isEmpty else { return [(text, nil)] }
        let chars = Array(text)
        var result: [(String, Color?)] = []
        var plain = ""
        var i = 0

        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber }

        while i < chars.count {
            // Marcação inline {Golpe|Pokémon}
            if chars[i] == "{", let close = chars[(i+1)...].firstIndex(of: "}") {
                let inner = String(chars[(i+1)..<close])
                if let bar = inner.firstIndex(of: "|") {
                    let move = String(inner[..<bar])
                    let owner = String(inner[inner.index(after: bar)...])
                    if !plain.isEmpty { result.append((plain, nil)); plain = "" }
                    result.append((move, nameColor[owner]))
                    i = close + 1
                    continue
                }
            }
            var matched = false
            for (phrase, color) in tokens {
                let pc = Array(phrase)
                guard i + pc.count <= chars.count else { continue }
                var equal = true
                for k in 0..<pc.count where chars[i + k] != pc[k] { equal = false; break }
                guard equal else { continue }
                let beforeOK = (i == 0) || !isWord(chars[i - 1])
                let after = i + pc.count
                let afterOK = (after >= chars.count) || !isWord(chars[after])
                guard beforeOK && afterOK else { continue }
                if !plain.isEmpty { result.append((plain, nil)); plain = "" }
                result.append((phrase, color))
                i = after
                matched = true
                break
            }
            if !matched { plain.append(chars[i]); i += 1 }
        }
        if !plain.isEmpty { result.append((plain, nil)) }
        return result
    }
}

// Disponibiliza o colorizador via Environment, definido uma vez por modo.
private struct ColorizerKey: EnvironmentKey {
    static let defaultValue = Colorizer(palette: nil)
}

extension EnvironmentValues {
    var colorizer: Colorizer {
        get { self[ColorizerKey.self] }
        set { self[ColorizerKey.self] = newValue }
    }
}

/// Texto que colore automaticamente nomes de golpes e Pokémon conforme a paleta do modo.
struct ColoredText: View {
    @Environment(\.colorizer) private var colorizer
    let text: String
    var base: Color = Theme.text
    var size: CGFloat = 13
    var weight: Font.Weight = .regular
    var design: Font.Design = .rounded

    var body: some View {
        let runs = colorizer.runs(text)
        return runs.reduce(Text("")) { acc, run in
            acc + Text(run.0).foregroundColor(run.1 ?? base)
        }
        .font(.system(size: size, weight: weight, design: design))
    }
}
