import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Tela do sistema de Cooldown/Alarme (#33), aberta pelo "reloginho" da barra de topo.
/// Lista principal = os BONECOS (cadastro). Ao abrir um boneco: abas Batalhas e Berries.
struct CooldownView: View {
    @Binding var showCooldowns: Bool
    @EnvironmentObject var store: CooldownStore

    @State private var selectedCharId: String? = nil
    @State private var tab: Tab = .battles
    @State private var newCharName = ""
    @State private var showElite4 = false
    @State private var showOptional = false
    @State private var showBerryPicker = false
    @State private var refreshTick = Date()
    enum Tab { case battles, berries }

    /// Âncora do botão "Adicionar berry": após adicionar, rolamos de volta pra cá para
    /// que o botão continue à vista (o berryPicker é um overlay e recria a árvore, o que
    /// jogava o ScrollView pro topo e impedia adicionar várias berries em sequência).
    private static let addBerryAnchor = "cd.addBerry.anchor"

    /// Só pra snapshot (--cdshot): renderiza sem ScrollView, que o ImageRenderer não captura.
    private let previewNoScroll: Bool

    init(showCooldowns: Binding<Bool>, previewCharId: String? = nil,
         previewBerries: Bool = false, previewExpandElite4: Bool = false,
         previewNoScroll: Bool = false) {
        _showCooldowns = showCooldowns
        _selectedCharId = State(initialValue: previewCharId)
        _tab = State(initialValue: previewBerries ? .berries : .battles)
        _showElite4 = State(initialValue: previewExpandElite4)
        self.previewNoScroll = previewNoScroll
    }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var selectedChar: GameCharacter? {
        store.state.characters.first { $0.id == selectedCharId }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            let content = Group {
                if let char = selectedChar { characterDetail(char) }
                else { characterList }
            }.padding(12)
            if previewNoScroll {
                content.frame(maxWidth: .infinity, alignment: .top)
            } else {
                ScrollViewReader { proxy in
                    ScrollView { content }
                        // Ao adicionar uma berry (via overlay berryPicker) a árvore é recriada e o
                        // ScrollView voltava pro topo → não dava pra adicionar várias em sequência.
                        // Após a lista mudar, rola de volta pro botão "Adicionar".
                        .onChange(of: store.shownBerries.count) { _ in
                            guard tab == .berries, selectedCharId != nil else { return }
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(Self.addBerryAnchor, anchor: .bottom)
                                }
                            }
                        }
                }
            }
        }
        .overlay { if showBerryPicker { berryPicker } }
        .onReceive(ticker) { refreshTick = $0 }
        .onDisappear { showCooldowns = false }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                if selectedCharId != nil { selectedCharId = nil } else { showCooldowns = false }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    Text(selectedCharId != nil ? tr(.cdCharacters) : tr(.back))
                        .font(Theme.rounded(12, weight: .semibold))
                }
                .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text((selectedChar?.name ?? tr(.cdTitle)).uppercased())
                .font(Theme.rounded(12, weight: .bold)).foregroundColor(Theme.text).tracking(0.5)
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 64, height: 1)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    // MARK: - Lista de personagens (cadastro)

    private var characterList: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(tr(.cdCharacters))
            if store.state.characters.isEmpty {
                Text(tr(.cdNoCharacters))
                    .font(Theme.rounded(12)).foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
            } else {
                group {
                    ForEach(Array(store.state.characters.enumerated()), id: \.element.id) { i, char in
                        if i > 0 { rowDivider }
                        characterRow(char)
                    }
                }
            }
            // cadastro
            HStack(spacing: 8) {
                TextField(tr(.cdCharacterName), text: $newCharName)
                    .textFieldStyle(.plain)
                    .font(Theme.rounded(13)).foregroundColor(Theme.text)
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(Color.black.opacity(0.28))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit(addCharacter)
                Button(action: addCharacter) {
                    Text(tr(.cdAdd)).font(Theme.rounded(13, weight: .semibold)).foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Theme.good).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private func characterRow(_ char: GameCharacter) -> some View {
        HStack(spacing: 8) {
            Button { selectedCharId = char.id; tab = .battles } label: {
                HStack(spacing: 9) {
                    CharAvatar(name: char.name, avatarBase64: char.avatar, size: 30)
                    Text(char.name).font(Theme.rounded(13, weight: .semibold)).foregroundColor(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(charSummary(char)).font(Theme.rounded(9)).foregroundColor(Theme.textDim)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            iconMini("pencil") { editCharacter(char) }
            iconMini("trash") { removeCharacter(char) }
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textDim.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    /// Ex.: "2 ativo(s)" — quantas tarefas desse boneco estão em cooldown/plantadas.
    private func charSummary(_ char: GameCharacter) -> String {
        let active = store.shownBattle(for: char).filter { store.isBattleActive(char, $0) }.count
        let planted = store.shownBerries.filter {
            if case .empty = store.berryStatus(char, $0).phase { return false }; return true
        }.count
        let n = active + planted
        return n == 0 ? "" : String(format: tr(.cdActiveCount), n)
    }

    // MARK: - Detalhe do boneco (Batalhas / Berries)

    private func characterDetail(_ char: GameCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // abas
            HStack(spacing: 6) {
                tabButton(tr(.cdBattles), "flame.fill", .battles)
                tabButton(tr(.cdBerries), "leaf.fill", .berries)
            }
            if tab == .battles { battlesSection(char) } else { berriesSection(char) }
        }
    }

    private func tabButton(_ title: String, _ symbol: String, _ t: Tab) -> some View {
        Button { tab = t } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title).font(Theme.rounded(12, weight: .semibold))
            }
            .foregroundColor(tab == t ? .black : Theme.textDim)
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(tab == t ? Theme.accent : Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: Batalhas

    private func battlesSection(_ char: GameCharacter) -> some View {
        let all = store.shownBattle(for: char)
        let elite = all.filter { $0.group == "elite4" }
        let others = all.filter { $0.group != "elite4" }
        return VStack(alignment: .leading, spacing: 8) {
            // Elite 4 vira um submenu que abre cada região
            if !elite.isEmpty { elite4Group(char, elite) }
            // demais batalhas (ginásio, Red, Cynthia & Morimoto, farm de treinadores)
            if !others.isEmpty {
                group {
                    ForEach(Array(others.enumerated()), id: \.element.id) { i, task in
                        if i > 0 { rowDivider }
                        battleRow(char, task)
                    }
                }
            }
            // opcionais (recolhido)
            Button { withAnimation(.easeInOut(duration: 0.15)) { showOptional.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: showOptional ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textDim)
                    Text(tr(.cdOptional).uppercased())
                        .font(Theme.rounded(9, weight: .bold)).foregroundColor(Theme.accent).tracking(0.8)
                    Spacer()
                }.padding(.top, 2).padding(.horizontal, 4).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if showOptional {
                group {
                    ForEach(Array(store.catalog.optionalTasks.enumerated()), id: \.element.id) { i, task in
                        if i > 0 { rowDivider }
                        battleRow(char, task)
                    }
                }
            }
        }
    }

    /// Submenu da Elite 4: um cabeçalho que expande as 5 regiões.
    private func elite4Group(_ char: GameCharacter, _ tasks: [BattleTask]) -> some View {
        let activeCount = tasks.filter { store.isBattleActive(char, $0) }.count
        return group {
            Button { withAnimation(.easeInOut(duration: 0.15)) { showElite4.toggle() } } label: {
                HStack(spacing: 11) {
                    ItemIcon(name: "trophy", size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr(.cdElite4)).font(Theme.rounded(13, weight: .bold)).foregroundColor(Theme.text)
                        Text(activeCount > 0 ? String(format: tr(.cdActiveCount), activeCount)
                                              : "\(tasks.count) \(AppLang.current == .en ? "regions" : "regiões")")
                            .font(Theme.rounded(10)).foregroundColor(Theme.textDim)
                    }
                    Spacer()
                    Image(systemName: showElite4 ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textDim)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if showElite4 {
                ForEach(tasks) { task in
                    rowDivider
                    battleRow(char, task, isChild: true)
                }
            }
        }
    }

    /// Rótulo curto quando a tarefa está sob um submenu (ex.: "Elite 4 — Kanto" -> "Kanto").
    private func shortLabel(_ task: BattleTask) -> String {
        let full = task.name.localized
        if let r = full.range(of: "—") { return full[r.upperBound...].trimmingCharacters(in: .whitespaces) }
        return full
    }

    private func battleRow(_ char: GameCharacter, _ task: BattleTask, isChild: Bool = false) -> some View {
        let phase = store.battlePhase(char, task)
        let remain = store.battleRemainingMs(char, task)
        return HStack(spacing: 11) {
            CDTaskIcon(spec: task.icon, color: cdColor(task.color), size: isChild ? 26 : 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(isChild ? shortLabel(task) : task.name.localized)
                    .font(Theme.rounded(13, weight: .semibold)).foregroundColor(Theme.text)
                    .lineLimit(1).minimumScaleFactor(0.8)
                switch phase {
                case .running:
                    chronoChip("hourglass", "", fmtRemain(remain), Theme.accent)
                case .ready:
                    Text(tr(.cdDoNow)).font(Theme.rounded(11, weight: .bold)).foregroundColor(Theme.good)
                case .idle:
                    Text(tr(.cdTapToStart) + " · " + fmtHoursLabel(task.hours))
                        .font(Theme.rounded(10)).foregroundColor(Theme.textDim).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 4)
            if phase == .running {
                resetButton { store.clearBattle(char, task) }
            } else {
                Image(systemName: "play.circle.fill").font(.system(size: 22))
                    .foregroundColor(phase == .ready ? Theme.good : Theme.good.opacity(0.85))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(phase == .ready ? Theme.good.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { if phase != .running { store.markBattle(char, task) } }
    }

    // MARK: Berries

    private func berriesSection(_ char: GameCharacter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            group {
                let berries = store.shownBerries
                ForEach(Array(berries.enumerated()), id: \.element.id) { i, berry in
                    if i > 0 { rowDivider }
                    berryRow(char, berry)
                }
            }
            Button { showBerryPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 13, weight: .bold))
                    Text(tr(.cdAddBerry)).font(Theme.rounded(12, weight: .semibold))
                }.foregroundColor(Theme.accent).padding(.top, 4)
            }.buttonStyle(.plain)
            .id(Self.addBerryAnchor)
        }
    }

    private func berryRow(_ char: GameCharacter, _ berry: BerryDef) -> some View {
        let st = store.berryStatus(char, berry)
        return HStack(alignment: .top, spacing: 11) {
            BerryIcon(berryId: berry.id, size: 30)
                .saturation(st.phase == .empty ? 0.35 : 1)
                .opacity(st.phase == .empty ? 0.65 : 1)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                // nome + ação principal na MESMA linha (deixa os cronômetros com largura cheia embaixo)
                HStack(spacing: 8) {
                    Text(berry.name.localized).font(Theme.rounded(13, weight: .semibold))
                        .foregroundColor(Theme.text).lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    berryActions(char, berry, st)
                }
                berryLines(char, berry, st)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(berryHighlight(st.phase))
    }

    /// Os cronômetros de uma berry: colheita (🌾) e próxima rega (💧) — sempre visíveis enquanto cresce.
    @ViewBuilder
    private func berryLines(_ char: GameCharacter, _ berry: BerryDef, _ st: CooldownStore.BerryStatus) -> some View {
        switch st.phase {
        case .empty:
            if let tier = store.catalog.tier(berry.tier) {
                Text("⏱ " + fmtHoursLabel(tier.growthHours) + " · 💧 \(tier.waterWindowsHours.count)×")
                    .font(Theme.rounded(10)).foregroundColor(Theme.textDim)
            } else {
                Text(tr(.cdEmpty)).font(Theme.rounded(11)).foregroundColor(Theme.textDim)
            }
        case .growing:
            VStack(alignment: .leading, spacing: 3) {
                // colheita (cronômetro)
                chronoChip("leaf.fill", tr(.cdHarvestShort), fmtRemain(st.harvestRemainMs), Theme.good)
                // próxima rega: AGORA / cronômetro / concluídas
                let prog = " (\(st.waterings)/\(st.totalWaters))"
                if st.waterPending {
                    chronoChip("drop.fill", "", tr(.cdWaterNow).uppercased() + prog, Theme.choice, urgent: true)
                } else if let w = st.nextWaterRemainMs {
                    chronoChip("drop.fill", tr(.cdNextWater), fmtRemain(max(0, w)) + prog, Theme.choice)
                } else if st.totalWaters > 0 {
                    chronoChip("drop.fill", tr(.cdNextWater), tr(.cdAllWatered) + " ✓", Theme.textDim)
                }
            }
        case .ready:
            chronoChip("checkmark.seal.fill", tr(.cdHarvestShort), tr(.cdReadyLabel).uppercased(), Theme.good, urgent: true)
        case .wilted:
            chronoChip("exclamationmark.triangle.fill", tr(.cdHarvestShort), tr(.cdWilted).uppercased(), Theme.warning, urgent: true)
        }
    }

    /// Cronômetro claro: ícone + rótulo pequeno (opcional) + TEMPO em destaque (mono).
    /// `urgent` = fundo colorido. Nunca quebra linha (fixedSize).
    private func chronoChip(_ symbol: String, _ label: String, _ time: String, _ color: Color, urgent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).foregroundColor(color)
            if !label.isEmpty {
                Text(label.uppercased()).font(Theme.rounded(8.5, weight: .bold))
                    .foregroundColor(Theme.textDim).tracking(0.3).lineLimit(1)
            }
            Text(time).font(Theme.mono(12.5, weight: .bold)).foregroundColor(color).lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(urgent ? color.opacity(0.16) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private func berryActions(_ char: GameCharacter, _ berry: BerryDef, _ st: CooldownStore.BerryStatus) -> some View {
        switch st.phase {
        case .empty:
            HStack(spacing: 6) {
                pillButton(tr(.cdPlant), Theme.good) { store.plantBerry(char, berry) }
                iconMini("trash") { store.removeBerry(char, berry.id) }
            }
        case .growing:
            HStack(spacing: 6) {
                if st.waterPending { pillButton(tr(.cdWatered), Theme.choice) { store.waterBerry(char, berry) } }
                resetIconMini { store.harvestBerry(char, berry) }
            }
        case .ready, .wilted:
            pillButton(tr(.cdHarvest), Theme.good) { store.harvestBerry(char, berry) }
        }
    }

    private func berryHighlight(_ phase: CooldownStore.BerryPhase) -> Color {
        switch phase {
        case .ready: return Theme.good.opacity(0.12)
        case .wilted: return Theme.warning.opacity(0.12)
        default: return .clear
        }
    }

    // MARK: - Seletor de berry (biblioteca)

    private var berryPicker: some View {
        ZStack {
            Theme.bg.opacity(0.98).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { showBerryPicker = false } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                            Text(tr(.back)).font(Theme.rounded(12, weight: .semibold))
                        }.foregroundColor(Theme.accent)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(tr(.cdAddBerry).uppercased()).font(Theme.rounded(12, weight: .bold))
                        .foregroundColor(Theme.text).tracking(0.5)
                    Spacer(); Color.clear.frame(width: 50)
                }.padding(.horizontal, 10).padding(.vertical, 8)
                Rectangle().fill(Theme.line).frame(height: 1)
                ScrollView {
                    let available = store.catalog.berries.filter { b in !store.shownBerries.contains { $0.id == b.id } }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(store.catalog.berryTiers) { tier in
                            let list = available.filter { $0.tier == tier.tier }
                            if !list.isEmpty {
                                Text(String(format: tr(.cdTierLabel), Int(tier.growthHours)))
                                    .font(Theme.rounded(9, weight: .bold)).foregroundColor(Theme.accent)
                                    .tracking(0.8).padding(.top, 8).padding(.leading, 4)
                                group {
                                    ForEach(Array(list.enumerated()), id: \.element.id) { i, berry in
                                        if i > 0 { rowDivider }
                                        Button { store.addBerry(berry.id); showBerryPicker = false } label: {
                                            HStack(spacing: 10) {
                                                BerryIcon(berryId: berry.id, size: 24)
                                                Text(berry.name.localized).font(Theme.rounded(13)).foregroundColor(Theme.text)
                                                Spacer()
                                                Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                                            }.padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }.padding(12)
                }
            }
        }
    }

    // MARK: - Ações (NSAlert)

    private func addCharacter() {
        store.addCharacter(name: newCharName)
        newCharName = ""
    }
    /// Editar boneco: renomeia (campo de texto) e oferece o botão "Foto…" pra trocar/remover a foto.
    private func editCharacter(_ char: GameCharacter) {
        let alert = NSAlert()
        alert.messageText = tr(.cdRenameTitle)
        alert.informativeText = tr(.cdPhotoHint)
        alert.addButton(withTitle: "OK")            // .alertFirstButtonReturn
        alert.addButton(withTitle: tr(.cdPhoto))    // .alertSecondButtonReturn
        alert.addButton(withTitle: tr(.cancel))     // .alertThirdButtonReturn
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = char.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let resp = alert.runModal()
        guard resp != .alertThirdButtonReturn else { return }   // cancelar
        store.renameCharacter(char.id, to: field.stringValue)   // aplica o nome (OK ou Foto)
        if resp == .alertSecondButtonReturn { managePhoto(char) }
    }

    /// Se já tem foto: pergunta trocar/remover; senão abre o seletor direto.
    private func managePhoto(_ char: GameCharacter) {
        let hasPhoto = store.state.characters.first { $0.id == char.id }?.avatar != nil
        guard hasPhoto else { pickAvatar(char); return }
        let a = NSAlert()
        a.messageText = tr(.cdPhoto)
        a.addButton(withTitle: tr(.cdChangePhoto))  // .first
        a.addButton(withTitle: tr(.cdRemovePhoto))  // .second
        a.addButton(withTitle: tr(.cancel))         // .third
        switch a.runModal() {
        case .alertFirstButtonReturn: pickAvatar(char)
        case .alertSecondButtonReturn: store.setAvatar(char.id, pngBase64: nil)
        default: break
        }
    }

    /// Abre o seletor de imagem, reduz pra um ícone quadrado de 128×128 e salva no boneco.
    private func pickAvatar(_ char: GameCharacter) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = tr(.cdChoosePhoto)
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url),
           let b64 = squareIconBase64(img, side: 128) {
            store.setAvatar(char.id, pngBase64: b64)
        }
    }

    /// Recorta a imagem no centro (aspect-fill) e redimensiona pra `side`×`side` px; devolve PNG base64.
    private func squareIconBase64(_ image: NSImage, side: CGFloat) -> String? {
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0 else { return nil }
        let out = NSImage(size: NSSize(width: side, height: side))
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let scale = max(side / iw, side / ih)   // preenche o quadrado (corta o excesso)
        let dw = iw * scale, dh = ih * scale
        image.draw(in: NSRect(x: (side - dw) / 2, y: (side - dh) / 2, width: dw, height: dh),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        out.unlockFocus()
        guard let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png.base64EncodedString()
    }
    private func removeCharacter(_ char: GameCharacter) {
        let a = NSAlert()
        a.messageText = String(format: tr(.cdRemoveConfirm), char.name)
        a.addButton(withTitle: tr(.cdRemove)); a.addButton(withTitle: tr(.cancel))
        if a.runModal() == .alertFirstButtonReturn {
            if selectedCharId == char.id { selectedCharId = nil }
            store.removeCharacter(char.id)
        }
    }
    // MARK: - Componentes locais

    @ViewBuilder
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(Theme.rounded(12, weight: .black))
            .foregroundColor(Theme.text).tracking(0.5).padding(.bottom, 2)
    }
    private var rowDivider: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 48)
    }
    private func iconMini(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textDim).frame(width: 22, height: 22)
        }.buttonStyle(.plain)
    }
    /// Botão de reset CLARO (ícone de girar + rótulo "Resetar"), contornado em vermelho.
    private func resetButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                Text(tr(.cdReset)).font(Theme.rounded(11, weight: .semibold))
            }
            .foregroundColor(Theme.danger)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .overlay(Capsule().stroke(Theme.danger.opacity(0.55), lineWidth: 1))
        }.buttonStyle(.plain).help(tr(.cdReset))
    }
    /// Reset compacto (só o ícone ↺ com anel vermelho) — pra linhas apertadas de berry. Não é um "X".
    private func resetIconMini(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.danger).frame(width: 24, height: 24)
                .overlay(Circle().stroke(Theme.danger.opacity(0.45), lineWidth: 1))
        }.buttonStyle(.plain).help(tr(.cdReset))
    }
    private func pillButton(_ title: String, _ bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.rounded(11, weight: .bold)).foregroundColor(.black)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(bg).clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    /// "6h", "18h", "7d" — rótulo curto de uma duração em horas.
    private func fmtHoursLabel(_ hours: Double) -> String {
        if hours >= 24, hours.truncatingRemainder(dividingBy: 24) == 0 {
            return "\(Int(hours / 24))d"
        }
        return "\(Int(hours))h"
    }
}

