#!/bin/bash
# Empacota o Destruidor de Red num .app de duplo-clique (modo release).
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="FarmOracleMMO"
BIN_NAME="DestruidorDeRed"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"

# Versão vem da fonte única /VERSION (sincronizada pelo bump-version).
APP_VERSION="$(tr -d '[:space:]' < ../VERSION 2>/dev/null || echo '1.1.0')"
[ -z "${APP_VERSION}" ] && APP_VERSION="1.1.0"

echo "==> Sincronizando dados de /data..."
bash scripts/sync-data.sh

echo "==> Compilando em modo release..."
swift build -c release

echo "==> Montando ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Binário
cp "${BUILD_DIR}/${BIN_NAME}" "${APP_DIR}/Contents/MacOS/${BIN_NAME}"

# Bundle de recursos gerado pelo SwiftPM (red.json, teams/, sprites, etc.).
# IMPORTANTE: o acessador `Bundle.module` é gerado pelo toolchain e a lista de
# locais que ele consulta VARIA entre versões de Xcode. O Xcode local costuma
# procurar ao lado do executável (Contents/MacOS), mas o runner do CI procura na
# RAIZ do .app (Bundle.main.bundleURL). Se o bundle só existir num lugar, o app
# compilado no CI abre e morre na hora com "could not load resource bundle".
# Para ser à prova de toolchain, copiamos o bundle para os três locais possíveis.
BUNDLE="${BIN_NAME}_${BIN_NAME}.bundle"
if [ -d "${BUILD_DIR}/${BUNDLE}" ]; then
  # Canônico: Contents/Resources. É o ÚNICO local que o codesign aceita — bundle de recursos
  # solto na raiz do .app ou em Contents/MacOS quebra a assinatura ("unsealed contents present
  # in the bundle root"). O app local (swift build) resolve o Bundle.module por aqui (validado
  # por --selftest). Necessário pro alarme de notificações do #33 (exige app assinado).
  cp -R "${BUILD_DIR}/${BUNDLE}" "${APP_DIR}/Contents/Resources/${BUNDLE}"
  # Só no CI: o runner resolve o Bundle.module pela RAIZ do .app (Bundle.main.bundleURL) e o
  # Xcode ao lado do executável — mantemos essas cópias-extra apenas no CI (que não assina).
  # TODO(#33): pra a RELEASE também ter notificação, resolver a assinatura no CI sem a cópia da raiz.
  if [ -n "${CI:-}" ]; then
    cp -R "${BUILD_DIR}/${BUNDLE}" "${APP_DIR}/${BUNDLE}"
    cp -R "${BUILD_DIR}/${BUNDLE}" "${APP_DIR}/Contents/MacOS/${BUNDLE}"
  fi
fi

# Ícone do app: Master Ball.
if [ -f "icon/MasterBall.icns" ]; then
  cp "icon/MasterBall.icns" "${APP_DIR}/Contents/Resources/MasterBall.icns"
fi

