import SwiftUI

/// Tabela "golpe → alvos" (ex.: golpe final do Bisharp dependendo de quem está em campo).
/// Os nomes de golpes e Pokémon ficam em inglês para baterem com a tela do jogo.
struct ConditionalTableView: View {
    let table: ConditionalTable

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(table.title ?? tr(.conditionalTableTitleDefault))
                .font(Theme.rounded(11, weight: .semibold))
                .foregroundColor(Theme.textDim)

            ForEach(table.rows) { row in
                HStack(alignment: .top, spacing: 6) {
                    Text(row.move)
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textDim)
                        .padding(.top, 2)
                    Text(row.targets.joined(separator: ", "))
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelHi)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
