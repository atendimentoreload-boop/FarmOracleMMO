using System.Text;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using PrestreloAjuda.Models;

namespace PrestreloAjuda.Services;

/// Constrói, a partir da paleta do modo, uma lista de termos (nomes de golpes e Pokémon) com
/// suas cores, para colorir o texto deixando claro qual Pokémon usa cada ataque.
/// Porte fiel do `Colorizer`/`GameColors.swift` do app Mac.
public sealed class Colorizer
{
    /// Cor de alerta (âmbar) para avisos como "não precisa usar Encore para bufar".
    public static readonly Color WarningColor = Color.FromRgb(255, 199, 71);

    /// Avisos sempre destacados em âmbar, independente da paleta do modo.
    private static readonly string[] Alerts =
    {
        "(não precisa usar Encore para bufar)",
        "Não precisa usar Encore para bufar"
    };

    private readonly List<(string Phrase, Brush Color)> _tokens = new();
    private readonly Dictionary<string, Brush> _nameColor = new();

    public bool IsEmpty => _tokens.Count == 0;

    public Colorizer(IEnumerable<PaletteEntry>? palette)
    {
        foreach (var entry in palette ?? Enumerable.Empty<PaletteEntry>())
        {
            var brush = Freeze(FromHex(entry.Color));
            _nameColor[entry.Name] = brush;
            _tokens.Add((entry.Name, brush));
            foreach (var move in entry.Moves) _tokens.Add((move, brush));
        }
        // Avisos de alerta (âmbar) — válidos em todos os modos.
        var warn = Freeze(WarningColor);
        foreach (var a in Alerts) _tokens.Add((a, warn));
        // Mais longos primeiro, para casar "Water Spout" antes de qualquer subtrecho.
        _tokens.Sort((a, b) => b.Phrase.Length.CompareTo(a.Phrase.Length));
    }

    private static bool IsWord(char c) => char.IsLetterOrDigit(c);

    /// Divide o texto em trechos coloridos (cor != null) e neutros (null).
    /// Suporta a marcação `{Golpe|Pokémon}`: mostra "Golpe" com a cor do Pokémon indicado,
    /// resolvendo golpes que mais de um Pokémon usa (cor certa por contexto).
    public List<(string Text, Brush? Color)> Runs(string text)
    {
        var result = new List<(string, Brush?)>();
        if (IsEmpty) { result.Add((text, null)); return result; }

        var plain = new StringBuilder();
        int i = 0, n = text.Length;

        while (i < n)
        {
            // Marcação inline {Golpe|Pokémon}
            if (text[i] == '{')
            {
                int close = text.IndexOf('}', i + 1);
                if (close > i)
                {
                    string inner = text.Substring(i + 1, close - i - 1);
                    int bar = inner.IndexOf('|');
                    if (bar >= 0)
                    {
                        string move = inner.Substring(0, bar);
                        string owner = inner[(bar + 1)..];
                        if (plain.Length > 0) { result.Add((plain.ToString(), null)); plain.Clear(); }
                        _nameColor.TryGetValue(owner, out var oc);
                        result.Add((move, oc));
                        i = close + 1;
                        continue;
                    }
                }
            }

            bool matched = false;
            foreach (var (phrase, color) in _tokens)
            {
                int len = phrase.Length;
                if (i + len > n) continue;
                if (string.CompareOrdinal(text, i, phrase, 0, len) != 0) continue;
                bool beforeOk = i == 0 || !IsWord(text[i - 1]);
                int after = i + len;
                bool afterOk = after >= n || !IsWord(text[after]);
                if (!beforeOk || !afterOk) continue;
                if (plain.Length > 0) { result.Add((plain.ToString(), null)); plain.Clear(); }
                result.Add((phrase, color));
                i = after;
                matched = true;
                break;
            }
            if (!matched) { plain.Append(text[i]); i++; }
        }
        if (plain.Length > 0) result.Add((plain.ToString(), null));
        return result;
    }

    /// Substitui o conteúdo de um TextBlock por Runs coloridos (cor da paleta ou `baseColor`).
    public void Apply(TextBlock tb, string text, Brush baseColor)
    {
        tb.Inlines.Clear();
        Append(tb, text, baseColor);
    }

    /// Acrescenta Runs coloridos a um TextBlock já existente (sem limpar o que já há).
    public void Append(TextBlock tb, string text, Brush baseColor)
    {
        foreach (var (chunk, color) in Runs(text))
            tb.Inlines.Add(new Run(chunk) { Foreground = color ?? baseColor });
    }

    private static Color FromHex(string hex)
    {
        hex = hex.Trim().TrimStart('#');
        if (hex.Length < 6) return Colors.White;
        try
        {
            byte r = Convert.ToByte(hex.Substring(0, 2), 16);
            byte g = Convert.ToByte(hex.Substring(2, 2), 16);
            byte b = Convert.ToByte(hex.Substring(4, 2), 16);
            return Color.FromRgb(r, g, b);
        }
        catch { return Colors.White; }
    }

    private static Brush Freeze(Color c)
    {
        var b = new SolidColorBrush(c);
        b.Freeze();
        return b;
    }
}
