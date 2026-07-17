import SwiftUI

/// Mostra o nó atual: passos revelados, tabelas condicionais, escolha ou botão "Próximo".
struct NodeView: View {
    @EnvironmentObject var engine: SolveEngine
    @EnvironmentObject var appModel: AppModel
    @Environment(\.colorizer) private var colorizer
    @State private var showTeams = false

    /// Lead da próxima parada (mostrado no pós-luta quando o avanço é um salto para outra cidade).
    private var nextLeadHint: String? {
        guard let branch = engine.pendingBranch, branch.kind == .goto,
              let target = branch.nodeId,
              let hint = engine.solve.nodes[target]?.leadHint else { return nil }
        return hint
    }

    /// "Unova 3 · Mistralton" -> "Mistralton"
    private func shortStop(_ title: String) -> String {
        if let r = title.range(of: "· ") { return String(title[r.upperBound...]) }
        return title
    }

    /// Pokémon ATIVO do oponente: começa no lead e só muda quando ele troca (opção = nome de
    /// Pokémon). Em golpe/"ficou"/manter, continua o mesmo. nil se a trilha não tem Pokémon (farm).
    private var activeOpponentMon: String? {
        PokemonIcon.actingOpponentMon(trail: engine.pathTrail,
                                      steps: engine.revealedSteps.compactMap { $0.text })
    }

    private func colorizedHint(_ hint: String) -> Text {
        colorizer.runs(hint).reduce(Text("")) { acc, run in
            acc + Text(run.0).foregroundColor(run.1 ?? Theme.text)
        }
        .font(Theme.rounded(11, weight: .semibold))
    }

