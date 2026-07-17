# tools — pipeline de dados (Pokeking → FarmOracleMMO)

Como os roteiros da Elite 4 saem do **Pokeking** e viram os JSON em [`/data`](../data)
que os 3 apps consomem.

> **Caso de uso principal:** o site tem um campo **CODE** (página "account info") que, ao ser
> trocado, **muda os times da Elite 4**. As 5 regiões, os 25 treinadores e os leads continuam os
> mesmos — **o que muda são as soluções (roteiros)**. Então, sempre que você troca o CODE, é só
> **re-extrair** e **reconverter** pra atualizar o app. Este documento deixa esse caminho pronto.

> **Legenda:** ✅ = confirmado e testado · ⚠️ = ressalva importante.

---

## TL;DR — atualizar a Elite 4 (depois de trocar o CODE)

1. No site (logado), aplique o **CODE** do time desejado (account info → CODE → save).
2. F12 → Console → cole [`extract-pokeking-console.js`](extract-pokeking-console.js) inteiro → Enter.
   - Baixa **`pokeking_full.json`** (~500 KB) pra sua pasta de Downloads.
   - Se o Chrome bloquear a colagem: digite `allow pasting` + Enter e cole de novo.
3. Mova o arquivo pra `tools/` e rode:
   ```bash
   python tools/build_elite4.py            # lê tools/pokeking_full.json → grava data/elite4_*.json
   python tools/export_elite4_txt.py       # (opcional) gera árvores .txt no Desktop p/ revisar
   ```
4. Revise a tradução (ver passo 5) e lance a nova versão (ver [VERSIONING.md](../VERSIONING.md)).

O resto deste README explica cada peça e **como a API foi descoberta** (pra não se perder no futuro).

---

## Fluxo geral

```
Pokeking (site chinês de PokeMMO, http://pokeking.icu)
   │   API REST em  http://backend.pokeking.icu/api/   (auth via cookie web-token da sessão)
   ▼
[1] EXTRAIR     extract-pokeking-console.js (no F12)  → pokeking_full.json  (cru, em CHINÊS)
   ▼
[2] CONVERTER+  build_elite4.py  (usa clear_translate p/ traduzir CN→PT)  → data/elite4_*.json
    TRADUZIR
   ▼
[3] CONFERIR    export_elite4_txt.py  (árvore legível p/ revisão)
   ▼
[4] LANÇAR      scripts/bump-version + tag vX.Y.Z  (ver VERSIONING.md)
```

---

## 1. A API do Pokeking ✅ (descoberta via F12 / Network)

Base: **`http://backend.pokeking.icu/api/`**. Autenticação pelo cookie **`web-token`** (JWT da
sua sessão logada) — por isso a extração **roda no navegador, logado**; não dá pra fazer de fora.
O backend libera CORS pra origem `http://pokeking.icu`, então um `fetch(..., {credentials:'include'})`
rodando no Console do site funciona.

Endpoints usados (todos GET, exceto onde indicado):

| Endpoint | Para quê | Resposta |
|---|---|---|
| `area/list` | lista as **6 áreas** | `[{code, name}]` — ver áreas abaixo |
| `npc/listByArea?area=<CÓDIGO>` | **campeões** de uma região | `[{id, name}]` |
| `monsterRouter/listByNpc?npcId=<N>` | **todos os leads + árvore** de um campeão ⭐ | `{children:[ <nó-lead> ]}` |
| `monsterRouter/findRouter?npcId=<N>&monsterId=<M>` | árvore de **1 lead** só | `{success, result:<nó-lead>}` |

⭐ O `listByNpc` já devolve a **árvore completa** de todos os leads do campeão (testado: idêntico ao
`findRouter` lead a lead). Por isso o harvester faz **1 chamada por campeão** (~25 no total), e o
`findRouter` individual nem é usado.

**Áreas (`area/list`):**

