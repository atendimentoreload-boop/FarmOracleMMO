import Foundation

enum SolveLoaderError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return String(format: tr(.errorSolveFileNotFound), name)
        }
    }
}

/// Carrega um `Solve` a partir de um JSON embarcado no app (pasta Resources).
/// Aceita nomes com subpasta (ex.: "teams/reversed_fate/elite4_kanto"), resolvendo
/// o último componente como nome do recurso e o resto como subdiretório do bundle.
enum SolveLoader {
    /// Carrega um `Solve`. Quando `lang == .en`, tenta primeiro a variante traduzida
    /// (subpasta `en/` antes do nome do arquivo) e cai para o PT se ela não existir —
    /// assim um roteiro ainda sem tradução nunca quebra, apenas aparece em português.
    static func load(named name: String, lang: Lang = .pt) throws -> Solve {
        if lang == .en, let enURL = resourceURL(for: enVariant(of: name), exactSubdirOnly: true) {
            return try decode(enURL)
        }
        guard let url = resourceURL(for: name) else { throw SolveLoaderError.notFound(name) }
        return try decode(url)
    }

    /// Insere o diretório de idioma `en/` antes do último componente do caminho.
    /// "red" → "en/red" · "teams/x/elite4_kanto" → "teams/x/en/elite4_kanto"
    /// "teams/x/emoji/elite4_kanto" → "teams/x/emoji/en/elite4_kanto"
    private static func enVariant(of name: String) -> String {
        var parts = name.split(separator: "/").map(String.init)
        let base = parts.popLast() ?? name
        parts.append("en")
        parts.append(base)
        return parts.joined(separator: "/")
    }

    /// Resolve a URL do recurso JSON. `exactSubdirOnly` evita o fallback sem subpasta
    /// (usado na tentativa EN, para não casar acidentalmente um arquivo PT de mesmo nome).
    private static func resourceURL(for name: String, exactSubdirOnly: Bool = false) -> URL? {
        let parts = name.split(separator: "/").map(String.init)
        let base = parts.last ?? name
        let subdir = parts.count > 1 ? parts.dropLast().joined(separator: "/") : nil
        if let u = Bundle.module.url(forResource: base, withExtension: "json", subdirectory: subdir) {
            return u
        }
        if exactSubdirOnly { return nil }
        return Bundle.module.url(forResource: base, withExtension: "json")
    }

    private static func decode(_ url: URL) throws -> Solve {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Solve.self, from: data)
    }
}