# Info.plist — LSUIElement esconde do Dock; app fica só como overlay.
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.reload.prestreloajuda</string>
  <key>CFBundleExecutable</key><string>${BIN_NAME}</string>
  <key>CFBundleIconFile</key><string>MasterBall</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
  <key>CFBundleVersion</key><string>${APP_VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Assinatura ad-hoc do bundle. NECESSÁRIA pro sistema de Cooldown/Alarme (#33): o
# UserNotifications exige identidade estável — em .app SEM assinatura, requestAuthorization
# falha ("Notifications are not allowed") e nenhum alarme é agendado. `codesign --sign -` é
# grátis (não notariza), mas dá a identidade estável (bundle id com.reload.prestreloajuda).
# Não substitui a liberação de quarentena do usuário na 1ª abertura (ver LEIA-ME abaixo).
if [ -z "${CI:-}" ] && command -v codesign >/dev/null 2>&1; then
  if codesign --force --deep --sign - "${APP_DIR}"; then
    echo "==> Assinado ad-hoc (codesign) — necessário pro alarme de notificações."
  else
    echo "!! codesign ad-hoc falhou — o alarme (notificações) pode não registrar." >&2
  fi
fi

# Abridor de 1ª vez: o .app NÃO é notarizado (sem conta paga Apple), então todo download
# pela internet vem com `com.apple.quarantine` e o macOS diz "está danificado". Este
# .command (que vai junto no zip) tira a quarentena do app ao lado e abre — sem o usuário
# precisar digitar nada no Terminal. Na 1ª vez, abrir com botão direito > Abrir.
OPENER="dist/Abrir FarmOracleMMO (1a vez).command"
cat > "${OPENER}" <<'OPEN'
#!/bin/bash
cd "$(dirname "$0")"
APP="FarmOracleMMO.app"
echo "Liberando ${APP} (removendo quarentena do macOS)..."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null
open "$APP" && echo "Pronto! Da próxima vez é só abrir o app normalmente." || {
  echo "Não encontrei ${APP} nesta pasta. Deixe os dois juntos e rode de novo."; read -r _;
}
OPEN
chmod +x "${OPENER}"

# LEIA-ME dentro do zip: o .command acima parou de funcionar no macOS Sequoia (15+),
# onde a Apple removeu o atalho "botão direito > Abrir" para scripts/apps não notarizados.
# Estas instruções (xattr / Ajustes do Sistema) viajam junto com o download.
README_TXT="dist/LEIA-ME (macOS).txt"
cat > "${README_TXT}" <<'TXT'
COMO ABRIR O FarmOracleMMO NO MAC (só na primeira vez)

O app NÃO é notarizado pela Apple, então ao baixar o macOS o marca com "quarentena"
e mostra "está danificado" ou "a Apple não pôde verificar...". O app NÃO está
danificado — é a trava de segurança da Apple para apps fora da App Store.
Libere uma vez e pronto:

JEITO QUE SEMPRE FUNCIONA (Terminal)
  1. Abra o Terminal (Cmd+Espaco, digite Terminal, Enter).
  2. Digite isto com um ESPACO no final (sem dar Enter ainda):
        xattr -cr
  3. Arraste o FarmOracleMMO (o app) para dentro do Terminal — o caminho aparece sozinho.
  4. Aperte Enter.
  5. De duplo-clique no FarmOracleMMO. Abre normal (e em todas as proximas vezes).

ALTERNATIVA SEM TERMINAL (Ajustes do Sistema)
  1. De duplo-clique no app; no aviso, clique OK (NAO em "Mover para o Lixo").
  2. Ajustes do Sistema > Privacidade e Seguranca.
  3. Role ate o fim: aparece o FarmOracleMMO com o botao "Abrir Mesmo Assim". Clique.

OBS: no macOS ate o Sonoma (14) tambem da pra usar o arquivo
"Abrir FarmOracleMMO (1a vez).command" (botao direito > Abrir). No Sequoia (15+)
esse atalho foi bloqueado pela Apple — use o Terminal acima.
TXT

echo "==> Pronto: ${APP_DIR}  (v${APP_VERSION})"

# --- Paridade entre plataformas -------------------------------------------
# Este .app é a "versão de teste validada" do Mac. Antes de portar/lançar pro
# Windows e Android, o validador lista tudo que já existe aqui e ainda falta lá
# (ou o que fez a matriz divergir do código). NÃO bloqueia o build do Mac (|| true):
# é um checklist de porte. Fonte da verdade: tools/parity/features.json.
if command -v python3 >/dev/null 2>&1 && [ -f ../tools/parity/check.py ]; then
  echo ""
  echo "==> Paridade entre plataformas (checklist de porte p/ Windows/Android):"
  python3 ../tools/parity/check.py --quiet --no-md || true
  echo ""
fi

# No CI (GitHub Actions define CI=true) paramos aqui — só queremos o .app empacotado.
if [ -n "${CI:-}" ]; then
  echo "==> CI detectado: pulando publicação no Desktop."
  exit 0
fi

# --- Uso local: publica a VERSÃO DE TESTE na Área de Trabalho e abre ---
# Tudo que fazemos fica só nesta máquina como "versão de teste" (ícone marcado
# "(TESTE)"). Os usuários só recebem update via tag+push -> CI (version.json).
# A cada build, o ícone de teste da mesa é SUBSTITUÍDO pelo novo.
DESKTOP_APP="${HOME}/Desktop/${APP_NAME} (TESTE).app"
echo "==> Publicando versão de TESTE na Área de Trabalho..."
# O processo se chama pelo binário (DestruidorDeRed), não pelo nome do app.
killall "${BIN_NAME}" 2>/dev/null || true
killall "${APP_NAME}" 2>/dev/null || true
sleep 0.6
rm -rf "${DESKTOP_APP}"
# Remove ícones antigos pra não duplicar: nome de produção e o nome anterior.
rm -rf "${HOME}/Desktop/${APP_NAME}.app"
rm -rf "${HOME}/Desktop/Prestrelo Ajuda.app"
cp -R "${APP_DIR}" "${DESKTOP_APP}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${DESKTOP_APP}" 2>/dev/null || true
open -n "${DESKTOP_APP}"
echo "    Versão de teste atualizada e aberta: ${DESKTOP_APP}"
