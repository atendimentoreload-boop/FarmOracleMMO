# Catálogo de Cooldowns/Berries do PokeMMO — para o sistema de CD (#33)

> Pesquisado em fontes oficiais (Support KB do PokeMMO, ShoutWiki, Fandom, pokemmohub, fórum oficial) com verificação por 2ª fonte (workflow 04/07). **Confiança marcada em cada item; o que não teve fonte firme está "⚠️ a confirmar" — nunca chutado** (ver [[seguir-guia-nunca-inventar]]). Âncora do protótipo: Elite 4 = 6h ✅ e Red = 168h ✅ batem; **"Rota de Farm = 20h" NÃO bate com nenhuma batalha** (ver §5).

## 1) Batalhas
| Atividade | CD | Confiança | Fonte | Cadastro |
|---|---|---|---|---|
| **Elite 4** — Kanto/Johto/Hoenn/Sinnoh/Unova (inclui Campeão) | **6h** | alta | Support KB + ShoutWiki | ✅ padrão |
| **Rebatalha de Ginásio** (gym rerun) | **18h** (só após vencer a E4 da região) | alta (3 fontes) | Support KB + ShoutWiki + Fandom | ✅ padrão (o "24h" antigo está **errado**) |
| **Red** — Monte Silver | **168h** (1×/semana) | alta | ShoutWiki + changelog 18/10/2023 | ✅ padrão |
| **Morimoto** — Castelia (Unova) | **~24h** (reset diário) | alta | X oficial PokeMMO + Fandom | ✅ padrão |
| **Cynthia** — Undella (Unova) | **18h OU 24h**, sazonal (primavera / primavera+verão) | ⚠️ incerto (conflito de fontes oficiais) | ShoutWiki Repeatable Events (18h) vs wiki Cynthia (24h, só primavera) | ⚠️ a confirmar |
| Treinadores comuns (rematch) | 6h **ou** 18h (varia) + vencer 5 treinadores | alta | Support KB | opcional (não é valor único) |
| Treinadores Ricos/Notáveis | 6h? | incerto (1 fonte) | ShoutWiki | opcional |
| Groomers (subir amizade) | 18h? | incerto (1 fonte) | ShoutWiki | opcional |
| Steven — Meteor Falls | **sem rebatalha** (luta única) | média | fórum | ❌ não cadastrar |

**⏱️ Detalhe crítico do alarme da E4:** o timer de 6h começa ao **ENTRAR** na sala (falar com os 2 guardas), **não** ao vencer (2 threads do fórum oficial, confiança média). O "marcar" da E4 = ao entrar.

**Cynthia ≠ Morimoto:** são **duas batalhas separadas** em Unova (Undella e Castelia), com CDs diferentes — não um item só.

## 2) Berries (plantar → regar → colher)
**Mecânica confirmada (alta):** planta só em **Hoenn e Unova** (Loamy Soil); Wailmer Pail (grátis) rega, Harvesting Tool colhe (**$250 ou $350?** — conflito). O crescimento é **FIXO por tier** (regar **não acelera**, só mantém o yield). **Janela de colheita (wilt) = 8h** após crescer 100% (o número mais firme do dataset). Sem mulch/adubo no PokeMMO. Plots: Route 104=11, 120=10, 123=12, Mistralton=72, Abundant Shrine=84.

| Tier | Crescimento | Yield | Regas* | Berries |
|---|---|---|---|---|
| T1 | **16h** | 3–6 | 1× | Cheri, Chesto, Pecha, Rawst, Aspear, Oran, Persim, Razz, Bluk, Nanab, Wepear, Pinap |
| T2 | **20h** | 4–7 | 2× | **Leppa**, Figy, Wiki, Mago, Aguav, Iapapa, Cornn, Magost, Rabuta, Nomel |
| T3 | **42h** | 7–9 | 3× | Resistência de tipo (Occa, Passho, Wacan, Rindo, Yache, Chople…) + Enigma |
| T4 | **44h** | 7–10 | 3× | **EV berries** (Pomeg-HP, Kelpsy-Atk, Qualot-Def, Hondew-SpA, Grepa-SpD, Tamato-Spe) + Lum, Sitrus, Custap, Jaboca, Micle |
| T5 | **67h** | 10–13 | 4× | Liechi, Ganlon, Salac, Petaya, Apicot, Starf, Lansat |

Crescimento (16/20/42/44/67h) e wilt (8h) = **alta confiança** (pokemmohub + ShoutWiki + Fandom).
**\* Contagem de rega (1×/2×/3×/3×/4×) e janelas (1ª rega 7h/8h; entre regas 12h/15h) = ⚠️ SÓ 1 fonte (guia do fórum)** → a confirmar. Sistema de gotas: 0=seco e 5=flooded reduzem yield; regar só com ≤4 gotas.