| code | nome | conteúdo |
|---|---|---|
| `GUANDU` | 关都 / Kanto | 5 campeões (ids 1–5) |
| `FENGYUAN` | 丰源 / Hoenn | 5 campeões (ids 6–10) |
| `HEZHONG` | 合众 / Unova | 5 campeões (ids 11–15) |
| `SHENAO` | 神奥 / Sinnoh | 5 campeões (ids 16–20) |
| `CHENGDU` | 成都 / Johto | 5 campeões (ids 22–26) |
| `OTHER` | 其他 / "Outros" | 2 NPCs: **21 = 南瓜王 (Rei Abóbora)**, **27 = 赤红 (Red)** |

O harvester extrai só as 5 regiões da Elite 4. A área `OTHER` (Red / Rei Abóbora) fica de fora
de propósito — Red já existe em [data/red.json](../data/red.json) e o Rei Abóbora seria um modo
novo (a fazer, se quiser).

---

## 2. Formato cru do nó (router) ✅

Cada nó da árvore (em `listByNpc → children[]`) tem:

| Campo | Significado |
|---|---|
| `id` | id do nó. No nó-raiz de um lead, `id` = **monsterId** (o Pokémon do oponente) |
| `label` | nome (em chinês) do Pokémon **do oponente** (o lead, ou o que ele colocou em campo) |
| `operate` | ações do turno, separadas por vírgula chinesa `，` ou normal `,` |
| `attention` | aviso/observação (ex.: "não use Encore") |
| `lineList` | números do **time** que o oponente está usando (pós-luta / setup) |
| `children` | ramificações = **o que o oponente fez/colocou** depois (cada filho = 1 opção) |

A pergunta de ramificação no app é sempre *"O que o oponente fez / colocou em campo?"*, e cada
`label` de filho é uma resposta possível.

---

## 3. Extrair ✅ — [`extract-pokeking-console.js`](extract-pokeking-console.js)

Cole o arquivo inteiro no Console do F12 (site logado). Ele percorre
`area/list`(fixo nas 5 regiões) → `listByArea` → `listByNpc`, monta a estrutura
`{regions:[{code, champions:[{id, name, routers}]}]}` e **baixa `pokeking_full.json`**.

Tem um **sanity check**: se vier menos de 5 regiões / 25 campeões / 100 leads (ex.: sessão
deslogada), ele **não baixa** e avisa. Os dados parciais ficam em `window.__pkFull`.

> 🔎 **Como isso foi descoberto:** todo menu do site recarrega a página, então grampear XHR no
> console não sobrevivia. A captura saiu pela aba **Network** (com *Preserve log*): clicando num
> lead, a chamada `findRouter` aparecia; o **Copy as cURL** revelou a URL, os parâmetros e o
> cookie `web-token`. A partir daí, sondando endpoints irmãos no Console, achamos `listByArea` e
> `listByNpc`. (Em paralelo, a extensão **"Pokeking Translator"** — `content.js` + dicionário —
> traduzia a página ao vivo, mas a tradução do dado é feita offline pelo passo 5; pra extrair, a
> API basta.)

---

## 4. Converter ✅ — [`build_elite4.py`](build_elite4.py)

```bash
python tools/build_elite4.py [entrada.json] [dir_saida]
#   entrada.json  default: tools/pokeking_full.json
#   dir_saida     default: data/
```

Lê o dump, traduz com [clear_translate.py](clear_translate.py) e grava `elite4_<regiao>.json`
no formato do app (campeão = grupo; lead = entrada). Mapeia os códigos de região
(`GUANDU`→Kanto, etc.).

> ⚠️ **POKEKING_TEAM (apelidos do SEU time):** o apelido chinês de cada membro do time muda
> conforme o CODE/time (ex.: `蛙` = Toxicroak no Shadow Scale, mas = Poliwrath no Dingxianyou).
> O `clear_translate.py` é **parametrizado por time** via a env var `POKEKING_TEAM`
> (default: `shadow_scale`). **Ao re-gerar um time, exporte o time certo**, senão os Pokémon do
> seu time saem com os nomes do time antigo:
> ```bash
> POKEKING_TEAM=dingxianyou python tools/build_elite4.py tools/pokeking_full.json data/teams/dingxianyou
> ```
> Os times configurados ficam no dict `TEAMS` no topo do `clear_translate.py` (membro→Pokémon,
> stat de buff, aliases). Time novo = adicionar uma entrada lá (os CODEs de cada time estão no [`data/teams.json`](../data/teams.json)).
> Depois do build, rode `tools/traduzir-roteiros.py` no time e (re)injete `warning`/`sequentialGroups`.

