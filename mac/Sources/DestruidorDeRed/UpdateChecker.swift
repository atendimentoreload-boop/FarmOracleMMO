import Foundation

/// Dados de versão publicados em `/version.json` (raw do GitHub).
struct UpdateInfo {
    let latest: String
    let minimum: String
    let url: String
}

/// Checa a versão mínima exigida online e compara com a versão local.
/// Política "fail-open": se não der pra checar (offline/erro), retorna nil e NÃO bloqueia.
enum UpdateChecker {
    private static let versionURL = URL(string:
        "https://raw.githubusercontent.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/main/version.json")!
    static let releasesURL =
        "https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest"

    static func fetch() async -> UpdateInfo? {
        do {
            var req = URLRequest(url: versionURL)
            req.timeoutInterval = 6
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return UpdateInfo(
                latest: obj["latest"] as? String ?? "",
                minimum: obj["minimum"] as? String ?? "",
                url: obj["url"] as? String ?? releasesURL
            )
        } catch {
            return nil // fail-open
        }
    }

    /// Compara "x.y.z". Retorna < 0 se a < b, 0 se iguais, > 0 se a > b.
    static func compare(_ a: String, _ b: String) -> Int {
        let pa = parse(a), pb = parse(b)
        for i in 0..<3 where pa[i] != pb[i] { return pa[i] < pb[i] ? -1 : 1 }
        return 0
    }

    private static func parse(_ v: String) -> [Int] {
        var r = [0, 0, 0]
        let parts = v.split(separator: ".")
        for i in 0..<min(3, parts.count) { r[i] = Int(parts[i]) ?? 0 }
        return r
    }
}
