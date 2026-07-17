using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using PrestreloAjuda.Services;

namespace PrestreloAjuda;

/// Seletor de idioma da 1ª abertura (porte do LanguagePicker do Android, MainActivity.kt).
/// Bilíngue de propósito: o usuário ainda não escolheu. Aparece só uma vez — a flag
/// TeamPrefs.LanguageChosen impede reexibição. O idioma do Windows vem em destaque (1º botão).
public partial class LanguagePicker : Window
{
    /// Idioma escolhido pelo usuário; null enquanto ele não toca num dos botões.
    public Lang? Picked { get; private set; }

    public LanguagePicker(Lang suggested)
    {
        InitializeComponent();
        RootBorder.Background = Theme.Bg;
        RootBorder.BorderBrush = Theme.Border;

        Host.Children.Add(new TextBlock
        {
            Text = "FarmOracleMMO", Foreground = Theme.Text, FontSize = 22,
            FontWeight = FontWeights.Black, HorizontalAlignment = HorizontalAlignment.Center
        });
        Host.Children.Add(new TextBlock
        {
            Text = "Escolha o idioma  ·  Choose your language",
            Foreground = Theme.TextDim, FontSize = 13, TextAlignment = TextAlignment.Center,
            Margin = new Thickness(0, 10, 0, 22), HorizontalAlignment = HorizontalAlignment.Center
        });

        // Idioma do aparelho em destaque (1º botão, primary); o outro fica como alternativa.
        var other = suggested == Lang.En ? Lang.Pt : Lang.En;
        Host.Children.Add(LangButton(suggested, primary: true));
        Host.Children.Add(LangButton(other, primary: false));
    }

    private Border LangButton(Lang lang, bool primary)
    {
        var label = lang == Lang.Pt ? "\U0001F1E7\U0001F1F7  Português" : "\U0001F1FA\U0001F1F8  English";
        var text = new TextBlock
        {
            Text = label, FontSize = 15, FontWeight = FontWeights.SemiBold,
            Foreground = primary ? Brushes.Black : Theme.Text,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var btn = new Border
        {
            Child = text, Height = 48, CornerRadius = new CornerRadius(10),
            Background = primary ? Theme.Accent : Theme.Panel,
            Margin = new Thickness(0, 0, 0, 12), Cursor = Cursors.Hand
        };
        btn.MouseLeftButtonUp += (_, _) => Pick(lang);
        return btn;
    }

    private void Pick(Lang lang)
    {
        Picked = lang;
        Close();
    }
}
