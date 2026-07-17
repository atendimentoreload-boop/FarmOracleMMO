using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using PrestreloAjuda.Interop;

namespace PrestreloAjuda;

/// Master Ball flutuante (estado minimizado).
/// Arrastar = reposiciona (não abre). Duplo-clique = restaura o overlay.
public partial class MiniBallWindow : Window
{
    private readonly Action _onRestore;

    public MiniBallWindow(Action onRestore)
    {
        InitializeComponent();
        _onRestore = onRestore;
        try
        {
            Ball.Source = new BitmapImage(
                new Uri("pack://application:,,,/Assets/masterball.png"));
        }
        catch { /* sem imagem: a janelinha fica transparente, mas funcional */ }

        SourceInitialized += (_, _) => Native.MakeOverlay(this);
    }

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            _onRestore();
            return;
        }
        try { DragMove(); } catch { /* ignora se o botão já soltou */ }

        // Não deixar o usuário largar a bolinha fora da tela — ela é o botão de restaurar (#40).
        var wa = SystemParameters.WorkArea;
        double w = ActualWidth > 0 ? ActualWidth : Width;
        double h = ActualHeight > 0 ? ActualHeight : Height;
        Left = Math.Min(Math.Max(Left, wa.Left), Math.Max(wa.Left, wa.Right - w));
        Top = Math.Min(Math.Max(Top, wa.Top), Math.Max(wa.Top, wa.Bottom - h));
    }
}
