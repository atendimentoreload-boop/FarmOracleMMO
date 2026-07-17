import AppKit
import SwiftUI
import Combine

/// Controla aparência e comportamento da janela overlay: opacidade e tamanho de fonte.
/// Exposto à UI via @EnvironmentObject.
@MainActor
final class OverlayController: ObservableObject {
    weak var window: NSWindow?

    /// Chave da opacidade persistida (a escolha do usuário sobrevive entre aberturas).
    private static let opacityKey = "overlay.opacity"
    /// Chave do nível de tamanho de fonte (0=Compacto, 1=Normal, 2=Grande). Mesma que o Theme lê.
    private static let uiScaleKey = "overlay.uiScale"

    @Published private(set) var opacity: Double = {
        guard let v = UserDefaults.standard.object(forKey: OverlayController.opacityKey) as? Double
        else { return 0.95 }
        return min(max(v, 0.35), 1.0)
    }()
    /// Nível de tamanho de fonte (0/1/2). O botão "A−/A/A+" do topo cicla; o Theme aplica o fator.
    @Published private(set) var uiScale: Int = {
        let v = UserDefaults.standard.object(forKey: OverlayController.uiScaleKey) as? Int ?? 1
        return min(max(v, 0), 2)
    }()
    @Published private(set) var minimized: Bool = false

    /// Bolinha (Master Ball) flutuante mostrada quando a janela está minimizada.
    private var miniWindow: NSPanel?
    /// Debounce: instante da última restauração (evita recolher de novo logo após abrir).
    private var lastRestore: Date = .distantPast

    func attach(window: NSWindow) {
        self.window = window
        window.alphaValue = CGFloat(opacity)
        Theme.scale = Theme.scaleFactor(uiScale)
    }

    // MARK: - Opacidade

    func setOpacity(_ value: Double) {
        opacity = min(max(value, 0.35), 1.0)
        window?.alphaValue = CGFloat(opacity)
        UserDefaults.standard.set(opacity, forKey: OverlayController.opacityKey)
    }

    func bumpOpacity(_ delta: Double) {
        setOpacity(opacity + delta)
    }

    // MARK: - Tamanho de fonte (cicla Compacto → Normal → Grande)

    /// Avança 1 nível de fonte (0→1→2→0), atualiza o Theme e persiste. A UI re-renderiza
    /// porque a ContentView usa `.id(controller.uiScale)`.
    func cycleUiScale() {
        uiScale = (uiScale + 1) % 3
        Theme.scale = Theme.scaleFactor(uiScale)
        UserDefaults.standard.set(uiScale, forKey: OverlayController.uiScaleKey)
    }

    /// Glifo do botão de fonte conforme o nível atual.
    var uiScaleGlyph: String { ["A−", "A", "A+"][min(max(uiScale, 0), 2)] }

    // MARK: - Minimizar (recolhe na Master Ball)

    func toggleMinimize() {
        if minimized { restore() } else { minimize() }
    }

    /// Esconde o overlay e mostra uma Master Ball flutuante no lugar.
    func minimize() {
        guard !minimized, let main = window else { return }
        // Debounce: ignora um "recolher" que chega logo após restaurar — o duplo-clique de abrir
        // deixa o cursor sobre o botão de minimizar e fecharia de novo na hora.
        guard Date().timeIntervalSince(lastRestore) > 0.4 else { return }
        minimized = true
        showMiniBall(anchor: main.frame)
        main.orderOut(nil)
    }

    /// Restaura o overlay e remove a Master Ball.
    func restore() {
        guard minimized else { return }
        minimized = false
        // O overlay acompanha PARA ONDE a bolinha foi arrastada (antes voltava pro lugar antigo).
        // A bolinha foi posta em (anchor.maxX - side, anchor.maxY); invertendo, recupera o canto.
        if let ball = miniWindow, let main = window {
            let side = ball.frame.width
            var p = NSPoint(x: ball.frame.minX + side - main.frame.width, y: ball.frame.maxY)
            if let vis = (ball.screen ?? main.screen ?? NSScreen.main)?.visibleFrame {
                p.x = min(max(p.x, vis.minX), vis.maxX - main.frame.width)
                p.y = min(max(p.y, vis.minY + main.frame.height), vis.maxY)
            }
            main.setFrameTopLeftPoint(p)
        }
        miniWindow?.orderOut(nil)
        window?.orderFrontRegardless()
        lastRestore = Date()
    }

    private func showMiniBall(anchor: NSRect) {
        let side: CGFloat = 56
        if miniWindow == nil {
            let ball = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: side, height: side),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            ball.isOpaque = false
            ball.backgroundColor = .clear
            ball.level = .floating
            ball.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            ball.hasShadow = true
            ball.ignoresMouseEvents = false
            // Arraste e duplo-clique são tratados manualmente em MiniBallView,
            // então NÃO usamos o arraste automático pelo fundo (senão soltar viraria clique).
            ball.isMovableByWindowBackground = false

            let view = MiniBallView(image: MiniBallView.image) { [weak self] in self?.restore() }
            ball.contentView = view
            miniWindow = ball
        }
        // Coloca a bola onde estava o canto superior direito do overlay.
        miniWindow?.setFrameTopLeftPoint(NSPoint(x: anchor.maxX - side, y: anchor.maxY))
        miniWindow?.orderFrontRegardless()
    }
}

// MARK: - Conteúdo da pílula

/// Master Ball flutuante (estado minimizado).
/// Arrastar = reposiciona a bolinha (sem abrir). Duplo-clique = restaura o overlay.
final class MiniBallView: NSView {
    private let onRestore: () -> Void

    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "masterball", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }()

    init(image: NSImage?, onRestore: @escaping () -> Void) {
        self.onRestore = onRestore
        super.init(frame: .zero)
        wantsLayer = true
        let iv = NSImageView()
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            iv.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            iv.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
        toolTip = tr(.miniBallTooltip)
    }

    required init?(coder: NSCoder) { fatalError() }

    // Não deixamos a janela arrastar sozinha — controlamos no mouseDragged.
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let o = win.frame.origin
        win.setFrameOrigin(NSPoint(x: o.x + event.deltaX, y: o.y - event.deltaY))
    }

    // Só o duplo-clique abre. Clique simples ou soltar após arrastar não fazem nada.
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 { onRestore() }
    }
}
