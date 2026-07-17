using System.Net.Http;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Dados de versão publicados em /version.json (raw do GitHub).
public sealed record UpdateInfo(string Latest, string Minimum, string Url);

/// Checa a versão mínima exigida online e compara com a versão local.
/// Política "fail-open": se não der pra checar (offline/erro), NÃO bloqueia.
public static class UpdateChecker
{
    private const string VersionUrl =
        "https://raw.githubusercontent.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/main/version.json";

    public const string ReleasesUrl =
        "https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest";

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(6) };

    public static async Task<UpdateInfo?> FetchAsync()
    {
        try
        {
            var json = await Http.GetStringAsync(VersionUrl);
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            string Get(string k, string fallback) =>
                r.TryGetProperty(k, out var v) ? v.GetString() ?? fallback : fallback;
            return new UpdateInfo(Get("latest", ""), Get("minimum", ""), Get("url", ReleasesUrl));
        }
        catch { return null; } // fail-open: sem rede não bloqueia
    }

    /// Compara versões "x.y.z". Retorna &lt;0 se a &lt; b, 0 se iguais, &gt;0 se a &gt; b.
    public static int Compare(string a, string b)
    {
        int[] pa = Parse(a), pb = Parse(b);
        for (int i = 0; i < 3; i++)
            if (pa[i] != pb[i]) return pa[i].CompareTo(pb[i]);
        return 0;
    }

    private static int[] Parse(string v)
    {
        var parts = (v ?? "").Split('.');
        var r = new int[3];
        for (int i = 0; i < 3 && i < parts.Length; i++) int.TryParse(parts[i], out r[i]);
        return r;
    }
}
