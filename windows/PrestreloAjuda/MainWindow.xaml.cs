using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PrestreloAjuda.Engine;
using PrestreloAjuda.Interop;
using PrestreloAjuda.Models;
using PrestreloAjuda.Services;

namespace PrestreloAjuda;

public partial class MainWindow : Window
{
    private readonly AppModel _model;
    private SolveEngine? _hookedEngine;

    private double _opacityLevel = TeamPrefs.Opacity;   // persiste entre aberturas (teamprefs.json)
    private int _uiScale = TeamPrefs.UiScale;           // tamanho de fonte (0=Compacto,1=Normal,2=Grande)
    private MiniBallWindow? _mini;
    private const double MiniSide = 60;         // lado da Master Ball minimizada
    private DateTime _restoredAt = DateTime.MinValue; // debounce: evita recolher logo após restaurar

    // Navegação de UI
    private EntryGroup? _selectedGroup;   // drilldown da home (região → cidade)
    private string? _openCategory;        // submenu do menu de modos (Elite 4)
    private bool _showSettings;           // tela de Configurações (Menu) aberta?
    private string? _settingsPanel;       // sub-tela das Configurações ("shortcut" / "language" / null)
    // Grupos de time abertos nas Configurações. Vazio = todos recolhidos (a lista de times de
    // cada modo só aparece ao clicar no cabeçalho do modo — igual ao Mac; evita poluir com muitos times).
    private readonly HashSet<string> _expandedTeamGroups = new();
    private string _search = "";          // filtro de busca das listas da home
    private bool _showSkipped;            // #42: pulados somem da lista; este toggle reexibe

    // Cores por Pokémon do modo atual (golpes/nomes pintados conforme a paleta).
    private Colorizer _colorizer = new(null);

    // Atalho configurável do botão "Próximo".
    private ShortcutCombo? _nextCombo;
    // Atalho configurável de "Pular parada" (#71).
    private ShortcutCombo? _skipCombo;
    private bool _capturing;
    private bool _capturingSkip;   // qual combo a captura atual vai gravar

    private const int NextHotkeyId = 0xA12;   // atalho configurável do "Próximo"
    private const int SkipHotkeyId = 0xA13;   // atalho configurável de "Pular parada" (#71)

    // Atalhos FIXOS F1..F12 para as opções da pergunta "Qual a situação?".
    // Só ficam registrados ENQUANTO a escolha está na tela (ver SyncChoiceHotkeys), então
    // fora disso as teclas F voltam a funcionar normalmente no PokeMMO.
    private const int ChoiceHotkeyBase = 0xA20; // ids 0xA20..0xA2B
    private const int MaxChoiceKeys = 12;
    private static readonly uint[] FKeyVks =     // VK_F1 .. VK_F12
        { 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B };
    private readonly List<Option> _choiceOptions = new();
    private int _choiceHotkeyCount;

    private static readonly Dictionary<string, BitmapImage?> ImgCache = new();

    /// Versão do app (vem do <Version> do .csproj, sincronizado pela fonte única /VERSION).
    private static readonly string AppVersion = FormatVersion();

    private static string FormatVersion()
    {
        var v = typeof(MainWindow).Assembly.GetName().Version;
        return v == null ? "1.1.0" : $"{v.Major}.{v.Minor}.{v.Build}";
    }

    public MainWindow(AppModel model)
    {
        InitializeComponent();
        _model = model;
        _model.Changed += OnModelChanged;

        // Sistema de Cooldown/Alarme (#33): carrega catálogo + estado e reconcilia os alarmes ainda
        // no futuro (o ctor já reagenda). Aberto pelo "reloginho" ao lado do chip de idioma.
        _cooldowns = new CooldownStore();
        // Rede de segurança do #40: se a bolinha minimizada se perder, o duplo-clique no ícone
        // da bandeja traz a janela de volta (a janela some da barra de tarefas por ser tool-window).
        _cooldowns.Notifications.RestoreRequested += () => Dispatcher.Invoke(Restore);

        RootBorder.Background = Theme.Bg;
        RootBorder.BorderBrush = Theme.Border;

        Loaded += async (_, _) =>
        {
            PositionTopRight();
            await CheckForcedUpdateAsync();
            // #73: na 1ª abertura (o idioma já foi escolhido no App.xaml.cs) o guia "Como ler o
            // overlay" abre sozinho uma vez; depois só reabre pelo "?". Espelha o onAppear do
            // ContentView do Mac. Não abre por cima do bloqueio de atualização obrigatória.
            if (BlockHost.Visibility != Visibility.Visible && !TeamPrefs.SeenOverlayGuide)
            {
                TeamPrefs.SeenOverlayGuide = true;
                OpenHelp();
            }
        };
        SourceInitialized += OnSourceInitialized;

        Opacity = _opacityLevel;
        Render();
    }

    // MARK: - Ciclo de vida / overlay

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        Native.MakeOverlay(this);
        var src = (HwndSource)PresentationSource.FromVisual(this)!;
        src.AddHook(WndProc);

