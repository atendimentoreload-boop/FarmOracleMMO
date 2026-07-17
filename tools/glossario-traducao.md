# Glossário de tradução das solves (PT-BR)

Padrões recorrentes extraídos com o autor. Usar pra traduzir/reescrever de forma consistente
as ~224 frases não-claras (chinês vazado + inglês misturado). **Não é só trocar palavra —
muitas frases empacotam várias ações com cronologia e precisam virar passos separados.**

## Tokens / gírias (inglês → PT)
| Token | Significado |
|---|---|
| `die` / `dies` / `not die` / `die ok` | morrer / ser nocauteado (`not die` = não morre) |
| `star` | **Jirachi** (apelido — Pokémon estrela). `star dies` = "se o Jirachi morrer" |
| `runs` / `run` / `runs para X` | o oponente **foge / troca** (para X) |
| `see below` / `see under` / `veja abaixo` | ver a **solve abaixo** (alternativa logo abaixo) |
| `see above` / `run see above` | **voltar** a uma solve anterior — descobrir pra qual Pokémon ele voltou e pôr todos como opção |
| `see what happens` / `see who` / `see solve` | observar qual situação ocorre e seguir a solve correspondente |
| `vswitch` / `vswitches` / `used vswitch` | **Volt Switch** (golpe). `only vswitches on X` = só dá Volt Switch no X |
| `wary of health` / `wary of hp` / `be wary of hp` | **cuidado com o HP** — se baixar, curar (Max Potion / Energy Root) |
| `hard swap` / `hard troca` / `try hard swap` | **troca direta/forçada** (mais arriscada). `to save money` = economizar (não gastar cura) |
| `crit` / `crítico` | acerto crítico |
| `lives` / `lives crítico` | **sobrevive** (ao crítico) |
| `insta ko` | nocaute imediato |
| `pressione` / `pressione till` | continuar pressionando/batendo até... |
| `continuar` / `continue` | seguir bufando |
| `b4` = before = antes · `till` = até · `u` = você · `wo` = sem · `idk` = não sei · `pode` = can |
| `Full Restore` | cura total — **o inimigo** pode usar |
| `HJK` = High Jump Kick · `Sball` = Shadow Ball · `Sucker Punch` = golpe de prioridade |
| `Max Potion` / `Energy Root` | itens de cura **nossos** |
| `krow` = Murkrow · `Dark pluse` = Dark Pulse (typo) |

## Emojis = Pokémon / ação (CONFIRMADO pelo autor — traduzir, NUNCA apagar)
Os emojis não são decoração: cada um é um Pokémon do nosso time ou uma ação. Na versão de
TEXTO devem virar o nome/ação por extenso.

| Emoji | Significa | Tipo |
|---|---|---|
| `🗡` | **Gallade** | Pokémon |
| `👊` | **Scrafty** | Pokémon |
| `🐭` | **Pikachu** | Pokémon |
| `🐲` | **Dragonite** | Pokémon |
| `🕯` | **Chandelure** | Pokémon |
| `💫` | **Jirachi** (= o "star" dos textos) | Pokémon |
| `👏` | **Encore** | ação/golpe |
| `📌` | **Stealth Rock** (+ ORDEM: se sai antes/depois do golpe do oponente muda a situação) | ação/golpe |
| `💀` | morre / KO | estado |
| `↪️` | troca / segue | ação |
| `⚠️` | aviso — caminho em teste (já em PT, manter) | nota |
| `①②③` | ordem dos passos (1º/2º/3º) | ordem |
| `；` | ponto-e-vírgula chinês vazado → virar `·` ou quebra de passo | lixo |

> Ex.: `U turn 🗡👏` = "U-turn · Gallade · Encore". `🐭👏 3+2` = "Pikachu · Encore [+3 Ataque, +2 Velocidade]". `💫faint` = "Jirachi morre".

## Termos do Shadow Scale (confirmados pelo autor)
| Termo no texto | Significa |
|---|---|
| `Electric Cure X` | **Thunder Punch** (golpe elétrico do Toxicroak) no X |
| `Power Gem` | golpe do **Heatran** (correto, manter) |
| `Goldfish` | **Goldeen** (Pokémon) |
| `Remaining X` | golpe X **no resto do time** |
| `CT` / `CTfirst` / `CTsmall` | crítico / crítico primeiro / crítico baixo |
| `At Muk Front` | **na frente do Muk** |
| `Many Dance one time` | use **só 1 Dragon Dance** |
| `Pray garantido` | garantido · `Still` = permanece |

## Padrões estruturais (precisa REESTRUTURAR, não só traduzir)
1. **Várias ações numa linha com cronologia** (X primeiro, depois Y, depois Z) → separar em passos na ordem certa. Não inverter a ordem.
2. **`runs see above/below`** → ramificação: criar uma opção pra cada Pokémon que ele pode trocar, cada uma levando à solve certa.
3. **Stealth Rock + "primeiro/antes/depois"** → condicional de quem move primeiro.
4. **`?` genéricas** (→ "Siga conforme a situação") → **deletar** (69). `?` que levam a "Oponente está usando o time X" → **renomear** (8).
