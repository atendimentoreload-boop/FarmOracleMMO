# Versionamento

Os 3 apps (**Mac**, **Windows**, **Android**) compartilham **uma única versão**, definida no
arquivo [`VERSION`](VERSION) na raiz do monorepo.

## Regra de ouro

> **Qualquer atualização deve ser testada primeiro. Ao compilar/lançar, a versão dos 3 sobe junto.**

Nunca edite a versão à mão em cada projeto — use o script de bump, que mantém tudo em sincronia.

## Onde a versão aparece

| Plataforma | Arquivo | Campo |
| --- | --- | --- |
| Fonte única | `VERSION` | `1.1.0` |
| Windows | `windows/PrestreloAjuda/PrestreloAjuda.csproj` | `<Version>` |
| Android | `android/app/build.gradle.kts` | `versionName` + `versionCode` |
| macOS | `mac/Sources/DestruidorDeRed/Version.swift` | `AppVersion.current` |

Cada app mostra a versão no rodapé do menu inicial (ex.: `v1.1.0`).
O `versionCode` do Android é derivado automaticamente: `major*10000 + minor*100 + patch`
(ex.: `1.1.0 → 10100`).

## Como subir a versão

Na raiz do repo (`prestrelo-ajuda/`):

```bash
# Windows (PowerShell)
./scripts/bump-version.ps1 patch      # 1.1.0 -> 1.1.1
./scripts/bump-version.ps1 minor      # 1.1.0 -> 1.2.0
./scripts/bump-version.ps1 major      # 1.1.0 -> 2.0.0
./scripts/bump-version.ps1 1.4.2      # define exata

# Mac / Linux (bash)
./scripts/bump-version.sh patch
```

O script atualiza os 4 pontos de uma vez. Depois é só **compilar cada plataforma** — todas
saem com a mesma versão nova.

## Fluxo recomendado por atualização

1. Fazer a mudança numa branch.
2. **Testar** na(s) plataforma(s) afetada(s).
3. Rodar o `bump-version` (escolhendo patch/minor/major).
4. Compilar e publicar nos 3 (ou nas plataformas que já têm release).
5. Commitar com a versão no commit/tag.

## Arquitetura de distribuição (2 repositórios)

- **`prestrelo-ajuda` (PRIVADO):** este repo — todo o código-fonte, dados e scripts.
- **`prestrelo-ajuda-download` (PÚBLICO):** distribuição — `version.json` + Releases (apk/exe/app).

Os apps leem a versão e baixam atualização **do repo público**. O código fica privado.

> ⚠️ Há **dois** `version.json`: o deste repo (atualizado pelo `bump-version`, é a "fonte")
> e o do repo público (o que os apps **de fato leem**). No release, você copia/sobe o
> `version.json` para o repo público (ver passo a passo abaixo).

## Atualização obrigatória (bloqueio de versão antiga)

Os 3 apps checam, **ao abrir**, o `version.json` publicado no repo **público**:

```
https://raw.githubusercontent.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/main/version.json
```

```json
{ "latest": "1.1.0", "minimum": "1.0.0", "url": ".../releases/latest" }
```

- Se a versão local **< `minimum`** → o app **trava** numa tela "Atualização obrigatória"
  com botão de download. Não dá pra usar até atualizar.
- **Fail-open:** se não conseguir checar (GitHub fora do ar), o app **não** bloqueia.
  (O jogo é online, então na prática o jogador sempre tem internet ao abrir.)

### Passo a passo de um release

1. Corrigir + **testar** (repo privado).
2. `./scripts/bump-version.ps1 patch|minor|major` (atualiza versão dos 3 + `version.json` deste repo).
3. Compilar os 3 apps (Windows `.exe`, Android `.apk`, macOS `.app`).
4. No repo **público** `prestrelo-ajuda-download`:
   - Criar uma **Release** com os arquivos compilados anexados.
   - Atualizar o `version.json` (copie o deste repo) → **commit + push na `main`**.
5. Se for **forçar** todo mundo a sair da versão antiga: no `version.json` do repo público,
   suba o `"minimum"` para a versão obrigatória e push.

> ⚠️ O `bump-version` atualiza só o `"latest"`. O `"minimum"` é mexido **à mão**, de propósito,
> porque forçar atualização é decisão deliberada (quebra quem está na versão antiga).

> 📌 O bloqueio lê o `version.json` do **repo público**. Só vale depois de commitado/pushado lá.
> Fora isso, fail-open (se não conseguir ler, não bloqueia).
