import SwiftUI

/// Paleta e fontes do overlay — visual escuro, compacto, inspirado no pokepaste.
enum Theme {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let panel = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let panelHi = Color(red: 0.17, green: 0.17, blue: 0.20)
    static let border = Color.white.opacity(0.10)
    static let line = Color.white.opacity(0.07)

    static let text = Color(red: 0.92, green: 0.92, blue: 0.94)
    static let textDim = Color(red: 0.62, green: 0.62, blue: 0.66)

    static let accent = Color(red: 1.0, green: 0.62, blue: 0.20)   // laranja (Infernape)
    static let accentSoft = Color(red: 1.0, green: 0.62, blue: 0.20).opacity(0.18)
    static let choice = Color(red: 0.40, green: 0.72, blue: 1.0)    // azul p/ escolhas
    static let choiceSoft = Color(red: 0.40, green: 0.72, blue: 1.0).opacity(0.16)
    static let good = Color(red: 0.45, green: 0.85, blue: 0.50)     // verde terminal
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.28)   // âmbar (avisos/alertas)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)    // vermelho (não funcionou)

    /// Multiplicador global de tamanho de fonte (Compacto/Normal/Grande), ciclado pelo botão
    /// "A−/A/A+" da barra de topo. Carrega o nível salvo na 1ª leitura; o OverlayController
    /// atualiza este valor ao ciclar. Espelha o `uiScale` do Android (3 níveis).
    static var scale: CGFloat = Theme.scaleFactor(
        (UserDefaults.standard.object(forKey: "overlay.uiScale") as? Int) ?? 1)

    /// Fator por nível: 0 = Compacto, 1 = Normal, 2 = Grande.
    static func scaleFactor(_ level: Int) -> CGFloat {
        [0.85, 1.0, 1.2][min(max(level, 0), 2)]
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight, design: .monospaced)
    }
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight, design: .rounded)
    }
}