// MARK: - Ícones do sistema de cooldown

/// Ícone de uma tarefa de batalha, resolvido pela spec do catálogo:
/// "region:x" (mapa) · "trainer:x" (retrato) · "item:x" · "sprite:x" (Pokémon) · "sf:símbolo".
/// Sem spec (ou desconhecida) cai no ponto colorido da tarefa.
struct CDTaskIcon: View {
    let spec: String?
    let color: Color
    let size: CGFloat

    var body: some View {
        if let spec, let sep = spec.firstIndex(of: ":") {
            let kind = String(spec[..<sep])
            let name = String(spec[spec.index(after: sep)...])
            switch kind {
            case "region":  RegionMap(region: name, size: size)
            case "trainer": TrainerPortrait(name: name, size: size)
            case "item":    ItemIcon(name: name, size: size)
            case "sprite":  PokemonIcon(name: name, size: size)
            case "sf":
                Image(systemName: name).font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundColor(color).frame(width: size, height: size)
            default: dot
            }
        } else { dot }
    }

    private var dot: some View {
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: size, height: size)
            Circle().fill(color).frame(width: size * 0.42, height: size * 0.42)
                .shadow(color: color.opacity(0.7), radius: 3)
        }
    }
}

/// Ícone do boneco: a foto (PNG base64) recortada em círculo, ou o monograma (1ª letra) se não houver.
struct CharAvatar: View {
    let name: String
    let avatarBase64: String?
    let size: CGFloat

