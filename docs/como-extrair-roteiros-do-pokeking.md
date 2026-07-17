# Como extrair os roteiros do Pokeking (CODE → JSON do app)

> Este artigo documenta como os guias de batalha do FarmOracleMMO nascem: extração dos
> roteiros do **Pokeking** com a sua própria conta, conversão pro formato do app e tradução.
> É o mesmo processo que usamos em toda atualização de dados.
>
> 🇺🇸 English version: [Extracting battle routes from Pokeking](en/extracting-pokeking-routes.md)

## O que é o Pokeking (e o que é o CODE)

O **[Pokeking](http://pokeking.icu)** é um guia chinês de PokeMMO que mapeia, luta a luta, como
vencer a Elite 4: para cada um dos 25 treinadores (5 regiões × 5 campeões), ele tem uma **árvore
de decisão** — "o oponente colocou X em campo → faça Y". É a fonte da verdade dos solves do
FarmOracle.

O detalhe que faz tudo funcionar é o **CODE**: na página *account info* do site existe um campo
`CODE` que define **qual time de jogador** as soluções assumem. Trocou o CODE → o site passa a
mostrar os roteiros calculados para aquele time (os 25 treinadores e os leads continuam os
mesmos; o que muda são as **respostas**). Cada time do FarmOracle corresponde a um CODE — eles
estão no campo `code` do [`data/teams.json`](../data/teams.json), e o app mostra cada um pra você
aplicar no site.

## O que você precisa

1. **Conta no Pokeking, logada no navegador** — a API do site só responde com o cookie de sessão
   (`web-token`, um JWT que expira em horas). Não dá pra extrair "de fora".
2. **O CODE do time** que você quer extrair (ex.: os do `data/teams.json`, ou um CODE novo que
   alguém da comunidade compartilhou).
3. Python 3 para a conversão (`tools/build_elite4.py`).

## Passo 1 — Aplicar o CODE

No site (logado): **account info → campo CODE → colar → save**. A partir daí toda a navegação
de Elite 4 do site mostra os roteiros daquele time.

## Passo 2 — Extrair pelo Console (F12)

Abra o DevTools (**F12 → Console**) em qualquer página do site logado e cole o conteúdo inteiro
de [`tools/extract-pokeking-console.js`](../tools/extract-pokeking-console.js) → Enter.

- O script percorre as 5 regiões → 25 campeões → todos os leads, monta um JSON único e **baixa
  `pokeking_full.json`** (~500 KB, em chinês) na sua pasta de Downloads.
- Se o Chrome bloquear a colagem, digite `allow pasting` + Enter e cole de novo.
- Tem **sanity check**: se vier menos de 5 regiões / 25 campeões / 100 leads (sessão caiu, CODE
  errado), ele **não baixa** e avisa no console.

### Como a API foi descoberta (a parte divertida)

Todo clique de menu do Pokeking recarrega a página, então grampear XHR no Console não
sobrevivia. O caminho foi a aba **Network** com *Preserve log* ligado: ao clicar num lead, a
chamada `findRouter` aparecia; o **Copy as cURL** revelou a URL base
(`http://backend.pokeking.icu/api/`), os parâmetros e o cookie `web-token`. Dali, sondando
endpoints "irmãos" no Console, chegamos aos que importam:

| Endpoint | Para quê |
|---|---|
| `area/list` | lista as 6 áreas (5 regiões da E4 + "outros": Red e Rei Abóbora) |
| `npc/listByArea?area=<código>` | os 5 campeões de uma região |
| `monsterRouter/listByNpc?npcId=<N>` | ⭐ a **árvore completa de todos os leads** de um campeão |

O ⭐ é o pulo do gato: `listByNpc` devolve tudo de uma vez, então a extração inteira são só
**~25 chamadas**. O backend libera CORS pra origem do próprio site, por isso o script roda no
Console (com `credentials: 'include'`) e não precisa de nada instalado.

### O formato cru

Cada nó da árvore tem `label` (o Pokémon que o oponente colocou, em chinês), `operate` (as ações
do seu turno), `attention` (avisos), e `children` (as ramificações — cada filho é uma resposta
possível à pergunta "o que o oponente fez?").

## Passo 3 — Converter pro formato do app

```bash
mv ~/Downloads/pokeking_full.json tools/
python3 tools/build_elite4.py                 # → data/elite4_<regiao>.json
```

Para um time específico (os apelidos chineses dos SEUS Pokémon mudam por time — `蛙` é
Toxicroak num time e Poliwrath em outro), exporte a env var `POKEKING_TEAM`:

```bash
POKEKING_TEAM=dingxianyou python3 tools/build_elite4.py tools/pokeking_full.json data/teams/dingxianyou
```

Os times configurados vivem no dict `TEAMS` do [`tools/clear_translate.py`](../tools/clear_translate.py)
— time novo = adicionar uma entrada lá (membro→Pokémon, stat de buff, aliases).

> 💡 Rode primeiro pra um diretório de teste (`tools/_test_out`) e compare com o `data/` atual
> antes de sobrescrever.

## Passo 4 — Tradução e revisão

A tradução CN→PT/EN é automática ([`clear_translate.py`](../tools/clear_translate.py) +
[`pokeking-dictionary.json`](../tools/pokeking-dictionary.json), chaves mais longas primeiro),
**mas não fica 100%**: uma geração fresca deixa um punhado de trechos em chinês ou inglês cru
por região. Depois do build:

1. `python3 tools/export_elite4_txt.py` — gera árvores `.txt` legíveis pra revisar.
2. Corrija **no dicionário** (não no JSON final) sempre que possível — assim a próxima
   re-extração já sai limpa.
3. Regra de ouro: **em dúvida de batalha, não chute** — confira no próprio Pokeking.

## Bônus 1 — Pegar os TIMES dos adversários (catálogo completo)

Além dos roteiros, dá pra extrair o **catálogo dos times dos 25 treinadores** (cada Pokémon com
habilidade, item e os 4 golpes). Esse dado **independe de CODE** — é a tabela global do site:

```bash
WEB_TOKEN='eyJ...' python3 tools/harvest-pokeking-teams.py
python3 tools/build-opponents-catalog.py      # traduz → data/elite4-opponents.json
```

- O `WEB_TOKEN` é o valor do cookie `web-token` da sua sessão logada (F12 → Application →
  Cookies). Expira em poucas horas — extraiu, usou.
- O endpoint por trás é o `player/findById?id=N` (a tabela crua completa; `area`/`npc` vêm
  nulos e são parseados do `fullName`). O `player/lineupMatch` (POST) é a variante filtrada
  pelo CODE.

## Bônus 2 — Cadastrar um time NOVO no app (via CODE)

Alguém da comunidade compartilhou um CODE novo? O caminho completo:

1. **Aplique o CODE** no site e confira os 6 Pokémon do time (account info).
2. **Extraia** os roteiros (passo 2) — o dump sai calculado pra esse time.
3. **Cadastre o time** no dict `TEAMS` do [`tools/clear_translate.py`](../tools/clear_translate.py):
   apelido chinês de cada membro → Pokémon, stat de buff e aliases.
4. **Converta** com `POKEKING_TEAM=<id_do_time>` (passo 3) pra `data/teams/<id_do_time>/`.
5. **Adicione a entrada** no [`data/teams.json`](../data/teams.json) (id, nome, CODE, pokémon,
   link do PokéPaste) — é esse manifesto que faz o time aparecer no seletor do app.
6. Traduza/revise (passo 4) e valide (passo 5). PT **e** EN, sempre.

## Passo 5 — Validar

```bash
python3 tools/validate-data.py    # JSON válido + todos os modos de todo time
python3 tools/parity/check.py     # o dado vale pras 3 plataformas
```

Os dados de `/data` são copiados pra dentro dos 3 apps na compilação — atualizou, os três
recebem juntos.

## Ética e limites

- **Use a sua própria conta** e o seu próprio `web-token` — o script roda na SUA sessão.
- **Não republique os dumps crus** (`pokeking_full.json` etc.): o conteúdo bruto é trabalho do
  Pokeking. O que este repositório versiona é o dado **derivado, convertido e traduzido** que o
  app consome — com crédito à fonte.
- O Pokeking é a fonte da verdade dos solves: se o guia do app divergir do site, o site vence
  (e a gente corrige o dado).
