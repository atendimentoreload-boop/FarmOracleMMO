import AppKit
import Carbon.HIToolbox
import Combine

/// Gerencia um atalho de teclado configurável para o botão "Próximo" + os atalhos F1..F12 das
/// opções da escolha.
///
/// Usa **Carbon `RegisterEventHotKey`** (hotkey de SISTEMA): funciona mesmo com o PokeMMO em foco
/// — inclusive em jogos que consomem o input — e **NÃO precisa de permissão de Acessibilidade**
/// (ao contrário do antigo `NSEvent` global monitor). É o equivalente ao `RegisterHotKey` do Windows.
///
/// - O atalho do "Próximo" fica registrado o tempo todo (enquanto houver combo definido).
/// - As F1..Fn ficam registradas SÓ enquanto há uma escolha de N opções na tela (via
///   `syncChoiceHotkeys`), pra não roubar as F-keys do jogo fora desse momento.
@MainActor
final class ShortcutManager: ObservableObject {
    struct Combo: Codable, Equatable {
        var keyCode: UInt16
        var modifiers: UInt   // rawValue de [.command,.option,.control,.shift]
        var display: String
    }

    /// Qual atalho estamos configurando/acionando: o "Próximo" ou o "Pular parada" (#71).
    enum Kind { case next, skip }

    @Published private(set) var combo: Combo?        // "Próximo"
    @Published private(set) var skipCombo: Combo?    // "Pular parada" (#71)
    @Published private(set) var isCapturing = false
    /// Mantido por compatibilidade com a UI. Com Carbon não precisamos de Acessibilidade → sempre true.
    @Published private(set) var accessibilityGranted = true

    /// Chamado quando o atalho do "Próximo" é acionado.
    var onTrigger: (() -> Void)?

    /// Chamado quando o atalho do "Pular parada" é acionado (#71).
    var onSkipTrigger: (() -> Void)?

    /// Chamado quando uma tecla F1..F12 é pressionada (índice 0..11 = opção 1..12 da escolha).
    var onChoiceKey: ((Int) -> Bool)?

    /// keyCodes (macOS, = virtual keycodes do Carbon) de F1..F12, em ordem.
    private static let fKeyCodes: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    private var localMonitor: Any?
    private var comboRef: EventHotKeyRef?
    private var skipComboRef: EventHotKeyRef?
    private var fKeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var registeredChoiceCount = -1
    private var captureTarget: Kind = .next   // qual combo a captura atual vai gravar

    private let defaultsKey = "nextShortcut"
    private let skipDefaultsKey = "skipShortcut"
    private static let relevantMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    static let hotKeySignature = OSType(0x46524D4F)   // 'FRMO'
    static let comboHotKeyID: UInt32 = 1
    static let skipHotKeyID: UInt32 = 2
    static let fKeyHotKeyBase: UInt32 = 100

    init() {
        load()
        installCarbonHandler()
        registerCombos()
        installLocalMonitor()
    }

    /// Combo atual de um dos atalhos (leitura pra UI).
    func combo(for kind: Kind) -> Combo? { kind == .next ? combo : skipCombo }

    // MARK: - Captura (gravar o atalho)

    func startCapture(_ target: Kind = .next) {
        captureTarget = target
        isCapturing = true
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    }

    func cancelCapture() {
        isCapturing = false
    }

    func clear(_ target: Kind = .next) {
        if target == .next { combo = nil } else { skipCombo = nil }
        save()
        registerCombos()   // combo == nil → apenas desregistra aquele
    }

    /// No-op: o Carbon hotkey dispensa Acessibilidade. Mantido porque a UI ainda referencia.
    @discardableResult
    func requestAccessibility() -> Bool {
        accessibilityGranted = true
        return true
    }

    // MARK: - Hotkeys do sistema (Carbon)

