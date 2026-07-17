import SwiftUI

/// Acha um PNG dentro do bundle de recursos, tentando primeiro a API padrão e, se falhar,
/// montando o caminho direto (resourceURL/subdir/name.png). Robusto a peculiaridades do
/// `Bundle.module` quando o app é empacotado como .app.
func moduleResourceURL(_ name: String, in subdir: String) -> URL? {
    if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: subdir) {
        return url
    }
    for base in [Bundle.module.resourceURL, Bundle.module.bundleURL] {
        if let u = base?.appendingPathComponent(subdir).appendingPathComponent(name + ".png"),
           FileManager.default.fileExists(atPath: u.path) {
            return u
        }
    }
    return nil
}

/// Ícone (sprite) de um Pokémon, carregado de Resources/sprites pelo nome. Se não houver
/// sprite para aquele rótulo (ex.: nome de cidade), não mostra nada.
struct PokemonIcon: View {
    let name: String
    let size: CGFloat

    private static var cache: [String: NSImage] = [:]

    /// Normaliza um rótulo para chave de sprite (minúsculas, só alfanuméricos).
    static func spriteKey(_ name: String) -> String {
        String(String.UnicodeScalarView(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    /// Existe sprite para este rótulo? (usado pra saber se um rótulo da trilha é um Pokémon).
    static func spriteExists(_ name: String) -> Bool {
        let key = spriteKey(name)
        if key.isEmpty { return false }
        if cache[key] != nil { return true }
        return moduleResourceURL(key, in: "sprites") != nil
    }

    /// Casa um sprite começando na palavra `start`, testando janelas de 3→1 palavras (pega
    /// nomes de 2 palavras como "Wash Rotom"/"Mr Mime"). Devolve o trecho casado ou nil.
    private static func spriteSequence(_ words: [String], from start: Int) -> String? {
        var n = min(3, words.count - start)
        while n >= 1 {
            let seq = words[start..<(start + n)].joined(separator: " ")
            if spriteExists(seq) { return seq }
            n -= 1
        }
        return nil
    }

    /// Se o rótulo COMEÇA com o nome de um Pokémon (ex.: "Gallade travado no golpe",
    /// "Charizard morreu", "Wash Rotom"), devolve esse nome; senão nil.
    static func leadingSpriteName(in label: String) -> String? {
        let words = label.split(omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "/" }).map(String.init)
        if words.isEmpty { return nil }
        return spriteSequence(words, from: 0)
    }

    /// Melhor sprite para um rótulo de OPÇÃO ("o que o oponente fez / colocou em campo").
    /// Prioridade: 1) Pokémon no INÍCIO ("Gallade travado no golpe"); 2) Pokémon logo após um
    /// marcador de oponente ("Contra"/"vs."/"versus" → "Contra Gallade", "vs. Blastoise",
    /// "troque para Dragonite Contra Gengar" → Gengar); 3) primeiro Pokémon em qualquer posição
    /// ("deixe fugir Houndoom", "Scald /Gyarados"). Divide em espaço E "/". nil = sem Pokémon.
    static func optionSpriteName(in label: String) -> String? {
        let words = label.split(omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "/" }).map(String.init)
        if words.isEmpty { return nil }
        if let lead = spriteSequence(words, from: 0) { return lead }
        let markers: Set<String> = ["contra", "vs", "versus"]
        for i in words.indices where markers.contains(spriteKey(words[i])) {
            if i + 1 < words.count, let m = spriteSequence(words, from: i + 1) { return m }
        }
        for i in words.indices {
            if let m = spriteSequence(words, from: i) { return m }
        }
        return nil
    }

    /// Verbos que introduzem o NOSSO Pokémon (troca de entrada) — não conta como oponente.
    private static let ourSwitchVerbs: Set<String> = [
        "troque", "troca", "trocar", "volte", "volta", "mande", "manda", "use", "lidere", "lidera", "puxe", "puxa"
    ]

    /// Pokémon ATIVO do oponente, ciente do contexto do nó. Base: último Pokémon "limpo" da trilha
    /// (lead / troca do oponente). Depois, se os passos JÁ REVELADOS citam um Pokémon do oponente
    /// ("Habilidade do Claydol", "→ sai Gengar", "Gengar Stealth Rock"), passa a ser esse — ignorando
    /// as NOSSAS trocas ("troque para Dragonite"). Assim um golpe puro mostra quem realmente age.
    static func actingOpponentMon(trail: [String], steps: [String]) -> String? {
        var mon: String? = nil
        for label in trail where spriteExists(label) { mon = label }
        for text in steps {
            let first = spriteKey(text.split(separator: " ").first.map(String.init) ?? "")
            if ourSwitchVerbs.contains(first) { continue }
            if let m = optionSpriteName(in: text) { mon = m }
        }
        return mon
    }

    private var image: NSImage? {
        let key = PokemonIcon.spriteKey(name)
        if key.isEmpty { return nil }
        if let cached = PokemonIcon.cache[key] { return cached }
        guard let url = moduleResourceURL(key, in: "sprites"),
              let img = NSImage(contentsOf: url) else { return nil }
        PokemonIcon.cache[key] = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
        }
    }
}

