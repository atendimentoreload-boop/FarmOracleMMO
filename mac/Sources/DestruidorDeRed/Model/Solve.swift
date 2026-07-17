import Foundation

// MARK: - Modelo de dados (data-driven)
//
// Uma "luta" (Solve) é uma coleção de nós (Node) identificados por id, mais uma lista de
// pontos de entrada (o que o oponente pode mandar primeiro). Cada nó tem uma sequência de
// passos lineares e, opcionalmente, uma ramificação final (escolha ou salto).
//
// O engine não conhece nada específico do Red — basta trocar o JSON para mapear outra luta.

struct Solve: Codable {
    let id: String
    let title: String
    /// Mensagem fixa exibida na tela inicial (ex.: "Lidere com Infernape").
    let lead: String?
    /// Pergunta/instrução acima da grade de entradas (ex.: "O que o Red colocou?").
    let homePrompt: String?
    /// Título acima da lista de grupos (ex.: "Escolha o campeão:" / "Escolha a região:").
    let groupPrompt: String?
    /// Se verdadeiro, mostra o botão de marcar "pular" em cada entrada (só faz sentido na rota de farm).
    let allowSkip: Bool?
    /// Se verdadeiro, mostra TODOS os passos de um nó de uma vez (sem "Próximo" passo a passo).
    /// Ideal para listas curtas de gym, onde o único avanço é ir para a próxima parada.
    let revealAll: Bool?
    /// Aviso destacado (âmbar) mostrado na tela inicial do modo. Ex.: na Elite 4, avisa que o
    /// guia só vale 100% a partir da 5ª vitória contra aquela Elite.
    let warning: String?
    /// Quando verdadeiro, os `groups` são feitos EM ORDEM (Elite 4: elite 1 → … → campeão).
    /// Habilita o botão "Próximo treinador" no fim de cada luta e "Reiniciar" no campeão.
    let sequentialGroups: Bool?
    /// Legenda/ajuda opcional (explica termos, mostra o time, etc.).
    let legend: [LegendEntry]?
    /// Link do Poképaste com o time exato (Pokémon, itens, golpes) a ser montado.
    /// Exibido como botão "Ver o time" na tela inicial do modo.
    /// `var` porque o time ativo sobrescreve o Poképaste dos modos Elite 4.
    var pokepaste: String?
    /// Link do DOCUMENTO oficial (Google Docs) que originou a estratégia — exibido como
    /// botão de documento ao lado do Poképaste no menu. Opcional.
    var doc: String?
    /// O que o oponente pode mandar primeiro — vira a grade de botões da tela inicial.
    /// Usado quando NÃO há `groups` (navegação em uma etapa).
    let entryPoints: [EntryPoint]?
    /// Agrupamento em duas etapas (ex.: região → cidade). Quando presente, a tela inicial
    /// mostra primeiro os grupos e depois as entradas de cada grupo.
    let groups: [EntryGroup]?
    /// Paleta de cores por Pokémon: colore os nomes de golpes/Pokémon no texto, deixando
    /// claro qual Pokémon usa cada ataque.
    let palette: [PaletteEntry]?
    /// Todos os nós da árvore, indexados por id.
    let nodes: [String: Node]
}

struct PaletteEntry: Codable {
    let name: String          // nome do Pokémon (ex.: "Blastoise")
    let color: String         // cor hex (ex.: "#4FA3FF")
    let moves: [String]       // golpes que esse Pokémon usa (ex.: ["Water Spout"])
}

struct EntryGroup: Codable, Identifiable {
    var id: String { name }
    let name: String
    let entries: [EntryPoint]
    /// Nome do arquivo (sem extensão) do retrato do treinador em Resources/trainers (ex.: "cynthia").
    let portrait: String?
}

struct LegendEntry: Codable, Identifiable {
    var id: String { term }
    let term: String
    let meaning: String
}

struct EntryPoint: Codable, Identifiable {
    var id: String { label }
    let label: String
    let nodeId: String
    /// Retrato de treinador opcional (ex.: líder de ginásio numa cidade da rota de farm).
    let portrait: String?
}

struct Node: Codable {
    let id: String
    /// Rótulo curto mostrado como "breadcrumb" (ex.: "Snorlax", "Snorlax vivo").
    let title: String?
    let steps: [Step]
    let branch: Branch?
    /// Se presente, habilita "Pular esta parada" saltando direto para este nó (próxima cidade).
    let skipTo: String?
    /// Dica de lead desta parada (ex.: "Blastoise e Weezing"). Mostrada no pós-luta da parada
    /// anterior como "próximo lead", para você já preparar a troca de Pokémon.
    let leadHint: String?
    /// Lead estruturado da parada (Pokémon + item segurado): mostrado no topo do ginásio
    /// como ícone + item, e usado no "próximo ginásio" (respeitando os pulados).
    let gymLead: [GymLead]?
}

/// Um Pokémon do lead de um ginásio, com o item que ele segura naquela parada.
struct GymLead: Codable, Identifiable {
    var id: String { pokemon }
    let pokemon: String   // ex.: "Blastoise"
    let item: String?     // ex.: "Choice Scarf"
}

// MARK: - Passos

/// Um passo de um nó. Usa um campo `kind` para discriminar o tipo no JSON.
struct Step: Codable, Identifiable {
    enum Kind: String, Codable {
        case action   // instrução a executar
        case note     // observação/contexto, sem ser uma ação
        case setup    // preparação pós-luta (troca de item/posição, cura, restaurar PP)
        case conditional // tabela "golpe -> alvos" (ex.: Sweep)
    }

    let id: String
    let kind: Kind
    /// Texto da ação ou da nota (em português claro). Nulo para `conditional`.
    let text: String?
    /// Preenchido apenas quando `kind == .conditional`.
    let table: ConditionalTable?

    init(id: String, kind: Kind, text: String? = nil, table: ConditionalTable? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.table = table
    }
}

struct ConditionalTable: Codable {
    /// Cabeçalho da tabela (ex.: "Escolha do golpe final").
    let title: String?
    let rows: [ConditionalRow]
}

struct ConditionalRow: Codable, Identifiable {
    var id: String { move }
    /// Nome do golpe — mantido em inglês (ex.: "Sucker Punch").
    let move: String
    /// Alvos para os quais esse golpe se aplica (em inglês: nomes de Pokémon).
    let targets: [String]
}

// MARK: - Ramificação final do nó

/// Ramificação opcional ao terminar os passos de um nó.
struct Branch: Codable {
    enum Kind: String, Codable {
        case choice // pergunta ao jogador o que o oponente fez -> botões
        case goto   // salta automaticamente para outro nó ("Go to Emboar Solve")
    }

    let kind: Kind
    /// Pergunta exibida acima dos botões (apenas para `.choice`).
    let prompt: String?
    /// Opções/botões (apenas para `.choice`).
    let options: [Option]?
    /// Nó de destino (apenas para `.goto`).
    let nodeId: String?
}

struct Option: Codable, Identifiable {
    var id: String { label + "->" + nodeId }
    let label: String
    let nodeId: String
}