    private func installCarbonHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), shortcutHotKeyCallback,
                            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    /// Chamado pelo callback C quando QUALQUER hotkey nosso dispara.
    func handleHotKey(_ id: UInt32) {
        if id == Self.comboHotKeyID {
            onTrigger?()
        } else if id == Self.skipHotKeyID {
            onSkipTrigger?()
        } else if id >= Self.fKeyHotKeyBase {
            _ = onChoiceKey?(Int(id - Self.fKeyHotKeyBase))
        }
    }

    private func registerCombos() {
        register(combo, id: Self.comboHotKeyID, ref: &comboRef)
        register(skipCombo, id: Self.skipHotKeyID, ref: &skipComboRef)
    }

    /// (Re)registra um combo como hotkey de sistema; `combo == nil` só desregistra.
    private func register(_ combo: Combo?, id: UInt32, ref refBox: inout EventHotKeyRef?) {
        if let ref = refBox { UnregisterEventHotKey(ref); refBox = nil }
        guard let combo else { return }
        let hkID = EventHotKeyID(signature: Self.hotKeySignature, id: id)
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(combo.keyCode), Self.carbonMods(combo.modifiers),
                               hkID, GetApplicationEventTarget(), 0, &ref) == noErr {
            refBox = ref
        }
    }

    /// (Re)registra F1..F`count` como hotkeys de sistema. `count == 0` libera as F-keys pro jogo.
    func syncChoiceHotkeys(count: Int) {
        let n = max(0, min(count, 12))
        if n == registeredChoiceCount { return }
        registeredChoiceCount = n
        for ref in fKeyRefs { UnregisterEventHotKey(ref) }
        fKeyRefs.removeAll()
        guard n > 0 else { return }
        for i in 0..<n {
            let hkID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.fKeyHotKeyBase + UInt32(i))
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(UInt32(Self.fKeyCodes[i]), 0, hkID,
                                   GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                fKeyRefs.append(ref)
            }
        }
    }

    private static func carbonMods(_ nsRaw: UInt) -> UInt32 {
        let f = NSEvent.ModifierFlags(rawValue: nsRaw)
        var m: UInt32 = 0
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.option)  { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        if f.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    // MARK: - Monitor local (só para gravar o atalho com o overlay em foco)

    private func installLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isCapturing {
                self.handleCapture(event)
                return nil
            }
            return event
        }
    }

    private func handleCapture(_ event: NSEvent) {
        if event.keyCode == 53 { isCapturing = false; return }      // Esc cancela
        if Self.isModifierKeyCode(event.keyCode) { return }         // espera tecla "de verdade"
        let mods = event.modifierFlags.intersection(Self.relevantMods)
        let captured = Combo(keyCode: event.keyCode, modifiers: mods.rawValue,
                             display: Self.displayString(for: event, mods: mods))
        if captureTarget == .next { combo = captured } else { skipCombo = captured }
        isCapturing = false
        save()
        registerCombos()
    }

    // MARK: - Persistência

    private func load() {
        combo = Self.loadCombo(key: defaultsKey)
        skipCombo = Self.loadCombo(key: skipDefaultsKey)
    }

    private static func loadCombo(key: String) -> Combo? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Combo.self, from: data) else { return nil }
        return saved
    }

    private func save() {
        Self.saveCombo(combo, key: defaultsKey)
        Self.saveCombo(skipCombo, key: skipDefaultsKey)
    }

    private static func saveCombo(_ combo: Combo?, key: String) {
        if let combo, let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Helpers de exibição

    private static func isModifierKeyCode(_ code: UInt16) -> Bool {
        [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code)
    }

    private static func displayString(for event: NSEvent, mods: NSEvent.ModifierFlags) -> String {
        var prefix = ""
        if mods.contains(.control) { prefix += "⌃" }
        if mods.contains(.option) { prefix += "⌥" }
        if mods.contains(.shift) { prefix += "⇧" }
        if mods.contains(.command) { prefix += "⌘" }
        return prefix + keyName(for: event)
    }

    private static func keyName(for event: NSEvent) -> String {
        if let special = specialKeyNames[event.keyCode] { return special }
        let chars = event.charactersIgnoringModifiers ?? ""
        return chars.uppercased().isEmpty ? String(format: tr(.keyNameUnknownFallback), Int(event.keyCode)) : chars.uppercased()
    }

    private static let specialKeyNames: [UInt16: String] = [
        49: tr(.keyNameSpace), 36: "Return", 48: "Tab", 53: "Esc", 51: "Delete",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        50: "`"
    ]
}

/// Callback C do Carbon (não pode capturar contexto). Recupera o `ShortcutManager` pelo userData
/// e despacha o id do hotkey pra ele na main thread.
private func shortcutHotKeyCallback(_ next: EventHandlerCallRef?,
                                    _ event: EventRef?,
                                    _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return noErr }
    var hkID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    guard status == noErr else { return noErr }
    let id = hkID.id
    let mgr = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { mgr.handleHotKey(id) }
    return noErr
}