### 2b) Berries — dados COMPLETOS (04/07, extraídos do módulo de dados do pokemmohub)
**64 berries** no total (12×16h · 10×20h · 23×42h · 12×44h · 7×67h). Crescimento + yield + wilt(8h) = **alta confiança** (dado direto da fonte). Rega = **modelo eficiente do fórum** (regar o mínimo; confirmado pelo mecanismo do pokemmohub), com as **janelas-limite** (regar antes de estourar; adiantar nunca penaliza):

| Tier | Cresce | Regas | Janelas-limite (h após plantar) | Colher até (wilt) |
|---|---|---|---|---|
| 16h | 16h | **1×** | máx 7h | 24h |
| 20h | 20h | **2×** | 7h · 18h | 28h |
| 42h | 42h | **3×** | 8h · 23h · 38h | 50h |
| 44h | 44h | **3×** | 8h · 23h · 38h | 52h |
| 67h | 67h | **4×** | 8h · 23h · 38h · 53h | 75h |

- **Berries de farm (⭐):** Leppa (20h, PP) · Oran (16h) · Sitrus/Lum + as 6 EV berries (Pomeg-HP, Kelpsy-Atk, Qualot-Def, Hondew-SpA, Grepa-SpD, Tamato-Spe) todas **44h** → mesma agenda, dá pra sincronizar.
- **Regra do CD:** disparar o lembrete de rega **~1h antes** do limite (adiantar é seguro; passar do limite perde yield). Nunca regar em cima de 5 gotas ("alaga" = −1 yield). Se o servidor cai, ao voltar rega tudo pra 5 → precisa botão "re-sincronizar rega".
- **Lista completa por tier** — 16h: Cheri, Chesto, Pecha, Rawst, Aspear, Razz, Bluk, Nanab, Wepear, Pinap, Persim, Oran · 20h: Aguav, Wiki, Mago, Figy, Iapapa, Leppa, Cornn, Magost, Rabuta, Nomel · 42h: Spelon, Pamtre, Watmel, Durin, Belue, Occa, Passho, Wacan, Rindo, Yache, Chople, Kebia, Shuca, Coba, Payapa, Tanga, Charti, Kasib, Haban, Colbur, Babiri, Chilan, Enigma · 44h: Pomeg, Kelpsy, Qualot, Hondew, Grepa, Tamato, Sitrus, Lum, Custap, Jaboca, Rowap, Micle · 67h: Liechi, Ganlon, Salac, Petaya, Apicot, Lansat, Starf.
- **⚠️ a confirmar:** wilt 8h (fórum diz 7h → margem); janelas exatas ("aproximado ao minuto", pode mudar com update do jogo); yield Lansat/Starf (11–13 vs 10–13).

## 3) Diário / outros (opcionais)
| Atividade | CD | Confiança | Cadastro |
|---|---|---|---|
| Colher Apricorns (Johto) | **6h** real (recresce) | alta | ✅ opcional |
| Spawn de Alpha | **6h** (1/dia PokeMMO) | alta | ✅ opcional |
| Ho-Oh (weekly boss) | **168h** | média | 🔶 opcional |
| Raid Heatran | **~3 meses** | média | 🔶 opcional |
| Lendários Roaming (aves Kanto / feras Johto) | **mensal** (rotação) | média | 🔶 opcional |
| Loteria / Berry Master | ? | desconhecido | ❌ não achei fonte no PokeMMO |

Referência: **dia PokeMMO = 6h reais** (1h real = 4h in-game), reset 0:00 server.

## 4) Proposta de cadastro padrão (as de alta confiança)
Elite 4 (5 regiões) 6h · Gym rerun 18h · Red 168h · Morimoto 24h · Apricorns 6h · Alpha 6h · Berries por tier (16/20/42/44/67h) + wilt 8h. Opcionais (média) entram desligados, com aviso.

## 5) ⚠️ Precisa confirmar com o usuário
1. **"Rota de Farm = 20h" (do protótipo)** — não existe batalha de 20h; CDs reais são 6h/18h (o 20h é o tier da **Leppa**). De onde vem esse 20h? É rota de treinadores comuns?
2. **Cynthia:** 18h vs 24h, e estação (só primavera vs primavera+verão).
3. **Berries — regas por tier** (1×/2×/3×/3×/4×) e **janelas** — 1 fonte só.
4. **Harvesting Tool $250 ou $350.**
5. **Mulch existe?** (concluído por ausência.)
6. Quais **opcionais** entram (Ho-Oh, Heatran, Roaming, Groomers, Treinadores Ricos).
