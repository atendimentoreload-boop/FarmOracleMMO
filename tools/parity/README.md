# Sistema de Paridade entre plataformas

Garante que **toda feature exista nas 3 plataformas (macOS · Windows · Android)** —
a não ser que esteja **explicitamente** marcada como exclusão intencional.

É o antídoto pro problema clássico: "a rota de farm tem 1 time a menos no Windows e
faltam os menus escondidos" — coisas que existiam no Mac/Android mas nunca foram portadas.

## Peças

| Arquivo | O que é |
|---|---|
| `tools/parity/features.json` | **Fonte da verdade.** A matriz: cada feature, por plataforma, tem um `status` e uma `sig` (assinatura de código). Você edita **aqui**. |
| `tools/parity/check.py` | O **validador**. Confere a assinatura no código real, aplica a regra de paridade e gera o `PARIDADE.md`. |
| `PARIDADE.md` (na raiz) | Matriz **legível**, gerada automaticamente. Não edite à mão. |

## Como funciona a verificação

Para cada feature × plataforma, o `status` pode ser:

- **`done`** — feita. A `sig` (um trecho real de código) **precisa** existir no fonte da
  plataforma. Se não existir, o validador acusa: *a matriz está mentindo* (ou a feature quebrou).
- **`todo`** — ainda não feita nesta plataforma. Se ao menos uma outra plataforma tiver
  `done`, isso vira **pendência de paridade**. Se a `sig` for encontrada no código, o validador
  avisa pra você reclassificar como `done`.
- **`excluded`** — de propósito **fora** desta plataforma. Exige `reason`.
- **`na`** — não se aplica (paradigma diferente, ex.: teclas F1..F12 num app de toque). Exige `reason`.
- **`"manual": true`** — pula a checagem de código (diferença comportamental que não dá pra
  provar por um grep simples). Usa só o status declarado.

**Regra de paridade:** se UMA plataforma é `done`, todas as outras precisam ser
`done`, `excluded` ou `na`. Qualquer `todo` é uma pendência a resolver antes de lançar.

## Onde o sistema é ENFORCADO

O **portão bloqueante** é o CI: o job **`verify-parity`** em
[.github/workflows/release.yml](../../.github/workflows/release.yml) roda o modo completo
(`python3 tools/parity/check.py`) e é `needs` do `create-release`. **Com qualquer pendência
de paridade (ou matriz fora de sincronia com o código), a Release nem é criada** — é a regra
"nunca lançar com uma plataforma atrás" aplicada por máquina, não por disciplina. Ele também
confere que o `PARIDADE.md` commitado está atualizado (`git diff --exit-code`).

> Consequência: enquanto houver `todo` numa feature que é `done` em outra plataforma, o próximo
> `git tag && push` falha no CI até você **portar** ou **marcar exclusão** (`excluded`/`na` + `reason`).

Não engatamos o gate no build do Windows (`.csproj`) nem no Gradle de propósito: **Python não
vem por padrão no Windows** (e lá o executável é `python`/`py`, não `python3`), o que quebraria
o build de quem não tem. O runner do CI tem Python — é o lugar certo pra travar.

## Fluxo de uso

### 1. Ao compilar a versão de teste validada (Mac)
O `mac/scripts/build-app.sh` roda o validador no fim e imprime o **checklist de porte**
(o que existe no Mac e falta no Windows/Android). É só um lembrete local — **não bloqueia** o
build do Mac (o bloqueio real é o CI, acima).

### 2. Antes de compilar/portar/lançar cada plataforma (manual)
Rode o **portão** da plataforma-alvo. Ele lista o que falta e falha (exit 1) só por problemas
**daquela** plataforma (inconsistências de outras viram aviso não-fatal):

```bash
python3 tools/parity/check.py --gate windows
python3 tools/parity/check.py --gate android
python3 tools/parity/check.py --gate mac
```

Aí você tem duas saídas por item:
- **portar a feature** pra aquela plataforma (e mudar o status pra `done` + assinatura), ou
- **marcar como exclusão intencional** (`excluded`/`na` + `reason`) no `features.json`.

Enquanto houver pendência sem uma dessas decisões, o portão falha — foi o combinado:
nada de lançar uma plataforma atrás das outras.

### 3. Relatório completo / regenerar o PARIDADE.md
```bash
python3 tools/parity/check.py          # matriz + problemas + regenera PARIDADE.md
python3 tools/parity/check.py --no-md  # sem regenerar o .md
```

## Quando criar uma feature nova

1. Adicione uma entrada em `features.json` **já com as 3 plataformas**.
2. A(s) que ainda não têm = `todo`. Conforme implementa, troca pra `done` + `sig`.
3. Se uma plataforma não deve ter, marque `excluded`/`na` **com `reason`** — aí o portão
   não reclama.

Assim, toda feature nova nasce rastreada nas 3 plataformas por padrão.

## Como escolher uma boa `sig` (assinatura)

Um trecho **curto e único** que só aparece se a feature existir: nome de função/classe/enum,
uma constante, uma string literal de UI. Ex.: `func setFarmRoute(` (Swift), `SetFarmRoute`
(C#), `onSelectFarmRoute` (Kotlin). Evite palavras genéricas (`red`, `next`) que casam com
qualquer coisa. O validador faz busca literal (substring) só em arquivos de código
(`.swift`, `.cs`, `.xaml`, `.kt`, `.xml`), ignorando `bin/`, `obj/`, `.build/`, etc.
