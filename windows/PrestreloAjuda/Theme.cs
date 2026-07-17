using System.Windows.Media;

namespace PrestreloAjuda;

/// Paleta do app (espelha o tema escuro do app Mac).
public static class Theme
{
    public static readonly Color BgColor      = FromHex("#1A1A1F");
    public static readonly Color PanelColor   = FromHex("#26262E");
    public static readonly Color PanelHiColor = FromHex("#33333B"); // painel um tom mais claro (Mac panelHi)
    public static readonly Color TextColor    = FromHex("#F0F0F2");
    public static readonly Color TextDimColor = FromHex("#9A9AA5");
    public static readonly Color AccentColor  = FromHex("#FF9E33"); // laranja
    public static readonly Color GoodColor    = FromHex("#57C36B"); // verde
    public static readonly Color ChoiceColor  = FromHex("#58A6FF"); // azul
    public static readonly Color WarningColor = FromHex("#FFC747"); // âmbar (avisos)
    public static readonly Color DangerColor  = FromHex("#FF6B6B"); // vermelho (não funcionou)
    public static readonly Color BorderColor  = FromHex("#3A3A44");

    public static readonly Brush Bg      = Freeze(BgColor);
    public static readonly Brush Panel   = Freeze(PanelColor);
    public static readonly Brush PanelHi = Freeze(PanelHiColor);
    public static readonly Brush Text    = Freeze(TextColor);
    public static readonly Brush TextDim = Freeze(TextDimColor);
    public static readonly Brush Accent  = Freeze(AccentColor);
    public static readonly Brush Good    = Freeze(GoodColor);
    public static readonly Brush Choice  = Freeze(ChoiceColor);
    public static readonly Brush Border  = Freeze(BorderColor);
    public static readonly Brush Warning = Freeze(WarningColor);
    public static readonly Brush Danger  = Freeze(DangerColor);
    public static readonly Brush AccentSoft = Freeze(WithAlpha(AccentColor, 0x33));
    public static readonly Brush ChoiceSoft  = Freeze(WithAlpha(ChoiceColor, 0x22));
    public static readonly Brush GoodSoft   = Freeze(WithAlpha(GoodColor, 0x22));
    public static readonly Brush PanelSoft  = Freeze(WithAlpha(PanelColor, 0xCC));
    public static readonly Brush WarningSoft = Freeze(WithAlpha(WarningColor, 0x22));
    public static readonly Brush DangerSoft  = Freeze(WithAlpha(DangerColor, 0x22));

    public static Color WithAlpha(Color c, byte a) => Color.FromArgb(a, c.R, c.G, c.B);

    private static Color FromHex(string hex)
    {
        hex = hex.TrimStart('#');
        byte r = Convert.ToByte(hex.Substring(0, 2), 16);
        byte g = Convert.ToByte(hex.Substring(2, 2), 16);
        byte b = Convert.ToByte(hex.Substring(4, 2), 16);
        return Color.FromRgb(r, g, b);
    }

    private static Brush Freeze(Color c)
    {
        var b = new SolidColorBrush(c);
        b.Freeze();
        return b;
    }
}