> 💡 **Dica:** rode primeiro pra um diretório de teste e compare antes de sobrescrever `data/`:
> ```bash
> python tools/build_elite4.py tools/pokeking_full.json tools/_test_out
> ```

### Conversor alternativo — [`pokeking_to_solve.py`](pokeking_to_solve.py)

Para uma **região/campeão avulso** (sem o dump completo). Entrada no formato
`{id, title, champions:{Campeão:{Lead:<result>}}}` (ver [_e4_input.json](_e4_input.json)),
já traduzida pelo [translate.py](translate.py). Útil pra extrair só um boss novo (ex.: a área `OTHER`).

---

## 5. Tradução (CN → PT) ✅ e suas ressalvas ⚠️

- [clear_translate.py](clear_translate.py) — tradução "em português claro" (gíria do nosso time
  fixo + termos), usada pelo `build_elite4.py`.
- [translate.py](translate.py) — substituição simples via [pokeking-dictionary.json](pokeking-dictionary.json)
  (CN→EN/PT, chaves mais longas primeiro — mesma lógica do `content.js` da extensão).

⚠️ **A tradução automática NÃO fica 100%.** Uma re-geração fresca deixa ~10–17 trechos em chinês
por região e algum inglês cru. As correções da **v1.1.1 foram feitas à mão, direto nos
`data/elite4_*.json`** (não no dicionário) — então **re-gerar por cima perde essas correções**.

**Implicação prática para o seu fluxo (trocar o CODE):** quando o time muda, os roteiros são
outros, então re-gerar é o certo — mas reserve um tempo de **revisão de tradução** depois (ver
[TRADUCAO-PENDENTE.md](../TRADUCAO-PENDENTE.md)). **Para reduzir esse trabalho a cada extração,
o ideal é migrar as correções para o `pokeking-dictionary.json`** (ver pendências) — aí a
tradução melhora sozinha a cada re-geração, em vez de exigir conserto manual no JSON.

---

## 6. Conferir ✅

```bash
python tools/export_elite4_txt.py
```

Gera `Elite4-<Regiao>.txt` (árvore completa, legível) no Desktop, lendo `data/elite4_*.json`.
Use para revisar tradução e lógica antes de lançar.

---

## 7. Lançar ✅

Os dados são **copiados** para dentro de cada app na compilação (não lidos em runtime). Depois de
atualizar `/data`, suba a versão dos 3 apps juntos e crie a tag — ver
[VERSIONING.md](../VERSIONING.md) e [data/README.md](../data/README.md).

---

## Notas de compatibilidade (Windows) ✅

Os scripts foram escritos no Mac do autor. Já corrigidos para rodar no Windows também:
leem/escrevem em **UTF-8 explícito** e usam `os.path` (não `/` cravado). Se mexer neles, mantenha
`encoding="utf-8"` em todo `open()` e `sys.stdout.reconfigure(encoding="utf-8")` antes de imprimir.

---

## Pendências para deixar o processo ainda melhor

- [ ] **Migrar as correções de tradução da v1.1.1 (e futuras) para o `pokeking-dictionary.json`**,
      em vez de editar o JSON na mão — assim cada re-extração já sai limpa. (Dá pra extrair os
      pares CN→PT do diff do commit `9f5e846`.)
- [ ] **Extrair a área `OTHER`** (Red npc 27, Rei Abóbora npc 21) se quiser virar modo no app.
- [ ] **Salvar a extensão "Pokeking Translator"** (`content.js`, `manifest`) em `tools/` — hoje só
      sobrou o dicionário.
