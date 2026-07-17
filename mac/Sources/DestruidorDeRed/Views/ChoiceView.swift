import SwiftUI

/// Pergunta de ramificação: o que o oponente fez? Grade de quadradinhos (1 por opção).
struct ChoiceView: View {
    @EnvironmentObject var engine: SolveEngine
    let branch: Branch

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    /// Pokémon ativo do oponente: último rótulo da trilha que é um Pokémon
    /// (o lead, ou o último que ele trocou). Mesma regra do indicador "no campo".
    private var activeOpponentMon: String? {
        PokemonIcon.actingOpponentMon(trail: engine.pathTrail,
                                      steps: engine.revealedSteps.compactMap { $0.text })
    }

    /// Sprite da opção: o Pokémon citado no rótulo — no início ("Gallade travado no golpe"),
    /// após um marcador de oponente ("Contra Gallade", "vs. Blastoise") ou em qualquer posição
    /// ("deixe fugir Houndoom"). Se é um golpe/ação pura (sem Pokémon), mostra o Pokémon ativo
    /// do oponente (quem dá o golpe).
    private func iconName(for option: Option) -> String {
        if let mon = PokemonIcon.optionSpriteName(in: option.label) { return mon }
        // Opção catch-all "Demais times/Other teams" (nó *_def): sempre Master Ball, nunca
        // herda o oponente ativo do trail (#65 — senão um mon citado antes na run vaza pra cá).
        if option.nodeId.hasSuffix("_def") { return option.label }
        return activeOpponentMon ?? option.label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(branch.prompt ?? tr(.choicePromptDefault))
                .font(Theme.rounded(12, weight: .bold))
                .foregroundColor(Theme.choice)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array((branch.options ?? []).enumerated()), id: \.element.id) { index, option in
                    optionCell(index: index, option: option)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .background(Theme.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    /// Quadradinho de uma opção: selo F1..F12 ACIMA (fora da caixa do texto, mas da mesma opção),
    /// e abaixo o sprite (se for Pokémon) + label.
    private func optionCell(index: Int, option: Option) -> some View {
        Button {
            engine.choose(option)
        } label: {
            VStack(spacing: 2) {
                // Selo da tecla fixa (F1..F12), fora do quadrado do texto. Altura reservada
                // sempre (mesmo sem selo) pra alinhar as células.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if index < 12 {
                        Text("F\(index + 1)")
                            .font(Theme.rounded(9, weight: .bold))
                            .foregroundColor(Theme.choice)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Theme.choice.opacity(0.55), lineWidth: 1)
                            )
                    }
                }
                .frame(height: 15)

                VStack(spacing: 3) {
                    // Golpe/ação → foto do Pokémon ativo do oponente; troca → foto do novo Pokémon.
                    // Opção sem Pokémon (ex.: "Demais times") → Master Ball no lugar do vazio.
                    MonOrBallIcon(name: iconName(for: option), size: 36)
                    Text(option.label)
                        .font(Theme.rounded(11, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Theme.choiceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Theme.choice.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
}
