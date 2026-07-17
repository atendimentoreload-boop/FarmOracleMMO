using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Preferências de time/visualização, em %LOCALAPPDATA%\PrestreloAjuda\teamprefs.json.
/// (Separado do ShortcutStore para não colidir no mesmo arquivo.)
public static class TeamPrefs
{
    private static string Dir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PrestreloAjuda");
    private static string FilePath => Path.Combine(Dir, "teamprefs.json");

    private sealed class Data
    {
        public string? Team { get; set; }
        public bool Emoji { get; set; }
        /// Idioma da interface ("pt" / "en"). null = ainda não escolhido (padrão "pt").
        public string? Language { get; set; }
        /// Opacidade do overlay (0.35..1.0). null = padrão 0.95.
        public double? Opacity { get; set; }
        /// Rota ativa do Farm de Ginásios ("veteran" / "lucky_girl"). null = padrão "veteran".
        public string? FarmRoute { get; set; }
        /// Estratégia/time ativo do modo Cynthia & Morimoto. null = padrão "cynthia_morimoto".
        public string? CynthiaMorimotoStrategy { get; set; }
        /// Estratégia/time ativo do modo Red ("red" / "red_colored"). null = padrão "red".
        public string? RedStrategy { get; set; }
        /// Estratégia/time ativo do modo Ho-Oh ("hooh" / "hooh_trickroom"). null = padrão "hooh".
        public string? HoohStrategy { get; set; }
        /// Tamanho de fonte (0=Compacto, 1=Normal, 2=Grande). null = padrão 1 (Normal).
        public int? UiScale { get; set; }
        /// Se o usuário já escolheu o idioma na 1ª abertura (mostra o seletor só uma vez).
        public bool LanguageChosen { get; set; }
        /// #73: se o guia "Como ler o overlay" já abriu sozinho na 1ª vez (depois só pelo "?").
        public bool SeenOverlayGuide { get; set; }
    }

    private static Data _data = LoadData();

    private static Data LoadData()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<Data>(File.ReadAllText(FilePath)) ?? new Data();
        }
        catch { /* best-effort */ }
        return new Data();
    }

    public static string? Team
    {
        get => _data.Team;
        set { _data.Team = value; Save(); }
    }

    public static bool Emoji
    {
        get => _data.Emoji;
        set { _data.Emoji = value; Save(); }
    }

    /// Idioma da interface ("pt" / "en"). Na 1ª abertura segue o idioma do Windows
    /// (PT se o sistema estiver em português; caso contrário, EN). Depois respeita a escolha.
    public static string Language
    {
        get => _data.Language ?? DeviceDefaultLanguage();
        set { _data.Language = value; Save(); }
    }

    /// Idioma do Windows reduzido a "pt"/"en" (default usado só na 1ª abertura).
    private static string DeviceDefaultLanguage()
        => System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName
            .ToLowerInvariant() == "pt" ? "pt" : "en";

    /// Opacidade do overlay (0.35..1.0). Padrão: 0.95.
    public static double Opacity
    {
        get => Math.Clamp(_data.Opacity ?? 0.95, 0.35, 1.0);
        set { _data.Opacity = Math.Clamp(value, 0.35, 1.0); Save(); }
    }

    /// Rota ativa do Farm de Ginásios ("veteran" / "lucky_girl"). Padrão "veteran".
    public static string FarmRoute
    {
        get => _data.FarmRoute ?? "veteran";
        set { _data.FarmRoute = value; Save(); }
    }

    /// Estratégia/time ativo do modo Cynthia & Morimoto. Padrão "cynthia_morimoto" (a 1ª).
    public static string CynthiaMorimotoStrategy
    {
        get => _data.CynthiaMorimotoStrategy ?? "cynthia_morimoto";
        set { _data.CynthiaMorimotoStrategy = value; Save(); }
    }

    /// Estratégia/time ativo do modo Red ("red" / "red_colored"). Padrão "red" (a 1ª).
    public static string RedStrategy
    {
        get => _data.RedStrategy ?? "red";
        set { _data.RedStrategy = value; Save(); }
    }

    /// Estratégia/time ativo do modo Ho-Oh ("hooh" / "hooh_trickroom"). Padrão "hooh" (a 1ª).
    public static string HoohStrategy
    {
        get => _data.HoohStrategy ?? "hooh";
        set { _data.HoohStrategy = value; Save(); }
    }

    /// Tamanho de fonte do overlay (0=Compacto, 1=Normal, 2=Grande). Padrão 1 (Normal).
    public static int UiScale
    {
        get => Math.Clamp(_data.UiScale ?? 1, 0, 2);
        set { _data.UiScale = Math.Clamp(value, 0, 2); Save(); }
    }

    /// Se o usuário já escolheu o idioma na 1ª abertura (o seletor PT/EN só aparece uma vez).
    /// Porte da flag langChosen do Android (TeamPrefs.langChosen/setLangChosen).
    public static bool LanguageChosen
    {
        get => _data.LanguageChosen;
        set { _data.LanguageChosen = value; Save(); }
    }

    /// #73: se o guia "Como ler o overlay" já abriu sozinho uma vez (depois só reabre pelo "?").
    /// Espelha a flag seenOverlayGuide do TeamPrefs.swift do Mac.
    public static bool SeenOverlayGuide
    {
        get => _data.SeenOverlayGuide;
        set { _data.SeenOverlayGuide = value; Save(); }
    }

    private static void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(_data, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* preferência é best-effort */ }
    }
}
