using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Atalho de teclado configurável do botão "Próximo".
/// `Vk` é a virtual-key do Win32; `Mods` combina MOD_CONTROL/ALT/SHIFT/WIN (ver Interop.Native).
public sealed class ShortcutCombo
{
    public uint Vk { get; set; }
    public uint Mods { get; set; }
    public string Display { get; set; } = "";
}

/// Persiste as preferências do app em %LOCALAPPDATA%\PrestreloAjuda\settings.json
/// (equivalente ao UserDefaults usado pelo ShortcutManager do Mac).
public static class ShortcutStore
{
    private static string Dir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PrestreloAjuda");

    private static string FilePath => Path.Combine(Dir, "settings.json");

    private sealed class Settings
    {
        public ShortcutCombo? Next { get; set; }
        public ShortcutCombo? Skip { get; set; }   // atalho "Pular parada" (#71)
    }

    private static Settings ReadAll()
    {
        try
        {
            if (!File.Exists(FilePath)) return new Settings();
            return JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
        }
        catch { return new Settings(); }
    }

    private static void Write(Settings s)
    {
        try
        {
            Directory.CreateDirectory(Dir);
            var json = JsonSerializer.Serialize(s, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(FilePath, json);
        }
        catch { /* preferência é best-effort */ }
    }

    public static ShortcutCombo? Load() => ReadAll().Next;
    public static ShortcutCombo? LoadSkip() => ReadAll().Skip;

    // Preservam o OUTRO combo ao salvar (não sobrescrevem o arquivo inteiro).
    public static void Save(ShortcutCombo? combo) { var s = ReadAll(); s.Next = combo; Write(s); }
    public static void SaveSkip(ShortcutCombo? combo) { var s = ReadAll(); s.Skip = combo; Write(s); }
}
