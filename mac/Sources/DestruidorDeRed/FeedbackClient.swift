import Foundation

/// Envia o feedback "funcionou / não funcionou" da Elite 4 para uma planilha do Google
/// (via Web App do Apps Script). Tudo é "fire-and-forget": se falhar, não atrapalha o jogo.
///
/// COMO LIGAR: publique o Apps Script (ver `tools/feedback-apps-script.gs`) como Web App e
/// cole a URL `/exec` em `FeedbackClient.endpoint`. Enquanto estiver vazia, os botões só
/// agradecem localmente (não enviam nada).
enum FeedbackClient {
    /// Cole aqui a URL do seu Web App do Apps Script (termina em `/exec`).
    static let endpoint = "https://script.google.com/macros/s/AKfycby_mOTEZqwLis9jJYBYVdFhW2vk99O8R9PMF1oLYHx0ocMiWWVPH4VSTyXTdK88mMVRuA/exec"

    static var isConfigured: Bool { !endpoint.isEmpty }

    /// Envia um feedback. `result` = "funcionou" ou "nao_funcionou".
    static func send(result: String, mode: String, team: String?, trainer: String?,
                     lead: String?, path: String?, node: String?, description: String?) {
        guard let url = URL(string: endpoint), isConfigured else { return }
        let payload: [String: Any] = [
            "result": result,
            "mode": mode,
            "team": team ?? "",
            "trainer": trainer ?? "",
            "lead": lead ?? "",
            "path": path ?? "",
            "node": node ?? "",
            "description": description ?? "",
            "platform": "mac",
            "version": AppVersion.current,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // text/plain evita o preflight de CORS do Apps Script (inofensivo em app nativo).
        req.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 8
        URLSession.shared.dataTask(with: req).resume()
    }
}
