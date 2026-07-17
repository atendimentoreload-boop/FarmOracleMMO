import AppKit
import SwiftUI

/// Janela do overlay: sem bordas, fundo transparente, sempre no topo e capaz de flutuar
/// sobre apps em tela cheia. Arrastável clicando em qualquer ponto.
final class OverlayWindow: NSWindow {
    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 380),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovableByWindowBackground = true
        hasShadow = true
        isReleasedWhenClosed = false
        minSize = NSSize(width: 230, height: 190)

        let hosting = NSHostingView(rootView: content)
        // Impede o SwiftUI de redimensionar a janela para caber o conteúdo (o ScrollView
        // "quer" altura infinita e fazia a janela esticar, escondendo os botões de baixo).
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 14
        hosting.layer?.masksToBounds = true

        // Container NÃO invertido (origem embaixo-esquerda). O NSHostingView é "flipped"
        // (origem no topo), o que jogava a alça pro canto de cima; aqui o canto inferior-
        // direito fica correto e a alça não é cortada pelo arredondado (é irmã do hosting).
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 380))
        container.autoresizesSubviews = true
        hosting.frame = container.bounds
        container.addSubview(hosting)

        // Alça de redimensionar no canto inferior-direito (equivalente ao grip do app Windows).
        let gripSize: CGFloat = 24
        let grip = ResizeGripView()
        grip.frame = NSRect(x: container.bounds.width - gripSize - 2, y: 2,
                            width: gripSize, height: gripSize)
        grip.autoresizingMask = [.minXMargin, .maxYMargin]   // gruda no canto inferior-direito
        container.addSubview(grip)

        contentView = container

        // Posiciona no canto superior direito da tela principal.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            setFrameTopLeftPoint(NSPoint(x: visible.maxX - frame.width - 16,
                                         y: visible.maxY - 12))
        }
    }

    // Janela sem bordas precisa permitir virar key/main para botões e texto funcionarem.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Alça de redimensionamento no canto inferior-direito. Arrastar muda largura e altura
/// mantendo o canto superior-esquerdo fixo (igual à "bordinha" do app de Windows).
final class ResizeGripView: NSView {
    // Não deixa a janela arrastar quando o gesto começa aqui — queremos redimensionar.
    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        // Três tracinhos diagonais no canto, afastados ~7px da borda pra não serem
        // comidos pelo canto arredondado do painel. Bem visíveis (claro + sombra atrás).
        let path = NSBezierPath()
        path.lineWidth = 2.0
        path.lineCapStyle = .round
        for off in stride(from: 8.0, through: 18.0, by: 5.0) {
            path.move(to: NSPoint(x: w - off, y: 6))
            path.line(to: NSPoint(x: w - 6, y: off))
        }
        // Sombra escura atrás (dá contraste em fundo claro) + traço claro por cima.
        NSColor.black.withAlphaComponent(0.45).setStroke()
        let shadow = path.copy() as! NSBezierPath
        let m = AffineTransform(translationByX: 1, byY: -1)
        shadow.transform(using: m)
        shadow.stroke()
        NSColor.white.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let f = win.frame
        let top = f.maxY                       // mantém a borda de cima fixa
        let newW = max(win.minSize.width, f.width + event.deltaX)
        let newH = max(win.minSize.height, f.height + event.deltaY)
        let origin = NSPoint(x: f.minX, y: top - newH)
        win.setFrame(NSRect(origin: origin, size: NSSize(width: newW, height: newH)), display: true)
    }
}
