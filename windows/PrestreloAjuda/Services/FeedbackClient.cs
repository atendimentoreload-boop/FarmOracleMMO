using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Envia o feedback "funcionou / não funcionou" da Elite 4 para uma planilha do Google
/// (Web App do Apps Script). Fire-and-forget: se falhar, não atrapalha o jogo.
///
/// COMO LIGAR: publique o Apps Script (tools/feedback-apps-script.gs) como Web App e cole
/// a URL /exec em <see cref="Endpoint"/>. Enquanto vazia, os botões só agradecem (sem enviar).
public static class FeedbackClient
{
    // Cole aqui a URL do seu Web App do Apps Script (termina em /exec).
    private const string Endpoint = "https://script.google.com/macros/s/AKfycby_mOTEZqwLis9jJYBYVdFhW2vk99O8R9PMF1oLYHx0ocMiWWVPH4VSTyXTdK88mMVRuA/exec";

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(8) };

    public static bool IsConfigured => !string.IsNullOrEmpty(Endpoint);

    private static string Version()
    {
        var v = typeof(FeedbackClient).Assembly.GetName().Version;
        return v == null ? "0.0.0" : $"{v.Major}.{v.Minor}.{v.Build}";
    }

    public static void Send(string result, string mode, string? team, string? trainer,
                            string? lead, string? path, string? node, string? description)
    {
        if (!IsConfigured) return;
        var payload = JsonSerializer.Serialize(new
        {
            result,
            mode,
            team = team ?? "",
            trainer = trainer ?? "",
            lead = lead ?? "",
            path = path ?? "",
            node = node ?? "",
            description = description ?? "",
            platform = "windows",
            version = Version(),
        });
        // Fire-and-forget; text/plain evita o preflight de CORS do Apps Script.
        _ = Task.Run(async () =>
        {
            try
            {
                using var content = new StringContent(payload, Encoding.UTF8, "text/plain");
                await Http.PostAsync(Endpoint, content);
            }
            catch { /* silencioso */ }
        });
    }
}
