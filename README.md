# FarmOracleMMO

**O assistente de farm do PokeMMO que te fala, turno a turno, exatamente o que fazer em cada luta.**
Elite 4, reruns de ginásio, Red, Cynthia & Morimoto e Ho-Oh — tudo no passo a passo, num overlay
que fica por cima do jogo. Grátis, em Português e Inglês, para **Windows, macOS e Android**.

> 📜 **Leia primeiro: [Sobre o projeto](SOBRE-O-PROJETO.md)** — por que o código foi aberto e a
> condição de uso (**é proibido vender**). Projeto de estudo que cresceu com a comunidade.
>
> 🇺🇸 **English?** [Jump to the English section](#english) · Article: [Extracting routes from Pokeking](docs/en/extracting-pokeking-routes.md)

- ⬇️ **Download (sempre a versão mais atual):** https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest
- 💬 **Discord da comunidade:** https://discord.gg/9jCuB6BDBC
- 🧵 **Tópico no fórum do PokeMMO:** [FarmOracleMMO — a turn-by-turn battle helper](https://forums.pokemmo.com/index.php?/topic/198436-farmoraclemmo-a-turn-by-turn-battle-helper-for-red-gym-farm-the-elite-4-windows-%C2%B7-mac-%C2%B7-android/)

## O que tem dentro

- ⚔️ Guias de batalha turno a turno (vários times de Elite 4, ginásios em dupla, Red, C&M, Ho-Oh)
- 🧭 Overlay ajustável (opacidade, tamanho de fonte A−/A/A+, atalhos F1–F12)
- ⏱️ Cronômetros de cooldown por personagem (E4, ginásio, Red, C&M, rota de treinadores)
- 🌱 Plantação com aviso de regar/colher
- 📋 PokéPaste de cada time (IVs, itens, ataques) + manual de quem criou o time
- 🔁 Botão "funcionou / não funcionou" em cada solve — o feedback melhora os guias
- 🇧🇷🇺🇸 Todo conteúdo em PT **e** EN

## Estrutura do repositório

| Pasta | O que é |
|---|---|
| [`mac/`](mac/) | App macOS (Swift / SwiftUI) |
| [`windows/`](windows/) | App Windows (C# / WPF) |
| [`android/`](android/) | App Android (Kotlin / Compose) |
| [`data/`](data/) | **Fonte única de dados** consumida pelas 3 plataformas (times, rotas, solves, PT+EN) |
| [`tools/`](tools/) | Pipeline de dados: extração do Pokeking, conversão, tradução CN→PT/EN, validadores |
| [`tools/parity/`](tools/parity/) | Sistema de paridade — garante toda feature nas 3 plataformas |
| [`manual/`](manual/) | Manuais em PDF (PT + EN) |
| [`docs/`](docs/) | Artigos — como os dados nascem ([extração do Pokeking](docs/como-extrair-roteiros-do-pokeking.md)) |
| [`HUB-DE-ATUALIZACOES.md`](HUB-DE-ATUALIZACOES.md) | Histórico real de pedidos/decisões/pendências ([versão visual](HUB.html)) — o mapa pra quem quiser continuar |

## Como compilar

**macOS** (Xcode / Swift 5.9+):
```bash
cd mac && swift build            # binário de desenvolvimento
./scripts/build-app.sh           # gera o .app
```

**Windows** (.NET 8 SDK):
```powershell
cd windows
dotnet build -c Release
```

**Android** (Android Studio ou CLI, JDK 17):
```bash
cd android && ./gradlew assembleDebug
```
> O APK de release exige um keystore próprio (não versionado). Configure o seu em `android/keystore/`.

## De onde vêm os dados

Os roteiros de batalha vêm do **[Pokeking](http://pokeking.icu)** (guia chinês de PokeMMO) — a
fonte da verdade dos solves — extraídos com a sua própria conta, convertidos e traduzidos pelo
pipeline em [`tools/`](tools/README.md). O processo completo está documentado no artigo
**[Como extrair os roteiros do Pokeking](docs/como-extrair-roteiros-do-pokeking.md)**.

Antes de commitar mudanças em `data/`, rode os validadores:
```bash
python3 tools/validate-data.py    # JSON válido + todos os modos presentes
python3 tools/parity/check.py     # paridade entre as 3 plataformas
```

## Contribuindo

- Entre no [Discord](https://discord.gg/9jCuB6BDBC) — bugs, ideias e novos times passam por lá.
- Todo conteúdo novo sai **em PT e EN** (nunca só num idioma).
- Toda feature nova precisa existir (ou ter plano) **nas 3 plataformas** — o
  [`tools/parity/check.py`](tools/parity/) é o portão.

## Licença

[PolyForm Noncommercial 1.0.0](LICENSE) — pode usar, estudar, modificar e redistribuir
**para qualquer fim não comercial**. **Vender este app ou qualquer derivado é expressamente
proibido** — leia [Sobre o projeto](SOBRE-O-PROJETO.md).

Créditos: comunidade FarmOracle (pedidos, testes, times e traduções) e **Pokeking** pelos
roteiros que fazem tudo isso funcionar. Este projeto não é afiliado ao PokeMMO nem ao Pokeking.

---

# English

**FarmOracleMMO is a free PokeMMO farming assistant that tells you, turn by turn, exactly what
to do in every battle** — Elite 4, gym reruns, Red, Cynthia & Morimoto and Ho-Oh — in an overlay
on top of the game. Portuguese and English, for **Windows, macOS and Android**.

- ⬇️ **Download:** https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest
- 💬 **Discord:** https://discord.gg/9jCuB6BDBC
- 📖 **Article:** [Extracting battle routes from Pokeking](docs/en/extracting-pokeking-routes.md)

**Repo layout:** `mac/` (Swift), `windows/` (C#/WPF), `android/` (Kotlin/Compose), `data/`
(single source of truth for all 3 platforms, PT+EN), `tools/` (Pokeking extraction, conversion,
translation and validation pipeline), `manual/` (PDF manuals).

**Building:** `cd mac && swift build` · `cd windows && dotnet build -c Release` ·
`cd android && ./gradlew assembleDebug` (release APKs need your own keystore — never committed).

**Data:** battle routes come from **[Pokeking](http://pokeking.icu)** (Chinese PokeMMO guide),
extracted with your own logged-in account and converted by the [`tools/`](tools/README.md)
pipeline. Run `python3 tools/validate-data.py` and `python3 tools/parity/check.py` before
committing data changes. All new content ships in **both PT and EN**, and every feature must
exist on **all 3 platforms**.

**License:** [PolyForm Noncommercial 1.0.0](LICENSE) — use, study, modify and redistribute for
any **noncommercial** purpose; **selling this app or any derivative is expressly prohibited**
(see [About this project](SOBRE-O-PROJETO.md), English section included). Credits: the
FarmOracle community and **Pokeking** for the routes. Not affiliated with PokeMMO or Pokeking.
