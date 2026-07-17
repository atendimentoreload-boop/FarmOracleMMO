import SwiftUI

/// Overlay "Ver times": mostra os times POSSÍVEIS do adversário no ponto atual.
/// Vários times → todas as possibilidades (compare habilidade/item pra identificar).
/// Um só → time confirmado.
struct TeamsOverlayView: View {
    let data: AppModel.PossibleOpponentTeams
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            ScrollView {
                VStack(spacing: 10) {
                    if !data.confirmed {
                        Text(tr(.teamsDistinguishHint))
                            .font(Theme.rounded(10))
                            .foregroundColor(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(data.teams) { team in
                        teamCard(team)
                    }
                }
                .padding(10)
            }
        }
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .padding(6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: data.confirmed ? "checkmark.seal.fill" : "rectangle.stack.fill")
                .foregroundColor(data.confirmed ? Theme.good : Theme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(data.confirmed ? tr(.teamsConfirmedTitle) : String(format: tr(.teamsPossibleTitle), data.teams.count))
                    .font(Theme.rounded(9, weight: .heavy))
                    .foregroundColor(data.confirmed ? Theme.good : Theme.accent)
                Text("\(data.trainer) · lead \(data.lead)")
                    .font(Theme.rounded(12, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    private func teamCard(_ team: OpponentTeam) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: tr(.teamsTeamCardTitle), "\(team.team)"))
                .font(Theme.rounded(11, weight: .heavy))
                .foregroundColor(Theme.choice)
            ForEach(team.pokemon) { mon in
                monRow(mon)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func monRow(_ mon: OpponentMon) -> some View {
        HStack(alignment: .top, spacing: 7) {
            PokemonIcon(name: mon.pokemon, size: 26)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(mon.pokemon)
                        .font(Theme.rounded(11, weight: .bold))
                        .foregroundColor(Theme.text)
                    if !mon.item.isEmpty {
                        Text(mon.item)
                            .font(Theme.rounded(9, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .lineLimit(1)
                    }
                }
                if !mon.ability.isEmpty {
                    Text(mon.ability)
                        .font(Theme.rounded(9))
                        .foregroundColor(Theme.good)
                }
                Text(mon.moves.joined(separator: " · "))
                    .font(Theme.rounded(9))
                    .foregroundColor(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