/// Ícone da Master Ball ("money ball", o ícone do app), de Resources/masterball.png.
/// Usado como placeholder onde a "rota" não tem Pokémon (opção "Demais times", entradas
/// utilitárias tipo "RNG & Habilidades", cidades puladas sem sprite).
struct MasterBallIcon: View {
    let size: CGFloat

    private static var cached: NSImage?

    private var image: NSImage? {
        if let c = MasterBallIcon.cached { return c }
        guard let url = Bundle.module.url(forResource: "masterball", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        MasterBallIcon.cached = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .interpolation(.medium)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

/// Mostra o sprite do Pokémon do rótulo; se não existir sprite, cai na Master Ball.
/// Só usar onde a entrada/opção pode legitimamente não ter Pokémon (rotas/opções utilitárias).
struct MonOrBallIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if PokemonIcon.spriteExists(name) {
            PokemonIcon(name: name, size: size)
        } else {
            MasterBallIcon(size: size)
        }
    }
}

/// Retrato de um treinador (líder de ginásio / Elite 4), de Resources/trainers.
struct TrainerPortrait: View {
    let name: String
    let size: CGFloat

    private static var cache: [String: NSImage] = [:]

    private var image: NSImage? {
        let key = name.lowercased()
        if let cached = TrainerPortrait.cache[key] { return cached }
        guard let url = moduleResourceURL(key, in: "trainers"),
              let img = NSImage(contentsOf: url) else { return nil }
        TrainerPortrait.cache[key] = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .interpolation(.medium)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

/// Ícone de item (ex.: Amulet Coin), de Resources/items.
struct ItemIcon: View {
    let name: String
    let size: CGFloat

    private static var cache: [String: NSImage] = [:]

    private var image: NSImage? {
        let key = name.lowercased()
        if let c = ItemIcon.cache[key] { return c }
        guard let url = moduleResourceURL(key, in: "items"),
              let img = NSImage(contentsOf: url) else { return nil }
        ItemIcon.cache[key] = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

/// Mapinha da região (Kanto, Hoenn, …), de Resources/regions.
struct RegionMap: View {
    let region: String
    let size: CGFloat

    private static var cache: [String: NSImage] = [:]

    private var image: NSImage? {
        let key = region.lowercased()
        if let c = RegionMap.cache[key] { return c }
        guard let url = moduleResourceURL(key, in: "regions"),
              let img = NSImage(contentsOf: url) else { return nil }
        RegionMap.cache[key] = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

/// Os 3 Pokémon iniciais de uma região, sobrepostos — usado como ícone no lugar do mapa.
/// Cai de volta no mapa da região se não houver iniciais mapeados.
// TODO(ícones): a sobreposição esconde o inicial do MEIO (o de fogo fica quase invisível).
// No futuro, trocar por ícones/layout que mostrem os 3 separados (sem cobrir o do meio).
struct RegionStartersIcon: View {
    let region: String
    let size: CGFloat

    static let starters: [String: [String]] = [
        "kanto":  ["bulbasaur", "charmander", "squirtle"],
        "johto":  ["chikorita", "cyndaquil", "totodile"],
        "hoenn":  ["treecko", "torchic", "mudkip"],
        "sinnoh": ["turtwig", "chimchar", "piplup"],
        "unova":  ["snivy", "tepig", "oshawott"],
    ]

    var body: some View {
        if let names = RegionStartersIcon.starters[region.lowercased()] {
            let sprite = size * 0.72   // preenche bem o quadrado
            let step = (size - sprite) / 2
            ZStack(alignment: .topLeading) {
                // Desenha o do MEIO por último (ordem 0,2,1) pra o inicial de fogo não ficar
                // escondido atrás do 3º — corrige o "fogo some" (Backlog #8). Espelha o Android.
                ForEach([0, 2, 1], id: \.self) { i in
                    PokemonIcon(name: names[i], size: sprite)
                        .offset(x: CGFloat(i) * step, y: (size - sprite) / 2)
                }
            }
            .frame(width: size, height: size, alignment: .topLeading)
        } else {
            RegionMap(region: region, size: size)
        }
    }
}

/// Tela inicial de um modo. Com `groups`, navega em duas etapas (região → cidade) e permite
/// marcar cidades para pular; sem `groups`, mostra a grade de entradas direta (ex.: Red).
struct HomeView: View {
    @EnvironmentObject var engine: SolveEngine
    @EnvironmentObject var skips: SkipStore
    @State private var search: String = ""
    @State private var showSkipped: Bool = false   // #42: pulados somem da lista; este botão reexibe
    @FocusState private var searchFocused: Bool

    /// Grupo aberto vem do engine (assim o "Próximo treinador"/"Reiniciar" de um nó consegue
    /// trocar qual lista de leads aparece). Espelha `engine.selectedGroupName`.
    private var selectedGroup: EntryGroup? {
        guard let name = engine.selectedGroupName else { return nil }
        return engine.solve.groups?.first { $0.name == name }
    }

    /// Filtra entradas pelo texto da busca (case-insensitive).
    private func filtered(_ entries: [EntryPoint]) -> [EntryPoint] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { $0.label.lowercased().contains(q) }
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]
    private var solveId: String { engine.solve.id }
    private var allowSkip: Bool { engine.solve.allowSkip ?? false }

    var body: some View {
        VStack(spacing: 10) {
            if let lead = engine.solve.lead {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundColor(Theme.accent)
                    Text(lead)
                        .font(Theme.rounded(12, weight: .bold))
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let warning = engine.solve.warning {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.warning)
                        .padding(.top, 1)
                    Text(warning)
                        .font(Theme.rounded(11, weight: .semibold))
                        .foregroundColor(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7).padding(.horizontal, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warning.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.warning.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let groups = engine.solve.groups {
                if let group = selectedGroup {
                    cityStep(group)
                } else {
                    regionStep(groups)
                }
            } else {
                flatStep(engine.solve.entryPoints ?? [])
            }
        }
        .padding(10)
    }

    // MARK: - Etapa 1: regiões

    private func regionStep(_ groups: [EntryGroup]) -> some View {
        VStack(spacing: 8) {
            Text(engine.solve.groupPrompt ?? tr(.homeGroupPromptDefault))
                .font(Theme.rounded(11, weight: .medium))
                .foregroundColor(Theme.textDim)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(groups) { group in
                        Button { engine.selectedGroupName = group.name; search = "" } label: {
                            HStack(spacing: 8) {
                                if let p = group.portrait {
                                    TrainerPortrait(name: p, size: 34)
                                        .frame(width: 34, height: 34)
                                } else {
                                    RegionStartersIcon(region: group.name, size: 44)
                                        .frame(width: 44, height: 44)
                                }
                                Text(group.name)
                                    .font(Theme.rounded(14, weight: .bold))
                                    .foregroundColor(Theme.text)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textDim)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Etapa 2: cidades (com marcar para pular)

    private func cityStep(_ group: EntryGroup) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button { engine.selectedGroupName = nil; search = "" } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Text(tr(.back)).font(Theme.rounded(11, weight: .medium))
                    }
                    .foregroundColor(Theme.choice)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(group.name)
                    .font(Theme.rounded(12, weight: .bold))
                    .foregroundColor(Theme.text)
            }

            searchField(placeholder: allowSkip ? tr(.searchCity) : tr(.searchPokemon))

            let rows = filtered(group.entries)
            if rows.isEmpty {
                Text(String(format: tr(.searchNoResults), search))
                    .font(Theme.rounded(10))
                    .foregroundColor(Theme.textDim)
                    .padding(.top, 6)
            }
            ScrollView {
                if allowSkip {
                    // Rota de farm: cidades com "marcar para pular" → lista.
                    // #42 (Lewis): os marcados pra pular SOMEM da lista; um botão reexibe pra desmarcar.
                    let visible = rows.filter { !skips.isSkipped(solveId, $0.nodeId) }
                    let skippedRows = rows.filter { skips.isSkipped(solveId, $0.nodeId) }
                    VStack(spacing: 6) {
                        ForEach(visible) { entry in
                            cityRow(entry)
                        }
                        if !skippedRows.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { showSkipped.toggle() }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: showSkipped ? "eye.slash" : "eye")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(showSkipped
                                         ? tr(.hideSkipped)
                                         : String(format: tr(.showSkipped), skippedRows.count))
                                        .font(Theme.rounded(10, weight: .semibold))
                                }
                                .foregroundColor(Theme.textDim)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Theme.panel.opacity(0.5))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            if showSkipped {
                                ForEach(skippedRows) { entry in
                                    cityRow(entry)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                } else {
                    // Leads de Pokémon (Elite 4) → grade de quadradinhos.
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(rows) { entry in
                            pokemonCell(entry)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    /// Célula de Pokémon em grade (quadradinho com ícone + nome) — lead da Elite 4.
    private func pokemonCell(_ entry: EntryPoint) -> some View {
        Button { engine.jumpTo(entry, group: selectedGroup) } label: {
            VStack(spacing: 3) {
                if let p = entry.portrait {
                    TrainerPortrait(name: p, size: 34).frame(width: 34, height: 34)
                } else {
                    MonOrBallIcon(name: entry.label, size: 34)
                }
                Text(entry.label)
                    .font(Theme.mono(12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Campo de busca que filtra a lista ao digitar.
    private func searchField(placeholder: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Theme.accent)
            ZStack(alignment: .leading) {
                // Placeholder próprio (o nativo fica quase invisível no tema escuro).
                if search.isEmpty {
                    Text(placeholder)
                        .font(Theme.rounded(12))
                        .foregroundColor(Theme.textDim)
                }
                TextField("", text: $search)
                    .textFieldStyle(.plain)
                    .font(Theme.rounded(12))
                    .foregroundColor(Theme.text)
                    .focused($searchFocused)
            }
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(searchFocused ? Theme.accent.opacity(0.6) : Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onAppear {
            // Já deixa a busca pronta pra digitar ao abrir a tela.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { searchFocused = true }
        }
    }

    private func cityRow(_ entry: EntryPoint) -> some View {
        let skipped = allowSkip && skips.isSkipped(solveId, entry.nodeId)
        return HStack(spacing: 8) {
            if allowSkip {
                Button {
                    skips.toggle(solveId, entry.nodeId)
                } label: {
                    Image(systemName: skipped ? "xmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundColor(skipped ? Theme.accent : Theme.textDim.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(skipped ? tr(.citySkipUncheckHelp) : tr(.citySkipMarkHelp))
            }

            Button {
                engine.jumpTo(entry, group: selectedGroup)
            } label: {
                HStack(spacing: 6) {
                    if let p = entry.portrait {
                        TrainerPortrait(name: p, size: 26).frame(width: 26, height: 26)
                    } else {
                        MonOrBallIcon(name: entry.label, size: 24)
                    }
                    Text(entry.label)
                        .font(Theme.mono(12, weight: .medium))
                        .foregroundColor(skipped ? Theme.textDim : Theme.text)
                        .strikethrough(skipped, color: Theme.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    if skipped {
                        Text(tr(.citySkipBadge))
                            .font(Theme.rounded(9, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textDim.opacity(0.7))
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel.opacity(skipped ? 0.5 : 1))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Modo simples (sem regiões)

    private func flatStep(_ entries: [EntryPoint]) -> some View {
        VStack(spacing: 10) {
            Text(engine.solve.homePrompt ?? tr(.flatHomePromptDefault))
                .font(Theme.rounded(11, weight: .medium))
                .foregroundColor(Theme.textDim)
            searchField(placeholder: tr(.searchPokemon))
            let rows = filtered(entries)
            if rows.isEmpty {
                Text(String(format: tr(.searchNoResults), search))
                    .font(Theme.rounded(10))
                    .foregroundColor(Theme.textDim)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(rows) { entry in
                        Button { engine.jumpTo(entry) } label: {
                            VStack(spacing: 3) {
                                // Entrada com retrato de treinador (ex.: Morimoto, Cynthia) mostra a
                                // foto; senão cai no sprite do Pokémon pelo nome (ex.: leads do Red).
                                if let p = entry.portrait {
                                    TrainerPortrait(name: p, size: 34).frame(width: 34, height: 34)
                                } else {
                                    MonOrBallIcon(name: entry.label, size: 34)
                                }
                                Text(entry.label)
                                    .font(Theme.mono(12, weight: .medium))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 4)
                            .background(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}
