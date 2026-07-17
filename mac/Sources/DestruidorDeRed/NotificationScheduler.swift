import Foundation
import AppKit
import UserNotifications

/// Agenda notificações locais que disparam na hora exata **mesmo com o app FECHADO** — o daemon
/// de notificações do macOS (`usernoted`) vira dono do agendamento (≠ Timer interno, que morre).
/// Design #33. Requer o app ASSINADO (ao menos ad-hoc); sem assinatura o `requestAuthorization`
/// tende a falhar e nada agenda — nesse caso o fallback é a contagem in-app.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorized = false
    private(set) var denied = false

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    override init() {
        super.init()
        center.delegate = self
    }

    /// Pede permissão uma vez (prompt do sistema). Chamar no launch.
    func requestAuthIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.authorized = true
                case .denied:
                    self.denied = true
                default:
                    self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        Task { @MainActor in self.authorized = granted; self.denied = !granted }
                    }
                }
            }
        }
    }

    /// Agenda uma notificação pra disparar em `fireAtMs` (epoch ms). Se já passou, não agenda.
    /// Reusar o mesmo `id` sobrescreve o agendamento anterior (idempotente).
    func schedule(id: String, fireAtMs: Double, title: String, body: String) {
        let seconds = (fireAtMs - nowMs()) / 1000.0
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    func cancel(id: String) { cancel(ids: [id]) }

    /// Remove agendamentos pendentes cujo id comece com um prefixo (ex.: todos de um boneco/tarefa).
    func cancel(prefix: String) {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    // Mostra o banner mesmo com o app em foco.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Ao tocar na notificação: traz o app pra frente.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
        completionHandler()
    }
}
