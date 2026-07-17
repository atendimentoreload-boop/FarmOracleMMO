using System.IO;
using System.Windows.Threading;
using WinForms = System.Windows.Forms;
using Drawing = System.Drawing;

namespace PrestreloAjuda.Services;

/// Notificações do sistema de Cooldown/Alarme (#33) no Windows (porte da API de
/// NotificationScheduler.swift, adaptado à plataforma).
///
/// LIMITAÇÃO HONESTA (documentada de propósito): este app é DESEMPACOTADO (sem MSIX / sem identidade
/// registrada), então NÃO existe forma confiável de agendar um toast que dispare com o app FECHADO —
/// isso exigiria empacotamento + AppUserModelID, ou uma Tarefa Agendada/serviço à parte. É o mesmo
/// tipo de limite do Mac, que só notifica com o app fechado quando ele está ASSINADO. Aqui a
/// estratégia é: ENQUANTO O APP ESTÁ ABERTO, um DispatcherTimer de 1s observa os alvos agendados
/// (guardados em memória) e, quando o relógio passa do fireAt, dispara UMA VEZ um balloon tip pela
/// bandeja (NotifyIcon). O tracker + a contagem ao vivo na tela funcionam 100%; só o disparo
/// automático fica limitado ao tempo em que o app está aberto.
///
/// A API lógica (Schedule / Cancel / CancelPrefix) espelha o Mac para o CooldownStore ser 1:1.
public sealed class CooldownNotifications : IDisposable
{
    private sealed class Target
    {
        public double FireAtMs;
        public string Title = "";
        public string Body = "";
    }

    // Alvos agendados por id (mesma convenção de id do Mac, p/ cancelar por prefixo).
    private readonly Dictionary<string, Target> _targets = new();
    private readonly WinForms.NotifyIcon _tray;
    private readonly DispatcherTimer _timer;
    private bool _disposed;

    /// Resgate do #40: duplo-clique no ícone da bandeja pede pra restaurar a janela.
    /// A MainWindow assina isso pra recuperar o overlay mesmo se a bolinha minimizada se perder.
    public Action? RestoreRequested;

    public CooldownNotifications()
    {
        _tray = new WinForms.NotifyIcon
        {
            Text = "FarmOracleMMO",
            Icon = LoadTrayIcon(),
            Visible = true, // precisa estar visível p/ o balloon tip aparecer
        };
        // Duplo-clique na bandeja = restaurar a janela (rede de segurança do #40).
        _tray.DoubleClick += (_, _) => RestoreRequested?.Invoke();
        // Relógio interno: a cada 1s checa se algum alvo venceu e dispara o balloon.
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += (_, _) => Fire();
        _timer.Start();
    }

    private static Drawing.Icon LoadTrayIcon()
    {
        try
        {
            var ico = Path.Combine(AppContext.BaseDirectory, "Assets", "masterball.ico");
            if (File.Exists(ico)) return new Drawing.Icon(ico);
        }
        catch { /* cai no ícone genérico */ }
        return Drawing.SystemIcons.Application;
    }

    /// Agenda uma notificação pra disparar em `fireAtMs` (epoch ms). Se já passou, NÃO agenda
    /// (e limpa um agendamento anterior de mesmo id). Reusar o mesmo `id` sobrescreve (idempotente).
    public void Schedule(string id, double fireAtMs, string title, string body)
    {
        if (fireAtMs - Cd.NowMs() <= 0) { _targets.Remove(id); return; }
        _targets[id] = new Target { FireAtMs = fireAtMs, Title = title, Body = body };
    }

    /// Cancela o agendamento de um id específico.
    public void Cancel(string id) => _targets.Remove(id);

    /// Cancela todos os agendamentos cujo id comece com um prefixo (ex.: todos de um boneco/tarefa).
    public void CancelPrefix(string prefix)
    {
        foreach (var k in _targets.Keys.Where(k => k.StartsWith(prefix, StringComparison.Ordinal)).ToList())
            _targets.Remove(k);
    }

    private void Fire()
    {
        if (_disposed) return;
        double now = Cd.NowMs();
        var due = _targets.Where(kv => kv.Value.FireAtMs <= now).ToList();
        foreach (var kv in due)
        {
            _targets.Remove(kv.Key);
            try { _tray.ShowBalloonTip(8000, kv.Value.Title, kv.Value.Body, WinForms.ToolTipIcon.Info); }
            catch { /* balloon é best-effort */ }
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        try { _timer.Stop(); } catch { }
        try { _tray.Visible = false; _tray.Dispose(); } catch { }
    }
}
