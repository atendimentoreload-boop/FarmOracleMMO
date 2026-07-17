import SwiftUI

/// Tela de ajuda: configuração do atalho do "Próximo", glossário do modo atual e atalhos da janela.
struct LegendView: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var showLegend: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                howToCard

                ShortcutSettingsView(shortcuts: appModel.shortcuts)

                if let legend = appModel.engine?.solve.legend, !legend.isEmpty {
                    section(tr(.legendGlossary))
                    ForEach(legend) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.term)
                                .font(Theme.mono(12, weight: .bold))
                                .foregroundColor(Theme.accent)
                            Text(item.meaning)
                                .font(Theme.rounded(11))
                                .foregroundColor(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                section(tr(.legendWindowShortcuts))
                shortcut(tr(.legendDragKey), tr(.legendDragDesc))
                shortcut("+ / −", tr(.legendOpacityDesc))
            }
            .padding(12)
        }
    }

    // MARK: - "Como ler o overlay" (#73 — onboarding; auto-abre 1x, depois fica na ajuda)

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(.legendHowToTitle))
                .font(Theme.rounded(14, weight: .bold))
                .foregroundColor(Theme.text)

            howToRow(tr(.legendHowToArrow))
            howToRow(tr(.legendHowToIcons))
            howToRow(tr(.legendHowToChoose))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                    Text(tr(.legendNewbieTitle))
                        .font(Theme.rounded(12, weight: .bold))
                        .foregroundColor(Theme.text)
                }
                Text(tr(.legendNewbieBody))
                    .font(Theme.rounded(11))
                    .foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panelHi)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button { showLegend = false } label: {
                Text(tr(.legendGotIt))
                    .font(Theme.rounded(12, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func howToRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("→")
                .font(Theme.mono(12, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 14, alignment: .center)
            Text(text)
                .font(Theme.rounded(11))
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(Theme.rounded(13, weight: .bold))
            .foregroundColor(Theme.text)
            .padding(.top, 2)
    }

    private func shortcut(_ key: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.panelHi)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(desc)
                .font(Theme.rounded(11))
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Configuração do atalho do "Próximo"

struct ShortcutSettingsView: View {
    @ObservedObject var shortcuts: ShortcutManager
    /// Qual atalho este painel configura: "Próximo" (padrão) ou "Pular parada" (#71).
    var kind: ShortcutManager.Kind = .next

    private var currentCombo: ShortcutManager.Combo? { shortcuts.combo(for: kind) }
    private var titleKey: L { kind == .next ? .shortcutTitle : .navSkipShortcut }
    private var descriptionKey: L { kind == .next ? .shortcutDescription : .shortcutSkipDescription }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(titleKey))
                .font(Theme.rounded(13, weight: .bold))
                .foregroundColor(Theme.text)

            Text(tr(descriptionKey))
                .font(Theme.rounded(11))
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(tr(.shortcutCurrent))
                    .font(Theme.rounded(11))
                    .foregroundColor(Theme.textDim)
                Text(currentCombo?.display ?? tr(.none))
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundColor(currentCombo == nil ? Theme.textDim : Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .frame(minWidth: 60)
                    .background(Theme.panelHi)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    shortcuts.startCapture(kind)
                } label: {
                    Text(currentCombo == nil ? tr(.shortcutSet) : tr(.shortcutChange))
                        .font(Theme.rounded(12, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if currentCombo != nil {
                    Button(tr(.shortcutClear)) { shortcuts.clear(kind) }
                        .buttonStyle(.plain)
                        .font(Theme.rounded(12, weight: .medium))
                        .foregroundColor(Theme.textDim)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Theme.panelHi)
                        .clipShape(Capsule())
                }
            }

            if currentCombo != nil && !shortcuts.accessibilityGranted {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                    Text(tr(.shortcutAccessWarning))
                        .font(Theme.rounded(10))
                        .foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                Button(tr(.shortcutGrant)) { shortcuts.requestAccessibility() }
                    .buttonStyle(.plain)
                    .font(Theme.rounded(11, weight: .medium))
                    .foregroundColor(Theme.choice)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
