using System.IO;
using System.Text.Json;
using PrestreloAjuda.Models;

namespace PrestreloAjuda.Services;

/// Carrega um Solve a partir de um JSON em data/ (copiado de /data ao compilar).
public static class SolveLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true
    };

    /// Pasta data/ ao lado do executável (vinda de ../../data via csproj).
    public static string DataDir => Path.Combine(AppContext.BaseDirectory, "data");

    /// Carrega um Solve. Quando lang == En, tenta primeiro a variante traduzida (subpasta `en/`
    /// antes do nome do arquivo) e cai para o PT se ela não existir — assim um roteiro ainda sem
    /// tradução nunca quebra, apenas aparece em português. Porte fiel do SolveLoader.swift do Mac.
    public static Solve Load(string name, Lang lang = Lang.Pt)
    {
        if (lang == Lang.En)
        {
            var enPath = Path.Combine(DataDir, EnVariant(name) + ".json");
            if (File.Exists(enPath)) return Decode(enPath, name);
        }

        var path = Path.Combine(DataDir, name + ".json");
        if (!File.Exists(path))
            throw new FileNotFoundException($"Arquivo {name}.json não encontrado em {DataDir}.", path);
        return Decode(path, name);
    }

    /// Insere o diretório de idioma `en/` antes do último componente do caminho.
    /// "red" → "en/red" · "teams/x/elite4_kanto" → "teams/x/en/elite4_kanto"
    /// "teams/x/emoji/elite4_kanto" → "teams/x/emoji/en/elite4_kanto"
    private static string EnVariant(string name)
    {
        var parts = name.Replace('\\', '/').Split('/');
        if (parts.Length == 0) return "en/" + name;
        var baseName = parts[^1];
        var prefix = parts.Length > 1 ? string.Join("/", parts[..^1]) + "/" : "";
        return prefix + "en/" + baseName;
    }

    private static Solve Decode(string path, string name)
    {
        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<Solve>(json, Options)
               ?? throw new InvalidDataException($"Falha ao ler {name}.json.");
    }
}
