import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: OverlayWindow?
    private let controller = OverlayController()
    private var cooldowns: CooldownStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        presentLanguagePickerIfNeeded()   // 1ª abertura: escolher idioma antes de montar o app
        let appModel: AppModel
        do {
            appModel = try AppModel()
        } catch {
            presentLoadError(error)
            return
        }

        appModel.checkForcedUpdate()

        let cooldowns = CooldownStore()
        self.cooldowns = cooldowns

        let root = ContentView()
            .environmentObject(appModel)
            .environmentObject(appModel.skips)
            .environmentObject(controller)
            .environmentObject(cooldowns)

        let win = OverlayWindow(content: root)
        controller.attach(window: win)
        win.makeKeyAndOrderFront(nil)
        self.window = win

        cooldowns.start()   // pede permissão de notificação (uma vez)
    }

    /// 1ª abertura: mostra o seletor PT/EN antes de montar a janela principal (porte do
    /// Android/Windows). Salva a escolha, marca a flag e sincroniza o idioma global.
    /// Bloqueia via `runModal` até o usuário escolher — depois nunca mais aparece.
    private func presentLanguagePickerIfNeeded() {
        guard !TeamPrefs.languageChosen else { return }
        let suggested = Lang(rawValue: TeamPrefs.deviceDefaultLanguage()) ?? .pt

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.center()

        let picker = LanguagePicker(suggested: suggested) { [weak panel] lang in
            TeamPrefs.language = lang.rawValue
            TeamPrefs.languageChosen = true
            AppLang.current = lang
            NSApp.stopModal()
            panel?.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: picker)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
    }

    private func presentLoadError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = tr(.loadErrorTitle)
        alert.informativeText = "\(error)"
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }
}
