# Prestrelo Ajuda — Android

App nativo Android (Kotlin + Jetpack Compose) do guia turno-a-turno do PokeMMO.
Mesma fonte de dados das versões Mac/Windows (`/data`), copiada para os assets na build.

## Pré-requisitos (uma vez)

- **JDK 17** — `brew install openjdk@17`
- **Android SDK** — `brew install --cask android-commandlinetools`
  então: `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`
- Ajuste `local.properties` com `sdk.dir=<caminho do SDK>`
  (ex.: `/opt/homebrew/share/android-commandlinetools`)

## Build

```bash
export JAVA_HOME="$(brew --prefix openjdk@17)"
bash scripts/sync-data.sh        # copia /data -> assets
./gradlew assembleDebug          # gera app/build/outputs/apk/debug/app-debug.apk
```

## Instalar/testar

- **Celular**: ative a Depuração USB, plugue e `adb install -r app-debug.apk`.
- **Emulador**: `sdkmanager "emulator" "system-images;android-34;google_apis;arm64-v8a"`,
  crie um AVD com `avdmanager`, rode `emulator -avd <nome>` e `adb install`.

## Estrutura

- `app/src/main/java/com/reload/prestreloajuda/`
  - `model/Solve.kt` — modelo data-driven (espelho do Swift/C#)
  - `engine/SolveEngine.kt` — máquina de estados do roteiro
  - `data/SolveLoader.kt` — lê os JSON dos assets
  - `ui/` — Compose (menu de modos, roteiro, colorizer, tema)
- `scripts/sync-data.sh` — sincroniza `/data` para `assets/data`

## Status

✅ App funcional (menu de modos, roteiro turno-a-turno, sprites, cores, alerta âmbar).
🚧 Overlay flutuante sobre o jogo (próximo passo).
