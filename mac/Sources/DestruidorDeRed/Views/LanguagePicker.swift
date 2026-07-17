import SwiftUI

/// Seletor de idioma da 1ª abertura (porte do LanguagePicker do Android/Windows).
/// Bilíngue de propósito: o usuário ainda não escolheu, então os textos são fixos nos dois
/// idiomas (NÃO passam por tr()/L). Aparece só uma vez — a flag TeamPrefs.languageChosen
/// impede a reexibição. O idioma do sistema vem em destaque (1º botão, primary).
struct LanguagePicker: View {
    /// Idioma sugerido (do sistema), exibido como opção principal.
    let suggested: Lang
    /// Chamado quando o usuário toca num dos dois botões.
    let onPick: (Lang) -> Void

    var body: some View {
        let other: Lang = suggested == .pt ? .en : .pt
        VStack(spacing: 0) {
            Text("FarmOracleMMO")
                .font(Theme.rounded(22, weight: .black))
                .foregroundColor(Theme.text)
            Text("Escolha o idioma  ·  Choose your language")
                .font(Theme.rounded(13))
                .foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 22)
            langButton(suggested, primary: true)
                .padding(.bottom, 12)
            langButton(other, primary: false)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    @ViewBuilder
    private func langButton(_ lang: Lang, primary: Bool) -> some View {
        let label = lang == .pt ? "🇧🇷  Português" : "🇺🇸  English"
        Button(action: { onPick(lang) }) {
            Text(label)
                .font(Theme.rounded(15, weight: .semibold))
                .foregroundColor(primary ? .black : Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(primary ? Theme.accent : Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
