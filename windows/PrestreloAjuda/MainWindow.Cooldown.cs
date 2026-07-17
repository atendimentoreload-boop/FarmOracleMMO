using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;
using Microsoft.Win32;
using PrestreloAjuda.Interop;
using PrestreloAjuda.Services;
using BattlePhase = PrestreloAjuda.Services.CooldownStore.BattlePhase;
using BerryPhase = PrestreloAjuda.Services.CooldownStore.BerryPhase;
using BerryStatus = PrestreloAjuda.Services.CooldownStore.BerryStatus;

namespace PrestreloAjuda;

/// Tela do sistema de Cooldown/Alarme (#33) — porte de CooldownView.swift do Mac.
/// Overlay próprio (CooldownHost) por cima de tudo, aberto pelo "reloginho" ao lado do chip de idioma.
/// Lista principal = os BONECOS (cadastro). Ao abrir um boneco: abas Batalhas / Berries.
public partial class MainWindow
{
    // Store carregado no construtor (ver MainWindow.xaml.cs); reconcilia os alarmes no init.
    private CooldownStore _cooldowns = null!;

    // Ticker de 1s que re-renderiza os cronômetros enquanto a tela está aberta.
    private DispatcherTimer? _cdTicker;

    // Estado de navegação da tela.
    private enum CdTab { Battles, Berries }
    private string? _cdSelectedCharId;
    private CdTab _cdTab = CdTab.Battles;
    private bool _cdShowElite4;
    private bool _cdShowOptional;
    private bool _cdShowBerryPicker;
    private string? _cdEditingCharId;
    private string _cdNewCharName = "";
    private TextBox? _cdNameBox;   // referência p/ o ticker não roubar o foco enquanto digita

    // MARK: - Abrir / fechar / ticker

    private void OpenCooldowns()
    {
        _cdSelectedCharId = null;
        _cdTab = CdTab.Battles;
        _cdShowElite4 = false;
        _cdShowOptional = false;
        _cdShowBerryPicker = false;
        _cdEditingCharId = null;
        _cdNewCharName = "";
        CooldownHost.Visibility = Visibility.Visible;
        RenderCooldowns();
        StartCdTicker();
    }

    private void CloseCooldowns()
    {
        _cdTicker?.Stop();
        CooldownHost.Visibility = Visibility.Collapsed;
        CooldownHost.Content = null;
        Native.SetNoActivate(this, true);
    }

    private void StartCdTicker()
    {
        if (_cdTicker == null)
        {
            _cdTicker = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _cdTicker.Tick += (_, _) => CdTick();
        }
        _cdTicker.Start();
    }

    private void CdTick()
    {
        if (CooldownHost.Visibility != Visibility.Visible) { _cdTicker?.Stop(); return; }
        // Não re-renderiza enquanto o usuário digita um nome (senão o campo perde o foco a cada 1s).
        if (_cdNameBox != null && _cdNameBox.IsKeyboardFocusWithin) return;
        RenderCooldowns();
    }

    private GameCharacter? SelectedCdChar() => _cdSelectedCharId == null
        ? null
        : _cooldowns.State.Characters.FirstOrDefault(c => c.Id == _cdSelectedCharId);

    // MARK: - Render raiz

