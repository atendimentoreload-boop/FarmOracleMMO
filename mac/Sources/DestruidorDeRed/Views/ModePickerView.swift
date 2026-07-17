import SwiftUI
import AppKit

/// Tela de menu: escolhe qual modo abrir. Modos com `category` ficam num submenu
/// (ex.: "Elite 4 ▸" abre as 5 regiões), pra não poluir o menu principal.
struct ModePickerView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var openCategory: String? = nil

    /// Abre o menu de Configurações (troca de time, overlay, atalho, idioma).
    var onOpenSettings: () -> Void = {}
    /// Abre o sistema de Cooldown/Alarme (reloginho ao lado do chip de idioma).
    var onOpenCooldowns: () -> Void = {}

    /// Amarelo do botão de Poképaste (verde fica no `Theme.good`).
    private let pasteYellow = Color(red: 1.0, green: 0.82, blue: 0.25)

    /// Modos sem categoria (aparecem direto no menu principal).
    private var topModes: [AppModel.Mode] { appModel.modes.filter { $0.category == nil } }

    /// Índice do 1º modo com categoria (bloco da Elite 4) — divide os modos soltos
    /// em "antes" (Red, Farm) e "depois" (Cynthia & Morimoto, Ho-Oh).
    private var firstCategoryIndex: Int? { appModel.modes.firstIndex { $0.category != nil } }
    /// Modos soltos exibidos ANTES das categorias.
    private var topModesBefore: [AppModel.Mode] {
        guard let i = firstCategoryIndex else { return topModes }
        return Array(appModel.modes[..<i]).filter { $0.category == nil }
    }
    /// Modos soltos exibidos DEPOIS das categorias (Elite 4).
    private var topModesAfter: [AppModel.Mode] {
        guard let i = firstCategoryIndex else { return [] }
        return Array(appModel.modes[(i + 1)...]).filter { $0.category == nil }
    }

    /// Categorias, na ordem em que aparecem.
    private var categories: [String] {
        var seen = Set<String>(); var out: [String] = []
        for m in appModel.modes { if let c = m.category, !seen.contains(c) { seen.insert(c); out.append(c) } }
        return out
    }

    private func modes(in category: String) -> [AppModel.Mode] {
        appModel.modes.filter { $0.category == category }
    }

    /// Atalho rápido PT⇄EN na tela inicial (Backlog #13): alterna o idioma sem entrar no
    /// Menu → Idioma. Mostra a bandeira/sigla do idioma ATUAL; tocar troca para o outro.
    /// setLanguage remonta os modos e, como appModel é observado, a home inteira re-renderiza.
    private var languageChip: some View {
        let isEN = appModel.language == .en
        return Button {
            appModel.setLanguage(isEN ? .pt : .en)
        } label: {
            HStack(spacing: 4) {
                Text(isEN ? "🇺🇸" : "🇧🇷").font(.system(size: 12))
                Text(isEN ? "EN" : "PT")
                    .font(Theme.rounded(10, weight: .bold))
                    .foregroundColor(Theme.text)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.panel)
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(appModel.t(.language))
    }

    /// Reloginho do sistema de Cooldown/Alarme — fica ao lado do chip de idioma (antes ficava
    /// na barra de topo). Abre a tela de cooldowns via `onOpenCooldowns`.
    private var cooldownChip: some View {
        Button(action: onOpenCooldowns) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.panel)
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tr(.cdReloginhoHelp))
    }

    /// Ícone (item) de uma categoria: Elite 4 → taça; rotas de farm → ginásio.
    private func categoryItem(_ cat: String) -> String? {
        modes(in: cat).contains { $0.id.hasPrefix("elite4_") } ? "trophy" : "gym"
    }

    /// Subtítulo do card de categoria (Elite 4 vs rotas de farm de ginásios).
    private func categorySubtitle(_ cat: String) -> String {
        modes(in: cat).contains { $0.id.hasPrefix("elite4_") } ? tr(.categorySubtitle) : tr(.modeGymFarmSubtitle)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let cat = openCategory {
                // ----- Submenu de uma categoria (ex.: regiões do Elite 4) -----
                HStack(spacing: 6) {
                    Button { openCategory = nil } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                            Text("Menu").font(Theme.rounded(12, weight: .semibold))
                        }
                        .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(cat).font(Theme.rounded(12, weight: .bold)).foregroundColor(Theme.text)
                    Spacer()
                    Color.clear.frame(width: 40, height: 1)
                }
                .padding(.top, 2)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(modes(in: cat)) { mode in
                            let region = mode.id.hasPrefix("elite4_") ? String(mode.id.dropFirst(7)) : nil
                            card(title: mode.title, subtitle: mode.subtitle, symbol: mode.symbol,
                                 portrait: mode.portrait, item: mode.item, region: region, pokepaste: mode.pokepaste) {
                                appModel.select(mode)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            } else {
                // ----- Menu principal -----
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    cooldownChip
                    languageChip
                }
                Text(tr(.modePickerPrompt))
                    .font(Theme.rounded(12, weight: .medium))
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(topModesBefore) { mode in
                            card(title: mode.title, subtitle: mode.subtitle, symbol: mode.symbol,
                                 pokemon: mode.pokemon, portrait: mode.portrait, item: mode.item,
                                 pokepaste: mode.pokepaste, comingSoon: mode.comingSoon) {
                                appModel.select(mode)
                            }
                        }
                        ForEach(categories, id: \.self) { cat in
                            card(title: cat,
                                 subtitle: categorySubtitle(cat),
                                 symbol: "crown.fill",
                                 item: categoryItem(cat),
                                 pokepaste: modes(in: cat).first?.pokepaste) {
                                openCategory = cat
                            }
                        }
                        ForEach(topModesAfter) { mode in
                            card(title: mode.title, subtitle: mode.subtitle, symbol: mode.symbol,
                                 pokemon: mode.pokemon, portrait: mode.portrait, item: mode.item,
                                 pokepaste: mode.pokepaste, comingSoon: mode.comingSoon) {
                                appModel.select(mode)
                            }
                        }
                        Button(action: onOpenSettings) {
                            HStack(spacing: 9) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Menu")
                                        .font(Theme.rounded(13, weight: .bold)).foregroundColor(Theme.text)
                                    Text(tr(.settingsCardSubtitle))
                                        .font(Theme.rounded(9)).foregroundColor(Theme.textDim).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textDim)
                            }
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        Text("v\(AppVersion.current)")
                            .font(Theme.rounded(9)).foregroundColor(Theme.textDim).opacity(0.7)
                            .frame(maxWidth: .infinity).padding(.top, 2)

                        CreditsFooter()
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(10)
    }

    // MARK: - Card de modo

    /// Ícone do card: sprite de Pokémon (representante do time) > retrato de treinador > item >
    /// mapa da região > símbolo SF.
    @ViewBuilder
    private func icon(pokemon: String?, portrait: String?, item: String?, region: String?, symbol: String) -> some View {
        if let pk = pokemon {
            PokemonIcon(name: pk, size: 40)
        } else if let p = portrait {
            TrainerPortrait(name: p, size: 44)
        } else if let it = item {
            ItemIcon(name: it, size: 36)
        } else if let region = region {
            RegionStartersIcon(region: region, size: 46)
        } else {
            Image(systemName: symbol).font(.system(size: 22)).foregroundColor(Theme.accent)
        }
    }

    /// Botão circular colorido (play verde / interrogação amarela).
    private func circleButton(_ symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color))
        }
        .buttonStyle(.plain)
    }

    /// Selo "em breve" para modos ainda sem conteúdo (ex.: Ho-Oh).
    private var comingSoonBadge: some View {
        Text(tr(.comingSoon).uppercased())
            .font(Theme.rounded(8, weight: .black)).tracking(0.4)
            .foregroundColor(.black)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(red: 1.0, green: 0.82, blue: 0.25))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func card(title: String, subtitle: String, symbol: String,
                      pokemon: String? = nil, portrait: String? = nil, item: String? = nil, region: String? = nil,
                      pokepaste: String?, comingSoon: Bool = false, play: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            icon(pokemon: pokemon, portrait: portrait, item: item, region: region, symbol: symbol)
                .frame(width: 46, height: 46)
                .opacity(comingSoon ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Theme.rounded(14, weight: .bold))
                        .foregroundColor(Theme.text)
                    if comingSoon { comingSoonBadge }
                }
                Text(subtitle)
                    .font(Theme.rounded(11))
                    .foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)

            circleButton("play.fill", color: Theme.good, action: play)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
    }
}
