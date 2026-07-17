import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var controller: OverlayController
    @State private var showLegend = false
    @State private var showSettings = false
    @State private var showCooldowns = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderBar(showLegend: $showLegend, showSettings: $showSettings,
                          showCooldowns: $showCooldowns)
                Rectangle().fill(Theme.line).frame(height: 1)

                Group {
                    if showSettings {
                        SettingsView(showSettings: $showSettings)
                    } else if showLegend {
                        LegendView(showLegend: $showLegend)
                    } else if showCooldowns {
                        CooldownView(showCooldowns: $showCooldowns)
                    } else if let engine = appModel.engine {
                        SolveRootView()
                            .environmentObject(engine)
                    } else {
                        ModePickerView(onOpenSettings: { showSettings = true },
                                       onOpenCooldowns: { showCooldowns = true })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Ciclar o tamanho de fonte muda o Theme.scale (global); o .id força a árvore a
            // re-renderizar com as novas medidas de fonte.
            .id(controller.uiScale)

            CaptureLayer(shortcuts: appModel.shortcuts)

            if let up = appModel.forcedUpdate {
                UpdateBlockView(info: up)
            }
        }
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        // #73: na 1ª abertura (após escolher o idioma) o guia "Como ler o overlay" aparece
        // sozinho uma vez; depois só reabre pelo "?". Fica no ZStack de fora pro ciclo de
        // fonte (`.id(controller.uiScale)`) não re-disparar isto.
        .onAppear {
            if !TeamPrefs.seenOverlayGuide {
                TeamPrefs.seenOverlayGuide = true
                showLegend = true
            }
        }
    }
}

// MARK: - Tela de atualização obrigatória

struct UpdateBlockView: View {
    let info: UpdateInfo

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Theme.accent)
                Text(tr(.updateRequiredTitle))
                    .font(Theme.rounded(16, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(String(format: tr(.updateRequiredBody), AppVersion.current, info.minimum))
                    .font(Theme.rounded(12))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: info.url) { NSWorkspace.shared.open(url) }
                } label: {
                    Text(tr(.downloadUpdate))
                        .font(Theme.rounded(13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                Button(tr(.close)) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(Theme.rounded(11))
                    .foregroundColor(Theme.textDim)
                    .padding(.top, 2)
            }
            .padding(24)
        }
    }
}

// MARK: - Conteúdo de um modo (luta/rota) + barra inferior

struct SolveRootView: View {
    @EnvironmentObject var engine: SolveEngine

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if engine.isHome {
                    HomeView()
                } else {
                    NodeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle().fill(Theme.line).frame(height: 1)
            BottomBar()
        }
        .environment(\.colorizer, Colorizer(palette: engine.solve.palette))
    }
}

// MARK: - Barra superior (título + controles)

struct HeaderBar: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var controller: OverlayController
    @Binding var showLegend: Bool
    @Binding var showSettings: Bool
    @Binding var showCooldowns: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !appModel.inMenu {
                Button {
                    showLegend = false
                    showSettings = false
                    showCooldowns = false
                    appModel.exitToMenu()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                        Text("Menu").font(Theme.rounded(11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                .help(tr(.switchModeHelp))
            } else {
                Circle().fill(Theme.accent).frame(width: 7, height: 7)
            }

            Text(appModel.currentTitle ?? "FarmOracleMMO")
                .font(Theme.rounded(11, weight: .semibold))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            iconButton("questionmark.circle", help: tr(.helpAndLegendHelp), active: showLegend) {
                showSettings = false
                showCooldowns = false
                showLegend.toggle()
            }
            iconButton("minus.circle", help: tr(.lessOpacityHelp)) {
                controller.bumpOpacity(-0.1)
            }
            iconButton("plus.circle", help: tr(.moreOpacityHelp)) {
                controller.bumpOpacity(0.1)
            }
            // Tamanho de fonte: cicla Compacto → Normal → Grande (glifo A−/A/A+), igual ao Android.
            // Estilo de CHIP (texto claro + cápsula com borda) pra não se camuflar entre os ícones
            // — usuários não achavam o controle de fonte (feedback do Hyper, #46).
            Button { controller.cycleUiScale() } label: {
                Text(controller.uiScaleGlyph)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .frame(minWidth: 24, minHeight: 18)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(Theme.panelHi))
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(appModel.language == .en ? "Font size (A−/A/A+)" : "Tamanho da fonte (A−/A/A+)")
            iconButton("minus.square", help: tr(.minimizeHelp)) {
                controller.minimize()
            }
            iconButton("xmark.circle", help: tr(.close)) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func iconButton(_ system: String, help: String, active: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(active ? Theme.accent : Theme.textDim)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Barra inferior (Voltar / Reset / progresso)

struct BottomBar: View {
    @EnvironmentObject var engine: SolveEngine

    var body: some View {
        HStack(spacing: 8) {
            barButton("chevron.left", tr(.back), enabled: engine.canBack) {
                engine.back()
            }
            barButton("arrow.counterclockwise", tr(.restart), enabled: !engine.isHome) {
                engine.reset()
            }

            Spacer()

            if let progress = progressText {
                Text(progress)
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.textDim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var progressText: String? {
        guard engine.solve.revealAll != true,
              let node = engine.currentNode, !node.steps.isEmpty else { return nil }
        let current = min(engine.stepIndex + 1, node.steps.count)
        return String(format: tr(.stepProgress), current, node.steps.count)
    }

    private func barButton(_ icon: String, _ label: String, enabled: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(Theme.rounded(11, weight: .medium))
            }
            .foregroundColor(enabled ? Theme.text : Theme.textDim.opacity(0.4))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.panel)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Camada de captura de atalho

struct CaptureLayer: View {
    @ObservedObject var shortcuts: ShortcutManager

    var body: some View {
        if shortcuts.isCapturing {
            ZStack {
                Color.black.opacity(0.78).ignoresSafeArea()
                VStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 30))
                        .foregroundColor(Theme.accent)
                    Text(tr(.capturePressKey))
                        .font(Theme.rounded(15, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(tr(.captureHint))
                        .font(Theme.rounded(11))
                        .foregroundColor(Theme.textDim)
                        .multilineTextAlignment(.center)
                    Button(tr(.cancel)) { shortcuts.cancelCapture() }
                        .buttonStyle(.plain)
                        .font(Theme.rounded(12, weight: .medium))
                        .foregroundColor(Theme.choice)
                        .padding(.top, 2)
                }
                .padding(20)
            }
            .transition(.opacity)
        }
    }
}
