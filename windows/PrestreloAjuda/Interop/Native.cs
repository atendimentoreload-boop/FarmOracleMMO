using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace PrestreloAjuda.Interop;

/// Ajustes nativos (Win32) para a janela de overlay: estilos estendidos que deixam a janela
/// fora do Alt-Tab, sem roubar foco do jogo e, opcionalmente, com cliques atravessando.
public static class Native
{
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_LAYERED     = 0x00080000;
    private const int WS_EX_NOACTIVATE  = 0x08000000; // não vira foreground ao clicar (não rouba foco)
    private const int WS_EX_TOOLWINDOW  = 0x00000080; // some do Alt-Tab e da barra de tarefas

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowLong(IntPtr hwnd, int index);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

    private static IntPtr Handle(Window w) => new WindowInteropHelper(w).Handle;

    /// Aplica os estilos base do overlay: toolwindow (fora do Alt-Tab) + no-activate (não rouba foco).
    /// Chamar depois que a janela tiver handle (evento SourceInitialized).
    public static void MakeOverlay(Window w)
    {
        var hwnd = Handle(w);
        if (hwnd == IntPtr.Zero) return;
        int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        ex |= WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED;
        SetWindowLong(hwnd, GWL_EXSTYLE, ex);
    }

    /// Liga/desliga o modo "cliques atravessam para o jogo".

    /// Liga/desliga o estilo "não roubar foco" (NOACTIVATE). Desligamos por instantes para
    /// permitir digitar na busca / capturar o atalho; religamos em seguida para o overlay
    /// voltar a não tirar o jogo do foco.
    public static void SetNoActivate(Window w, bool on)
    {
        var hwnd = Handle(w);
        if (hwnd == IntPtr.Zero) return;
        int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        if (on) ex |= WS_EX_NOACTIVATE;
        else ex &= ~WS_EX_NOACTIVATE;
        SetWindowLong(hwnd, GWL_EXSTYLE, ex);
    }

    // --- Atalhos globais (Ctrl+Alt+L do click-through e o "Próximo" configurável) ---

    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;
    public const uint MOD_NOREPEAT = 0x4000;
    public const int WM_HOTKEY = 0x0312;

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