        _nextCombo = ShortcutStore.Load();
        _skipCombo = ShortcutStore.LoadSkip();
        RegisterNextHotkey();
        RegisterSkipHotkey();
        ApplyUiScale(); // reflete o tamanho de fonte salvo
        BuildHeader(); // reflete o atalho carregado no botão
    }

    private IntPtr Handle => new WindowInteropHelper(this).Handle;

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr w, IntPtr l, ref bool handled)
    {
        if (msg == Native.WM_HOTKEY)
        {
            int id = w.ToInt32();
            if (id == NextHotkeyId) { AdvanceViaShortcut(); handled = true; }
            else if (id == SkipHotkeyId) { SkipViaShortcut(); handled = true; }
            else if (id >= ChoiceHotkeyBase && id < ChoiceHotkeyBase + MaxChoiceKeys)
            {
                int idx = id - ChoiceHotkeyBase;
                if (!_model.InMenu && idx < _choiceOptions.Count)
                    _model.Engine?.Choose(_choiceOptions[idx]);
                handled = true;
            }
        }
        return IntPtr.Zero;
    }

    /// (Re)registra F1..Fn como atalhos globais para as opções da escolha atual.
    /// Só é chamado pelo RenderNode quando há uma pergunta "Qual a situação?" na tela.
    private void SyncChoiceHotkeys(IReadOnlyList<Option> options)
    {
        ClearChoiceHotkeys();
        if (Handle == IntPtr.Zero) return; // ainda sem janela (Render no construtor)
        int n = Math.Min(options.Count, MaxChoiceKeys);
        for (int i = 0; i < n; i++)
        {
            _choiceOptions.Add(options[i]);
            Native.RegisterHotKey(Handle, ChoiceHotkeyBase + i, Native.MOD_NOREPEAT, FKeyVks[i]);
        }
        _choiceHotkeyCount = n;
    }

    /// Libera as F-keys para o jogo de novo (chamado a cada Render e ao fechar).
    private void ClearChoiceHotkeys()
    {
        for (int i = 0; i < _choiceHotkeyCount; i++)
            try { Native.UnregisterHotKey(Handle, ChoiceHotkeyBase + i); } catch { }
        _choiceHotkeyCount = 0;
        _choiceOptions.Clear();
    }

    /// Ação do atalho "Próximo" (porte do advanceViaShortcut do Mac): avança o passo; se já está
    /// no nó terminal de uma luta sequencial (Elite 4), encadeia o PRÓXIMO treinador.
    private void AdvanceViaShortcut()
    {
        if (_model.InMenu || _showSettings) return;
        var engine = _model.Engine;
        if (engine == null) return;
        if (engine.Solve.SequentialGroups == true && engine.IsTerminal && engine.NextGroup is { } nxt)
        {
            _selectedGroup = nxt;
            _search = "";
            engine.AdvanceToNextGroup();
        }
        else
        {
            engine.Next();
        }
    }

    /// Ação do atalho "Pular parada" (#71): pula a parada atual da rota de farm, se houver.
    private void SkipViaShortcut()
    {
        if (_model.InMenu || _showSettings) return;
        var engine = _model.Engine;
        if (engine == null) return;
        if (engine.CanSkip) engine.Skip();
    }

    /// (Re)registra o atalho global do "Próximo" conforme o combo salvo.
    private void RegisterNextHotkey()
    {
        try { Native.UnregisterHotKey(Handle, NextHotkeyId); } catch { }
        if (_nextCombo == null) return;
        Native.RegisterHotKey(Handle, NextHotkeyId, _nextCombo.Mods | Native.MOD_NOREPEAT, _nextCombo.Vk);
    }

    /// (Re)registra o atalho global de "Pular parada" conforme o combo salvo (#71).
    private void RegisterSkipHotkey()
    {
        try { Native.UnregisterHotKey(Handle, SkipHotkeyId); } catch { }
        if (_skipCombo == null) return;
        Native.RegisterHotKey(Handle, SkipHotkeyId, _skipCombo.Mods | Native.MOD_NOREPEAT, _skipCombo.Vk);
    }

    // MARK: - Atualização obrigatória

    /// Ao abrir, checa a versão mínima online. Se a versão local for menor, trava o app.
    /// Fail-open: se não conseguir checar (offline/erro), não bloqueia.
    private async Task CheckForcedUpdateAsync()
    {
#if DEBUG
        // Builds de desenvolvimento (debug) NUNCA bloqueiam — você roda local à vontade.
        await Task.CompletedTask;
#else
        var info = await UpdateChecker.FetchAsync();
        if (info == null || string.IsNullOrEmpty(info.Minimum)) return;
        if (UpdateChecker.Compare(AppVersion, info.Minimum) < 0)
            ShowUpdateBlock(info);
#endif
    }

    private void ShowUpdateBlock(UpdateInfo info)
    {
        var stack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(24) };
        stack.Children.Add(new TextBlock { Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 32, Foreground = Theme.Accent, HorizontalAlignment = HorizontalAlignment.Center });
        stack.Children.Add(new TextBlock { Text = Strings.T(L.UpdateRequiredTitle), FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Theme.Text, Margin = new Thickness(0, 10, 0, 0), HorizontalAlignment = HorizontalAlignment.Center });
        stack.Children.Add(new TextBlock
        {
            Text = string.Format(Strings.T(L.UpdateRequiredBody), AppVersion, info.Minimum),
            FontSize = 12, Foreground = Theme.TextDim, TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 6, 0, 0), HorizontalAlignment = HorizontalAlignment.Center
        });

        var dlTb = new TextBlock { Text = Strings.T(L.DownloadUpdate), Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center };
        var dl = new Border { Child = dlTb, Background = Theme.Accent, CornerRadius = new CornerRadius(10), Padding = new Thickness(16, 9, 16, 9), Margin = new Thickness(0, 14, 0, 0), HorizontalAlignment = HorizontalAlignment.Center };
        MakeClickable(dl, () => OpenUrl(info.Url));
        stack.Children.Add(dl);

        var close = new TextBlock { Text = Strings.T(L.Close), FontSize = 11, Foreground = Theme.TextDim, Cursor = Cursors.Hand, Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Center };
        close.MouseLeftButtonUp += (_, e) => { e.Handled = true; Close(); };
        stack.Children.Add(close);

        BlockHost.Content = new Border { Background = new SolidColorBrush(Color.FromArgb(0xF5, 0x16, 0x16, 0x1A)), Child = stack };
        BlockHost.Visibility = Visibility.Visible;
    }

    protected override void OnClosed(EventArgs e)
    {
        try { Native.UnregisterHotKey(Handle, NextHotkeyId); } catch { }
        try { Native.UnregisterHotKey(Handle, SkipHotkeyId); } catch { }
        ClearChoiceHotkeys();
        _cdTicker?.Stop();
        _cooldowns?.Notifications.Dispose();   // remove o ícone da bandeja + para o relógio interno
        _mini?.Close();
        base.OnClosed(e);
        Application.Current.Shutdown();
    }

    private void PositionTopRight()
    {
        var wa = SystemParameters.WorkArea;
        Left = wa.Right - Width - 16;
        Top = wa.Top + 12;
    }

    private void OnModelChanged()
    {
        HookEngine();
        if (_model.InMenu) _selectedGroup = null;
        else { _showSettings = false; _settingsPanel = null; } // entrou num modo: fecha Configurações
        _search = "";
        Render();
    }

    private void HookEngine()
    {
        var e = _model.Engine;
        if (ReferenceEquals(e, _hookedEngine)) return;
        if (_hookedEngine != null) _hookedEngine.Changed -= Render;
        _hookedEngine = e;
        if (_hookedEngine != null) _hookedEngine.Changed += Render;
    }

    private void BumpOpacity(double d) => SetOpacity(_opacityLevel + d);

    /// Define a opacidade (clampada) e persiste no teamprefs.json para sobreviver entre aberturas.
    private void SetOpacity(double value)
    {
        _opacityLevel = Math.Clamp(value, 0.35, 1.0);
        Opacity = _opacityLevel;
        TeamPrefs.Opacity = _opacityLevel;
    }

    // MARK: - Tamanho de fonte (cicla Compacto → Normal → Grande, igual ao Mac/Android)

    private static double UiScaleFactor(int level) => level switch { 0 => 0.85, 2 => 1.2, _ => 1.0 };
    private string UiScaleGlyph() => _uiScale switch { 0 => "A−", 2 => "A+", _ => "A" };

    /// Escala o conteúdo principal (ContentHost) pelo fator do nível; o chrome (topo/rodapé) fica fixo.
    private void ApplyUiScale()
    {
        double f = UiScaleFactor(_uiScale);
        ContentHost.LayoutTransform = f == 1.0 ? Transform.Identity : new ScaleTransform(f, f);
    }

    /// Avança 1 nível de fonte (0→1→2→0), persiste e reaplica.
    private void CycleUiScale()
    {
        _uiScale = (_uiScale + 1) % 3;
        TeamPrefs.UiScale = _uiScale;
        ApplyUiScale();
        BuildHeader(); // atualiza o glifo A−/A/A+
    }

    private void Minimize()
    {
        // Debounce: ignora um "recolher" que chega logo após restaurar (o duplo-clique de abrir
        // deixa o cursor sobre o botão de minimizar e fecharia de novo na hora). ~400ms.
        if ((DateTime.UtcNow - _restoredAt).TotalMilliseconds < 400) return;
        _mini ??= new MiniBallWindow(Restore);
        _mini.Left = Left + Width - MiniSide;
        _mini.Top = Top;
        ClampBall(_mini); // nunca deixar a bolinha nascer fora da tela (#40: senão perde o resgate)
        _mini.Show();
        Hide();
    }

    /// Mantém a bolinha (Master Ball) dentro da área de trabalho — ela é o botão de restaurar,
    /// então precisa estar sempre visível/clicável (rede de segurança do #40).
    private void ClampBall(Window ball)
    {
        var wa = SystemParameters.WorkArea;
        ball.Left = Math.Min(Math.Max(ball.Left, wa.Left), Math.Max(wa.Left, wa.Right - MiniSide));
        ball.Top = Math.Min(Math.Max(ball.Top, wa.Top), Math.Max(wa.Top, wa.Bottom - MiniSide));
    }

    private void Restore()
    {
        // Se o Windows tiver maximizado a janela (snap pro topo) antes de esconder,
        // o WPF estoura ao reabrir: "Cannot show Window when ShowActivated is false
        // and WindowState is set to Maximized". Voltamos pro estado Normal antes do
        // Show() — a janela reabre no canto da bolinha (posição abaixo) em vez de crashar.
        if (WindowState == WindowState.Maximized)
            WindowState = WindowState.Normal;

        // A janela acompanha PARA ONDE a bolinha foi arrastada (antes ela voltava pro lugar antigo).
        // A bolinha foi posta em (Left + Width - MiniSide, Top); invertendo, recupera o canto.
        // Só reposiciona quando estava REALMENTE escondida (restaurar pela bolinha); assim o
        // duplo-clique na bandeja com a janela já aberta só traz pra frente, sem teletransportar (#40).
        if (_mini != null && !IsVisible)
        {
            Left = _mini.Left + MiniSide - Width;
            Top = _mini.Top;
            ClampToScreen();
        }
        _mini?.Hide();
        Show();
        Topmost = true;
        _restoredAt = DateTime.UtcNow;
    }

    /// Mantém a janela dentro da área de trabalho (não some fora da tela ao restaurar).
    private void ClampToScreen()
    {
        var wa = SystemParameters.WorkArea;
        if (Width > 0) Left = Math.Min(Math.Max(Left, wa.Left), Math.Max(wa.Left, wa.Right - Width));
        if (Height > 0) Top = Math.Min(Math.Max(Top, wa.Top), Math.Max(wa.Top, wa.Bottom - Height));
    }

    private void OnHeaderDrag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            try { DragMove(); } catch { /* botão soltou antes */ }
        }
    }

    // MARK: - Captura do atalho "Próximo" (espelha o ShortcutManager + CaptureLayer do Mac)

    private void StartCapture(bool skip = false)
    {
        if (_capturing) return;
        _capturingSkip = skip;
        _capturing = true;
        Native.SetNoActivate(this, false);
        Activate();
        Focus();
        BuildCaptureOverlay();
        PreviewKeyDown += OnCaptureKeyDown;
        Dispatcher.BeginInvoke(new Action(() => Keyboard.Focus(this)),
            System.Windows.Threading.DispatcherPriority.Input);
    }

    private void EndCapture()
    {
        _capturing = false;
        PreviewKeyDown -= OnCaptureKeyDown;
        CaptureHost.Content = null;
        CaptureHost.Visibility = Visibility.Collapsed;
        Native.SetNoActivate(this, true);
        // Atualiza o tooltip/estado do botão; e re-renderiza a tela de atalho das Configurações
        // (se aberta) para refletir o combo novo/limpo.
        if (_showSettings && (_settingsPanel == "shortcut" || _settingsPanel == "skipShortcut")) Render();
        else BuildHeader();
    }

    private void OnCaptureKeyDown(object sender, KeyEventArgs e)
    {
        if (!_capturing) return;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        e.Handled = true;

        if (key == Key.Escape) { EndCapture(); return; }
        if (IsModifierKey(key)) return; // espera uma tecla "de verdade"

        uint vk = (uint)KeyInterop.VirtualKeyFromKey(key);
        if (vk == 0) return;

        uint mods = 0;
        var m = Keyboard.Modifiers;
        if (m.HasFlag(ModifierKeys.Control)) mods |= Native.MOD_CONTROL;
        if (m.HasFlag(ModifierKeys.Alt)) mods |= Native.MOD_ALT;
        if (m.HasFlag(ModifierKeys.Shift)) mods |= Native.MOD_SHIFT;
        if (m.HasFlag(ModifierKeys.Windows)) mods |= Native.MOD_WIN;

        var captured = new ShortcutCombo { Vk = vk, Mods = mods, Display = DisplayString(mods, key) };
        if (_capturingSkip)
        {
            _skipCombo = captured;
            ShortcutStore.SaveSkip(_skipCombo);
            RegisterSkipHotkey();
        }
        else
        {
            _nextCombo = captured;
            ShortcutStore.Save(_nextCombo);
            RegisterNextHotkey();
        }
        EndCapture();
    }

    private void BuildCaptureOverlay()
    {
        var stack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(20) };
        stack.Children.Add(new TextBlock { Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 30, Foreground = Theme.Accent, HorizontalAlignment = HorizontalAlignment.Center });
        stack.Children.Add(new TextBlock { Text = Strings.T(L.CapturePressKey), FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Theme.Text, Margin = new Thickness(0, 8, 0, 0), HorizontalAlignment = HorizontalAlignment.Center });
        stack.Children.Add(new TextBlock { Text = Strings.T(L.CaptureHint), FontSize = 11, Foreground = Theme.TextDim, TextAlignment = TextAlignment.Center, Margin = new Thickness(0, 4, 0, 0), HorizontalAlignment = HorizontalAlignment.Center });
        var cancel = new TextBlock { Text = Strings.T(L.Cancel), FontSize = 12, FontWeight = FontWeights.Medium, Foreground = Theme.Choice, Cursor = Cursors.Hand, Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Center };
        cancel.MouseLeftButtonUp += (_, e) => { e.Handled = true; EndCapture(); };
        stack.Children.Add(cancel);

        CaptureHost.Content = new Border { Background = new SolidColorBrush(Color.FromArgb(0xC7, 0x10, 0x10, 0x14)), Child = stack };
        CaptureHost.Visibility = Visibility.Visible;
    }

    private static bool IsModifierKey(Key k) =>
        k is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
          or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin
          or Key.System or Key.CapsLock or Key.Apps or Key.None;

    private static string DisplayString(uint mods, Key key)
    {
        var parts = new List<string>();
        if ((mods & Native.MOD_CONTROL) != 0) parts.Add("Ctrl");
        if ((mods & Native.MOD_ALT) != 0) parts.Add("Alt");
        if ((mods & Native.MOD_SHIFT) != 0) parts.Add("Shift");
        if ((mods & Native.MOD_WIN) != 0) parts.Add("Win");
        parts.Add(KeyName(key));
        return string.Join("+", parts);
    }

    private static string KeyName(Key key) => key switch
    {
        >= Key.D0 and <= Key.D9 => ((char)('0' + (key - Key.D0))).ToString(),
        >= Key.NumPad0 and <= Key.NumPad9 => "Num" + (key - Key.NumPad0),
        >= Key.A and <= Key.Z => key.ToString(),
        >= Key.F1 and <= Key.F24 => key.ToString(),
        Key.Space => Strings.T(L.KeyNameSpace),
        Key.Enter => "Enter",
        Key.Tab => "Tab",
        Key.Back => "Backspace",
        Key.Left => "←", Key.Right => "→", Key.Up => "↑", Key.Down => "↓",
        Key.OemTilde => "`",
        Key.OemMinus => "-",
        Key.OemPlus => "+",
        Key.OemComma => ",",
        Key.OemPeriod => ".",
        _ => key.ToString()
    };

    // MARK: - Render principal

    private void Render()
    {
        _colorizer = new Colorizer(_model.InMenu ? null : _model.Engine!.Solve.Palette);

        HideTeamsOverlay();   // qualquer navegação fecha o overlay "Ver times"
        BuildHeader();
        BuildBottom();
        ContentHost.Children.Clear();
        ClearChoiceHotkeys(); // RenderNode re-registra F1..Fn se houver escolha na tela

        if (_model.InMenu && _showSettings) RenderSettings();
        else if (_model.InMenu) RenderModePicker();
        else if (_model.Engine!.IsHome) RenderHome();
        else RenderNode();
    }

    private void BuildHeader()
    {
        var dock = new DockPanel { Margin = new Thickness(10, 7, 10, 7), LastChildFill = true };

        if (_showSettings)
        {
            // Em Configurações: o "‹ Menu" volta da sub-tela (atalho/idioma) ou fecha as Configurações.
            var back = Pill("‹ Menu", Brushes.Black, Theme.Accent, () =>
            {
                if (_settingsPanel != null) _settingsPanel = null;
                else _showSettings = false;
                Render();
            });
            back.Margin = new Thickness(0, 0, 8, 0);
            DockPanel.SetDock(back, Dock.Left);
            dock.Children.Add(back);
        }
        else if (!_model.InMenu)
        {
            var back = Pill("‹ Menu", Brushes.Black, Theme.Accent, () =>
            {
                _selectedGroup = null; _openCategory = null; _model.ExitToMenu();
            });
            back.Margin = new Thickness(0, 0, 8, 0);
            DockPanel.SetDock(back, Dock.Left);
            dock.Children.Add(back);
        }
        else
        {
            var dot = new Border
            {
                Width = 7, Height = 7, CornerRadius = new CornerRadius(4), Background = Theme.Accent,
                VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(2, 0, 8, 0)
            };
            DockPanel.SetDock(dot, Dock.Left);
            dock.Children.Add(dot);
        }

        var right = new StackPanel { Orientation = Orientation.Horizontal };
        DockPanel.SetDock(right, Dock.Right);
        // #73: "?" abre o guia "Como ler o overlay" (espelha o botão de ajuda do HeaderBar do Mac).
        right.Children.Add(Glyph("", Strings.T(L.LegendHowToTitle), ToggleHelp,
            active: HelpHost.Visibility == Visibility.Visible, symbol: true));
        right.Children.Add(Glyph("",
            _nextCombo != null ? string.Format(Strings.T(L.NextShortcutSet), _nextCombo.Display) : Strings.T(L.NextShortcutDefine),
            () => StartCapture(), active: _nextCombo != null, symbol: true));
        right.Children.Add(Glyph("−", Strings.T(L.LessOpacityHelp), () => BumpOpacity(-0.1)));
        right.Children.Add(Glyph("+", Strings.T(L.MoreOpacityHelp), () => BumpOpacity(0.1)));
        // Tamanho de fonte: cicla Compacto → Normal → Grande (glifo A−/A/A+), igual ao Mac/Android.
        right.Children.Add(Glyph(UiScaleGlyph(),
            _model.Language == Lang.En ? "Font size (A−/A/A+)" : "Tamanho da fonte (A−/A/A+)",
            CycleUiScale, filled: true));
        right.Children.Add(Glyph("", Strings.T(L.MinimizeHelp), Minimize, symbol: true));
        right.Children.Add(Glyph("", Strings.T(L.CloseHelp), Close, symbol: true));
        dock.Children.Add(right);

        var title = new TextBlock
        {
            Text = HeaderTitle(),
            Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(4, 0, 4, 0)
        };
        dock.Children.Add(title);

        var stack = new StackPanel();
        var header = new Border { Child = dock };
        header.MouseLeftButtonDown += OnHeaderDrag;
        stack.Children.Add(header);
        stack.Children.Add(Line());
        HeaderHost.Content = stack;
    }

    /// Título do cabeçalho: nas Configurações mostra "MENU" (ou o nome da sub-tela), senão o modo atual.
    private string HeaderTitle()
    {
        if (_showSettings)
        {
            if (_settingsPanel == "shortcut") return Strings.T(L.Shortcut).ToUpperInvariant();
            if (_settingsPanel == "skipShortcut") return Strings.T(L.NavSkipShortcut).ToUpperInvariant();
            if (_settingsPanel == "language") return Strings.T(L.Language).ToUpperInvariant();
            return "MENU";
        }
        return _model.CurrentTitle ?? "FarmOracleMMO";
    }

    private void BuildBottom()
    {
        if (_model.InMenu) { BottomHost.Content = null; return; }
        var engine = _model.Engine!;

        var dock = new DockPanel { Margin = new Thickness(10, 7, 10, 7) };
        var progress = new TextBlock
        {
            Text = ProgressText(engine) ?? "", Foreground = Theme.TextDim, FontSize = 10,
            VerticalAlignment = VerticalAlignment.Center
        };
        DockPanel.SetDock(progress, Dock.Right);
        dock.Children.Add(progress);

        var left = new StackPanel { Orientation = Orientation.Horizontal };
        left.Children.Add(SmallButton("‹ " + Strings.T(L.BackButton), engine.CanBack, engine.Back));
        // Reiniciar volta para a seleção de treinadores/grupos (limpa o grupo aberto na view),
        // não para a lista de leads do grupo atual.
        left.Children.Add(SmallButton("⟲ " + Strings.T(L.Restart), !engine.IsHome,
            () => { _selectedGroup = null; _search = ""; engine.Reset(); }));
        dock.Children.Add(left);

        var stack = new StackPanel();
        stack.Children.Add(Line());
        stack.Children.Add(dock);
        BottomHost.Content = stack;
    }

    private static string? ProgressText(SolveEngine e)
    {
        if (e.Solve.RevealAll == true) return null;
        var node = e.CurrentNode;
        if (node == null || node.Steps.Count == 0) return null;
        int cur = Math.Min(e.StepIndex + 1, node.Steps.Count);
        return string.Format(Strings.T(L.StepProgress), cur, node.Steps.Count);
    }

    // MARK: - Menu de modos

    private void RenderModePicker()
    {
        if (_openCategory == null)
        {
            ContentHost.Children.Add(LanguageChipRow(Strings.T(L.ModePickerPrompt)));
            // Divide os modos soltos pelo bloco de categorias (Elite 4): "antes" (Red, Farm) e
            // "depois" (Cynthia & Morimoto, Ho-Oh) — assim os novos aparecem após a Elite 4.
            int firstCatIdx = _model.Modes.FindIndex(m => m.Category != null);
            void AddTopMode(Mode m)
            {
                var mm = m;
                ContentHost.Children.Add(ModeCard(mm.Title, mm.Subtitle,
                    ModeIcon(mm.Portrait, mm.Item, null, mm.Symbol), mm.Pokepaste, () => _model.Select(mm), mm.ComingSoon));
            }
            var topBefore = firstCatIdx < 0
                ? _model.Modes.Where(m => m.Category == null)
                : _model.Modes.Take(firstCatIdx).Where(m => m.Category == null);
            foreach (var m in topBefore) AddTopMode(m);
            foreach (var cat in Categories())
            {
                var c = cat;
                var paste = _model.Modes.First(m => m.Category == c).Pokepaste;
                ContentHost.Children.Add(ModeCard(c, Strings.T(L.CategorySubtitle),
                    ModeIcon(null, CategoryItem(c), null, "crown"), paste, () => { _openCategory = c; Render(); }));
            }
            if (firstCatIdx >= 0)
                foreach (var m in _model.Modes.Skip(firstCatIdx + 1).Where(m => m.Category == null))
                    AddTopMode(m);
            // Card de Configurações (troca de time em lista, opacidade, atalho, idioma, sobre).
            ContentHost.Children.Add(SettingsCard());
            ContentHost.Children.Add(new TextBlock
            {
                Text = $"v{AppVersion}", Foreground = Theme.TextDim, FontSize = 9, Opacity = 0.7,
                HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 10, 0, 2)
            });
            ContentHost.Children.Add(CreditsFooter());
        }
        else
        {
            ContentHost.Children.Add(BackRow("‹ Menu", _openCategory, () => { _openCategory = null; Render(); }));
            foreach (var m in _model.Modes.Where(m => m.Category == _openCategory))
            {
                var mm = m;
                var region = mm.Id.StartsWith("elite4_", StringComparison.Ordinal) ? mm.Id[7..] : null;
                ContentHost.Children.Add(ModeCard(mm.Title, mm.Subtitle,
                    ModeIcon(mm.Portrait, mm.Item, region, mm.Symbol), mm.Pokepaste, () => _model.Select(mm)));
            }
        }
    }

    private IEnumerable<string> Categories()
    {
        var seen = new HashSet<string>();
        foreach (var m in _model.Modes)
            if (m.Category != null && seen.Add(m.Category)) yield return m.Category;
    }

    // MARK: - Card de acesso às Configurações (no menu principal)

    /// Card "Menu" que abre a tela de Configurações (porte do settings card do ModePickerView do Mac).
    private Border SettingsCard()
    {
        var dock = new DockPanel { LastChildFill = true };

        var icon = new TextBlock
        {
            Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 18, // Settings
            Foreground = Theme.Accent, Width = 28,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
        DockPanel.SetDock(icon, Dock.Left);
        icon.Margin = new Thickness(0, 0, 9, 0);
        dock.Children.Add(icon);

        var chev = new TextBlock { Text = "›", Foreground = Theme.TextDim, FontSize = 16, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(chev, Dock.Right);
        dock.Children.Add(chev);

        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock { Text = Strings.T(L.SettingsCardTitle), Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Bold });
        col.Children.Add(new TextBlock { Text = Strings.T(L.SettingsCardSubtitle), Foreground = Theme.TextDim, FontSize = 9, TextTrimming = TextTrimming.CharacterEllipsis });
        dock.Children.Add(col);

        var card = new Border
        {
            Child = dock, Background = Theme.Panel, BorderBrush = Theme.AccentSoft, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12), Padding = new Thickness(11), Margin = new Thickness(0, 4, 0, 6)
        };
        MakeClickable(card, () => { _showSettings = true; _settingsPanel = null; Render(); });
        return card;
    }

    // MARK: - Tela de Configurações (porte do SettingsView.swift do Mac)

    private void RenderSettings()
    {
        if (_settingsPanel == "shortcut") { RenderShortcutPanel(); return; }
        if (_settingsPanel == "skipShortcut") { RenderShortcutPanel(skip: true); return; }
        if (_settingsPanel == "language") { RenderLanguagePanel(); return; }

        // ----- Lista principal -----
        ContentHost.Children.Add(SectionLabel(Strings.T(L.Teams)));

        // Grupo "Red": estratégia/time marcável (radio) — troca via SetRedStrategy, igual ao Cynthia & Morimoto.
        var redGroup = new StackPanel();
        var redStrats = AppModel.RedStrategies;
        for (int i = 0; i < redStrats.Count; i++)
        {
            if (i > 0) redGroup.Children.Add(RowDivider());
            var r = redStrats[i];
            redGroup.Children.Add(TeamLineRow(
                icon: SpriteIcon(r.Pokemon, 28),
                name: r.Name, sub: r.Roster,
                pokepaste: r.Pokepaste, selected: r.Id == _model.ActiveRedStrategyId,
                onSelect: () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetRedStrategy(r.Id); },
                source: r.Doc is { } rdoc ? new TeamSource.Doc(rdoc) : new TeamSource.NotFound()));
        }
        CollapsibleTeamGroup("Red", TrainerIcon("red", 24),
            redStrats.FirstOrDefault(r => r.Id == _model.ActiveRedStrategyId)?.Name, redGroup);

        // Grupo "Farm de Ginásios": rotas AGRUPADAS por time (TeamGroup), preservando a ordem de 1ª
        // aparição, igual ao Mac. Grupo com 1 rota = linha normal (radio); grupo com N rotas =
        // cabeçalho do time (roster + Poképaste/doc, uma vez) + sub-linhas compactas por variante.
        var farmGroup = new StackPanel();
        var farmGroupsOrdered = AppModel.FarmTeamGroupsOrdered;
        for (int gi = 0; gi < farmGroupsOrdered.Count; gi++)
        {
            if (gi > 0) farmGroup.Children.Add(RowDivider());
            var group = farmGroupsOrdered[gi];
            var routes = AppModel.FarmRoutesIn(group);
            if (routes.Count == 1)
            {
                var route = routes[0];
                farmGroup.Children.Add(TeamLineRow(
                    icon: SpriteIcon(route.Pokemon, 28),
                    name: route.Name, sub: route.Roster,
                    pokepaste: route.Pokepaste, selected: route.Id == _model.ActiveFarmRouteId,
                    onSelect: () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetFarmRoute(route.Id); },
                    source: route.Doc is { } fdoc ? new TeamSource.Doc(fdoc) : new TeamSource.NotFound()));
            }
            else
            {
                // MESMO time, várias rotas → cabeçalho do time + uma sub-linha por variante.
                farmGroup.Children.Add(FarmTeamHeader(group, routes));
                foreach (var route in routes)
                    farmGroup.Children.Add(FarmVariantRow(route));
            }
        }
        // Resumo recolhido: "Nome do time · Variante" da rota ativa (igual ao Mac).
        var activeFarm = _model.ActiveFarmRoute;
        CollapsibleTeamGroup(Strings.T(L.GymFarm), ItemIcon("gym", 20),
            $"{AppModel.FarmTeamName(activeFarm.TeamGroup)} · {activeFarm.Variant}", farmGroup);

        // Grupo "Cynthia & Morimoto": estratégia/time marcável (radio) — troca via SetCmStrategy.
        var cmGroup = new StackPanel();
        var cmStrats = AppModel.CynthiaMorimotoStrategies;
        for (int i = 0; i < cmStrats.Count; i++)
        {
            if (i > 0) cmGroup.Children.Add(RowDivider());
            var s = cmStrats[i];
            cmGroup.Children.Add(TeamLineRow(
                icon: TrainerIcon("cynthia", 28),
                name: s.Name, sub: s.Roster,
                pokepaste: s.Pokepaste, selected: s.Id == _model.ActiveCmStrategyId,
                onSelect: () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetCmStrategy(s.Id); },
                source: s.Doc is { } cmdoc ? new TeamSource.Doc(cmdoc) : new TeamSource.NotFound()));
        }
        CollapsibleTeamGroup("Cynthia & Morimoto", TrainerIcon("cynthia", 24),
            cmStrats.FirstOrDefault(s => s.Id == _model.ActiveCmStrategyId)?.Name, cmGroup);

        // Grupo "Ho-Oh": estratégia/time marcável (radio) — troca via SetHoohStrategy, igual ao Red.
        var hoohGroup = new StackPanel();
        var hoohStrats = AppModel.HoohStrategies;
        for (int i = 0; i < hoohStrats.Count; i++)
        {
            if (i > 0) hoohGroup.Children.Add(RowDivider());
            var h = hoohStrats[i];
            hoohGroup.Children.Add(TeamLineRow(
                icon: SpriteIcon(h.Pokemon, 28),
                name: h.Name, sub: h.Roster,
                pokepaste: h.Pokepaste, selected: h.Id == _model.ActiveHoohStrategyId,
                onSelect: () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetHoohStrategy(h.Id); },
                source: h.Video is { } hvid ? new TeamSource.Video(hvid) : new TeamSource.NotFound()));
        }
        CollapsibleTeamGroup("Ho-Oh", SpriteIcon("hooh", 22),
            hoohStrats.FirstOrDefault(h => h.Id == _model.ActiveHoohStrategyId)?.Name, hoohGroup);

        // Grupo "Elite 4": lista de times marcável (radio) + Poképaste por linha + Modo Emoji.
        var teamGroup = new StackPanel();
        var teams = _model.AvailableTeams;
        for (int i = 0; i < teams.Count; i++)
        {
            if (i > 0) teamGroup.Children.Add(RowDivider());
            var t = teams[i];
            teamGroup.Children.Add(TeamLineRow(
                icon: t.Icon != null ? SpriteIcon(t.Icon, 28) : null,
                name: t.Name, sub: string.Join(", ", t.Pokemon),
                pokepaste: t.Pokepaste, selected: t.Id == _model.ActiveTeamId,
                onSelect: () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetTeam(t.Id); },
                source: t.Code is { } code ? new TeamSource.Pokeking(code, t.Name) : null));
        }
        if (_model.EmojiAvailable)
        {
            teamGroup.Children.Add(RowDivider());
            teamGroup.Children.Add(EmojiToggleRow());
        }
        CollapsibleTeamGroup("Elite 4", ItemIcon("trophy", 20),
            teams.FirstOrDefault(t => t.Id == _model.ActiveTeamId)?.Name, teamGroup);

        // ----- Opções -----
        var optLabel = SectionLabel(Strings.T(L.Options));
        optLabel.Margin = new Thickness(2, 8, 2, 6);
        ContentHost.Children.Add(optLabel);

        GroupLabel(Strings.T(L.Overlay));
        var overlayGroup = new StackPanel();
        overlayGroup.Children.Add(OpacityRow());
        ContentHost.Children.Add(SettingsGroup(overlayGroup));

        GroupLabel(Strings.T(L.General));
        var generalGroup = new StackPanel();
        generalGroup.Children.Add(NavRow("", Strings.T(L.NavNextShortcut),
            _nextCombo?.Display ?? Strings.T(L.None), () => { _settingsPanel = "shortcut"; Render(); }));
        generalGroup.Children.Add(RowDivider());
        generalGroup.Children.Add(NavRow("", Strings.T(L.NavSkipShortcut),
            _skipCombo?.Display ?? Strings.T(L.None), () => { _settingsPanel = "skipShortcut"; Render(); }));
        generalGroup.Children.Add(RowDivider());
        generalGroup.Children.Add(NavRow("", Strings.T(L.Language),
            _model.Language == Lang.En ? "English" : Strings.T(L.Portuguese), () => { _settingsPanel = "language"; Render(); }));
        ContentHost.Children.Add(SettingsGroup(generalGroup));

        GroupLabel(Strings.T(L.About));
        var aboutGroup = new StackPanel();
        aboutGroup.Children.Add(InfoRow("\uE946", Strings.T(L.Version), $"v{AppVersion}"));
        ContentHost.Children.Add(SettingsGroup(aboutGroup));

        ContentHost.Children.Add(CreditsFooter());
    }

    // Links oficiais (centralizados): NOSSO Discord (FarmOracleMMO) + canal do YouTube.
    private const string DiscordUrl = "https://discord.gg/9jCuB6BDBC";
    private const string YoutubeUrl = "https://youtube.com/@viniciosprestrelo44?si=B18HIMXP0cg2Mq74";

    /// Rodap\u00E9 de cr\u00E9ditos (Desenvolvido por / Agradecimentos + \u00EDcones de Discord e YouTube).
    /// Reutilizado na p\u00E1gina inicial (RenderModePicker) e nas Configura\u00E7\u00F5es (RenderSettings).
    private FrameworkElement CreditsFooter()
    {
        var footer = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 14, 0, 6) };
        footer.Children.Add(new TextBlock
        {
            Text = Strings.T(L.DevelopedBy), Foreground = Theme.TextDim, FontSize = 10,
            FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center
        });
        footer.Children.Add(new TextBlock
        {
            Text = Strings.T(L.ThanksTo), Foreground = Theme.TextDim, FontSize = 9, Opacity = 0.85,
            HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 2, 0, 0)
        });
        var social = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 6, 0, 0) };
        void AddSocial(string icon, string url)
        {
            var el = ItemIcon(icon, 30);
            if (el == null) return;
            el.Margin = new Thickness(9, 0, 9, 0);
            MakeClickable(el, () => OpenUrl(url));
            social.Children.Add(el);
        }
        AddSocial("discord", DiscordUrl);
        AddSocial("youtube", YoutubeUrl);
        footer.Children.Add(social);
        return footer;
    }

    private void RenderShortcutPanel(bool skip = false)
    {
        var combo = skip ? _skipCombo : _nextCombo;
        ContentHost.Children.Add(new TextBlock
        {
            Text = Strings.T(skip ? L.NavSkipShortcut : L.NavNextShortcut), Foreground = Theme.Text, FontSize = 13,
            FontWeight = FontWeights.SemiBold, Margin = new Thickness(2, 2, 2, 4)
        });
        ContentHost.Children.Add(new TextBlock
        {
            Text = Strings.T(skip ? L.ShortcutSkipDescription : L.ShortcutDescription),
            Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(2, 0, 2, 6)
        });
        var group = new StackPanel();
        group.Children.Add(NavRow("\uE765", Strings.T(L.Shortcut),
            combo?.Display ?? Strings.T(L.None), () => StartCapture(skip)));
        if (combo != null)
        {
            group.Children.Add(RowDivider());
            var clear = NavRow("\uE711", Strings.T(L.Clear), "", () =>
            {
                if (skip) { _skipCombo = null; ShortcutStore.SaveSkip(null); RegisterSkipHotkey(); }
                else { _nextCombo = null; ShortcutStore.Save(null); RegisterNextHotkey(); }
                Render();
            });
            group.Children.Add(clear);
        }
        ContentHost.Children.Add(SettingsGroup(group));
    }

    private void RenderLanguagePanel()
    {
        var group = new StackPanel();
        group.Children.Add(LanguageRow("🇧🇷", Lang.Pt, Strings.T(L.Portuguese)));
        group.Children.Add(RowDivider());
        group.Children.Add(LanguageRow("🇺🇸", Lang.En, "English"));
        ContentHost.Children.Add(SettingsGroup(group));
    }

    // MARK: - Componentes da tela de Configurações

    private FrameworkElement TeamLineRow(FrameworkElement? icon, string name, string? sub,
                                         string? pokepaste, bool selected, Action? onSelect,
                                         TeamSource? source = null)
    {
        var dock = new DockPanel { LastChildFill = true };

        // Direita: Poképaste (?) + fonte + marca de seleção (radio).
        var rightStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        var pasteBtn = PasteButton(pokepaste);
        if (pasteBtn != null) rightStack.Children.Add(pasteBtn);
        var srcBtn = SourceButton(source);
        if (srcBtn != null) rightStack.Children.Add(srcBtn);
        var radio = new TextBlock
        {
            Text = selected ? "◉" : "○",   // ◉ marcado / ○ desmarcado
            FontSize = 15, FontWeight = FontWeights.Bold,
            Foreground = selected ? Theme.Good : Theme.TextDim,
            VerticalAlignment = VerticalAlignment.Center
        };
        rightStack.Children.Add(radio);
        DockPanel.SetDock(rightStack, Dock.Right);
        dock.Children.Add(rightStack);

        var iconHost = new Border { Width = 30, Height = 30, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        if (icon != null) { icon.HorizontalAlignment = HorizontalAlignment.Center; icon.VerticalAlignment = VerticalAlignment.Center; iconHost.Child = icon; }
        DockPanel.SetDock(iconHost, Dock.Left);
        dock.Children.Add(iconHost);

        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock { Text = name, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.SemiBold });
        if (!string.IsNullOrEmpty(sub))
            col.Children.Add(new TextBlock { Text = sub, Foreground = Theme.TextDim, FontSize = 9, TextTrimming = TextTrimming.CharacterEllipsis });
        dock.Children.Add(col);

        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 10, 12, 10) };
        if (onSelect != null) MakeClickable(row, onSelect);
        return row;
    }

    /// Botão amarelo do Poképaste (?). Retorna null se não houver link (porte do pasteButton do Mac).
    private FrameworkElement? PasteButton(string? pokepaste)
    {
        if (string.IsNullOrEmpty(pokepaste)) return null;
        var url = pokepaste;
        var paste = new TextBlock { Text = "?", Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        var pasteBtn = new Border { Child = paste, Width = 24, Height = 24, CornerRadius = new CornerRadius(12), Background = PasteYellow, Margin = new Thickness(0, 0, 8, 0), ToolTip = Strings.T(L.PasteHelp) };
        MakeClickable(pasteBtn, () => OpenUrl(url));
        return pasteBtn;
    }

    /// Botão da FONTE (doc/vídeo/pokeking/aviso) ao lado do Poképaste. Null se não houver fonte
    /// (porte do sourceButton do Mac).
    private FrameworkElement? SourceButton(TeamSource? source)
    {
        if (source == null) return null;
        string glyph = source switch
        {
            TeamSource.Video => "▶",
            TeamSource.Pokeking => "ⓘ",
            TeamSource.NotFound => "!",
            _ => "↗",
        };
        Brush bg = source is TeamSource.Video
            ? new SolidColorBrush(Color.FromRgb(0xE6, 0x38, 0x32))
            : new SolidColorBrush(Color.FromRgb(0x5C, 0x99, 0xF2));
        var srcText = new TextBlock { Text = glyph, Foreground = Brushes.White, FontSize = 11, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        var srcBtn = new Border { Child = srcText, Width = 24, Height = 24, CornerRadius = new CornerRadius(12), Background = bg, Margin = new Thickness(0, 0, 8, 0), ToolTip = Strings.T(L.SourceHelp) };
        var src = source;
        MakeClickable(srcBtn, () => OpenSource(src));
        return srcBtn;
    }

    /// Cabeçalho de um time do Farm com VÁRIAS rotas: nome do time (bold) + roster + Poképaste/doc
    /// (uma vez só), SEM rádio — a seleção fica nas sub-linhas de variante. Porte do farmTeamHeader do Mac.
    private FrameworkElement FarmTeamHeader(string group, IReadOnlyList<FarmRoute> routes)
    {
        var r = routes[0];
        var dock = new DockPanel { LastChildFill = true };

        var rightStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        var pasteBtn = PasteButton(r.Pokepaste);
        if (pasteBtn != null) rightStack.Children.Add(pasteBtn);
        var srcBtn = SourceButton(r.Doc is { } fdoc ? new TeamSource.Doc(fdoc) : new TeamSource.NotFound());
        if (srcBtn != null) rightStack.Children.Add(srcBtn);
        DockPanel.SetDock(rightStack, Dock.Right);
        dock.Children.Add(rightStack);

        var iconHost = new Border { Width = 30, Height = 30, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        var icon = SpriteIcon(r.Pokemon, 28);
        if (icon != null) { icon.HorizontalAlignment = HorizontalAlignment.Center; icon.VerticalAlignment = VerticalAlignment.Center; iconHost.Child = icon; }
        DockPanel.SetDock(iconHost, Dock.Left);
        dock.Children.Add(iconHost);

        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock { Text = AppModel.FarmTeamName(group), Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Bold });
        col.Children.Add(new TextBlock { Text = r.Roster, Foreground = Theme.TextDim, FontSize = 9, TextTrimming = TextTrimming.CharacterEllipsis });
        dock.Children.Add(col);

        // Não é clicável em si (a seleção é por variante); padding menor embaixo pra "colar" nas sub-linhas.
        return new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 10, 12, 4) };
    }

    /// Linha compacta de uma VARIANTE de rota (dentro do submenu do time): indicador + nome curto,
    /// indentado. Selecionar chama SetFarmRoute. Porte do farmVariantRow do Mac.
    private FrameworkElement FarmVariantRow(FarmRoute route)
    {
        bool selected = route.Id == _model.ActiveFarmRouteId;
        var dock = new DockPanel { LastChildFill = true };

        var radio = new TextBlock
        {
            Text = selected ? "◉" : "○",
            FontSize = 14, FontWeight = FontWeights.Bold,
            Foreground = selected ? Theme.Good : Theme.TextDim,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0)
        };
        DockPanel.SetDock(radio, Dock.Left);
        dock.Children.Add(radio);

        dock.Children.Add(new TextBlock
        {
            Text = route.Variant, Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center
        });

        // Indentação à esquerda (42) alinha com o divisor e com o farmVariantRow do Mac.
        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(42, 8, 12, 8) };
        MakeClickable(row, () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetFarmRoute(route.Id); });
        return row;
    }

    /// Fonte da estratégia mostrada no botão ao lado do time (igual ao Mac).
    private abstract record TeamSource
    {
        public sealed record Doc(string Url) : TeamSource;
        public sealed record Video(string Url) : TeamSource;
        public sealed record Pokeking(string Code, string Team) : TeamSource;
        public sealed record NotFound : TeamSource;
    }

    private void OpenSource(TeamSource s)
    {
        switch (s)
        {
            case TeamSource.Doc d: OpenUrl(d.Url); break;
            case TeamSource.Video v: OpenUrl(v.Url); break;
            case TeamSource.Pokeking pk:
                var body = string.Format(Strings.T(L.PokekingBody), pk.Code)
                    + "\n\n[ Sim/Yes ] " + Strings.T(L.CopyCode)
                    + "      [ Não/No ] " + Strings.T(L.OpenPokeking);
                var res = MessageBox.Show(body, "Pokeking — " + pk.Team,
                    MessageBoxButton.YesNoCancel, MessageBoxImage.Information);
                if (res == MessageBoxResult.Yes) Clipboard.SetText(pk.Code);
                else if (res == MessageBoxResult.No) OpenUrl("https://pokeking.icu");
                break;
            case TeamSource.NotFound:
                MessageBox.Show(Strings.T(L.DocNotFoundBody), Strings.T(L.DocNotFoundTitle),
                    MessageBoxButton.OK, MessageBoxImage.Information);
                break;
        }
    }

    private FrameworkElement EmojiToggleRow()
    {
        bool on = _model.EmojiMode;
        var dock = new DockPanel { LastChildFill = true };

        var pill = new Border
        {
            Background = on ? Theme.Good : Theme.Panel,
            BorderBrush = on ? Theme.Good : Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10), Padding = new Thickness(10, 3, 10, 3),
            VerticalAlignment = VerticalAlignment.Center,
            Child = new TextBlock { Text = on ? "ON" : "OFF", Foreground = on ? Brushes.Black : Theme.TextDim, FontSize = 11, FontWeight = FontWeights.Bold }
        };
        DockPanel.SetDock(pill, Dock.Right);
        dock.Children.Add(pill);

        var ico = new TextBlock { Text = "\uE76E", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 14, Foreground = Theme.Accent, Width = 20, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(ico, Dock.Left);
        dock.Children.Add(ico);

        dock.Children.Add(new TextBlock { Text = Strings.T(L.EmojiMode), Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Medium, VerticalAlignment = VerticalAlignment.Center });

        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 11, 12, 11) };
        MakeClickable(row, () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.ToggleEmoji(); });
        return row;
    }

    private FrameworkElement OpacityRow()
    {
        var head = new DockPanel { LastChildFill = true };
        var pct = new TextBlock { Text = $"{(int)Math.Round(_opacityLevel * 100)}%", Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.Bold, FontFamily = new FontFamily("Consolas"), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(pct, Dock.Right);
        head.Children.Add(pct);
        var ico = new TextBlock { Text = "\uE706", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 14, Foreground = Theme.Accent, Width = 20, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(ico, Dock.Left);
        head.Children.Add(ico);
        head.Children.Add(new TextBlock { Text = Strings.T(L.Opacity), Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Medium, VerticalAlignment = VerticalAlignment.Center });

        var slider = new Slider
        {
            Minimum = 0.35, Maximum = 1.0, Value = _opacityLevel,
            Margin = new Thickness(30, 8, 0, 0), Foreground = Theme.Accent
        };
        slider.ValueChanged += (_, e) =>
        {
            SetOpacity(e.NewValue);
            pct.Text = $"{(int)Math.Round(_opacityLevel * 100)}%";
        };
        // Clicar/arrastar o slider precisa de foco; libera o no-activate ao tocar e religa ao sair.
        slider.PreviewMouseLeftButtonDown += (_, _) => Native.SetNoActivate(this, false);
        slider.LostMouseCapture += (_, _) => Native.SetNoActivate(this, true);

        var col = new StackPanel();
        col.Children.Add(head);
        col.Children.Add(slider);
        return new Border { Child = col, Background = Brushes.Transparent, Padding = new Thickness(12, 11, 12, 11) };
    }

    private FrameworkElement LanguageRow(string flag, Lang lang, string name)
    {
        bool selected = _model.Language == lang;
        var dock = new DockPanel { LastChildFill = true };
        if (selected)
        {
            var check = new TextBlock { Text = "✓", FontSize = 14, FontWeight = FontWeights.Bold, Foreground = Theme.Good, VerticalAlignment = VerticalAlignment.Center };
            DockPanel.SetDock(check, Dock.Right);
            dock.Children.Add(check);
        }
        var fl = new TextBlock { Text = flag, FontSize = 16, Width = 22, Margin = new Thickness(0, 0, 8, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(fl, Dock.Left);
        dock.Children.Add(fl);
        dock.Children.Add(new TextBlock { Text = name, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Medium, VerticalAlignment = VerticalAlignment.Center });

        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 11, 12, 11) };
        MakeClickable(row, () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetLanguage(lang); });
        return row;
    }

    private FrameworkElement NavRow(string glyph, string title, string value, Action act)
    {
        var dock = new DockPanel { LastChildFill = true };

        var right = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        if (!string.IsNullOrEmpty(value))
            right.Children.Add(new TextBlock { Text = value, Foreground = Theme.TextDim, FontSize = 12, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 6, 0), TextTrimming = TextTrimming.CharacterEllipsis });
        right.Children.Add(new TextBlock { Text = "›", Foreground = Theme.TextDim, FontSize = 14, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center });
        DockPanel.SetDock(right, Dock.Right);
        dock.Children.Add(right);

        var ico = new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 14, Foreground = Theme.Accent, Width = 20, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(ico, Dock.Left);
        dock.Children.Add(ico);
        dock.Children.Add(new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Medium, VerticalAlignment = VerticalAlignment.Center });

        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 12, 12, 12) };
        MakeClickable(row, act);
        return row;
    }

    private FrameworkElement InfoRow(string glyph, string title, string value)
    {
        var dock = new DockPanel { LastChildFill = true };
        var val = new TextBlock { Text = value, Foreground = Theme.TextDim, FontSize = 12, FontWeight = FontWeights.Bold, FontFamily = new FontFamily("Consolas"), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(val, Dock.Right);
        dock.Children.Add(val);
        var ico = new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 14, Foreground = Theme.Accent, Width = 20, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(ico, Dock.Left);
        dock.Children.Add(ico);
        dock.Children.Add(new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Medium, VerticalAlignment = VerticalAlignment.Center });
        return new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 12, 12, 12) };
    }

    private static Border SettingsGroup(UIElement content) => new()
    {
        Child = content, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(12), Margin = new Thickness(0, 0, 0, 6)
    };

    private static TextBlock SectionLabel(string text) => new()
    {
        Text = text.ToUpperInvariant(), Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Black,
        Margin = new Thickness(2, 2, 2, 4)
    };

    private void GroupLabel(string text) => ContentHost.Children.Add(new TextBlock
    {
        Text = text.ToUpperInvariant(), Foreground = Theme.Accent, FontSize = 9, FontWeight = FontWeights.Bold,
        Margin = new Thickness(4, 6, 0, 2)
    });

    /// Cabeçalho de grupo de time RECOLHÍVEL (porte do collapsibleTeamGroup do SettingsView.swift):
    /// recolhido mostra só o nome do modo + o time ativo; expandido revela a lista de times.
    /// O estado fica em _expandedTeamGroups (campo), então persiste entre renders — selecionar
    /// um time NÃO fecha o grupo. Adiciona o cabeçalho (e o corpo, se aberto) ao ContentHost.
    private void CollapsibleTeamGroup(string title, FrameworkElement? icon, string? selected, UIElement body)
    {
        bool isOpen = _expandedTeamGroups.Contains(title);

        var head = new DockPanel { LastChildFill = true, Margin = new Thickness(4, 6, 4, 2) };

        // Chevron à direita (▼ aberto / ▶ recolhido).
        var chevron = new TextBlock
        {
            Text = isOpen ? "▼" : "▶", Foreground = Theme.TextDim, FontSize = 10, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(6, 0, 0, 0)
        };
        DockPanel.SetDock(chevron, Dock.Right);
        head.Children.Add(chevron);

        // Recolhido: mostra o time ativo ao lado do chevron (atalho visual, igual ao Mac).
        if (!isOpen && !string.IsNullOrEmpty(selected))
        {
            var sel = new TextBlock
            {
                Text = selected, Foreground = Theme.TextDim, FontSize = 10, VerticalAlignment = VerticalAlignment.Center,
                MaxWidth = 150, TextTrimming = TextTrimming.CharacterEllipsis, TextAlignment = TextAlignment.Right
            };
            DockPanel.SetDock(sel, Dock.Right);
            head.Children.Add(sel);
        }

        // Esquerda (preenche): ícone do modo + título.
        var left = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        if (icon != null)
        {
            icon.Margin = new Thickness(0, 0, 8, 0);
            left.Children.Add(icon);
        }
        left.Children.Add(new TextBlock
        {
            Text = title.ToUpperInvariant(), Foreground = Theme.Accent, FontSize = 9, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        });
        head.Children.Add(left);

        var headBorder = new Border { Child = head, Background = Brushes.Transparent, Padding = new Thickness(0, 2, 0, 2) };
        MakeClickable(headBorder, () =>
        {
            if (!_expandedTeamGroups.Add(title)) _expandedTeamGroups.Remove(title);  // toggle
            Render();
        });
        ContentHost.Children.Add(headBorder);

        if (isOpen) ContentHost.Children.Add(SettingsGroup(body));
    }

    private static Border RowDivider() => new()
    {
        Height = 1, Background = Theme.Border, Margin = new Thickness(42, 0, 0, 0)
    };

    /// Retrato representativo de uma categoria (Elite 4 → Cynthia), igual ao Mac.
    private static string? CategoryPortrait(string cat) => cat == "Elite 4" ? "cynthia" : null;

    // Ícone (item) representativo de uma categoria. Elite 4 → taça (data/items/trophy.png).
    private static string? CategoryItem(string cat) => cat == "Elite 4" ? "trophy" : null;

    /// Amarelo do botão de Poképaste (verde fica no Theme.Good).
    private static readonly Brush PasteYellow = new SolidColorBrush(Color.FromRgb(255, 209, 64));

    /// Card de modo: ícone + título/subtítulo + botão de play (verde) e, se houver, Poképaste (amarelo).
    private Border ModeCard(string title, string subtitle, FrameworkElement? icon, string? pokepaste, Action play,
        bool comingSoon = false)
    {
        var dock = new DockPanel();

        var iconHost = new Border { Width = 46, Height = 46, Margin = new Thickness(0, 0, 10, 0) };
        if (icon != null) iconHost.Child = icon;
        if (comingSoon) iconHost.Opacity = 0.55;
        DockPanel.SetDock(iconHost, Dock.Left);
        dock.Children.Add(iconHost);

        var btns = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        btns.Children.Add(CircleButton("", Theme.Good, play)); // play.fill (MDL2)
        if (!string.IsNullOrEmpty(pokepaste))
        {
            var url = pokepaste;
            btns.Children.Add(CircleButton("?", PasteYellow, () => OpenUrl(url), mdl2: false));
        }
        DockPanel.SetDock(btns, Dock.Right);
        dock.Children.Add(btns);

        var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        if (comingSoon)
        {
            var titleRow = new StackPanel { Orientation = Orientation.Horizontal };
            titleRow.Children.Add(new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 14, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center });
            titleRow.Children.Add(new Border
            {
                Background = PasteYellow, CornerRadius = new CornerRadius(8), Margin = new Thickness(6, 0, 0, 0),
                Padding = new Thickness(6, 1, 6, 1), VerticalAlignment = VerticalAlignment.Center,
                Child = new TextBlock { Text = Strings.T(L.ComingSoon).ToUpperInvariant(), Foreground = Brushes.Black, FontSize = 8, FontWeight = FontWeights.Bold }
            });
            texts.Children.Add(titleRow);
        }
        else
        {
            texts.Children.Add(new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 14, FontWeight = FontWeights.Bold });
        }
        texts.Children.Add(new TextBlock { Text = subtitle, Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 2, 0, 0) });
        dock.Children.Add(texts);

        var card = Card(dock, pad: new Thickness(11));
        MakeClickable(card, play);
        return card;
    }

    private Border CircleButton(string glyph, Brush bg, Action act, bool mdl2 = true)
    {
        var tb = new TextBlock
        {
            Text = glyph, Foreground = Brushes.White, FontSize = mdl2 ? 12 : 14, FontWeight = FontWeights.Bold,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
        if (mdl2) tb.FontFamily = new FontFamily("Segoe MDL2 Assets");
        var b = new Border { Child = tb, Width = 32, Height = 32, CornerRadius = new CornerRadius(16), Background = bg, Margin = new Thickness(7, 0, 0, 0) };
        MakeClickable(b, act);
        return b;
    }

    /// Ícone do card: retrato de treinador > item > mapa da região > glifo de destaque.
    private FrameworkElement ModeIcon(string? portrait, string? item, string? region, string symbol)
    {
        FrameworkElement? icon =
            portrait != null ? TrainerIcon(portrait, 44) :
            item != null ? ItemIcon(item, 38) :
            region != null ? StartersIcon(region, 46) : null;
        if (icon != null)
        {
            icon.HorizontalAlignment = HorizontalAlignment.Center;
            icon.VerticalAlignment = VerticalAlignment.Center;
            return icon;
        }
        var glyph = symbol switch { "bolt" => "", "map" => "", "crown" => "", _ => "" };
        return new TextBlock
        {
            Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 22, Foreground = Theme.Accent,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
    }

    private static void OpenUrl(string url)
    {
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true }); }
        catch { /* ignore */ }
    }

    // MARK: - Home (entradas / grupos)

    private void RenderHome()
    {
        var engine = _model.Engine!;
        var solve = engine.Solve;

        if (solve.Lead != null) ContentHost.Children.Add(LeadBanner(solve.Lead));
        if (solve.Warning != null) ContentHost.Children.Add(WarningBanner(solve.Warning));
        if (solve.Legend is { Count: > 0 } legend) ContentHost.Children.Add(LegendCard(legend));

        if (solve.Groups != null)
        {
            if (_selectedGroup == null)
            {
                ContentHost.Children.Add(Caption(solve.GroupPrompt ?? Strings.T(L.ChoosePrompt)));
                foreach (var g in solve.Groups)
                {
                    var gg = g;
                    ContentHost.Children.Add(GroupRow(gg, () => { _selectedGroup = gg; _search = ""; Render(); }));
                }
            }
            else
            {
                ContentHost.Children.Add(BackRow("‹ " + Strings.T(L.BackButton), _selectedGroup.Name, () => { _selectedGroup = null; _search = ""; Render(); }));
                AddSearchableEntries(engine, _selectedGroup.Entries,
                    engine.Solve.AllowSkip == true ? Strings.T(L.SearchCity) : Strings.T(L.SearchPokemon));
            }
        }
        else
        {
            ContentHost.Children.Add(Caption(solve.HomePrompt ?? Strings.T(L.FlatHomePromptDefault)));
            AddSearchableEntries(engine, solve.EntryPoints ?? new(), Strings.T(L.SearchPokemon));
        }
    }

    /// Campo de busca + lista filtrada de entradas (espelha o searchField do HomeView do Mac).
    /// O filtro reusa a lista existente sem re-renderizar tudo, para o foco do campo não se perder.
    private void AddSearchableEntries(SolveEngine engine, IReadOnlyList<EntryPoint> entries, string placeholder)
    {
        var listHost = new StackPanel { Margin = new Thickness(0, 2, 0, 0) };
        ContentHost.Children.Add(SearchField(placeholder, Repopulate));
        ContentHost.Children.Add(listHost);
        Repopulate();

        void Repopulate()
        {
            listHost.Children.Clear();
            var q = _search.Trim().ToLowerInvariant();
            var rows = string.IsNullOrEmpty(q)
                ? entries
                : entries.Where(e => e.Label.ToLowerInvariant().Contains(q)).ToList();
            if (rows.Count == 0)
            {
                listHost.Children.Add(new TextBlock
                {
                    Text = string.Format(Strings.T(L.SearchNoResults), _search),
                    Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap,
                    Margin = new Thickness(2, 6, 2, 0)
                });
                return;
            }
            // Rota de farm (marcar cidades p/ pular) → lista. Leads da Elite 4 → grade de
            // quadradinhos (mesma escolha visual do Mac: HomeView.cityStep/pokemonCell).
            if (engine.Solve.AllowSkip == true)
            {
                // #42 (Lewis): os marcados pra pular SOMEM da lista; um botão reexibe pra desmarcar.
                string modeId = _model.CurrentMode!.Id;
                var visible = rows.Where(e => !_model.Skips.IsSkipped(modeId, e.NodeId)).ToList();
                var skippedList = rows.Where(e => _model.Skips.IsSkipped(modeId, e.NodeId)).ToList();
                foreach (var entry in visible) listHost.Children.Add(EntryRow(engine, entry));
                if (skippedList.Count > 0)
                {
                    bool en = _model.Language == Lang.En;
                    string label = _showSkipped
                        ? (en ? "Hide skipped" : "Ocultar pulados")
                        : (en ? $"Show skipped ({skippedList.Count})" : $"Mostrar pulados ({skippedList.Count})");
                    var toggle = new Border
                    {
                        Background = Theme.PanelSoft, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
                        CornerRadius = new CornerRadius(8), Padding = new Thickness(10, 6, 10, 6),
                        Margin = new Thickness(0, 4, 0, 0),
                        Child = new TextBlock
                        {
                            Text = label, Foreground = Theme.TextDim, FontSize = 11, FontWeight = FontWeights.SemiBold,
                            HorizontalAlignment = HorizontalAlignment.Center, TextAlignment = TextAlignment.Center
                        }
                    };
                    MakeClickable(toggle, () => { _showSkipped = !_showSkipped; Repopulate(); });
                    listHost.Children.Add(toggle);
                    if (_showSkipped)
                        foreach (var entry in skippedList) listHost.Children.Add(EntryRow(engine, entry));
                }
            }
            else
            {
                var grid = new WrapPanel { Orientation = Orientation.Horizontal };
                foreach (var entry in rows) grid.Children.Add(PokemonCell(engine, entry));
                listHost.Children.Add(grid);
            }
        }
    }

    /// Célula de Pokémon em grade (quadradinho com ícone + nome) — lead da Elite 4.
    /// Porte do pokemonCell do Mac (HomeView.swift).
    private FrameworkElement PokemonCell(SolveEngine engine, EntryPoint entry)
    {
        var inner = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
        FrameworkElement? icon = entry.Portrait != null ? TrainerIcon(entry.Portrait, 34) : MonOrBallIcon(entry.Label, 34);
        if (icon != null) { icon.Margin = new Thickness(0, 0, 0, 3); inner.Children.Add(icon); }
        inner.Children.Add(new TextBlock
        {
            Text = entry.Label, Foreground = Theme.Text, FontSize = 11, FontFamily = new FontFamily("Consolas"),
            TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center
        });

        var box = new Border
        {
            Child = inner, Width = 84, Background = Theme.Panel, BorderBrush = Theme.Border,
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(9),
            Padding = new Thickness(4, 9, 4, 9), Margin = new Thickness(0, 0, 8, 8)
        };
        MakeClickable(box, () => engine.JumpTo(entry, _selectedGroup));
        return box;
    }

    /// Constrói o campo de busca. Como o overlay é "no-activate", clicar no campo libera o foco
    /// momentaneamente (SetNoActivate) para permitir digitar; ao sair, religa o no-activate.
    private Border SearchField(string placeholder, Action onChanged)
    {
        var glass = new TextBlock
        {
            Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 12,
            Foreground = Theme.Accent, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 7, 0)
        };
        var box = new TextBox
        {
            Text = _search, BorderThickness = new Thickness(0), Background = Brushes.Transparent,
            Foreground = Theme.Text, CaretBrush = Theme.Text, FontSize = 12,
            VerticalContentAlignment = VerticalAlignment.Center, Padding = new Thickness(0)
        };
        var ph = new TextBlock
        {
            Text = placeholder, Foreground = Theme.TextDim, FontSize = 12, IsHitTestVisible = false,
            VerticalAlignment = VerticalAlignment.Center,
            Visibility = string.IsNullOrEmpty(_search) ? Visibility.Visible : Visibility.Collapsed
        };
        var clear = new TextBlock
        {
            Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 11,
            Foreground = Theme.TextDim, VerticalAlignment = VerticalAlignment.Center, Cursor = Cursors.Hand,
            Margin = new Thickness(6, 0, 0, 0),
            Visibility = string.IsNullOrEmpty(_search) ? Visibility.Collapsed : Visibility.Visible
        };

        box.TextChanged += (_, _) =>
        {
            _search = box.Text;
            ph.Visibility = string.IsNullOrEmpty(box.Text) ? Visibility.Visible : Visibility.Collapsed;
            clear.Visibility = string.IsNullOrEmpty(box.Text) ? Visibility.Collapsed : Visibility.Visible;
            onChanged();
        };
        clear.MouseLeftButtonUp += (_, e) => { e.Handled = true; box.Clear(); FocusSearch(box); };

        var field = new Grid();
        field.Children.Add(ph);
        field.Children.Add(box);

        var dock = new DockPanel();
        DockPanel.SetDock(glass, Dock.Left);
        DockPanel.SetDock(clear, Dock.Right);
        dock.Children.Add(glass);
        dock.Children.Add(clear);
        dock.Children.Add(field);

        var border = new Border
        {
            Child = dock, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(9, 6, 9, 6), Margin = new Thickness(0, 0, 0, 6)
        };
        border.PreviewMouseLeftButtonDown += (_, _) => FocusSearch(box);
        box.GotKeyboardFocus += (_, _) => border.BorderBrush = Theme.Accent;
        box.LostKeyboardFocus += (_, _) => { border.BorderBrush = Theme.Border; Native.SetNoActivate(this, true); };
        return border;
    }

    /// Libera o foco do overlay e foca a caixa de busca para digitar.
    private void FocusSearch(TextBox box)
    {
        Native.SetNoActivate(this, false);
        Activate();
        Dispatcher.BeginInvoke(new Action(() =>
        {
            box.Focus();
            Keyboard.Focus(box);
            box.CaretIndex = box.Text.Length;
        }), System.Windows.Threading.DispatcherPriority.Input);
    }

    private Border GroupRow(EntryGroup group, Action act)
    {
        var dock = new DockPanel();
        FrameworkElement? icon = group.Portrait != null ? TrainerIcon(group.Portrait, 32) : StartersIcon(group.Name, 40);
        if (icon != null) { icon.Margin = new Thickness(0, 0, 8, 0); DockPanel.SetDock(icon, Dock.Left); dock.Children.Add(icon); }
        var chev = Chevron(); DockPanel.SetDock(chev, Dock.Right); dock.Children.Add(chev);
        dock.Children.Add(new TextBlock
        {
            Text = group.Name, Foreground = Theme.Text, FontSize = 14, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        });
        var card = Card(dock, pad: new Thickness(12, 11, 12, 11));
        MakeClickable(card, act);
        return card;
    }

    private FrameworkElement EntryRow(SolveEngine engine, EntryPoint entry)
    {
        bool allowSkip = engine.Solve.AllowSkip == true;
        string modeId = _model.CurrentMode!.Id;
        bool skipped = allowSkip && _model.Skips.IsSkipped(modeId, entry.NodeId);

        var row = new DockPanel { Margin = new Thickness(0, 0, 0, 6) };

        if (allowSkip)
        {
            var mark = new TextBlock
            {
                Text = skipped ? "⊗" : "○",
                Foreground = skipped ? Theme.Accent : Theme.TextDim,
                FontSize = 15, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0),
                ToolTip = skipped ? Strings.T(L.CitySkipUncheckHelp) : Strings.T(L.CitySkipMarkHelp)
            };
            MakeClickable(mark, () => { _model.Skips.Toggle(modeId, entry.NodeId); Render(); });
            DockPanel.SetDock(mark, Dock.Left);
            row.Children.Add(mark);
        }

        FrameworkElement? icon = entry.Portrait != null ? TrainerIcon(entry.Portrait, 24) : MonOrBallIcon(entry.Label, 24);

        var inner = new DockPanel();
        if (icon != null) { icon.Margin = new Thickness(0, 0, 6, 0); DockPanel.SetDock(icon, Dock.Left); inner.Children.Add(icon); }
        var chev = Chevron(); DockPanel.SetDock(chev, Dock.Right); inner.Children.Add(chev);
        inner.Children.Add(new TextBlock
        {
            Text = entry.Label, Foreground = skipped ? Theme.TextDim : Theme.Text, FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis,
            TextDecorations = skipped ? TextDecorations.Strikethrough : null
        });

        var card = Card(inner);
        card.Margin = new Thickness(0);
        MakeClickable(card, () => engine.JumpTo(entry, _selectedGroup));
        row.Children.Add(card);
        return row;
    }

    // MARK: - Nó (passos / escolhas)

    private void RenderNode()
    {
        var engine = _model.Engine!;
        var node = engine.CurrentNode!;

        if (engine.TopPortrait is string tp) ContentHost.Children.Add(OpponentHeader(tp, engine.TopName));
        if (ActiveOpponentMon(engine) is string activeMon) ContentHost.Children.Add(ActiveMonRow(activeMon));
        if (node.Title != null) ContentHost.Children.Add(NodeTitle(node.Title));
        if (node.GymLead is { Count: > 0 } leads) ContentHost.Children.Add(GymLeadHeader(Strings.T(L.GymLeadWith), leads, Theme.Accent));

        // "Ver times": no topo da luta da Elite 4, abre o overlay com os times possíveis do oponente.
        if (_model.PossibleOpponentTeamsNow() is { } pteams)
            ContentHost.Children.Add(VerTimesButton(pteams));

        bool revealAll = engine.Solve.RevealAll == true;
        // Ginásio da sequência: esconde o `setup` de entrada aqui — ele é mostrado no FIM do
        // ginásio ativo ANTERIOR (via UpcomingSetupSteps). Sub-nós (ex.: Driftveil) mantêm o setup.
        var steps = engine.HidesEntrySetup
            ? engine.RevealedSteps.Where(s => s.Kind != StepKind.Setup).ToList()
            : engine.RevealedSteps;
        for (int i = 0; i < steps.Count; i++)
        {
            bool isCurrent = !revealAll && i == steps.Count - 1;
            ContentHost.Children.Add(StepRow(steps[i], isCurrent, revealAll));
        }

        if (engine.PendingBranch is { Kind: BranchKind.Choice } ch)
        {
            var opts = ch.Options ?? new();
            SyncChoiceHotkeys(opts);
            ContentHost.Children.Add(ChoiceGrid(ch.Prompt ?? Strings.T(L.ChoicePromptDefault), opts, engine));
        }

        bool eliteEnd = engine.Solve.SequentialGroups == true && engine.IsTerminal;
        if (eliteEnd) AddEliteEndControls(engine);
        else if (engine.IsTerminal) ContentHost.Children.Add(TerminalBadge());

        // #68: feedback "funcionou/não" no FIM de cada ginásio do Gym Rerun (farm = allowSkip),
        // quando a solve acabou (branch "Continuar"/goto ou nó terminal). Na E4 já vem pelo
        // AddEliteEndControls, então o gate allowSkip evita duplicar.
        if (engine.Solve.AllowSkip == true &&
            (engine.PendingBranch is { Kind: BranchKind.Goto } || engine.IsTerminal))
            ContentHost.Children.Add(FeedbackControls(engine));

        // "PÓS-LUTA" de entrada do PRÓXIMO ginásio ativo, mostrado no fim do atual.
        foreach (var s in engine.UpcomingSetupSteps)
            ContentHost.Children.Add(StepRow(s, false, true));

        if (engine.UpcomingGymLead is { Count: > 0 } up)
        {
            var t = engine.UpcomingGymTitle;
            var title = Strings.T(L.NextGym) + (t != null ? " · " + ShortStop(t) : "");
            ContentHost.Children.Add(GymLeadHeader(title, up, Theme.Good));
        }
        else if (NextLeadHint(engine) is string hint)
        {
            ContentHost.Children.Add(NextLeadRow(hint));
        }

        if (engine.ShowNextButton) ContentHost.Children.Add(NextButton(engine));
        if (engine.CanSkip) ContentHost.Children.Add(SkipButton(engine));
    }

    private static string? NextLeadHint(SolveEngine e)
    {
        if (e.PendingBranch is { Kind: BranchKind.Goto } pb && pb.NodeId is string id
            && e.Solve.Nodes.TryGetValue(id, out var n)) return n.LeadHint;
        return null;
    }

    private static string ShortStop(string title)
    {
        int idx = title.IndexOf("· ", StringComparison.Ordinal);
        return idx >= 0 ? title[(idx + 2)..] : title;
    }

    private FrameworkElement StepRow(Step step, bool isCurrent, bool revealAll) => step.Kind switch
    {
        StepKind.Conditional => step.Table != null ? ConditionalView(step.Table) : new StackPanel(),
        StepKind.Note => NoteRow(step.Text ?? ""),
        StepKind.Setup => SetupRow(step.Text ?? ""),
        _ => ActionRow(step.Text ?? "", isCurrent, revealAll)
    };

    private Border ActionRow(string text, bool isCurrent, bool revealAll)
    {
        bool hi = isCurrent || revealAll;
        var marker = new TextBlock
        {
            Text = revealAll ? "▸" : (isCurrent ? "▶" : "✓"),
            Foreground = hi ? Theme.Accent : Theme.Good, FontSize = 12,
            VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 1, 8, 0)
        };
        var baseColor = hi ? Theme.Text : Theme.TextDim;
        var tb = new TextBlock
        {
            Foreground = baseColor, FontSize = 13,
            FontWeight = hi ? FontWeights.SemiBold : FontWeights.Normal, TextWrapping = TextWrapping.Wrap
        };
        _colorizer.Apply(tb, text, baseColor);
        var dock = new DockPanel();
        DockPanel.SetDock(marker, Dock.Left);
        dock.Children.Add(marker);
        dock.Children.Add(tb);
        return new Border
        {
            Child = dock, Background = isCurrent ? Theme.AccentSoft : Theme.Panel,
            BorderBrush = isCurrent ? Theme.Accent : Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(10, 8, 10, 8), Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private FrameworkElement NoteRow(string text)
    {
        var marker = new TextBlock { Text = "ⓘ", Foreground = Theme.TextDim, FontSize = 11, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 1, 8, 0) };
        var tb = new TextBlock { Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap };
        _colorizer.Apply(tb, text, Theme.TextDim);
        var dock = new DockPanel { Margin = new Thickness(2, 0, 2, 6) };
        DockPanel.SetDock(marker, Dock.Left);
        dock.Children.Add(marker);
        dock.Children.Add(tb);
        return dock;
    }

    private Border SetupRow(string text)
    {
        var head = new TextBlock { Text = Strings.T(L.StepSetupBadge), Foreground = Theme.Good, FontSize = 8, FontWeight = FontWeights.Black };
        var tb = new TextBlock { Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Medium, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 1, 0, 0) };
        _colorizer.Apply(tb, text, Theme.Text);
        var stack = new StackPanel();
        stack.Children.Add(head);
        stack.Children.Add(tb);
        return new Border
        {
            Child = stack, Background = Theme.GoodSoft, BorderBrush = Theme.Good, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(10, 7, 10, 7), Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private Border ConditionalView(Models.ConditionalTable table)
    {
        var stack = new StackPanel();
        if (table.Title != null)
            stack.Children.Add(new TextBlock { Text = table.Title, Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 4) });
        foreach (var r in table.Rows)
        {
            var move = new TextBlock { Text = r.Move, Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.SemiBold, Width = 108, TextWrapping = TextWrapping.Wrap, VerticalAlignment = VerticalAlignment.Top };
            var targets = new TextBlock { Text = string.Join(", ", r.Targets), Foreground = Theme.Text, FontSize = 12, TextWrapping = TextWrapping.Wrap };
            var dock = new DockPanel { Margin = new Thickness(0, 2, 0, 2) };
            DockPanel.SetDock(move, Dock.Left);
            dock.Children.Add(move);
            dock.Children.Add(targets);
            stack.Children.Add(dock);
        }
        return new Border
        {
            Child = stack, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(10, 8, 10, 8), Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private FrameworkElement NodeTitle(string title)
    {
        var dot = new TextBlock { Text = "◎", Foreground = Theme.Accent, FontSize = 11, Margin = new Thickness(0, 0, 5, 0), VerticalAlignment = VerticalAlignment.Center };
        var t = new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Bold, TextWrapping = TextWrapping.Wrap, VerticalAlignment = VerticalAlignment.Center };
        var dock = new DockPanel { Margin = new Thickness(0, 0, 0, 6) };
        DockPanel.SetDock(dot, Dock.Left);
        dock.Children.Add(dot);
        dock.Children.Add(t);
        return dock;
    }

    private Border GymLeadHeader(string title, List<GymLead> leads, Brush tint)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = title.ToUpperInvariant(), Foreground = tint, FontSize = 8, FontWeight = FontWeights.Black, Margin = new Thickness(0, 0, 0, 3) });
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var lead in leads)
        {
            var item = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 12, 0) };
            var icon = SpriteIcon(lead.Pokemon, 22);
            if (icon != null) { icon.Margin = new Thickness(0, 0, 4, 0); item.Children.Add(icon); }
            var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            col.Children.Add(new TextBlock { Text = lead.Pokemon, Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.Bold });
            if (lead.Item != null) col.Children.Add(new TextBlock { Text = lead.Item, Foreground = Theme.TextDim, FontSize = 9 });
            item.Children.Add(col);
            row.Children.Add(item);
        }
        stack.Children.Add(row);
        var soft = ReferenceEquals(tint, Theme.Good) ? Theme.GoodSoft : Theme.AccentSoft;
        return new Border
        {
            Child = stack, Background = soft, BorderBrush = tint, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(9, 6, 9, 6), Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private Border NextLeadRow(string hint)
    {
        var tb = new TextBlock { Foreground = Theme.Good, FontSize = 11, TextWrapping = TextWrapping.Wrap };
        tb.Inlines.Add(new Run(Strings.T(L.NextLeadLabel)) { Foreground = Theme.Good, FontWeight = FontWeights.Bold });
        _colorizer.Append(tb, hint, Theme.Text);
        return new Border { Child = tb, Background = Theme.GoodSoft, CornerRadius = new CornerRadius(9), Padding = new Thickness(9, 6, 9, 6), Margin = new Thickness(0, 0, 0, 6) };
    }

    private Border NextButton(SolveEngine engine)
    {
        string label = engine.CanAdvanceStep ? Strings.T(L.Next) : (engine.Solve.RevealAll == true ? Strings.T(L.NextStop) : Strings.T(L.ContinueLabel));
        var tb = new TextBlock { Text = label + "  ›", Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center };
        var b = new Border { Child = tb, Background = Theme.Accent, CornerRadius = new CornerRadius(10), Padding = new Thickness(10), Margin = new Thickness(0, 2, 0, 0) };
        MakeClickable(b, engine.Next);
        return b;
    }

    private Border SkipButton(SolveEngine engine)
    {
        var tb = new TextBlock { Text = "⤼ " + Strings.T(L.SkipThisStop), Foreground = Theme.TextDim, FontSize = 12, HorizontalAlignment = HorizontalAlignment.Center };
        var b = new Border { Child = tb, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(9), Padding = new Thickness(8), Margin = new Thickness(0, 6, 0, 0) };
        MakeClickable(b, engine.Skip);
        return b;
    }

    // MARK: - Grade de escolhas (porte do ChoiceView.swift do Mac)

    /// Pergunta "O que o oponente fez?" como grade de quadradinhos: cada célula tem o selo da
    /// tecla F1..F12 acima, o sprite do Pokémon (de quem dá o golpe / do mon trocado) e o rótulo.
    private FrameworkElement ChoiceGrid(string prompt, IReadOnlyList<Option> opts, SolveEngine engine)
    {
        var col = new StackPanel();
        col.Children.Add(new TextBlock
        {
            Text = prompt, Foreground = Theme.Choice, FontSize = 12, FontWeight = FontWeights.Bold,
            TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 7)
        });

        string? activeMon = ActiveOpponentMon(engine);
        var grid = new WrapPanel { Orientation = Orientation.Horizontal };
        for (int i = 0; i < opts.Count; i++)
        {
            var o = opts[i];
            int fKey = i < MaxChoiceKeys ? i + 1 : 0; // 0 = sem selo (passou de F12)
            grid.Children.Add(ChoiceCell(o, activeMon, fKey, () => engine.Choose(o)));
        }
        col.Children.Add(grid);

        return new Border
        {
            Child = col, Background = Theme.PanelSoft, CornerRadius = new CornerRadius(11),
            Padding = new Thickness(9, 8, 9, 8), Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private FrameworkElement ChoiceCell(Option option, string? activeMon, int fKey, Action act)
    {
        // Sprite: o Pokémon citado no rótulo (início, após "Contra"/"vs.", ou em qualquer posição);
        // senão o Pokémon ativo do oponente (quem dá o golpe); por fim o próprio rótulo (último recurso).
        // Catch-all "Demais times/Other teams" (nó *_def): sempre Master Ball, nunca herda o ativo (#65).
        string spriteName = OptionSpriteName(option.Label)
            ?? (option.NodeId.EndsWith("_def") ? option.Label : (activeMon ?? option.Label));

        var cellCol = new StackPanel();

        // Selo F1..F12 acima da caixa (altura reservada sempre, pra alinhar as células).
        var badgeHost = new Border { Height = 15, Margin = new Thickness(0, 0, 0, 2), HorizontalAlignment = HorizontalAlignment.Right };
        if (fKey > 0)
        {
            var badgeText = new TextBlock { Text = "F" + fKey, Foreground = Theme.Choice, FontSize = 9, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            badgeHost.Child = new Border { Child = badgeText, BorderBrush = Theme.Choice, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(4), Padding = new Thickness(5, 0, 5, 0) };
        }
        cellCol.Children.Add(badgeHost);

        var inner = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
        // Opção sem Pokémon (ex.: "Demais times") → Master Ball no lugar do vazio.
        var icon = MonOrBallIcon(spriteName, 36);
        icon.Margin = new Thickness(0, 0, 0, 3); inner.Children.Add(icon);
        // Rótulo colorido pela paleta do modo (mesmo Colorizer dos passos); respeita {Golpe|Pokémon}.
        var labelTb = new TextBlock
        {
            Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.SemiBold,
            TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center, MaxWidth = 96
        };
        _colorizer.Apply(labelTb, option.Label, Theme.Text);
        inner.Children.Add(labelTb);

        var box = new Border
        {
            Child = inner, Background = Theme.ChoiceSoft, BorderBrush = Theme.Choice, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9), Padding = new Thickness(6, 8, 6, 8)
        };
        cellCol.Children.Add(box);

        var cell = new Border { Child = cellCol, Width = 104, Margin = new Thickness(0, 0, 8, 8) };
        MakeClickable(cell, act);
        return cell;
    }

    /// Casa um sprite começando na palavra `start`, testando janelas de 3→1 palavras (pega nomes
    /// de 2 palavras como "Wash Rotom"/"Mr Mime"). Devolve o trecho casado ou null.
    private static string? SpriteSequence(string[] words, int start)
    {
        int max = Math.Min(3, words.Length - start);
        for (int n = max; n >= 1; n--)
        {
            var seq = string.Join(" ", words.Skip(start).Take(n));
            if (SpriteExists(seq)) return seq;
        }
        return null;
    }

    /// Se o rótulo COMEÇA com o nome de um Pokémon (ex.: "Wash Rotom", "Gallade travado no golpe"),
    /// devolve esse nome; senão null. Porte do leadingSpriteName do Mac.
    private static string? LeadingSpriteName(string label)
    {
        var words = label.Split(new[] { ' ', '/' }, StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return null;
        return SpriteSequence(words, 0);
    }

    /// Melhor sprite para um rótulo de OPÇÃO ("o que o oponente fez / colocou em campo"). Prioridade:
    /// 1) Pokémon no INÍCIO ("Gallade travado no golpe"); 2) Pokémon logo após um marcador de oponente
    /// ("Contra"/"vs."/"versus" → "vs. Blastoise", "troque para Dragonite Contra Gengar" → Gengar);
    /// 3) primeiro Pokémon em qualquer posição ("deixe fugir Houndoom", "Scald /Gyarados"). Espelha o Mac.
    private static readonly HashSet<string> OpponentMarkers = new() { "contra", "vs", "versus" };
    private static string? OptionSpriteName(string label)
    {
        var words = label.Split(new[] { ' ', '/' }, StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return null;
        if (SpriteSequence(words, 0) is { } lead) return lead;
        for (int i = 0; i < words.Length; i++)
            if (OpponentMarkers.Contains(Normalize(words[i])) && i + 1 < words.Length && SpriteSequence(words, i + 1) is { } m)
                return m;
        for (int i = 0; i < words.Length; i++)
            if (SpriteSequence(words, i) is { } m) return m;
        return null;
    }

    /// Existe sprite (data/sprites/<norm>.png) para este rótulo?
    private static bool SpriteExists(string name)
    {
        var key = Normalize(name);
        if (key.Length == 0) return false;
        return File.Exists(Path.Combine(SolveLoader.DataDir, "sprites", key + ".png"));
    }

    private FrameworkElement BackRow(string backLabel, string title, Action act)
    {
        var back = new TextBlock { Text = backLabel, Foreground = Theme.Choice, FontSize = 12, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
        MakeClickable(back, act);
        var t = new TextBlock { Text = title, Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
        var dock = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
        DockPanel.SetDock(back, Dock.Left);
        dock.Children.Add(back);
        dock.Children.Add(t);
        return dock;
    }

    // MARK: - Builders básicos

    private static Border Card(UIElement child, Brush? bg = null, Thickness? pad = null) => new()
    {
        Child = child, Background = bg ?? Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(10), Padding = pad ?? new Thickness(10, 9, 10, 9), Margin = new Thickness(0, 0, 0, 6)
    };

    private static TextBlock Caption(string text) => new()
    {
        Text = text, Foreground = Theme.TextDim, FontSize = 11, Margin = new Thickness(2, 2, 2, 6), TextWrapping = TextWrapping.Wrap
    };

    private static Border LeadBanner(string text)
    {
        var tb = new TextBlock { Text = text, Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Bold, TextWrapping = TextWrapping.Wrap, HorizontalAlignment = HorizontalAlignment.Center };
        return new Border { Child = tb, Background = Theme.AccentSoft, CornerRadius = new CornerRadius(10), Padding = new Thickness(8), Margin = new Thickness(0, 0, 0, 8) };
    }

    private Border TerminalBadge()
    {
        var tb = new TextBlock { Text = Strings.T(L.TerminalBadge), Foreground = Theme.Good, FontSize = 12, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap, HorizontalAlignment = HorizontalAlignment.Center };
        return new Border { Child = tb, Background = Theme.GoodSoft, CornerRadius = new CornerRadius(10), Padding = new Thickness(8, 10, 8, 10), Margin = new Thickness(0, 4, 0, 0) };
    }

    // MARK: - Cabeçalho do oponente (foto de quem você enfrenta agora)

    /// Verbos que introduzem o NOSSO Pokémon (troca de entrada) — não conta como oponente.
    private static readonly HashSet<string> OurSwitchVerbs = new()
        { "troque", "troca", "trocar", "volte", "volta", "mande", "manda", "use", "lidere", "lidera", "puxe", "puxa" };

    /// Pokémon ATIVO do oponente, ciente do contexto do nó. Base: último Pokémon "limpo" da trilha
    /// (lead / troca do oponente). Depois, se os passos JÁ REVELADOS citam um Pokémon do oponente
    /// ("Habilidade do Claydol", "→ sai Gengar"), passa a ser esse — ignorando as NOSSAS trocas
    /// ("troque para Dragonite"). Espelha o actingOpponentMon do Mac.
    private static string? ActiveOpponentMon(SolveEngine engine)
    {
        string? mon = null;
        foreach (var label in engine.PathTrail)
            if (File.Exists(Path.Combine(SolveLoader.DataDir, "sprites", Normalize(label) + ".png")))
                mon = label;
        foreach (var step in engine.RevealedSteps)
        {
            var text = step.Text;
            if (string.IsNullOrEmpty(text)) continue;
            var first = text.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "";
            if (OurSwitchVerbs.Contains(Normalize(first))) continue;
            if (OptionSpriteName(text) is { } m) mon = m;
        }
        return mon;
    }

    private Border ActiveMonRow(string mon)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(new TextBlock { Text = "▶", Foreground = Theme.Accent, FontSize = 9, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 4, 0) });
        if (SpriteIcon(mon, 20) is { } icon) { icon.Margin = new Thickness(0, 0, 5, 0); row.Children.Add(icon); }
        row.Children.Add(new TextBlock { Text = mon, Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        row.Children.Add(new TextBlock { Text = Strings.T(L.OpponentOnField), Foreground = Theme.TextDim, FontSize = 9, VerticalAlignment = VerticalAlignment.Center });
        return new Border { Child = row, Margin = new Thickness(0, 0, 0, 4) };
    }

    private Border OpponentHeader(string portrait, string? name)
    {
        var dock = new DockPanel { LastChildFill = true };
        var icon = TrainerIcon(portrait, 30);
        if (icon != null) { icon.Margin = new Thickness(0, 0, 8, 0); DockPanel.SetDock(icon, Dock.Left); dock.Children.Add(icon); }
        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock { Text = Strings.T(L.OpponentHeaderFacing), Foreground = Theme.Accent, FontSize = 8, FontWeight = FontWeights.Black });
        if (name != null) col.Children.Add(new TextBlock { Text = name, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Bold, TextTrimming = TextTrimming.CharacterEllipsis });
        dock.Children.Add(col);
        return new Border { Child = dock, Background = Theme.AccentSoft, CornerRadius = new CornerRadius(9), Padding = new Thickness(9, 5, 9, 5), Margin = new Thickness(0, 0, 0, 8) };
    }

    private static Border WarningBanner(string text)
    {
        var tb = new TextBlock { Text = "⚠️ " + text, Foreground = Theme.Warning, FontSize = 11, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap };
        return new Border { Child = tb, Background = Theme.WarningSoft, BorderBrush = Theme.Warning, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(10), Padding = new Thickness(9, 7, 9, 7), Margin = new Thickness(0, 0, 0, 8) };
    }

    // MARK: - Fim da luta na Elite 4: feedback + próximo treinador / reiniciar

    /// Bloco de feedback "funcionou / não funcionou" (#68): reusado no fim da luta da Elite 4
    /// (AddEliteEndControls) e no fim de cada ginásio do Gym Rerun (RenderNode). Border
    /// autocontido que se muta localmente: botões → caixa de motivo → agradecimento.
    private Border FeedbackControls(SolveEngine engine)
    {
        var fb = new Border { CornerRadius = new CornerRadius(9), Margin = new Thickness(0, 0, 0, 6) };

        void ShowThanks(bool ok)
        {
            fb.Background = Brushes.Transparent;
            fb.Child = new TextBlock
            {
                Text = ok ? Strings.T(L.FeedbackThanksOk) : Strings.T(L.FeedbackThanksFail),
                Foreground = Theme.TextDim, FontSize = 11, FontWeight = FontWeights.SemiBold,
                HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 6, 0, 6)
            };
        }

        void Submit(string result, string? description)
        {
            FeedbackClient.Send(result, _model.CurrentMode?.Title ?? engine.Solve.Title,
                _model.ActiveTeamId, engine.TopName, engine.PathTrail.FirstOrDefault(),
                string.Join(" → ", engine.PathTrail), engine.CurrentNodeId, description);
            ShowThanks(result == "funcionou");
        }

        void ShowFailBox()
        {
            var box = new TextBox
            {
                BorderThickness = new Thickness(0), Background = Theme.Bg, Foreground = Theme.Text,
                CaretBrush = Theme.Text, FontSize = 12, TextWrapping = TextWrapping.Wrap, AcceptsReturn = true,
                MinHeight = 46, Padding = new Thickness(8), Margin = new Thickness(0, 4, 0, 6)
            };
            box.PreviewMouseLeftButtonDown += (_, _) => FocusSearch(box);

            var send = Pill(Strings.T(L.Send), Brushes.Black, Theme.Warning, () => Submit("nao_funcionou", box.Text));
            send.HorizontalAlignment = HorizontalAlignment.Right;
            var cancel = new TextBlock { Text = Strings.T(L.Cancel), Foreground = Theme.TextDim, FontSize = 11, Cursor = Cursors.Hand, VerticalAlignment = VerticalAlignment.Center };
            MakeClickable(cancel, ShowButtons);
            var row = new DockPanel();
            DockPanel.SetDock(cancel, Dock.Left); row.Children.Add(cancel); row.Children.Add(send);

            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = Strings.T(L.FeedbackFailPrompt), Foreground = Theme.TextDim, FontSize = 10, FontWeight = FontWeights.SemiBold });
            stack.Children.Add(box);
            stack.Children.Add(row);
            fb.Background = Theme.Panel; fb.Padding = new Thickness(8); fb.Child = stack;
        }

        void ShowButtons()
        {
            fb.Background = Brushes.Transparent; fb.Padding = new Thickness(0);
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(6, GridUnitType.Pixel) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var ok = FeedbackButton(Strings.T(L.FeedbackWorked), Theme.Good, Theme.GoodSoft, () => Submit("funcionou", null));
            var no = FeedbackButton(Strings.T(L.FeedbackDidntWork), Theme.Danger, Theme.DangerSoft, ShowFailBox);
            Grid.SetColumn(ok, 0); Grid.SetColumn(no, 2);
            grid.Children.Add(ok); grid.Children.Add(no);
            fb.Child = grid;
        }

        ShowButtons();
        return fb;
    }

    private void AddEliteEndControls(SolveEngine engine)
    {
        var container = new StackPanel { Margin = new Thickness(0, 4, 0, 0) };

        // ---- Feedback (opcional) — reusado no Gym Rerun (#68) via FeedbackControls ----
        container.Children.Add(FeedbackControls(engine));

        // ---- Próximo treinador (ou reiniciar, no campeão) ----
        if (engine.NextGroup is EntryGroup nxt)
        {
            var dock = new DockPanel();
            var icon = nxt.Portrait != null ? TrainerIcon(nxt.Portrait, 22) : null;
            if (icon != null) { icon.Margin = new Thickness(0, 0, 7, 0); DockPanel.SetDock(icon, Dock.Left); dock.Children.Add(icon); }
            var chev = new TextBlock { Text = "›", Foreground = Brushes.Black, FontSize = 16, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center };
            DockPanel.SetDock(chev, Dock.Right); dock.Children.Add(chev);
            var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            col.Children.Add(new TextBlock { Text = Strings.T(L.NextTrainerBadge), Foreground = new SolidColorBrush(Color.FromArgb(0x99, 0, 0, 0)), FontSize = 8, FontWeight = FontWeights.Black });
            col.Children.Add(new TextBlock { Text = nxt.Name, Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.Bold });
            dock.Children.Add(col);
            var b = new Border { Child = dock, Background = Theme.Accent, CornerRadius = new CornerRadius(10), Padding = new Thickness(10, 8, 10, 8) };
            MakeClickable(b, () =>
            {
                _selectedGroup = engine.NextGroup; _search = ""; engine.AdvanceToNextGroup();
            });
            container.Children.Add(b);
        }
        else if (engine.IsChampionTerminal)
        {
            var tb = new TextBlock { Text = Strings.T(L.LeagueCompleted), Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center };
            var b = new Border { Child = tb, Background = Theme.Good, CornerRadius = new CornerRadius(10), Padding = new Thickness(10) };
            // "Liga concluída": em vez de sair pro menu (dead-end), volta pra SELEÇÃO da Elite 4
            // (lista de treinadores desta região) para rejogar — mesmo padrão do botão Reiniciar.
            MakeClickable(b, () => { _selectedGroup = null; _search = ""; engine.Reset(); });
            container.Children.Add(b);
        }

        ContentHost.Children.Add(container);
    }

    private Border FeedbackButton(string label, Brush fg, Brush bg, Action act)
    {
        var tb = new TextBlock { Text = label, Foreground = fg, FontSize = 11, FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center };
        var b = new Border { Child = tb, Background = bg, BorderBrush = fg, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(9), Padding = new Thickness(8) };
        MakeClickable(b, act);
        return b;
    }

    // Glossário do modo (colapsável) — espelha o "Glossário deste modo" do LegendView do Mac.
    private Border LegendCard(List<LegendEntry> legend)
    {
        var body = new StackPanel { Visibility = Visibility.Collapsed, Margin = new Thickness(10, 0, 10, 10) };
        foreach (var e in legend)
        {
            body.Children.Add(new TextBlock { Text = e.Term, Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.Bold, FontFamily = new FontFamily("Consolas") });
            body.Children.Add(new TextBlock { Text = e.Meaning, Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 6) });
        }

        var arrow = new TextBlock { Text = "▼", Foreground = Theme.TextDim, FontSize = 11, VerticalAlignment = VerticalAlignment.Center };
        var headDock = new DockPanel { LastChildFill = true, Margin = new Thickness(10, 8, 10, 8) };
        DockPanel.SetDock(arrow, Dock.Right);
        headDock.Children.Add(arrow);
        headDock.Children.Add(new TextBlock { Text = "📖 " + Strings.T(L.LegendGlossary), Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });

        var head = new Border { Child = headDock, Background = Brushes.Transparent };
        MakeClickable(head, () =>
        {
            bool open = body.Visibility == Visibility.Visible;
            body.Visibility = open ? Visibility.Collapsed : Visibility.Visible;
            arrow.Text = open ? "▼" : "▲";
        });

        var col = new StackPanel();
        col.Children.Add(head);
        col.Children.Add(body);

        return new Border
        {
            Child = col, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10), Margin = new Thickness(0, 0, 0, 8)
        };
    }

    // MARK: - Guia "Como ler o overlay" (#73)
    // O Mac mostra este guia dentro do painel de ajuda (LegendView) aberto pelo "?"; o app Windows
    // não tem esse painel (o glossário mora inline na home), então damos ao guia um overlay próprio
    // (HelpHost), no mesmo padrão dos overlays de Cooldowns / "Ver times", aberto pelo "?" do topo.

    /// Alterna o guia (o "?" do topo). Fechar também acontece pelo ✕ ou pelo botão "Entendi".
    private void ToggleHelp()
    {
        if (HelpHost.Visibility == Visibility.Visible) CloseHelp();
        else OpenHelp();
    }

    private void OpenHelp()
    {
        var close = new TextBlock
        {
            Text = "✕", Foreground = Theme.TextDim, FontSize = 14, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        };
        var closeB = new Border { Child = close, Padding = new Thickness(6, 2, 6, 2), Background = Brushes.Transparent };
        MakeClickable(closeB, CloseHelp);

        // Cabeçalho só com o ✕ (o título vem dentro do próprio card, igual ao Mac); arrastável (bug #56).
        var hdrDock = new DockPanel { LastChildFill = true, Margin = new Thickness(10, 8, 10, 8) };
        DockPanel.SetDock(closeB, Dock.Right);
        hdrDock.Children.Add(closeB);
        hdrDock.Children.Add(new Border { Background = Brushes.Transparent }); // ocupa a esquerda p/ arrastar
        hdrDock.MouseLeftButtonDown += OnHeaderDrag;

        var head = new StackPanel();
        head.Children.Add(hdrDock);
        head.Children.Add(Line());
        DockPanel.SetDock(head, Dock.Top);

        var body = new StackPanel { Margin = new Thickness(10) };
        body.Children.Add(HowToCard());

        var col = new DockPanel { LastChildFill = true };
        col.Children.Add(head);
        col.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = body });

        HelpHost.Content = new Border { Background = Theme.Bg, Child = col };
        HelpHost.Visibility = Visibility.Visible;
        BuildHeader(); // reflete o "?" ativo no topo
    }

    private void CloseHelp()
    {
        HelpHost.Visibility = Visibility.Collapsed;
        HelpHost.Content = null;
        BuildHeader(); // "?" volta ao estado normal
    }

    /// Card de onboarding "Como ler o overlay" — porte fiel do howToCard do LegendView do Mac.
    private Border HowToCard()
    {
        var col = new StackPanel();
        col.Children.Add(new TextBlock
        {
            Text = Strings.T(L.LegendHowToTitle), Foreground = Theme.Text, FontSize = 14, FontWeight = FontWeights.Bold,
            TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8)
        });

        col.Children.Add(HowToRow(Strings.T(L.LegendHowToArrow)));
        col.Children.Add(HowToRow(Strings.T(L.LegendHowToIcons)));
        col.Children.Add(HowToRow(Strings.T(L.LegendHowToChoose)));

        // Sub-card de aviso "Novo na Elite 4?": fundo um tom mais claro (PanelHi) + ⚠️ âmbar no ícone.
        var warnCol = new StackPanel();
        var warnHead = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 2) };
        warnHead.Children.Add(new TextBlock
        {
            Text = "⚠️", Foreground = Theme.Warning, FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 6, 0)
        });
        warnHead.Children.Add(new TextBlock
        {
            Text = Strings.T(L.LegendNewbieTitle), Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        });
        warnCol.Children.Add(warnHead);
        warnCol.Children.Add(new TextBlock
        {
            Text = Strings.T(L.LegendNewbieBody), Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap
        });
        col.Children.Add(new Border
        {
            Child = warnCol, Background = Theme.PanelHi, CornerRadius = new CornerRadius(8),
            Padding = new Thickness(8), Margin = new Thickness(0)
        });

        // Botão "Entendi" (capsule accent, texto preto, largura total) — fecha o guia, igual ao Mac.
        var gotItTb = new TextBlock
        {
            Text = Strings.T(L.LegendGotIt), Foreground = Brushes.Black, FontSize = 12, FontWeight = FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        var gotIt = new Border
        {
            Child = gotItTb, Background = Theme.Accent, CornerRadius = new CornerRadius(16),
            Padding = new Thickness(0, 7, 0, 7), Margin = new Thickness(0, 8, 0, 0), HorizontalAlignment = HorizontalAlignment.Stretch
        };
        MakeClickable(gotIt, CloseHelp);
        col.Children.Add(gotIt);

        return new Border
        {
            Child = col, Background = Theme.Panel, CornerRadius = new CornerRadius(11),
            Padding = new Thickness(10), Margin = new Thickness(0, 0, 0, 8)
        };
    }

    /// Uma linha do guia: "→" âmbar (mono, largura fixa) + texto que quebra, alinhados ao topo.
    private FrameworkElement HowToRow(string text)
    {
        var dock = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 0, 0, 8) };
        var arrow = new TextBlock
        {
            Text = "→", Foreground = Theme.Accent, FontFamily = new FontFamily("Consolas"),
            FontSize = 12, FontWeight = FontWeights.Bold, Width = 14, TextAlignment = TextAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 0, 8, 0)
        };
        DockPanel.SetDock(arrow, Dock.Left);
        dock.Children.Add(arrow);
        dock.Children.Add(new TextBlock
        {
            Text = text, Foreground = Theme.TextDim, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Top
        });
        return dock;
    }

    // MARK: - "Ver times" do oponente (overlay) — porte do TeamsOverlayView.swift

    /// Botão no topo da luta que abre o overlay com os times possíveis do oponente.
    private Border VerTimesButton(AppModel.PossibleOpponentTeams data)
    {
        var dock = new DockPanel { LastChildFill = true };

        var dot = new Border
        {
            Width = 8, Height = 8, CornerRadius = new CornerRadius(4),
            Background = data.Confirmed ? Theme.Good : Theme.Accent,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0)
        };
        DockPanel.SetDock(dot, Dock.Left);
        dock.Children.Add(dot);

        var chev = new TextBlock
        {
            Text = "›", Foreground = Theme.TextDim, FontSize = 16,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(6, 0, 0, 0)
        };
        DockPanel.SetDock(chev, Dock.Right);
        dock.Children.Add(chev);

        dock.Children.Add(new TextBlock
        {
            Text = data.Confirmed ? Strings.T(L.SeeTeamsConfirmed) : string.Format(Strings.T(L.SeeTeamsPossible), data.Teams.Count),
            Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis
        });

        var border = new Border
        {
            Child = dock,
            Background = data.Confirmed ? Theme.GoodSoft : Theme.AccentSoft,
            BorderBrush = data.Confirmed ? Theme.Good : Theme.Accent,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10, 8, 10, 8),
            Margin = new Thickness(0, 0, 0, 8)
        };
        MakeClickable(border, () => ShowTeamsOverlay(data));
        return border;
    }

    private void ShowTeamsOverlay(AppModel.PossibleOpponentTeams data)
    {
        var hdrDock = new DockPanel { LastChildFill = true, Margin = new Thickness(10, 8, 10, 8) };

        var close = new TextBlock
        {
            Text = "✕", Foreground = Theme.TextDim, FontSize = 14, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        };
        var closeB = new Border { Child = close, Padding = new Thickness(6, 2, 6, 2), Background = Brushes.Transparent };
        MakeClickable(closeB, HideTeamsOverlay);
        DockPanel.SetDock(closeB, Dock.Right);
        hdrDock.Children.Add(closeB);

        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock
        {
            Text = data.Confirmed ? Strings.T(L.TeamsConfirmedTitle) : string.Format(Strings.T(L.TeamsPossibleTitle), data.Teams.Count),
            Foreground = data.Confirmed ? Theme.Good : Theme.Accent, FontSize = 9, FontWeight = FontWeights.Black
        });
        col.Children.Add(new TextBlock
        {
            Text = $"{data.Trainer} · lead {data.Lead}",
            Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Bold,
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        hdrDock.Children.Add(col);

        var list = new StackPanel { Margin = new Thickness(10) };
        if (!data.Confirmed)
            list.Children.Add(new TextBlock
            {
                Text = Strings.T(L.TeamsDistinguishHint),
                Foreground = Theme.TextDim, FontSize = 10, TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 8)
            });
        foreach (var team in data.Teams) list.Children.Add(TeamCardUI(team));

        var head = new StackPanel();
        hdrDock.MouseLeftButtonDown += OnHeaderDrag; // overlay "Ver times" também precisa arrastar a janela (bug #56)
        head.Children.Add(hdrDock);
        head.Children.Add(Line());
        DockPanel.SetDock(head, Dock.Top);

        var dock = new DockPanel { LastChildFill = true };
        dock.Children.Add(head);
        dock.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = list });

        TeamsHost.Content = new Border { Background = Theme.Bg, Child = dock };
        TeamsHost.Visibility = Visibility.Visible;
    }

    private void HideTeamsOverlay()
    {
        TeamsHost.Visibility = Visibility.Collapsed;
        TeamsHost.Content = null;
    }

    private Border TeamCardUI(OpponentTeam team)
    {
        var col = new StackPanel();
        col.Children.Add(new TextBlock
        {
            Text = string.Format(Strings.T(L.TeamsTeamCardTitle), team.Team), Foreground = Theme.Choice,
            FontSize = 11, FontWeight = FontWeights.Black, Margin = new Thickness(0, 0, 0, 4)
        });
        foreach (var mon in team.Pokemon) col.Children.Add(MonRowUI(mon));

        return new Border
        {
            Child = col, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10), Padding = new Thickness(9), Margin = new Thickness(0, 0, 0, 8)
        };
    }

    private FrameworkElement MonRowUI(OpponentMon mon)
    {
        var dock = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 2, 0, 2) };
        if (SpriteIcon(mon.Pokemon, 26) is { } icon)
        {
            var iconHost = new Border { Child = icon, Width = 26, Height = 26, Margin = new Thickness(0, 0, 7, 0), VerticalAlignment = VerticalAlignment.Top };
            DockPanel.SetDock(iconHost, Dock.Left);
            dock.Children.Add(iconHost);
        }

        var col = new StackPanel();
        var line1 = new WrapPanel();
        line1.Children.Add(new TextBlock { Text = mon.Pokemon, Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 5, 0) });
        if (!string.IsNullOrEmpty(mon.Item))
            line1.Children.Add(new TextBlock { Text = mon.Item, Foreground = Theme.Accent, FontSize = 9, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        col.Children.Add(line1);

        if (!string.IsNullOrEmpty(mon.Ability))
            col.Children.Add(new TextBlock { Text = mon.Ability, Foreground = Theme.Good, FontSize = 9 });

        col.Children.Add(new TextBlock { Text = string.Join(" · ", mon.Moves), Foreground = Theme.TextDim, FontSize = 9, TextWrapping = TextWrapping.Wrap });

        dock.Children.Add(col);
        return dock;
    }

    private Border Pill(string text, Brush fg, Brush bg, Action act)
    {
        var tb = new TextBlock { Text = text, Foreground = fg, FontSize = 11, FontWeight = FontWeights.SemiBold };
        var b = new Border { Child = tb, Background = bg, CornerRadius = new CornerRadius(9), Padding = new Thickness(8, 3, 8, 3), VerticalAlignment = VerticalAlignment.Center };
        MakeClickable(b, act);
        return b;
    }

    /// Linha de topo da home: texto-guia à esquerda e o chip de idioma (PT⇄EN) à direita.
    /// Atalho rápido pra trocar de idioma sem entrar em Menu → Idioma (Backlog #13).
    private FrameworkElement LanguageChipRow(string prompt)
    {
        var dock = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 0, 0, 6) };
        // Direita: reloginho (Cooldowns/alarmes #33) + chip de idioma, lado a lado (igual ao Mac).
        var right = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        right.Children.Add(CooldownChip());
        var chip = LanguageChip();
        chip.Margin = new Thickness(6, 0, 0, 0);
        right.Children.Add(chip);
        DockPanel.SetDock(right, Dock.Right);
        dock.Children.Add(right);
        var cap = Caption(prompt);
        cap.Margin = new Thickness(2, 2, 8, 0);
        cap.VerticalAlignment = VerticalAlignment.Center;
        dock.Children.Add(cap);
        return dock;
    }

    /// Reloginho do sistema de Cooldown/Alarme (#33) — ao lado do chip de idioma; abre a tela de
    /// Cooldowns. Espelha o "clock.arrow.circlepath" do Mac (glifo History do Segoe MDL2).
    private FrameworkElement CooldownChip()
    {
        var tb = new TextBlock
        {
            Text = "", FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 13,
            Foreground = Theme.Text, HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var b = new Border
        {
            Child = tb, Background = Theme.Panel, CornerRadius = new CornerRadius(9),
            Padding = new Thickness(8, 4, 8, 4), VerticalAlignment = VerticalAlignment.Center,
            ToolTip = Strings.T(L.CdReloginhoHelp)
        };
        MakeClickable(b, OpenCooldowns);
        return b;
    }

    /// Chip PT⇄EN: mostra o idioma ATUAL e, ao tocar, alterna pro outro (re-render automático
    /// via AppModel.SetLanguage → Changed → Render). Mesmo caminho de troca do LanguageRow.
    private FrameworkElement LanguageChip()
    {
        bool pt = _model.Language == Lang.Pt;
        var target = pt ? Lang.En : Lang.Pt;
        var text = pt ? "\U0001F1E7\U0001F1F7 PT  ⇄  EN" : "\U0001F1FA\U0001F1F8 EN  ⇄  PT";
        var tb = new TextBlock { Text = text, Foreground = Theme.Text, FontSize = 11, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
        var b = new Border { Child = tb, Background = Theme.Panel, CornerRadius = new CornerRadius(9), Padding = new Thickness(9, 4, 9, 4), VerticalAlignment = VerticalAlignment.Center, ToolTip = Strings.T(L.Language) };
        MakeClickable(b, () => { _openCategory = null; _selectedGroup = null; _search = ""; _model.SetLanguage(target); });
        return b;
    }

    private Border Glyph(string glyph, string tip, Action act, bool active = false, bool symbol = false, bool filled = false)
    {
        // `filled` (#46): dá cor de destaque + fundo/borda de CHIP pro controle de fonte não passar batido.
        var tb = new TextBlock
        {
            Text = glyph, FontSize = symbol ? 12 : 14,
            Foreground = (active || filled) ? Theme.Accent : Theme.TextDim,
            FontWeight = filled ? FontWeights.Bold : FontWeights.Normal,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
        if (symbol) tb.FontFamily = new FontFamily("Segoe MDL2 Assets");
        var b = new Border
        {
            Child = tb, Width = filled ? 26 : 22, Height = 20,
            Background = filled ? Theme.Panel : Brushes.Transparent,
            BorderBrush = filled ? Theme.Border : null,
            BorderThickness = new Thickness(filled ? 1 : 0),
            CornerRadius = new CornerRadius(5), ToolTip = tip, Margin = new Thickness(1, 0, 1, 0)
        };
        MakeClickable(b, act);
        return b;
    }

    private Border SmallButton(string text, bool enabled, Action act)
    {
        var tb = new TextBlock { Text = text, Foreground = enabled ? Theme.Text : Theme.TextDim, FontSize = 11, FontWeight = FontWeights.Medium, Opacity = enabled ? 1 : 0.4 };
        var b = new Border { Child = tb, Background = Theme.Panel, CornerRadius = new CornerRadius(12), Padding = new Thickness(9, 5, 9, 5), Margin = new Thickness(0, 0, 6, 0) };
        if (enabled) MakeClickable(b, act);
        return b;
    }

    private static TextBlock Chevron() => new() { Text = "›", Foreground = Theme.TextDim, FontSize = 14, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(6, 0, 0, 0) };

    private static Border Line() => new() { Height = 1, Background = Theme.Border };

    private void MakeClickable(FrameworkElement el, Action act)
    {
        el.Cursor = Cursors.Hand;
        el.MouseLeftButtonDown += (_, e) => e.Handled = true;
        el.MouseLeftButtonUp += (_, e) => { e.Handled = true; act(); };
    }


    // MARK: - Imagens (sprites / retratos / mapas)

    private FrameworkElement? SpriteIcon(string name, double size)
    {
        var path = Path.Combine(SolveLoader.DataDir, "sprites", Normalize(name) + ".png");
        var img = LoadImage(path);
        if (img == null) return null;
        var el = new Image { Source = img, Width = size, Height = size, Stretch = Stretch.Uniform, SnapsToDevicePixels = true };
        RenderOptions.SetBitmapScalingMode(el, BitmapScalingMode.NearestNeighbor);
        return el;
    }

    // Master Ball ("money ball", ícone do app) — placeholder onde a rota/opção não tem Pokémon.
    private static BitmapImage? _ballImg;
    private static FrameworkElement BallIcon(double size)
    {
        _ballImg ??= new BitmapImage(new Uri("pack://application:,,,/Assets/masterball.png"));
        return new Image { Source = _ballImg, Width = size, Height = size, Stretch = Stretch.Uniform };
    }

    // Sprite do Pokémon do rótulo; se não houver, cai na Master Ball. Só onde pode faltar Pokémon.
    private FrameworkElement MonOrBallIcon(string name, double size) => SpriteIcon(name, size) ?? BallIcon(size);

    private FrameworkElement? TrainerIcon(string name, double size)
    {
        var path = Path.Combine(SolveLoader.DataDir, "trainers", name.ToLowerInvariant() + ".png");
        var img = LoadImage(path);
        return img == null ? null : new Image { Source = img, Width = size, Height = size, Stretch = Stretch.Uniform };
    }

    private FrameworkElement? RegionIcon(string name, double size)
    {
        var path = Path.Combine(SolveLoader.DataDir, "regions", name.ToLowerInvariant() + ".png");
        var img = LoadImage(path);
        return img == null ? null : new Image { Source = img, Width = size, Height = size, Stretch = Stretch.Uniform };
    }

    // Os 3 Pokémon iniciais de cada região (usados como ícone no lugar do mapa).
    private static readonly Dictionary<string, string[]> RegionStarters = new()
    {
        ["kanto"]  = new[] { "bulbasaur", "charmander", "squirtle" },
        ["johto"]  = new[] { "chikorita", "cyndaquil", "totodile" },
        ["hoenn"]  = new[] { "treecko", "torchic", "mudkip" },
        ["sinnoh"] = new[] { "turtwig", "chimchar", "piplup" },
        ["unova"]  = new[] { "snivy", "tepig", "oshawott" },
    };

    /// Ícone da região como os 3 iniciais sobrepostos (cabe num quadrado `size`).
    /// Cai de volta no mapa se a região não tiver iniciais mapeados.
    // Os 3 iniciais são desenhados sobrepostos; o do MEIO (fogo) é pintado por ÚLTIMO (ordem 0,2,1)
    // pra não ficar escondido atrás do 3º — corrige o "fogo some" (Backlog #8). Espelha o Android.
    private FrameworkElement? StartersIcon(string region, double size)
    {
        if (!RegionStarters.TryGetValue(region.ToLowerInvariant(), out var names))
            return RegionIcon(region, size);

        double sprite = size * 0.72;            // tamanho de cada sprite (preenche bem o quadrado)
        double step = (size - sprite) / 2;      // deslocamento p/ os 3 caberem na largura
        double top = (size - sprite) / 2;
        var canvas = new Canvas { Width = size, Height = size };
        foreach (int i in new[] { 0, 2, 1 })   // meio (fogo) por último → fica por cima
        {
            var img = LoadImage(Path.Combine(SolveLoader.DataDir, "sprites", names[i] + ".png"));
            if (img == null) continue;
            var el = new Image { Source = img, Width = sprite, Height = sprite, Stretch = Stretch.Uniform, SnapsToDevicePixels = true };
            RenderOptions.SetBitmapScalingMode(el, BitmapScalingMode.NearestNeighbor);
            Canvas.SetLeft(el, i * step);
            Canvas.SetTop(el, top);
            canvas.Children.Add(el);
        }
        return canvas;
    }

    private FrameworkElement? ItemIcon(string name, double size)
    {
        var path = Path.Combine(SolveLoader.DataDir, "items", name.ToLowerInvariant() + ".png");
        var img = LoadImage(path);
        return img == null ? null : new Image { Source = img, Width = size, Height = size, Stretch = Stretch.Uniform };
    }

    private static string Normalize(string name)
        => new(name.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());

    private static BitmapImage? LoadImage(string path)
    {
        if (ImgCache.TryGetValue(path, out var cached)) return cached;
        BitmapImage? img = null;
        try
        {
            if (File.Exists(path))
            {
                img = new BitmapImage();
                img.BeginInit();
                img.CacheOption = BitmapCacheOption.OnLoad;
                img.UriSource = new Uri(path);
                img.EndInit();
                img.Freeze();
            }
        }
        catch { img = null; }
        ImgCache[path] = img;
        return img;
    }
}
