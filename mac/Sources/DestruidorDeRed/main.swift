import AppKit
import SwiftUI
import UserNotifications

// --cdshot <png> [tab]: renderiza a tela de Cooldowns num PNG offscreen (dev only, invisível pro
// usuário). Semeia um boneco de DEMONSTRAÇÃO em memória (não toca no estado real). tab = battles|berries.
if let idx = CommandLine.arguments.firstIndex(of: "--cdshot") {
    let out = CommandLine.arguments.count > idx + 1 ? CommandLine.arguments[idx + 1] : "/tmp/cdshot.png"
    let wantBerries = CommandLine.arguments.contains("berries")
    let wantList = CommandLine.arguments.contains("list")
    let shotWidth = CommandLine.arguments.compactMap { Double($0) }.first ?? 300
    MainActor.assumeIsolated {
        _ = NSApplication.shared               // inicializa o AppKit p/ carregar NSImage/fontes
        let store = CooldownStore()
        store.seedDemoNoPersist()
        let root = CooldownView(showCooldowns: .constant(true),
                                previewCharId: wantList ? nil : "char_demo",
                                previewBerries: wantBerries, previewExpandElite4: true,
                                previewNoScroll: true)
            .environmentObject(store)
            .frame(width: shotWidth, height: 900)
            .background(Theme.bg)
        let renderer = ImageRenderer(content: root)
        renderer.scale = 2.0
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: out))
            FileHandle.standardError.write(Data("cdshot: escrito em \(out) (\(Int(img.size.width))x\(Int(img.size.height)))\n".utf8))
        } else {
            FileHandle.standardError.write(Data("cdshot: FALHOU ao renderizar\n".utf8))
        }
    }
    exit(0)
}

// --notiftest: agenda uma notificação 10s à frente e SAI. Se ela disparar com o processo já
// encerrado, o alarme com o app fechado funciona (dev only, invisível pro usuário).
if CommandLine.arguments.contains("--notiftest") {
    let center = UNUserNotificationCenter.current()
    let sem = DispatchSemaphore(value: 0)
    func schedule(_ status: UNAuthorizationStatus) {
        let c = UNMutableNotificationContent()
        c.title = "FarmOracle — teste de alarme"
        c.body = "Se você vê isto com o app fechado, o alarme funciona! ⚔️"
        c.sound = .default
        center.add(UNNotificationRequest(identifier: "notiftest", content: c,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))) { err in
            FileHandle.standardError.write(Data(
                "notiftest: authStatus=\(status.rawValue) addErr=\(String(describing: err))\n".utf8))
            sem.signal()
        }
    }
    center.getNotificationSettings { s in
        if s.authorizationStatus == .notDetermined {
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in schedule(.notDetermined) }
        } else { schedule(s.authorizationStatus) }
    }
    sem.wait(); exit(0)
}

// --notifcheck: lista as notificações JÁ ENTREGUES (pra confirmar que a de teste disparou).
if CommandLine.arguments.contains("--notifcheck") {
    let center = UNUserNotificationCenter.current()
    let sem = DispatchSemaphore(value: 0)
    center.getDeliveredNotifications { notes in
        FileHandle.standardError.write(Data(
            "delivered=\(notes.map { $0.request.identifier })\n".utf8))
        sem.signal()
    }
    sem.wait(); exit(0)
}

enum SelfTestError: Error, CustomStringConvertible {
    case msg(String)
    var description: String { if case let .msg(m) = self { return m } else { return "erro" } }
}

// --selftest: rede de segurança da release. Carrega TODOS os recursos que o app precisa
// (bundle do SwiftPM + JSON de cada time e de cada visual emoji) e sai com 0 (ok) ou 1
// (falhou), SEM abrir janela nenhuma — roda headless.
//
// O CI executa isto no `.app` JÁ EMPACOTADO, logo após o build e antes de publicar. Assim,
// se a release estiver quebrada (bundle no lugar errado pro Bundle.module, dado faltando,
// JSON inválido), o job FALHA aqui e a publicação é abortada — em vez de virar um
// "app que não abre" na mão do usuário. Foi exatamente esse buraco que deixou sair a
// release Mac com o bundle no lugar errado.
if CommandLine.arguments.contains("--selftest") {
    MainActor.assumeIsolated {
        do {
            let cfg = TeamsConfig.load()
            guard !cfg.teams.isEmpty else { throw SelfTestError.msg("teams.json ausente/vazio") }
            var total = 0
            for team in cfg.teams {
                let visuals = team.hasEmoji ? [false, true] : [false]
                for emoji in visuals {
                    // buildModes carrega red + veteran + os 5 Elite 4 do time/visual,
                    // resolvendo o bundle e decodificando cada JSON. Qualquer falha lança.
                    // Roda nos dois idiomas: o EN cai no PT se faltar arquivo, mas se um
                    // JSON EN existir e estiver quebrado, o decode lança e a release falha aqui.
                    for lang in Lang.allCases {
                        // Testa as duas rotas de farm E as estratégias do Red e do Ho-Oh pra garantir
                        // que todos os solves decodificam (um JSON quebrado falha a release aqui).
                        for route in ["veteran", "6pillars_basic", "lucky_girl"] {
                            for cmStrat in ["cynthia_morimoto", "cynthia_morimoto_cadozz"] {
                                for redStrat in ["red", "red_colored"] {
                                    for hoohStrat in ["hooh", "hooh_trickroom"] {
                                        let modes = try AppModel.buildModes(teams: cfg, teamId: team.id, emoji: emoji, lang: lang, farmRouteId: route, cmStrategyId: cmStrat, redStrategyId: redStrat, hoohStrategyId: hoohStrat)
                                        guard modes.count >= 7 else {
                                            throw SelfTestError.msg("time \(team.id) \(emoji ? "(emoji) " : "")[\(lang.rawValue)] rota \(route) cm \(cmStrat) red \(redStrat) hooh \(hoohStrat) carregou só \(modes.count) modos")
                                        }
                                        total += modes.count
                                    }
                                }
                            }
                        }
                    }
                }
            }
            FileHandle.standardError.write(Data(
                "selftest OK: \(cfg.teams.count) time(s), \(total) modos carregados.\n".utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("selftest FALHOU: \(error)\n".utf8))
            exit(1)
        }
    }
}

// Ponto de entrada normal. App "accessory": sem ícone no Dock e sem menu, para não roubar o
// foco do jogo. A janela é criada pelo AppDelegate.
//
// O arranque já ocorre na main thread, então podemos assumir o isolamento de MainActor
// para construir os objetos @MainActor (AppDelegate/controller).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
