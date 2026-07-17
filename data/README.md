# data — dados de jogo (fonte única)

Aqui mora **todo o conteúdo das lutas/rotas**, compartilhado por todas as plataformas
(Mac, Windows, Android). Edite aqui — não nas pastas dos apps.

## Conteúdo

- `red.json` — luta do Red
- `veteran.json` — Rota de Farm (Hoenn → Kanto → Sinnoh → Johto → Unova, incluindo a parada da Ocarina)
- `elite4_kanto.json`, `elite4_hoenn.json`, `elite4_sinnoh.json`, `elite4_johto.json`, `elite4_unova.json` — Elite 4 por região
- `sprites/` — ícones dos Pokémon (`{nome}.png`, minúsculo)
- `trainers/` — retratos de líderes/Elite 4/treinadores (`{nome}.png`)
- `regions/` — mapinhas das regiões (`{regiao}.png`)

## Como cada app usa

Cada plataforma **copia** estes arquivos para dentro do seu bundle ao compilar (ela não
referencia esta pasta em tempo de execução). No Mac, isso é feito por
[`mac/scripts/sync-data.sh`](../mac/scripts/sync-data.sh), chamado automaticamente pelo
`build-app.sh`.

## Formato dos JSON

Árvore de decisão *data-driven*. Resumo:

- `entryPoints` (ou `groups` → `entries`): o que o oponente pode mandar primeiro / seleção de região.
- `nodes`: cada nó tem `steps` (ações lineares) e um `branch` opcional:
  - `choice`: pergunta + `options` (botões) quando há várias possibilidades;
  - `goto`: salto automático para outro nó.
- Tipos de passo: `action` (instrução), `note` (observação), `setup` (pós-luta), `conditional` (tabela golpe → alvos).

Os dados são gerados/atualizados pelo pipeline em [`/tools`](../tools).
