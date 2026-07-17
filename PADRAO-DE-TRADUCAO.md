# Padrão de Tradução — roteiros do Elite 4 (PT-BR)

Padrão único para os roteiros de `data/teams/` ficarem em **português robusto**, que qualquer
pessoa entenda. Referência de qualidade: os roteiros do **Shadow Scale** (já aprovados). O
**Reversed Fate** é o que precisa ser nivelado a esse padrão.

---

## Regra de ouro

**Traduzir TUDO para português, EXCETO 4 coisas que ficam no nome oficial em inglês:**

1. **Nomes de Pokémon** — `Dragonite`, `Garchomp`, `Chandelure`, `Gengar`…
2. **Nomes de golpes** — `Encore`, `Stealth Rock`, `U-turn`, `Earthquake`, `Close Combat`, `Shadow Ball`, `Dragon Dance`…
3. **Nomes de itens** — `Life Orb`, `Rocky Helmet`, `Max Potion`, `Energy Root`, `X Attack`…
4. **Nomes de HABILIDADES** — `Pressure`, `Mold Breaker`, `Intimidate`, `Flash Fire`, `Cursed Body`… (igual golpe/item: NUNCA traduzir. ⚠️ a tradução errada `Pressure`→"aperteão" já apareceu e foi consertada.)

Todo o resto (ações, estados, conectores, termos de troca, atributos) vai em **português**.

> **"have / no" do oponente** (sobre habilidade/Pokémon/item): `Have X` → `tem X`; `No X` / `sem X` → `não tem X`; opção que é só a habilidade (`Pressure`) → `tem Pressure`. Ex.: par de opções `tem Pressure` / `não tem Pressure`. (O verbo `aperte`/`press` = "pressionar" NÃO é a habilidade — não confundir.)

> Apelidos/abreviações de Pokémon e golpe **são expandidos para o nome oficial** (continua em
> inglês, mas completo): `Dnite`→`Dragonite`, `Chomp`→`Garchomp`, `Tbolt`→`Thunderbolt`,
> `Eq`→`Earthquake`. Nunca deixar abreviação solta.

---

## Glossário (inglês → português)

### Atributos / buffs (sempre PT)
| Inglês | Português |
| --- | --- |
| `Atk` / `Attack` | Ataque |
| `Sp.Atk` / `Sp. Atk` / `SpAtk` | Ataque Especial |
| `Def` / `Defense` | Defesa |
| `Sp.Def` / `Sp. Def` | Defesa Especial |
| `Speed` | Velocidade |
| `HP` | HP *(mantém — universal)* |
| `+2 Atk, +2 Speed` | +2 Ataque, +2 Velocidade |
| `stat boost` | aumento de atributo |

### Ações / estados (sempre PT)
| Inglês | Português |
| --- | --- |
| `Stay` / `Still Stay` | Fica (não troca) |
| `Stay and continue until item reveal` | Fica e continua até revelar o item |
| `See under` / `see` | veja abaixo |
| `switch` / `run to X` | troque para X |
| `force switch` | force a troca |
| `let flee` / `→ sai X` | deixe fugir X |
| `sack` / `sacrifice` | sacrifique |
| `kill` / `KO` | nocauteia / nocauteie |
| `heal` / `Heal Full` | cure / cura total |
| `Full health` | vida cheia |
| `Low health` / `Low HP` | vida baixa / HP baixo |
| `self lock` / `self-lock` | travado no golpe |
| `Choice locked` | preso num golpe (Choice) |
| `goes under` | vai por baixo |
| `push` | pressione / varra |
| `went last` | foi por último |
| `facing` | contra |
| `misses X` | erra o X |
| `confirm 2HKO` | confirma o 2HKO |
| `crit` | crítico |

### Conectores / palavras comuns (sempre PT)
| Inglês | Português |
| --- | --- |
| `if` | se |
| `and` | e |
| `or` | ou |
| `to` | para |
| `no` (ex.: `no life orb`) | sem (ex.: sem Life Orb) |
| `first` | primeiro |
| `after` | depois |
| `last` | último |
| `can` | pode |
| `need` / `needed` | precisa |
| `test` | testar |
| `continue` | continuar |
| `moves` | golpes |
| `will confirm later` | confirmo depois |
| `fix mb` (my bad) | corrijo depois |

### Abreviações → nome oficial (continua em inglês, completo)
| Abrev. | Oficial |
| --- | --- |
| `Tbolt` / `tbolt` | Thunderbolt |
| `Eq` / `eq` | Earthquake |
| `Chomp` | Garchomp |
| `Dnite` | Dragonite |
| `X scissors` | X-Scissor |
| `Max pot` | Max Potion |

### Formas do Rotom (label = forma + Rotom, p/ casar o sprite)
| Sprite | Label correto |
| --- | --- |
| `washrotom.png` | Wash Rotom |
| `frostrotom.png` | Frost Rotom |
| `fanrotom.png` | Fan Rotom |
| `heatrotom.png` | Heat Rotom |

---

## Regra absoluta de destaque das NOTAS (`kind: "note"`)

As notas dizem **o golpe exato a usar em cada Pokémon** — são uma "linha de solução
dentro da linha de solução". Se o jogador não vê, usa o ataque errado e a estratégia
quebra. Por isso **toda nota tem que ser EXTREMAMENTE visual**, nunca apagada:
- fundo âmbar (`Theme.warning`) + borda + ícone de alerta + tag "ATENÇÃO";
- texto em **negrito** e tamanho cheio (não cinza/dim).
- Implementado em `noteRow` de `NodeView.swift` — vale para as 3894 notas de uma vez.

## Notas de estilo
- Frases curtas e diretas; separador de passos com `·`.
- Não inventar estratégia: se um trecho está embaralhado demais (ver `TRADUCAO-PENDENTE.md`),
  marcar e conferir no site Pokeking antes de reescrever.
- Capitalização dos nomes oficiais como na franquia (`Life Orb`, `Close Combat`).
