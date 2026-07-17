import Foundation

/// Catálogo dos times do adversário (Elite 4), extraído do Pokeking sem filtro de CODE.
/// Fonte: `data/elite4-opponents.json` → bundle. Estrutura: regiões → treinador → [times].
///
/// Usado pelo overlay "Ver times": dado o treinador e o lead, mostra os times POSSÍVEIS
/// (todos os que contêm aquele Pokémon), estreitados pelo `lineList` do roteiro quando houver.

struct OpponentMon: Codable, Identifiable, Hashable {
    let pokemon: String
    let ability: String
    let item: String
    let moves: [String]
    var id: String { pokemon }
}

struct OpponentTeam: Codable, Identifiable, Hashable {
    let team: Int                  // número "N号队伍" (canônico, bate com o lineList do roteiro)
    let pokemon: [OpponentMon]
    var id: Int { team }

    func contains(pokemonNamed name: String) -> Bool {
        let n = name.lowercased()
        return pokemon.contains { $0.pokemon.lowercased() == n }
    }
}

enum OpponentCatalog {
    private struct File: Codable { let regions: [String: [String: [OpponentTeam]]] }

    /// regiões → treinador → [times]. Carregado uma vez do bundle.
    static let regions: [String: [String: [OpponentTeam]]] = {
        guard let url = Bundle.module.url(forResource: "elite4-opponents", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.regions
    }()

    /// `elite4_sinnoh` → `Sinnoh`. nil para modos que não são da Elite 4.
    static func regionName(modeId: String) -> String? {
        [
            "elite4_kanto": "Kanto", "elite4_hoenn": "Hoenn", "elite4_sinnoh": "Sinnoh",
            "elite4_johto": "Johto", "elite4_unova": "Unova",
        ][modeId]
    }

    /// Nome do grupo no roteiro → chave no catálogo. Cuida dos casos especiais:
    /// Kanto "Gary" = campeão "Blue"; Johto "Bruno"/"Lance" são distintos dos de Kanto.
    static func trainerKey(region: String, group: String) -> String {
        if region == "Johto" {
            if group == "Bruno" { return "Bruno (Johto)" }
            if group == "Lance" { return "Lance (Johto)" }
        }
        if region == "Kanto", group == "Gary" { return "Blue" }
        return group
    }

    static func teams(region: String, trainer: String) -> [OpponentTeam] {
        regions[region]?[trainer] ?? []
    }
}
