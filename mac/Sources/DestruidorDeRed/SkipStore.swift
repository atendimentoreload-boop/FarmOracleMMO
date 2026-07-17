import Foundation
import Combine

/// Guarda, por modo (solve), as cidades/paradas marcadas para pular. Persiste em UserDefaults.
/// O fluxo linear ("Próximo") salta automaticamente as paradas marcadas.
@MainActor
final class SkipStore: ObservableObject {
    @Published private var map: [String: Set<String>] = [:]
    private let defaultsKey = "skippedNodes"

    init() { load() }

    func isSkipped(_ solveId: String, _ nodeId: String) -> Bool {
        map[solveId]?.contains(nodeId) ?? false
    }

    func toggle(_ solveId: String, _ nodeId: String) {
        var set = map[solveId] ?? []
        if set.contains(nodeId) {
            set.remove(nodeId)
        } else {
            set.insert(nodeId)
        }
        map[solveId] = set
        save()
    }

    func clear(_ solveId: String) {
        map[solveId] = []
        save()
    }

    func count(_ solveId: String) -> Int { map[solveId]?.count ?? 0 }

    // MARK: - Persistência

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else { return }
        map = decoded.mapValues { Set($0) }
    }

    private func save() {
        let encodable = map.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