    private var img: NSImage? {
        guard let b = avatarBase64, !b.isEmpty, let d = Data(base64Encoded: b) else { return nil }
        return NSImage(data: d)
    }

    var body: some View {
        Group {
            if let img {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Theme.accentSoft)
                    Text(String(name.prefix(1)).uppercased())
                        .font(Theme.rounded(size * 0.46, weight: .bold)).foregroundColor(Theme.accent)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
    }
}

/// Sprite de uma berry (Resources/sprites/berries/<nome>.png), pelo id "berry_<nome>".
struct BerryIcon: View {
    let berryId: String
    let size: CGFloat

    private static var cache: [String: NSImage] = [:]

    private var image: NSImage? {
        let key = berryId.hasPrefix("berry_") ? String(berryId.dropFirst(6)) : berryId
        if let c = BerryIcon.cache[key] { return c }
        guard let url = moduleResourceURL(key, in: "sprites/berries"),
              let img = NSImage(contentsOf: url) else { return nil }
        BerryIcon.cache[key] = img
        return img
    }

    var body: some View {
        if let img = image {
            Image(nsImage: img).interpolation(.none).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "leaf.fill").font(.system(size: size * 0.55))
                .foregroundColor(Theme.good).frame(width: size, height: size)
        }
    }
}

/// Converte "#rrggbb" numa Color.
func cdColor(_ hex: String) -> Color {
    var s = hex; if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    return Color(red: Double((v >> 16) & 0xff) / 255,
                 green: Double((v >> 8) & 0xff) / 255,
                 blue: Double(v & 0xff) / 255)
}
