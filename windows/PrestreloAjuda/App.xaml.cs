using System.Windows;
using PrestreloAjuda.Services;

namespace PrestreloAjuda;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 1ª abertura: escolher o idioma antes de tudo (porte do LanguagePicker do Android).
        // Mostra só uma vez — depois respeita a flag e a escolha salva em TeamPrefs.
        if (!TeamPrefs.LanguageChosen)
        {
            // OnExplicitShutdown enquanto o seletor é a única janela: evita o app fechar
            // quando ele é fechado, antes de abrirmos a MainWindow logo abaixo.
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            var suggested = Strings.ParseLang(TeamPrefs.Language); // idioma do Windows (pt/en)
            var picker = new LanguagePicker(suggested);
            picker.ShowDialog();
            if (picker.Picked is Lang chosen)
            {
                TeamPrefs.Language = Strings.Code(chosen);
                TeamPrefs.LanguageChosen = true;
                Strings.Current = chosen;
            }
            ShutdownMode = ShutdownMode.OnLastWindowClose;
        }

        AppModel model;
        try
        {
            model = AppModel.LoadDefault();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                string.Format(Strings.Text(L.LoadError, Strings.ParseLang(TeamPrefs.Language)), ex.Message),
                "FarmOracleMMO", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown();
            return;
        }

        var window = new MainWindow(model);
        window.Show();
    }
}
