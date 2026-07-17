# Prestrelo Ajuda

Overlay para macOS que fica **sempre no topo** da janela do PokeMMO e mostra, turno a turno,
roteiros 100% mapeados. Multi-modo:

- **Luta do Red** — solve para vencer o Red.
- **Rota de Farm (Veteran)** — Hoenn → Kanto → Sinnoh → Johto → Unova, parada a parada.

Recursos:

- Janela pequena, flutuante e arrastável (clique em qualquer ponto para mover).
- Modelo híbrido: caminho fixo → **lista de ações** com botão **Próximo**; quando há opções →
  **botões de escolha**.
- **Atalho configurável** para o "Próximo" que funciona com o **jogo em foco** (grave a tecla
  que quiser em Ajuda → "Definir").
- Instruções em **português claro**; nomes de golpes/Pokémon em **inglês** (batem com a tela do jogo).
- Leve e nativo (SwiftUI/AppKit) — sem Chromium, mínimo de RAM ao lado do jogo.

> Faz parte do monorepo [`prestrelo-ajuda`](../README.md). Os dados das lutas são
> compartilhados em [`/data`](../data) e copiados para cá na hora de compilar.

## Rodar (desenvolvimento)

Precisa de Xcode ou Command Line Tools instalados (`xcode-select --install`).

```bash
bash scripts/sync-data.sh   # copia os dados de /data para os Resources
swift run
```

A janela abre no canto superior direito.

## Gerar o app de duplo-clique

```bash
bash scripts/build-app.sh
open "dist/Prestrelo Ajuda.app"
```

## Controles

| Atalho / botão | Ação |
| --- | --- |
| Arraste a janela | mover o overlay |
| ícone de casa (topo) | voltar ao menu de modos |
| `+` / `−` (topo) | opacidade |
| ícone de mão (topo) ou `⌥⌘L` | deixar cliques passarem para o jogo (click-through) |
| `?` (topo) | ajuda, **definir atalho do Próximo** e legenda |
| `Voltar` / `Reiniciar` | navegar / recomeçar |
| atalho configurável | avança o **Próximo** (funciona com o jogo em foco) |

> O **atalho do Próximo** e o **click-through** funcionam com o jogo em foco graças à permissão
> de **Acessibilidade** (o macOS pede na primeira vez). Sem ela, o atalho só funciona com o
> overlay em foco; o click-through é sempre reversível pela pílula que aparece ao ligá-lo.

## Como adicionar/editar roteiros

O conteúdo vive em [`/data`](../data) (`red.json`, `veteran.json`, `elite4_*.json`) — **fonte
única compartilhada por todas as plataformas**. Edite lá e rode `bash scripts/sync-data.sh`.
O app é *data-driven*: para mapear outra luta/rota, crie um novo JSON no mesmo formato e
registre-o como um `Mode` em
[`AppDelegate.swift`](Sources/DestruidorDeRed/AppDelegate.swift) (veja o modelo em
[`Model/Solve.swift`](Sources/DestruidorDeRed/Model/Solve.swift)).

### Formato resumido
- `entryPoints`: o que o oponente pode mandar primeiro (vira a grade inicial de botões).
- `nodes`: cada nó tem `steps` (ações lineares) e um `branch` opcional:
  - `choice`: pergunta + `options` (botões) quando o oponente tem várias possibilidades;
  - `goto`: salto automático para outro nó (ex.: "Go to Emboar Solve").
- Tipos de passo: `action` (instrução), `note` (observação), `conditional` (tabela golpe → alvos).
