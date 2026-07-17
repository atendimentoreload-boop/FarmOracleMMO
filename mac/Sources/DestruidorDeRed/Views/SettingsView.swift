import SwiftUI
import AppKit

/// Fonte da estratégia de um time, mostrada como botão ao lado do Poképaste no menu.
enum TeamSource {
    case doc(String)                          // Google Docs — abre no navegador
    case video(String)                        // vídeo (YouTube) — abre no navegador
    case pokeking(code: String, team: String) // aviso com o CODE do Pokeking + site (Elite 4)
    case notFound                             // aviso: documento oficial ainda não encontrado
}

/// Menu de Configurações em estilo "lista de opções".
/// Cabeça da tela: **Times** agrupados por modo de batalha (Red / Gym Rerun / Elite 4),
/// cada time com seu Poképaste. Embaixo: opções gerais (opacidade, atalho, idioma).
/// Aberto pelo botão "Times e Opções" do menu; fechado pelo "Voltar".
struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var controller: OverlayController
    @Binding var showSettings: Bool

    /// Sub-tela aberta (nil = lista principal).
    @State private var panel: Panel? = nil
    enum Panel { case shortcut, skipShortcut, language
        var titleKey: L {
            switch self {
            case .shortcut: return .shortcut
            case .skipShortcut: return .navSkipShortcut
            case .language: return .language
            }
        }
    }

    /// Grupos de time abertos nas Configurações. Vazio = todos recolhidos (a lista de times de
    /// cada modo só aparece ao clicar no cabeçalho do modo — evita poluir com muitos times).
    @State private var expandedTeamGroups: Set<String> = []
    private func toggleTeamGroup(_ key: String) {
        if expandedTeamGroups.contains(key) { expandedTeamGroups.remove(key) }
        else { expandedTeamGroups.insert(key) }
    }

    private let pasteYellow = Color(red: 1.0, green: 0.82, blue: 0.25)

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            ScrollView {
                Group {
                    if let panel { panelView(panel) } else { mainList }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                if panel != nil { panel = nil } else { showSettings = false }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    Text(panel != nil ? "Menu" : appModel.t(.back)).font(Theme.rounded(12, weight: .semibold))
                }
                .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text((panel.map { appModel.t($0.titleKey) } ?? "Menu").uppercased())
                .font(Theme.rounded(12, weight: .bold)).foregroundColor(Theme.text).tracking(0.5)
            Spacer()
            Color.clear.frame(width: 64, height: 1)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    // MARK: - Lista principal

    private var mainList: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(appModel.t(.teams))

            collapsibleTeamGroup("Red", icon: AnyView(TrainerPortrait(name: "red", size: 24)),
                                 selected: appModel.activeRedStrategy.name) {
                ForEach(Array(appModel.redStrategies.enumerated()), id: \.element.id) { idx, strat in
                    if idx > 0 { rowDivider }
                    teamLineRow(icon: AnyView(PokemonIcon(name: strat.pokemon, size: 28)),
                                name: strat.name, sub: strat.roster,
                                pokepaste: strat.pokepaste, source: strat.doc.map { .doc($0) },
                                selected: strat.id == appModel.activeRedStrategyId,
                                onSelect: { appModel.setRedStrategy(strat.id) })
                }
            }

            collapsibleTeamGroup(appModel.t(.gymFarm), icon: AnyView(ItemIcon(name: "gym", size: 20)),
                                 selected: "\(AppModel.farmTeamName(appModel.activeFarmRoute.teamGroup)) · \(appModel.activeFarmRoute.variant)") {
                ForEach(Array(appModel.farmTeamGroupsOrdered.enumerated()), id: \.element) { gi, group in
                    let routes = appModel.farmRoutes(in: group)
                    if gi > 0 { rowDivider }
                    if routes.count == 1 {
                        let r = routes[0]
                        teamLineRow(icon: AnyView(PokemonIcon(name: r.pokemon, size: 28)),
                                    name: r.name, sub: r.roster,
                                    pokepaste: r.pokepaste, source: r.doc.map { .doc($0) },
                                    selected: r.id == appModel.activeFarmRouteId,
                                    onSelect: { appModel.setFarmRoute(r.id) })
                    } else {
                        // MESMO time, várias rotas → cabeçalho do time (roster + Poképaste/doc) + variantes
                        farmTeamHeader(group: group, routes: routes)
                        ForEach(routes) { r in farmVariantRow(r) }
                    }
                }
            }

            collapsibleTeamGroup("Cynthia & Morimoto", icon: AnyView(TrainerPortrait(name: "cynthia", size: 24)),
                                 selected: appModel.activeCmStrategy.name) {
                ForEach(Array(appModel.cynthiaMorimotoStrategies.enumerated()), id: \.element.id) { idx, strat in
                    if idx > 0 { rowDivider }
                    teamLineRow(icon: AnyView(PokemonIcon(name: "swellow", size: 28)),
                                name: strat.name, sub: strat.roster,
                                pokepaste: strat.pokepaste, source: strat.doc.map { .doc($0) },
                                selected: strat.id == appModel.activeCmStrategyId,
                                onSelect: { appModel.setCmStrategy(strat.id) })
                }
            }

            // Ho-Oh (rematch): estratégias selecionáveis (Allen - Yatsura + Trick Room), como o Red.
            // Fonte de cada uma = vídeo do YouTube (ícone vermelho de play).
            collapsibleTeamGroup("Ho-Oh", icon: AnyView(PokemonIcon(name: "hooh", size: 22)),
                                 selected: appModel.activeHoohStrategy.name) {
                ForEach(Array(appModel.hoohStrategies.enumerated()), id: \.element.id) { idx, strat in
                    if idx > 0 { rowDivider }
                    teamLineRow(icon: AnyView(PokemonIcon(name: strat.pokemon, size: 28)),
                                name: strat.name, sub: strat.roster,
                                pokepaste: strat.pokepaste, source: strat.video.map { .video($0) },
                                selected: strat.id == appModel.activeHoohStrategyId,
                                onSelect: { appModel.setHoohStrategy(strat.id) })
                }
            }

            collapsibleTeamGroup("Elite 4", icon: AnyView(ItemIcon(name: "trophy", size: 20)),
                                 selected: appModel.activeTeam.name) {
                ForEach(Array(appModel.availableTeams.enumerated()), id: \.element.id) { idx, team in
                    if idx > 0 { rowDivider }
                    teamLineRow(
                        icon: team.icon.map { AnyView(PokemonIcon(name: $0, size: 28)) }
                            ?? AnyView(rowIcon("person.fill")),
                        name: team.name,
                        sub: team.pokemon.joined(separator: ", "),
                        pokepaste: team.pokepaste,
                        source: team.code.map { .pokeking(code: $0, team: team.name) },
                        selected: team.id == appModel.activeTeamId,
                        onSelect: { appModel.setTeam(team.id) })
                }
                if appModel.emojiAvailable {
                    rowDivider
                    toggleRow(icon: "face.smiling", title: appModel.t(.emojiMode),
                              on: appModel.emojiMode) { appModel.toggleEmoji() }
                }
            }

            sectionLabel(appModel.t(.options)).padding(.top, 8)

            groupLabel("Overlay")
            settingsGroup { opacityRow }

            groupLabel(appModel.t(.general))
            settingsGroup {
                navRow(icon: "keyboard", title: appModel.t(.navNextShortcut),
                       value: appModel.shortcuts.combo?.display ?? appModel.t(.none)) { panel = .shortcut }
                rowDivider
                navRow(icon: "forward.end.fill", title: appModel.t(.navSkipShortcut),
                       value: appModel.shortcuts.skipCombo?.display ?? appModel.t(.none)) { panel = .skipShortcut }
                rowDivider
                navRow(icon: "globe", title: appModel.t(.language),
                       value: appModel.language == .en ? "English" : appModel.t(.portuguese)) { panel = .language }
            }

            groupLabel(appModel.t(.about))
            settingsGroup {
                infoRow(icon: "info.circle", title: appModel.t(.version), value: "v\(AppVersion.current)")
            }

            CreditsFooter()
        }
    }

    private var opacityRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                rowIcon("circle.lefthalf.filled")
                Text(appModel.t(.opacity)).font(Theme.rounded(13, weight: .medium)).foregroundColor(Theme.text)
                Spacer()
                Text("\(Int((controller.opacity * 100).rounded()))%")
                    .font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.accent)
            }
            Slider(value: Binding(get: { controller.opacity },
                                  set: { controller.setOpacity($0) }),
                   in: 0.35...1.0)
            .tint(Theme.accent)
            .padding(.leading, 30)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
    }

    // MARK: - Sub-telas

    @ViewBuilder
    private func panelView(_ panel: Panel) -> some View {
        switch panel {
        case .shortcut: ShortcutSettingsView(shortcuts: appModel.shortcuts)
        case .skipShortcut: ShortcutSettingsView(shortcuts: appModel.shortcuts, kind: .skip)
        case .language: languagePanel
        }
    }

    private var languagePanel: some View {
        settingsGroup {
            languageRow(flag: "🇧🇷", lang: .pt, name: appModel.t(.portuguese))
            rowDivider
            languageRow(flag: "🇺🇸", lang: .en, name: "English")
        }
    }

    private func languageRow(flag: String, lang: Lang, name: String) -> some View {
        let selected = appModel.language == lang
        return Button { appModel.setLanguage(lang) } label: {
            HStack(spacing: 10) {
                Text(flag).font(.system(size: 16)).frame(width: 20)
                Text(name).font(Theme.rounded(13, weight: .medium)).foregroundColor(Theme.text)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.good)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Linha de time

    /// Uma linha de time: ícone + nome (+ roster) à esquerda; Poképaste (?) e seleção à direita.
    /// `onSelect == nil` → time único do modo (não trocável por enquanto), mostrado já marcado.
    private func teamLineRow(icon: AnyView, name: String, sub: String?,
                             pokepaste: String?, source: TeamSource? = nil, selected: Bool,
                             onSelect: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            Button { onSelect?() } label: {
                HStack(spacing: 10) {
                    icon.frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).font(Theme.rounded(13, weight: .semibold)).foregroundColor(Theme.text)
                        if let sub {
                            Text(sub).font(Theme.rounded(9)).foregroundColor(Theme.textDim).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onSelect == nil)

            sourceButton(source)
            pasteButton(pokepaste)

            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(selected ? Theme.good : Theme.textDim.opacity(0.45))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    /// Cabeçalho de um time com VÁRIAS rotas: nome do time + roster + Poképaste/doc (uma vez só).
    private func farmTeamHeader(group: String, routes: [AppModel.FarmRoute]) -> some View {
        let r = routes[0]
        return HStack(spacing: 10) {
            PokemonIcon(name: r.pokemon, size: 28).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppModel.farmTeamName(group)).font(Theme.rounded(13, weight: .bold)).foregroundColor(Theme.text)
                Text(r.roster).font(Theme.rounded(9)).foregroundColor(Theme.textDim).lineLimit(1)
            }
            Spacer(minLength: 4)
            sourceButton(r.doc.map { .doc($0) })
            pasteButton(r.pokepaste)
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
    }

    /// Linha compacta de uma VARIANTE de rota (dentro do submenu do time): indicador + nome curto.
    private func farmVariantRow(_ r: AppModel.FarmRoute) -> some View {
        let selected = r.id == appModel.activeFarmRouteId
        return Button { appModel.setFarmRoute(r.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(selected ? Theme.good : Theme.textDim.opacity(0.45))
                Text(r.variant).font(Theme.rounded(12, weight: .semibold)).foregroundColor(Theme.text)
                Spacer(minLength: 4)
            }
            .padding(.leading, 42).padding(.trailing, 12).padding(.vertical, 8)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private func pasteButton(_ paste: String?) -> some View {
        if let paste, let url = URL(string: paste) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.black)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(pasteYellow))
            }
            .buttonStyle(.plain)
            .help(appModel.t(.pasteHelp))
        }
    }

    /// Botão da FONTE da estratégia — ao lado do Poképaste. Doc abre o Google Docs; Elite 4 e
    /// "não encontrado" abrem um aviso (NSAlert).
    @ViewBuilder
    private func sourceButton(_ source: TeamSource?) -> some View {
        if let source {
            Button { openSource(source) } label: {
                Image(systemName: sourceIcon(source))
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(sourceColor(source)))
            }
            .buttonStyle(.plain)
            .help(appModel.t(.docHelp))
        }
    }

    private func sourceIcon(_ s: TeamSource) -> String {
        switch s {
        case .video: return "play.rectangle.fill"
        case .pokeking: return "info.circle.fill"
        case .doc, .notFound: return "doc.text.fill"
        }
    }

    private func sourceColor(_ s: TeamSource) -> Color {
        switch s {
        case .video: return Color(red: 0.90, green: 0.22, blue: 0.21)  // vermelho (vídeo/YouTube)
        default: return Color(red: 0.36, green: 0.6, blue: 0.95)        // azul (doc/aviso)
        }
    }

    private func openSource(_ s: TeamSource) {
        switch s {
        case .doc(let url), .video(let url):
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        case .pokeking(let code, let team):
            let a = NSAlert()
            a.messageText = "Pokeking — \(team)"
            a.informativeText = String(format: appModel.t(.pokekingBody), code)
            a.addButton(withTitle: appModel.t(.copyCode))
            a.addButton(withTitle: appModel.t(.openPokeking))
            a.addButton(withTitle: appModel.t(.close))
            switch a.runModal() {
            case .alertFirstButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            case .alertSecondButtonReturn:
                if let u = URL(string: "https://pokeking.icu") { NSWorkspace.shared.open(u) }
            default: break
            }
        case .notFound:
            let a = NSAlert()
            a.messageText = appModel.t(.docNotFoundTitle)
            a.informativeText = appModel.t(.docNotFoundBody)
            a.addButton(withTitle: appModel.t(.close))
            a.runModal()
        }
    }

    // MARK: - Componentes

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.rounded(12, weight: .black)).foregroundColor(Theme.text).tracking(0.5)
            .padding(.bottom, 2)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.rounded(9, weight: .bold)).foregroundColor(Theme.accent).tracking(0.8)
            .padding(.top, 6).padding(.leading, 4)
    }

    /// Cabeçalho de grupo de time CLICÁVEL: recolhido mostra só o nome do modo + o time ativo;
    /// expandido revela a lista de times. Mantém o menu enxuto quando há muitos times.
    @ViewBuilder
    private func collapsibleTeamGroup<Content: View>(_ title: String, icon: AnyView, selected: String?,
                                                     @ViewBuilder _ content: () -> Content) -> some View {
        let isOpen = expandedTeamGroups.contains(title)
        Button { toggleTeamGroup(title) } label: {
            HStack(spacing: 8) {
                icon.frame(width: 24, height: 24)
                Text(title.uppercased())
                    .font(Theme.rounded(9, weight: .bold)).foregroundColor(Theme.accent).tracking(0.8)
                Spacer(minLength: 6)
                if !isOpen, let selected {
                    Text(selected).font(Theme.rounded(10)).foregroundColor(Theme.textDim).lineLimit(1)
                }
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textDim)
            }
            .padding(.top, 6).padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if isOpen { settingsGroup { content() } }
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 42)
    }

    private func rowIcon(_ system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.accent).frame(width: 20)
    }

    private func navRow(icon: String, title: String, value: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                rowIcon(icon)
                Text(title).font(Theme.rounded(13, weight: .medium)).foregroundColor(Theme.text)
                Spacer(minLength: 8)
                Text(value).font(Theme.rounded(12)).foregroundColor(Theme.textDim).lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.7))
            }
            .padding(.horizontal, 12).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, on: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                rowIcon(icon)
                Text(title).font(Theme.rounded(13, weight: .medium)).foregroundColor(Theme.text)
                Spacer(minLength: 8)
                Text(on ? "ON" : "OFF")
                    .font(Theme.rounded(11, weight: .bold))
                    .foregroundColor(on ? .black : Theme.textDim)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(on ? Theme.good : Theme.panelHi).clipShape(Capsule())
            }
            .padding(.horizontal, 12).padding(.vertical, 11).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            rowIcon(icon)
            Text(title).font(Theme.rounded(13, weight: .medium)).foregroundColor(Theme.text)
            Spacer(minLength: 8)
            Text(value).font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.textDim)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }
}

/// Rodapé de créditos (Desenvolvido por / Agradecimentos + ícones de Discord e YouTube).
/// Reutilizado na home e nas Configurações. Os links ficam centralizados aqui.
struct CreditsFooter: View {
    @EnvironmentObject var appModel: AppModel
    static let discordURL = "https://discord.gg/9jCuB6BDBC"
    static let youtubeURL = "https://youtube.com/@viniciosprestrelo44?si=B18HIMXP0cg2Mq74"

    var body: some View {
        VStack(spacing: 5) {
            Text(appModel.t(.developedBy))
                .font(Theme.rounded(10, weight: .semibold)).foregroundColor(Theme.textDim)
            Text(appModel.t(.thanksTo))
                .font(Theme.rounded(9)).foregroundColor(Theme.textDim.opacity(0.85))
            HStack(spacing: 18) {
                socialIcon("discord", Self.discordURL)
                socialIcon("youtube", Self.youtubeURL)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 6)
    }

    private func socialIcon(_ name: String, _ url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            ItemIcon(name: name, size: 30)
        }
        .buttonStyle(.plain)
        .help(url)
    }
}