    private void RenderCooldowns()
    {
        _cdNameBox = null;
        if (_cdShowBerryPicker) { RenderBerryPicker(); return; }

        var content = new StackPanel { Margin = new Thickness(12) };
        var ch = SelectedCdChar();
        if (ch != null) BuildCharacterDetail(content, ch);
        else BuildCharacterList(content);

        var col = new DockPanel { LastChildFill = true };
        var header = CdHeader();
        DockPanel.SetDock(header, Dock.Top);
        col.Children.Add(header);
        col.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = content });

        CooldownHost.Content = new Border { Background = Theme.Bg, Child = col };
    }

    private FrameworkElement CdHeader()
    {
        var dock = new DockPanel { LastChildFill = true, Margin = new Thickness(10, 8, 10, 8) };

        var backText = _cdSelectedCharId != null ? Strings.T(L.CdCharacters) : Strings.T(L.Back);
        var back = new TextBlock
        {
            Text = "‹ " + backText, Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center
        };
        MakeClickable(back, () =>
        {
            if (_cdSelectedCharId != null) { _cdSelectedCharId = null; _cdEditingCharId = null; RenderCooldowns(); }
            else CloseCooldowns();
        });
        DockPanel.SetDock(back, Dock.Left);
        dock.Children.Add(back);

        var sel = SelectedCdChar();
        dock.Children.Add(new TextBlock
        {
            Text = (sel?.Name ?? Strings.T(L.CdTitle)).ToUpperInvariant(), Foreground = Theme.Text,
            FontSize = 12, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis
        });

        var stack = new StackPanel();
        // Janela é WindowStyle=None: arrastar a janela só existe via OnHeaderDrag no header.
        // O overlay de Cooldowns desenha o próprio header, então precisa religar o handler (bug #56).
        var header = new Border { Child = dock };
        header.MouseLeftButtonDown += OnHeaderDrag;
        stack.Children.Add(header);
        stack.Children.Add(Line());
        return stack;
    }

    // MARK: - Lista de personagens (cadastro)

    private void BuildCharacterList(StackPanel host)
    {
        host.Children.Add(CdSectionLabel(Strings.T(L.CdCharacters)));

        var chars = _cooldowns.State.Characters;
        if (chars.Count == 0)
        {
            host.Children.Add(new TextBlock
            {
                Text = Strings.T(L.CdNoCharacters), Foreground = Theme.TextDim, FontSize = 12,
                TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 22, 0, 22)
            });
        }
        else
        {
            var group = new StackPanel();
            for (int i = 0; i < chars.Count; i++)
            {
                if (i > 0) group.Children.Add(CdRowDivider());
                group.Children.Add(CharacterRow(chars[i]));
            }
            host.Children.Add(CdGroup(group));
        }

        host.Children.Add(AddCharacterRow());
    }

    private FrameworkElement CharacterRow(GameCharacter ch)
    {
        if (_cdEditingCharId == ch.Id) return CharacterEditRow(ch);

        var dock = new DockPanel { LastChildFill = true };

        var right = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        right.Children.Add(CdIconMini("", () => { _cdEditingCharId = ch.Id; RenderCooldowns(); }));   // Edit
        right.Children.Add(CdIconMini("", () => ConfirmRemoveCharacter(ch)));                          // Delete
        right.Children.Add(new TextBlock
        {
            Text = "›", Foreground = Theme.TextDim, FontSize = 14, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(2, 0, 0, 0)
        });
        DockPanel.SetDock(right, Dock.Right);
        dock.Children.Add(right);

        var left = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        left.Children.Add(CharAvatar(ch, 30));
        left.Children.Add(new TextBlock
        {
            Text = ch.Name, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(9, 0, 0, 0),
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        var summary = CharSummary(ch);
        if (!string.IsNullOrEmpty(summary))
            left.Children.Add(new TextBlock
            {
                Text = summary, Foreground = Theme.TextDim, FontSize = 9,
                VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(6, 0, 0, 0)
            });
        dock.Children.Add(left);

        var row = new Border { Child = dock, Background = Brushes.Transparent, Padding = new Thickness(12, 9, 12, 9) };
        MakeClickable(row, () => { _cdSelectedCharId = ch.Id; _cdTab = CdTab.Battles; RenderCooldowns(); });
        return row;
    }

    /// Ex.: "2 ativo(s)" — quantas tarefas desse boneco estão em cooldown/plantadas.
    private string CharSummary(GameCharacter ch)
    {
        int active = _cooldowns.ShownBattle(ch).Count(t => _cooldowns.IsBattleActive(ch, t));
        int planted = _cooldowns.ShownBerries.Count(b => _cooldowns.BerryStat(ch, b).Phase != BerryPhase.Empty);
        int n = active + planted;
        return n == 0 ? "" : string.Format(Strings.T(L.CdActiveCount), n);
    }

    private FrameworkElement AddCharacterRow()
    {
        var box = new TextBox
        {
            Text = _cdNewCharName, BorderThickness = new Thickness(0), Background = Brushes.Transparent,
            Foreground = Theme.Text, CaretBrush = Theme.Text, FontSize = 13,
            VerticalContentAlignment = VerticalAlignment.Center
        };
        _cdNameBox = box;
        var ph = new TextBlock
        {
            Text = Strings.T(L.CdCharacterName), Foreground = Theme.TextDim, FontSize = 13, IsHitTestVisible = false,
            VerticalAlignment = VerticalAlignment.Center,
            Visibility = string.IsNullOrEmpty(_cdNewCharName) ? Visibility.Visible : Visibility.Collapsed
        };
        box.TextChanged += (_, _) =>
        {
            _cdNewCharName = box.Text;
            ph.Visibility = string.IsNullOrEmpty(box.Text) ? Visibility.Visible : Visibility.Collapsed;
        };
        box.PreviewMouseLeftButtonDown += (_, _) => FocusSearch(box);
        box.LostKeyboardFocus += (_, _) => Native.SetNoActivate(this, true);
        box.KeyDown += (_, e) => { if (e.Key == Key.Enter) { e.Handled = true; DoAddCharacter(); } };

        var field = new Grid();
        field.Children.Add(ph);
        field.Children.Add(box);
        var fieldBorder = new Border
        {
            Child = field, Background = new SolidColorBrush(Color.FromArgb(0x47, 0, 0, 0)),
            BorderBrush = Theme.Border, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(10),
            Padding = new Thickness(11, 9, 11, 9)
        };

        var addBtn = new Border
        {
            Child = new TextBlock { Text = Strings.T(L.CdAdd), Foreground = Brushes.Black, FontSize = 13, FontWeight = FontWeights.SemiBold },
            Background = Theme.Good, CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 9, 12, 9),
            Margin = new Thickness(8, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center
        };
        MakeClickable(addBtn, DoAddCharacter);

        var dock = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 8, 0, 0) };
        DockPanel.SetDock(addBtn, Dock.Right);
        dock.Children.Add(addBtn);
        dock.Children.Add(fieldBorder);
        return dock;
    }

    private void DoAddCharacter()
    {
        _cooldowns.AddCharacter(_cdNewCharName);
        _cdNewCharName = "";
        Native.SetNoActivate(this, true);
        RenderCooldowns();
    }

    /// Edição inline do boneco: renomear + escolher/trocar/remover foto (substitui o NSAlert do Mac).
    private FrameworkElement CharacterEditRow(GameCharacter ch)
    {
        var col = new StackPanel { Margin = new Thickness(4, 6, 4, 6) };
        col.Children.Add(new TextBlock
        {
            Text = Strings.T(L.CdRenameTitle), Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 4)
        });

        var box = new TextBox
        {
            Text = ch.Name, BorderThickness = new Thickness(0), Background = Brushes.Transparent,
            Foreground = Theme.Text, CaretBrush = Theme.Text, FontSize = 13,
            VerticalContentAlignment = VerticalAlignment.Center
        };
        _cdNameBox = box;
        box.PreviewMouseLeftButtonDown += (_, _) => FocusSearch(box);
        box.LostKeyboardFocus += (_, _) => Native.SetNoActivate(this, true);
        void Save()
        {
            _cooldowns.RenameCharacter(ch.Id, box.Text);
            _cdEditingCharId = null;
            Native.SetNoActivate(this, true);
            RenderCooldowns();
        }
        box.KeyDown += (_, e) => { if (e.Key == Key.Enter) { e.Handled = true; Save(); } };
        col.Children.Add(new Border
        {
            Child = box, Background = new SolidColorBrush(Color.FromArgb(0x47, 0, 0, 0)), BorderBrush = Theme.Border,
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(10), Padding = new Thickness(11, 9, 11, 9)
        });

        col.Children.Add(new TextBlock
        {
            Text = Strings.T(L.CdPhotoHint), Foreground = Theme.TextDim, FontSize = 9,
            Margin = new Thickness(2, 4, 0, 6), TextWrapping = TextWrapping.Wrap
        });

        bool hasPhoto = ch.Avatar != null;
        var btns = new StackPanel { Orientation = Orientation.Horizontal };
        btns.Children.Add(PillButton("OK", Theme.Good, Save));
        btns.Children.Add(PillButton(hasPhoto ? Strings.T(L.CdChangePhoto) : Strings.T(L.CdChoosePhoto),
            Theme.Choice, () => PickAvatar(ch)));
        if (hasPhoto)
            btns.Children.Add(PillButton(Strings.T(L.CdRemovePhoto), Theme.Danger,
                () => { _cooldowns.SetAvatar(ch.Id, null); RenderCooldowns(); }));
        var cancel = new TextBlock
        {
            Text = Strings.T(L.Cancel), Foreground = Theme.TextDim, FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(4, 0, 0, 0)
        };
        MakeClickable(cancel, () => { _cdEditingCharId = null; RenderCooldowns(); });
        btns.Children.Add(cancel);
        col.Children.Add(btns);

        return new Border
        {
            Child = col, Background = new SolidColorBrush(Color.FromArgb(0x22, 0xFF, 0xFF, 0xFF)),
            CornerRadius = new CornerRadius(10), Padding = new Thickness(8, 6, 8, 6)
        };
    }

    private void ConfirmRemoveCharacter(GameCharacter ch)
    {
        var res = MessageBox.Show(string.Format(Strings.T(L.CdRemoveConfirm), ch.Name),
            Strings.T(L.CdRemove), MessageBoxButton.OKCancel, MessageBoxImage.Warning);
        if (res != MessageBoxResult.OK) return;
        if (_cdSelectedCharId == ch.Id) _cdSelectedCharId = null;
        _cdEditingCharId = null;
        _cooldowns.RemoveCharacter(ch.Id);
        RenderCooldowns();
    }

    // MARK: - Detalhe do boneco (abas)

    private void BuildCharacterDetail(StackPanel host, GameCharacter ch)
    {
        var tabRow = new Grid { Margin = new Thickness(0, 0, 0, 10) };
        tabRow.ColumnDefinitions.Add(new ColumnDefinition());
        tabRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(6) });
        tabRow.ColumnDefinitions.Add(new ColumnDefinition());
        var battlesBtn = CdTabButton(Strings.T(L.CdBattles), CdTab.Battles);
        var berriesBtn = CdTabButton(Strings.T(L.CdBerries), CdTab.Berries);
        Grid.SetColumn(battlesBtn, 0);
        Grid.SetColumn(berriesBtn, 2);
        tabRow.Children.Add(battlesBtn);
        tabRow.Children.Add(berriesBtn);
        host.Children.Add(tabRow);

        if (_cdTab == CdTab.Battles) BuildBattles(host, ch);
        else BuildBerries(host, ch);
    }

    private FrameworkElement CdTabButton(string title, CdTab tab)
    {
        bool on = _cdTab == tab;
        var b = new Border
        {
            Child = new TextBlock
            {
                Text = title, Foreground = on ? Brushes.Black : Theme.TextDim, FontSize = 12,
                FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center
            },
            Background = on ? Theme.Accent : Theme.Panel, CornerRadius = new CornerRadius(9),
            Padding = new Thickness(0, 7, 0, 7)
        };
        MakeClickable(b, () => { _cdTab = tab; RenderCooldowns(); });
        return b;
    }

    // MARK: - Batalhas

    private void BuildBattles(StackPanel host, GameCharacter ch)
    {
        var all = _cooldowns.ShownBattle(ch);
        var elite = all.Where(t => t.Group == "elite4").ToList();
        var others = all.Where(t => t.Group != "elite4").ToList();

        if (elite.Count > 0) BuildElite4Group(host, ch, elite);

        if (others.Count > 0)
        {
            var group = new StackPanel();
            for (int i = 0; i < others.Count; i++)
            {
                if (i > 0) group.Children.Add(CdRowDivider());
                group.Children.Add(BattleRow(ch, others[i], false));
            }
            host.Children.Add(CdGroup(group));
        }

        // Opcionais (recolhido)
        var optHead = new StackPanel { Orientation = Orientation.Horizontal };
        optHead.Children.Add(new TextBlock
        {
            Text = _cdShowOptional ? "▼" : "▶", Foreground = Theme.TextDim, FontSize = 10,
            FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 6, 0)
        });
        optHead.Children.Add(new TextBlock
        {
            Text = Strings.T(L.CdOptional).ToUpperInvariant(), Foreground = Theme.Accent, FontSize = 9,
            FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center
        });
        var optBorder = new Border { Child = optHead, Background = Brushes.Transparent, Padding = new Thickness(4, 8, 4, 4) };
        MakeClickable(optBorder, () => { _cdShowOptional = !_cdShowOptional; RenderCooldowns(); });
        host.Children.Add(optBorder);

        if (_cdShowOptional)
        {
            var opt = _cooldowns.Catalog.OptionalTasks;
            var group = new StackPanel();
            for (int i = 0; i < opt.Count; i++)
            {
                if (i > 0) group.Children.Add(CdRowDivider());
                group.Children.Add(BattleRow(ch, opt[i], false));
            }
            host.Children.Add(CdGroup(group));
        }
    }

    /// Submenu Elite 4: cabeçalho que expande as 5 regiões (group == "elite4").
    private void BuildElite4Group(StackPanel host, GameCharacter ch, List<BattleTask> tasks)
    {
        int active = tasks.Count(t => _cooldowns.IsBattleActive(ch, t));
        var group = new StackPanel();

        var hdock = new DockPanel { LastChildFill = true };
        if (ItemIcon("trophy", 28) is { } trophy)
        {
            trophy.HorizontalAlignment = HorizontalAlignment.Center;
            trophy.VerticalAlignment = VerticalAlignment.Center;
            var ih = new Border { Child = trophy, Width = 28, Height = 28, Margin = new Thickness(0, 0, 11, 0), VerticalAlignment = VerticalAlignment.Center };
            DockPanel.SetDock(ih, Dock.Left);
            hdock.Children.Add(ih);
        }
        var chev = new TextBlock
        {
            Text = _cdShowElite4 ? "▼" : "▶", Foreground = Theme.TextDim, FontSize = 12, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center
        };
        DockPanel.SetDock(chev, Dock.Right);
        hdock.Children.Add(chev);
        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(new TextBlock { Text = Strings.T(L.CdElite4), Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.Bold });
        string sub = active > 0
            ? string.Format(Strings.T(L.CdActiveCount), active)
            : $"{tasks.Count} " + (_model.Language == Lang.En ? "regions" : "regiões");
        col.Children.Add(new TextBlock { Text = sub, Foreground = Theme.TextDim, FontSize = 10 });
        hdock.Children.Add(col);

        var hb = new Border { Child = hdock, Background = Brushes.Transparent, Padding = new Thickness(12, 10, 12, 10) };
        MakeClickable(hb, () => { _cdShowElite4 = !_cdShowElite4; RenderCooldowns(); });
        group.Children.Add(hb);

        if (_cdShowElite4)
            foreach (var t in tasks)
            {
                group.Children.Add(CdRowDivider());
                group.Children.Add(BattleRow(ch, t, true));
            }

        host.Children.Add(CdGroup(group));
    }

    private FrameworkElement BattleRow(GameCharacter ch, BattleTask task, bool isChild)
    {
        var phase = _cooldowns.Phase(ch, task);
        double remain = _cooldowns.BattleRemainingMs(ch, task);
        double size = isChild ? 26 : 30;

        var dock = new DockPanel { LastChildFill = true };

        FrameworkElement rightEl = phase == BattlePhase.Running
            ? ResetButton(() => { _cooldowns.ClearBattle(ch, task); RenderCooldowns(); })
            : PlayIcon(phase == BattlePhase.Ready);
        rightEl.VerticalAlignment = VerticalAlignment.Center;
        DockPanel.SetDock(rightEl, Dock.Right);
        dock.Children.Add(rightEl);

        var iconEl = CdTaskIcon(task.Icon, task.Color, size);
        var iconHost = new Border { Child = iconEl, Width = size, Height = size, Margin = new Thickness(0, 0, 11, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(iconHost, Dock.Left);
        dock.Children.Add(iconHost);

        var col = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 6, 0) };
        col.Children.Add(new TextBlock
        {
            Text = isChild ? ShortLabel(task) : task.Name.Localized, Foreground = Theme.Text, FontSize = 13,
            FontWeight = FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis
        });
        switch (phase)
        {
            case BattlePhase.Running:
                col.Children.Add(ChronoChip("⏳", "", Cd.FmtRemain(remain), Theme.Accent, false));
                break;
            case BattlePhase.Ready:
                col.Children.Add(new TextBlock { Text = Strings.T(L.CdDoNow), Foreground = Theme.Good, FontSize = 11, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 4, 0, 0) });
                break;
            default: // Idle
                col.Children.Add(new TextBlock
                {
                    Text = Strings.T(L.CdTapToStart) + " · " + Cd.FmtHoursLabel(task.Hours),
                    Foreground = Theme.TextDim, FontSize = 10, TextTrimming = TextTrimming.CharacterEllipsis,
                    Margin = new Thickness(0, 4, 0, 0)
                });
                break;
        }
        dock.Children.Add(col);

        var row = new Border
        {
            Child = dock, Background = phase == BattlePhase.Ready ? Theme.GoodSoft : Brushes.Transparent,
            Padding = new Thickness(12, 9, 12, 9)
        };
        if (phase != BattlePhase.Running)
            MakeClickable(row, () => { _cooldowns.MarkBattle(ch, task); RenderCooldowns(); });
        return row;
    }

    /// "Elite 4 — Kanto" -> "Kanto" quando a tarefa está sob o submenu.
    private static string ShortLabel(BattleTask task)
    {
        var full = task.Name.Localized;
        int idx = full.IndexOf('—');
        return idx >= 0 ? full.Substring(idx + 1).Trim() : full;
    }

    // MARK: - Berries

    private void BuildBerries(StackPanel host, GameCharacter ch)
    {
        var berries = _cooldowns.ShownBerries;
        var group = new StackPanel();
        for (int i = 0; i < berries.Count; i++)
        {
            if (i > 0) group.Children.Add(CdRowDivider());
            group.Children.Add(BerryRow(ch, berries[i]));
        }
        host.Children.Add(CdGroup(group));

        var add = new StackPanel { Orientation = Orientation.Horizontal };
        add.Children.Add(new TextBlock { Text = "＋", Foreground = Theme.Accent, FontSize = 13, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 6, 0) });
        add.Children.Add(new TextBlock { Text = Strings.T(L.CdAddBerry), Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        var addBorder = new Border { Child = add, Background = Brushes.Transparent, Padding = new Thickness(4, 8, 4, 4) };
        MakeClickable(addBorder, () => { _cdShowBerryPicker = true; RenderCooldowns(); });
        host.Children.Add(addBorder);
    }

    private FrameworkElement BerryRow(GameCharacter ch, BerryDef berry)
    {
        var st = _cooldowns.BerryStat(ch, berry);

        var dock = new DockPanel { LastChildFill = true };

        var iconEl = BerryIcon(berry.Id, 30);
        if (st.Phase == BerryPhase.Empty) iconEl.Opacity = 0.65;
        var iconHost = new Border { Child = iconEl, Width = 30, Height = 30, Margin = new Thickness(0, 1, 11, 0), VerticalAlignment = VerticalAlignment.Top };
        DockPanel.SetDock(iconHost, Dock.Left);
        dock.Children.Add(iconHost);

        var col = new StackPanel();
        var line = new DockPanel { LastChildFill = true };
        var actions = BerryActions(ch, berry, st);
        DockPanel.SetDock(actions, Dock.Right);
        line.Children.Add(actions);
        line.Children.Add(new TextBlock
        {
            Text = berry.Name.Localized, Foreground = Theme.Text, FontSize = 13, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis
        });
        col.Children.Add(line);
        BerryLines(col, berry, st);
        dock.Children.Add(col);

        return new Border { Child = dock, Background = BerryHighlight(st.Phase), Padding = new Thickness(12, 9, 12, 9) };
    }

    /// Os cronômetros de uma berry: colheita (🌾) e próxima rega (💧), enquanto cresce.
    private void BerryLines(StackPanel col, BerryDef berry, BerryStatus st)
    {
        switch (st.Phase)
        {
            case BerryPhase.Empty:
                var tier = _cooldowns.Catalog.FindTier(berry.Tier);
                col.Children.Add(new TextBlock
                {
                    Text = tier != null
                        ? "⏱ " + Cd.FmtHoursLabel(tier.GrowthHours) + " · 💧 " + tier.WaterWindowsHours.Count + "×"
                        : Strings.T(L.CdEmpty),
                    Foreground = Theme.TextDim, FontSize = 10, Margin = new Thickness(0, 4, 0, 0)
                });
                break;
            case BerryPhase.Growing:
                col.Children.Add(ChronoChip("🌾", Strings.T(L.CdHarvestShort), Cd.FmtRemain(st.HarvestRemainMs), Theme.Good, false));
                string prog = $" ({st.Waterings}/{st.TotalWaters})";
                if (st.WaterPending)
                    col.Children.Add(ChronoChip("💧", "", Strings.T(L.CdWaterNow).ToUpperInvariant() + prog, Theme.Choice, true));
                else if (st.NextWaterRemainMs is double w)
                    col.Children.Add(ChronoChip("💧", Strings.T(L.CdNextWater), Cd.FmtRemain(Math.Max(0, w)) + prog, Theme.Choice, false));
                else if (st.TotalWaters > 0)
                    col.Children.Add(ChronoChip("💧", Strings.T(L.CdNextWater), Strings.T(L.CdAllWatered) + " ✓", Theme.TextDim, false));
                break;
            case BerryPhase.Ready:
                col.Children.Add(ChronoChip("✅", Strings.T(L.CdHarvestShort), Strings.T(L.CdReadyLabel).ToUpperInvariant(), Theme.Good, true));
                break;
            case BerryPhase.Wilted:
                col.Children.Add(ChronoChip("⚠", Strings.T(L.CdHarvestShort), Strings.T(L.CdWilted).ToUpperInvariant(), Theme.Warning, true));
                break;
        }
    }

    private FrameworkElement BerryActions(GameCharacter ch, BerryDef berry, BerryStatus st)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        switch (st.Phase)
        {
            case BerryPhase.Empty:
                sp.Children.Add(PillButton(Strings.T(L.CdPlant), Theme.Good, () => { _cooldowns.PlantBerry(ch, berry); RenderCooldowns(); }));
                sp.Children.Add(CdIconMini("", () => { _cooldowns.RemoveBerry(ch, berry.Id); RenderCooldowns(); }));
                break;
            case BerryPhase.Growing:
                if (st.WaterPending)
                    sp.Children.Add(PillButton(Strings.T(L.CdWatered), Theme.Choice, () => { _cooldowns.WaterBerry(ch, berry); RenderCooldowns(); }));
                sp.Children.Add(ResetIconMini(() => { _cooldowns.HarvestBerry(ch, berry); RenderCooldowns(); }));
                break;
            default: // Ready / Wilted
                sp.Children.Add(PillButton(Strings.T(L.CdHarvest), Theme.Good, () => { _cooldowns.HarvestBerry(ch, berry); RenderCooldowns(); }));
                break;
        }
        return sp;
    }

    private static Brush BerryHighlight(BerryPhase phase) => phase switch
    {
        BerryPhase.Ready => Theme.GoodSoft,
        BerryPhase.Wilted => Theme.WarningSoft,
        _ => Brushes.Transparent,
    };

    // MARK: - Seletor de berry (biblioteca), agrupado por tier

    private void RenderBerryPicker()
    {
        var hdr = new DockPanel { LastChildFill = true, Margin = new Thickness(10, 8, 10, 8) };
        var back = new TextBlock { Text = "‹ " + Strings.T(L.Back), Foreground = Theme.Accent, FontSize = 12, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
        MakeClickable(back, () => { _cdShowBerryPicker = false; RenderCooldowns(); });
        DockPanel.SetDock(back, Dock.Left);
        hdr.Children.Add(back);
        hdr.Children.Add(new TextBlock
        {
            Text = Strings.T(L.CdAddBerry).ToUpperInvariant(), Foreground = Theme.Text, FontSize = 12,
            FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        });
        var head = new StackPanel();
        var hdrBorder = new Border { Child = hdr };
        hdrBorder.MouseLeftButtonDown += OnHeaderDrag; // arrastar a janela no seletor de berry (bug #56)
        head.Children.Add(hdrBorder);
        head.Children.Add(Line());

        var content = new StackPanel { Margin = new Thickness(12) };
        var shownIds = new HashSet<string>(_cooldowns.ShownBerries.Select(b => b.Id));
        var available = _cooldowns.Catalog.Berries.Where(b => !shownIds.Contains(b.Id)).ToList();
        foreach (var tier in _cooldowns.Catalog.BerryTiers)
        {
            var list = available.Where(b => b.Tier == tier.Tier).ToList();
            if (list.Count == 0) continue;
            content.Children.Add(new TextBlock
            {
                Text = string.Format(Strings.T(L.CdTierLabel), (int)tier.GrowthHours), Foreground = Theme.Accent,
                FontSize = 9, FontWeight = FontWeights.Bold, Margin = new Thickness(4, 8, 0, 2)
            });
            var group = new StackPanel();
            for (int i = 0; i < list.Count; i++)
            {
                if (i > 0) group.Children.Add(CdRowDivider());
                group.Children.Add(BerryPickerRow(list[i]));
            }
            content.Children.Add(CdGroup(group));
        }

        var col = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(head, Dock.Top);
        col.Children.Add(head);
        col.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = content });

        CooldownHost.Content = new Border { Background = Theme.Bg, Child = col };
    }

    private FrameworkElement BerryPickerRow(BerryDef berry)
    {
        var d = new DockPanel { LastChildFill = true };
        d.Children.Add(DockRight(new TextBlock { Text = "＋", Foreground = Theme.Accent, FontSize = 14, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center }));
        var ih = new Border { Child = BerryIcon(berry.Id, 24), Width = 24, Height = 24, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(ih, Dock.Left);
        d.Children.Add(ih);
        d.Children.Add(new TextBlock { Text = berry.Name.Localized, Foreground = Theme.Text, FontSize = 13, VerticalAlignment = VerticalAlignment.Center });

        var row = new Border { Child = d, Background = Brushes.Transparent, Padding = new Thickness(12, 8, 12, 8) };
        MakeClickable(row, () => { _cooldowns.AddBerry(berry.Id); _cdShowBerryPicker = false; RenderCooldowns(); });
        return row;
    }

    private static FrameworkElement DockRight(FrameworkElement el) { DockPanel.SetDock(el, Dock.Right); return el; }

    // MARK: - Foto do boneco (avatar)

    /// Abre o seletor, recorta o centro em quadrado e reduz p/ 128×128 PNG base64 (usa a imaging do WPF).
    private void PickAvatar(GameCharacter ch)
    {
        var dlg = new OpenFileDialog
        {
            Title = Strings.T(L.CdChoosePhoto),
            Filter = "Imagens|*.png;*.jpg;*.jpeg;*.bmp;*.gif|*.*|*.*",
            CheckFileExists = true, Multiselect = false
        };
        Native.SetNoActivate(this, false);
        Activate();
        bool? ok;
        try { ok = dlg.ShowDialog(this); }
        finally { Native.SetNoActivate(this, true); }
        if (ok == true)
        {
            var b64 = SquareIconBase64(dlg.FileName, 128);
            if (b64 != null) _cooldowns.SetAvatar(ch.Id, b64);
        }
        RenderCooldowns();
    }

    /// Recorta a imagem no centro (aspect-fill) e reduz p/ side×side px; devolve PNG base64. null em erro.
    private static string? SquareIconBase64(string path, int side)
    {
        try
        {
            var src = new BitmapImage();
            src.BeginInit();
            src.CacheOption = BitmapCacheOption.OnLoad;
            src.UriSource = new Uri(path);
            src.EndInit();
            src.Freeze();

            int w = src.PixelWidth, h = src.PixelHeight;
            if (w <= 0 || h <= 0) return null;
            int sq = Math.Min(w, h);
            var cropped = new CroppedBitmap(src, new Int32Rect((w - sq) / 2, (h - sq) / 2, sq, sq));
            double scale = (double)side / sq;
            var scaled = new TransformedBitmap(cropped, new ScaleTransform(scale, scale));

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(scaled));
            using var ms = new MemoryStream();
            encoder.Save(ms);
            return Convert.ToBase64String(ms.ToArray());
        }
        catch { return null; }
    }

    /// Ícone do boneco: a foto (PNG base64) em círculo, ou o monograma (1ª letra) se não houver.
    private static FrameworkElement CharAvatar(GameCharacter ch, double size)
    {
        var img = DecodeAvatar(ch.Avatar);
        var grid = new Grid { Width = size, Height = size };
        if (img != null)
        {
            var el = new Image { Source = img, Width = size, Height = size, Stretch = Stretch.UniformToFill };
            el.Clip = new EllipseGeometry(new Point(size / 2, size / 2), size / 2, size / 2);
            grid.Children.Add(el);
        }
        else
        {
            grid.Children.Add(new Ellipse { Fill = Theme.AccentSoft, Width = size, Height = size });
            grid.Children.Add(new TextBlock
            {
                Text = (ch.Name.Length > 0 ? ch.Name.Substring(0, 1) : "?").ToUpperInvariant(),
                Foreground = Theme.Accent, FontSize = size * 0.46, FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
            });
        }
        grid.Children.Add(new Ellipse { Stroke = Theme.Border, StrokeThickness = 1, Width = size, Height = size });
        return grid;
    }

    private static BitmapImage? DecodeAvatar(string? b64)
    {
        if (string.IsNullOrEmpty(b64)) return null;
        try
        {
            using var ms = new MemoryStream(Convert.FromBase64String(b64));
            var img = new BitmapImage();
            img.BeginInit();
            img.CacheOption = BitmapCacheOption.OnLoad;
            img.StreamSource = ms;
            img.EndInit();
            img.Freeze();
            return img;
        }
        catch { return null; }
    }

    // MARK: - Ícones do sistema de cooldown

    /// Ícone de uma tarefa: "region:x" (iniciais/mapa) · "trainer:x" · "item:x" · "sprite:x".
    /// "sf:x" (SF Symbol do Apple) e specs desconhecidas caem no PONTO COLORIDO da tarefa.
    private FrameworkElement CdTaskIcon(string? spec, string colorHex, double size)
    {
        if (!string.IsNullOrEmpty(spec))
        {
            int sep = spec.IndexOf(':');
            if (sep > 0)
            {
                var kind = spec.Substring(0, sep);
                var name = spec.Substring(sep + 1);
                FrameworkElement? el = kind switch
                {
                    "region" => StartersIcon(name, size),
                    "trainer" => TrainerIcon(name, size),
                    "item" => ItemIcon(name, size),
                    "sprite" => SpriteIcon(name, size),
                    _ => null,
                };
                if (el != null)
                {
                    el.HorizontalAlignment = HorizontalAlignment.Center;
                    el.VerticalAlignment = VerticalAlignment.Center;
                    return el;
                }
            }
        }
        return CdColorDot(colorHex, size);
    }

    private static FrameworkElement CdColorDot(string colorHex, double size)
    {
        var c = ParseHexColor(colorHex);
        var grid = new Grid { Width = size, Height = size };
        grid.Children.Add(new Ellipse { Fill = new SolidColorBrush(Color.FromArgb(0x2E, c.R, c.G, c.B)), Width = size, Height = size });
        double inner = size * 0.42;
        grid.Children.Add(new Ellipse { Fill = new SolidColorBrush(c), Width = inner, Height = inner, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
        return grid;
    }

    /// Sprite de uma berry (data/sprites/berries/<nome>.png), pelo id "berry_<nome>".
    private FrameworkElement BerryIcon(string berryId, double size)
    {
        var key = berryId.StartsWith("berry_", StringComparison.Ordinal) ? berryId.Substring(6) : berryId;
        var img = LoadImage(System.IO.Path.Combine(SolveLoader.DataDir, "sprites", "berries", key + ".png"));
        if (img != null)
        {
            var el = new Image { Source = img, Width = size, Height = size, Stretch = Stretch.Uniform, SnapsToDevicePixels = true };
            RenderOptions.SetBitmapScalingMode(el, BitmapScalingMode.NearestNeighbor);
            return el;
        }
        return new TextBlock
        {
            Text = "🌿", FontSize = size * 0.7, Foreground = Theme.Good,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
    }

    private static Color ParseHexColor(string hex)
    {
        var s = hex.TrimStart('#');
        if (s.Length < 6) return Colors.Gray;
        try
        {
            byte r = Convert.ToByte(s.Substring(0, 2), 16);
            byte g = Convert.ToByte(s.Substring(2, 2), 16);
            byte b = Convert.ToByte(s.Substring(4, 2), 16);
            return Color.FromRgb(r, g, b);
        }
        catch { return Colors.Gray; }
    }

    // MARK: - Componentes locais

    /// Cronômetro: ícone (emoji) + rótulo pequeno (opcional) + TEMPO em destaque (mono).
    private FrameworkElement ChronoChip(string glyph, string label, string time, Brush color, bool urgent)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        if (!string.IsNullOrEmpty(glyph))
            sp.Children.Add(new TextBlock { Text = glyph, FontSize = 10, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 5, 0) });
        if (!string.IsNullOrEmpty(label))
            sp.Children.Add(new TextBlock { Text = label.ToUpperInvariant(), Foreground = Theme.TextDim, FontSize = 8.5, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 5, 0) });
        sp.Children.Add(new TextBlock { Text = time, Foreground = color, FontSize = 12.5, FontWeight = FontWeights.Bold, FontFamily = new FontFamily("Consolas"), VerticalAlignment = VerticalAlignment.Center });

        return new Border
        {
            Child = sp,
            Background = urgent ? SoftBrush(color) : new SolidColorBrush(Color.FromArgb(0x0A, 0xFF, 0xFF, 0xFF)),
            CornerRadius = new CornerRadius(7), Padding = new Thickness(8, 4, 8, 4),
            HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 4, 0, 0)
        };
    }

    private FrameworkElement PillButton(string title, Brush bg, Action act)
    {
        var b = new Border
        {
            Child = new TextBlock { Text = title, Foreground = Brushes.Black, FontSize = 11, FontWeight = FontWeights.Bold },
            Background = bg, CornerRadius = new CornerRadius(11), Padding = new Thickness(11, 5, 11, 5),
            Margin = new Thickness(0, 0, 6, 0), VerticalAlignment = VerticalAlignment.Center
        };
        MakeClickable(b, act);
        return b;
    }

    /// Botão de reset CLARO (↺ + "Resetar"), contornado em vermelho.
    private FrameworkElement ResetButton(Action act)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        sp.Children.Add(new TextBlock { Text = "↺", Foreground = Theme.Danger, FontSize = 11, FontWeight = FontWeights.Bold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 4, 0) });
        sp.Children.Add(new TextBlock { Text = Strings.T(L.CdReset), Foreground = Theme.Danger, FontSize = 11, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        var b = new Border
        {
            Child = sp, Background = Brushes.Transparent, BorderBrush = SoftBrush(Theme.Danger),
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(11), Padding = new Thickness(9, 5, 9, 5),
            VerticalAlignment = VerticalAlignment.Center, ToolTip = Strings.T(L.CdReset)
        };
        MakeClickable(b, act);
        return b;
    }

    /// Reset compacto (só o ↺ com anel vermelho) — para as linhas apertadas de berry. Não é um "X".
    private FrameworkElement ResetIconMini(Action act)
    {
        var b = new Border
        {
            Child = new TextBlock { Text = "↺", Foreground = Theme.Danger, FontSize = 12, FontWeight = FontWeights.Bold, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center },
            Width = 24, Height = 24, CornerRadius = new CornerRadius(12), Background = Brushes.Transparent,
            BorderBrush = SoftBrush(Theme.Danger), BorderThickness = new Thickness(1),
            VerticalAlignment = VerticalAlignment.Center, ToolTip = Strings.T(L.CdReset)
        };
        MakeClickable(b, act);
        return b;
    }

    private FrameworkElement CdIconMini(string glyph, Action act)
    {
        var b = new Border
        {
            Child = new TextBlock
            {
                Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 12, Foreground = Theme.TextDim,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
            },
            Width = 24, Height = 24, Background = Brushes.Transparent, VerticalAlignment = VerticalAlignment.Center
        };
        MakeClickable(b, act);
        return b;
    }

    private FrameworkElement PlayIcon(bool ready)
    {
        return new Border
        {
            Child = new TextBlock { Text = "▶", Foreground = Brushes.White, FontSize = 11, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center },
            Width = 24, Height = 24, CornerRadius = new CornerRadius(12), Background = Theme.Good,
            Opacity = ready ? 1.0 : 0.9, VerticalAlignment = VerticalAlignment.Center
        };
    }

    private static Brush SoftBrush(Brush b)
    {
        if (b is SolidColorBrush s)
        {
            var c = s.Color;
            return new SolidColorBrush(Color.FromArgb(0x29, c.R, c.G, c.B));
        }
        return new SolidColorBrush(Color.FromArgb(0x29, 0xFF, 0xFF, 0xFF));
    }

    private static Border CdGroup(UIElement content) => new()
    {
        Child = content, Background = Theme.Panel, BorderBrush = Theme.Border, BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(12)
    };

    private static TextBlock CdSectionLabel(string text) => new()
    {
        Text = text.ToUpperInvariant(), Foreground = Theme.Text, FontSize = 12, FontWeight = FontWeights.Black,
        Margin = new Thickness(2, 0, 2, 6)
    };

    private static Border CdRowDivider() => new() { Height = 1, Background = Theme.Border, Margin = new Thickness(48, 0, 0, 0) };
}