    var body: some View {
        let teamsInfo = appModel.possibleOpponentTeams()
        return ZStack {
        VStack(spacing: 0) {
            if let portrait = engine.topPortrait {
                OpponentHeader(portrait: portrait, name: engine.topName)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }

            if let mon = activeOpponentMon {
                HStack(spacing: 6) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 8)).foregroundColor(Theme.accent)
                    PokemonIcon(name: mon, size: 20).frame(width: 20, height: 20)
                    Text(mon).font(Theme.rounded(11, weight: .semibold)).foregroundColor(Theme.text)
                    Text(tr(.opponentOnField)).font(Theme.rounded(9)).foregroundColor(Theme.textDim)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
            }

            if let info = teamsInfo {
                seeTeamsButton(info)
            }

            if let title = engine.currentNode?.title {
                HStack(spacing: 5) {
                    Image(systemName: "target").font(.system(size: 10)).foregroundColor(Theme.accent)
                    Text(title)
                        .font(Theme.rounded(12, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 9)
                .padding(.bottom, 4)
            }

            if let leads = engine.currentNode?.gymLead, !leads.isEmpty {
                GymLeadHeader(title: tr(.gymLeadWith), leads: leads, tint: Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 7) {
                        // Ginásio da sequência: esconde o `setup` de entrada aqui — ele é mostrado
                        // no FIM do ginásio ativo ANTERIOR (via upcomingSetupSteps). Sub-nós de opção
                        // (ex.: Driftveil, aviso de PP) NÃO são da sequência → mantêm o setup.
                        let hideSetup = engine.hidesEntrySetup
                        let steps = engine.revealedSteps.filter { !(hideSetup && $0.kind == .setup) }
                        let revealAll = engine.solve.revealAll == true
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            StepRow(step: step,
                                    isCurrent: !revealAll && index == steps.count - 1,
                                    revealAll: revealAll)
                                .id(step.id)
                        }

                        if let branch = engine.pendingBranch, branch.kind == .choice {
                            ChoiceView(branch: branch).padding(.top, 3)
                        }

                        if engine.isTerminal, engine.solve.sequentialGroups != true {
                            TerminalBadge()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .onChange(of: engine.stepIndex) { _ in
                    guard engine.solve.revealAll != true, let last = engine.revealedSteps.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            VStack(spacing: 6) {
                if engine.solve.sequentialGroups == true, engine.isTerminal {
                    EliteEndControls()
                }
                // #68: feedback "funcionou/não funcionou" no FIM de cada ginásio do Gym Rerun
                // (farm = allowSkip). Aparece quando a solve do ginásio acabou: branch "Continuar"
                // (goto) ou nó terminal. `.id` reseta o estado a cada ginásio.
                if engine.solve.allowSkip == true,
                   engine.pendingBranch?.kind == .goto || engine.isTerminal {
                    FeedbackControls().id(engine.currentNodeId)
                }
                // "PÓS-LUTA" de entrada do PRÓXIMO ginásio ativo, mostrado no fim do atual.
                ForEach(engine.upcomingSetupSteps) { step in
                    StepRow(step: step, isCurrent: false, revealAll: true)
                }
                if let upcoming = engine.upcomingGymLead, !upcoming.isEmpty {
                    GymLeadHeader(title: tr(.nextGym) + (engine.upcomingGymTitle.map { " · " + shortStop($0) } ?? ""),
                                  leads: upcoming, tint: Theme.good)
                } else if let hint = nextLeadHint {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.good)
                            .padding(.top, 2)
                        (Text(tr(.nextLeadLabel)).font(Theme.rounded(11, weight: .bold)).foregroundColor(Theme.good)
                            + colorizedHint(hint))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.good.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                if engine.showNextButton {
                    NextButton()
                }
                if engine.canSkip {
                    Button {
                        engine.skip()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "forward.end")
                            Text(tr(.skipThisStop))
                        }
                        .font(Theme.rounded(12, weight: .medium))
                        .foregroundColor(Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .padding(.top, engine.showNextButton || engine.canSkip ? 2 : 0)
        }
        .onAppear { appModel.syncChoiceHotkeys() }
        .onChange(of: engine.currentNodeId) { _ in appModel.syncChoiceHotkeys() }
        .onChange(of: engine.stepIndex) { _ in appModel.syncChoiceHotkeys() }
        .onDisappear { appModel.shortcuts.syncChoiceHotkeys(count: 0) }

            if showTeams, let info = teamsInfo {
                TeamsOverlayView(data: info) { showTeams = false }
            }
        }
    }

    /// Botão "Ver times" — mostra os times possíveis (ou o confirmado) do adversário atual.
    private func seeTeamsButton(_ info: AppModel.PossibleOpponentTeams) -> some View {
        Button { showTeams = true } label: {
            HStack(spacing: 6) {
                Image(systemName: info.confirmed ? "checkmark.seal.fill" : "rectangle.stack.fill")
                    .font(.system(size: 11))
                    .foregroundColor(info.confirmed ? Theme.good : Theme.accent)
                Text(info.confirmed ? tr(.seeTeamsConfirmed) : String(format: tr(.seeTeamsPossible), info.teams.count))
                    .font(Theme.rounded(11, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background((info.confirmed ? Theme.good : Theme.accent).opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke((info.confirmed ? Theme.good : Theme.accent).opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }
}

// MARK: - Cabeçalho de lead do ginásio (ícone + item)

struct GymLeadHeader: View {
    let title: String
    let leads: [GymLead]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(Theme.rounded(8, weight: .heavy))
                .foregroundColor(tint.opacity(0.9))
            HStack(spacing: 12) {
                ForEach(leads) { lead in
                    HStack(spacing: 4) {
                        PokemonIcon(name: lead.pokemon, size: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(lead.pokemon)
                                .font(Theme.rounded(11, weight: .bold))
                                .foregroundColor(Theme.text)
                            if let item = lead.item {
                                Text(item)
                                    .font(Theme.rounded(9))
                                    .foregroundColor(Theme.textDim)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(tint.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Linha de passo

struct StepRow: View {
    let step: Step
    let isCurrent: Bool
    var revealAll: Bool = false

    var body: some View {
        switch step.kind {
        case .action:
            if revealAll { revealAllActionRow } else { actionRow }
        case .note:
            noteRow
        case .setup:
            setupRow
        case .conditional:
            if let table = step.table {
                ConditionalTableView(table: table)
            }
        }
    }

    private var actionRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isCurrent ? "play.circle.fill" : "checkmark.circle")
                .font(.system(size: 13))
                .foregroundColor(isCurrent ? Theme.accent : Theme.good.opacity(0.7))
                .padding(.top, 1)
            ColoredText(text: step.text ?? "",
                        base: isCurrent ? Theme.text : Theme.textDim,
                        size: 13,
                        weight: isCurrent ? .semibold : .regular)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Theme.accentSoft : Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isCurrent ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // Linha de ação no modo "revela tudo": todas iguais, sem destaque de passo atual.
    private var revealAllActionRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.accent)
                .padding(.top, 1)
            ColoredText(text: step.text ?? "", base: Theme.text, size: 13, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var setupRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.good)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr(.stepSetupBadge))
                    .font(Theme.rounded(8, weight: .heavy))
                    .foregroundColor(Theme.good.opacity(0.9))
                ColoredText(text: step.text ?? "", base: Theme.text, size: 12, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.good.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(Theme.good.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // Nota = "linha de solução dentro da linha de solução": diz o golpe exato em cada
    // Pokémon. Se passar batido, a estratégia quebra — por isso tem que GRITAR (âmbar,
    // fundo + borda + texto em negrito), nunca apagado. Regra absoluta de destaque.
    private var noteRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.warning)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr(.stepNoteBadge))
                    .font(Theme.rounded(8, weight: .heavy))
                    .foregroundColor(Theme.warning)
                ColoredText(text: step.text ?? "", base: Theme.text, size: 13, weight: .bold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warning.opacity(0.16))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(Theme.warning.opacity(0.55), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Botão Próximo / Continuar

struct NextButton: View {
    @EnvironmentObject var engine: SolveEngine

    private var nextLabel: String {
        if engine.canAdvanceStep { return tr(.next) }
        if engine.solve.revealAll == true { return tr(.nextStop) }
        return tr(.continueLabel)
    }

    var body: some View {
        Button {
            engine.next()
        } label: {
            HStack(spacing: 6) {
                Text(nextLabel)
                Image(systemName: "chevron.right")
            }
            .font(Theme.rounded(13, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cabeçalho do oponente (foto de quem você enfrenta agora)

struct OpponentHeader: View {
    let portrait: String
    let name: String?

    var body: some View {
        HStack(spacing: 8) {
            TrainerPortrait(name: portrait, size: 30)
                .frame(width: 30, height: 30)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(tr(.opponentHeaderFacing))
                    .font(Theme.rounded(8, weight: .heavy))
                    .foregroundColor(Theme.accent.opacity(0.9))
                if let name = name {
                    Text(name)
                        .font(Theme.rounded(13, weight: .bold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Fim da luta na Elite 4: feedback + próximo treinador / reiniciar

struct EliteEndControls: View {
    @EnvironmentObject var engine: SolveEngine

    var body: some View {
        VStack(spacing: 6) {
            // ---- Feedback (opcional) — reusado no Gym Rerun (#68) via FeedbackControls ----
            FeedbackControls()

            // ---- Próximo treinador (ou reiniciar, no campeão) ----
            if let nxt = engine.nextGroup {
                Button { engine.advanceToNextGroup() } label: {
                    HStack(spacing: 7) {
                        TrainerPortrait(name: nxt.portrait ?? "", size: 22)
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tr(.nextTrainerBadge))
                                .font(Theme.rounded(8, weight: .heavy))
                                .foregroundColor(.black.opacity(0.6))
                            Text(nxt.name)
                                .font(Theme.rounded(13, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundColor(.black)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if engine.isChampionTerminal {
                // Liga concluída: recomeça a Elite 4 no 1º treinador (rollover) — não é beco
                // sem saída pro menu; mantém o farm da Elite 4 em loop.
                Button { engine.restartSequence() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                        Text(tr(.leagueCompleted))
                    }
                    .font(Theme.rounded(13, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.good)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Feedback "funcionou / não funcionou" (#68)

/// Bloco de feedback reusável: aparece no fim da luta da Elite 4 (EliteEndControls) e no fim de
/// cada ginásio do Gym Rerun (NodeView). Tem estado próprio (`sent`/`showFailBox`); quando
/// reaproveitado por ginásio, use `.id(engine.currentNodeId)` pra resetar a cada nó.
struct FeedbackControls: View {
    @EnvironmentObject var engine: SolveEngine
    @EnvironmentObject var appModel: AppModel

    /// nil = ainda não respondeu; "ok"/"fail" = já enviou.
    @State private var sent: String?
    @State private var showFailBox = false
    @State private var failText = ""

    private var modeTitle: String { appModel.currentMode?.title ?? engine.solve.title }

    var body: some View {
        VStack(spacing: 6) {
            if let sent = sent {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.good)
                    Text(sent == "ok" ? tr(.feedbackThanksOk) : tr(.feedbackThanksFail))
                        .font(Theme.rounded(11, weight: .semibold))
                        .foregroundColor(Theme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else if showFailBox {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tr(.feedbackFailPrompt))
                        .font(Theme.rounded(10, weight: .semibold))
                        .foregroundColor(Theme.textDim)
                    TextEditor(text: $failText)
                        .font(Theme.rounded(11))
                        .foregroundColor(Theme.text)
                        .scrollContentBackground(.hidden)
                        .frame(height: 54)
                        .padding(6)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack(spacing: 6) {
                        Button(tr(.cancel)) { showFailBox = false; failText = "" }
                            .buttonStyle(.plain)
                            .font(Theme.rounded(11))
                            .foregroundColor(Theme.textDim)
                        Spacer()
                        Button {
                            sendFeedback("nao_funcionou", description: failText)
                        } label: {
                            Text(tr(.send))
                                .font(Theme.rounded(11, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Theme.warning)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Theme.panel.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                HStack(spacing: 6) {
                    feedbackButton("hand.thumbsup.fill", tr(.feedbackWorked), Theme.good) {
                        sendFeedback("funcionou", description: nil)
                    }
                    feedbackButton("hand.thumbsdown.fill", tr(.feedbackDidntWork), Theme.danger) {
                        showFailBox = true
                    }
                }
            }
        }
    }

    private func sendFeedback(_ result: String, description: String?) {
        FeedbackClient.send(
            result: result,
            mode: modeTitle,
            team: appModel.activeTeamId,
            trainer: engine.topName,
            lead: engine.pathTrail.first,
            path: engine.pathTrail.joined(separator: " → "),
            node: engine.currentNodeId,
            description: description
        )
        sent = (result == "funcionou") ? "ok" : "fail"
    }

    private func feedbackButton(_ icon: String, _ label: String, _ color: Color,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(Theme.rounded(11, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selo de fim de solve

struct TerminalBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill").foregroundColor(Theme.good)
            Text(tr(.terminalBadge))
                .font(Theme.rounded(12, weight: .semibold))
                .foregroundColor(Theme.good)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Theme.good.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.top, 4)
    }
}
