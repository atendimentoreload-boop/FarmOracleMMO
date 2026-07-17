# Prestrelo Ajuda — Windows 🪟

App nativo de Windows (**C# / .NET 8 / WPF**) com overlay sempre no topo da janela do PokeMMO.
Reaproveita os dados de jogo de [`/data`](../data) (copiados para dentro do app ao compilar).

> Faz parte do monorepo [`prestrelo-ajuda`](../README.md).

## Pré-requisitos (no Windows)

- **Windows 10 ou 11**
- **.NET SDK 8.0** — baixe em https://dotnet.microsoft.com/download/dotnet/8.0
  (ou instale o **Visual Studio 2022** com a carga de trabalho ".NET Desktop Development", que já traz tudo).

Confirme no terminal (PowerShell):
```powershell
dotnet --version   # deve mostrar 8.x
```

## Rodar (desenvolvimento)

Na pasta `windows/`:
```powershell
dotnet run --project PrestreloAjuda
```
A janela abre no canto superior direito, sempre no topo.

## Gerar o .exe para distribuir

Build de release auto-contido (não precisa ter o .NET instalado na máquina de quem baixa):
```powershell
cd windows
dotnet publish PrestreloAjuda -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -o dist
```
O resultado fica em `windows/dist/` — o executável **Prestrelo Ajuda.exe** + a pasta `data/`.
Compacte os dois num `.zip` e suba na página de **[Releases](../../releases)**.

> Para um `.exe` menor que dependa do .NET instalado, troque para `--self-contained false`
> (sem `-r win-x64`).

## Controles

| Botão (topo) / atalho | Ação |
| --- | --- |
| arraste a barra de cima | mover o overlay |
| `‹ Menu` | voltar ao menu de modos |
| ícone de teclado | **definir o atalho do botão "Próximo"** — clique e aperte a tecla desejada |
| **atalho do "Próximo"** | avança o passo de forma **global** (funciona até com o jogo em foco) |
| barra de busca | filtra a lista de cidades/Pokémon ao digitar |
| `−` / `+` | opacidade |
| ícone de cursor | deixar cliques passarem pro jogo (click-through) |
| **Ctrl+Alt+L** | liga/desliga o click-through (funciona até com o jogo em foco — use para **destravar**) |
| ícone de minimizar | recolhe numa **Master Ball** flutuante; **duplo-clique** nela restaura |
| ✕ | fechar |
| `‹ Voltar` / `⟲ Reiniciar` | navegar / recomeçar |

## Estrutura

```
windows/
├── PrestreloAjuda.sln
└── PrestreloAjuda/
    ├── PrestreloAjuda.csproj      # WPF .NET 8; puxa ../../data no build
    ├── App.xaml(.cs)              # ponto de entrada (carrega os roteiros)
    ├── MainWindow.xaml(.cs)       # janela overlay + telas (menu/home/nó)
    ├── MiniBallWindow.xaml(.cs)   # Master Ball do estado minimizado
    ├── Models/Solve.cs            # modelo data-driven (porte do Solve.swift)
    ├── Engine/SolveEngine.cs      # motor da árvore de decisão (porte do SolveEngine.swift)
    ├── Services/                  # carregador de JSON + biblioteca de modos
    ├── Interop/Native.cs          # Win32: topmost, click-through, atalho global
    ├── Theme.cs                   # paleta (espelha o tema do Mac)
    └── Assets/                    # ícone Master Ball (.ico/.png)
```

## Notas

- A lógica (motor, modelos, dados) é **idêntica** à do app Mac.
- **Paridade com o Mac:** já tem busca nas listas, atalho configurável do "Próximo"
  e cores por Pokémon nos textos (golpes/nomes pintados conforme a paleta do modo, incluindo
  a marcação `{Golpe|Pokémon}`).
- O app **não rouba o foco** do jogo (estilo `NOACTIVATE`), então o PokeMMO continua recebendo
  as teclas normalmente enquanto você clica no overlay. Ao clicar na **busca** ou ao **gravar o
  atalho**, o overlay assume o foco por um instante (necessário para digitar/capturar a tecla) e
  o devolve em seguida.
- O **atalho do "Próximo"** é registrado globalmente (`RegisterHotKey`), então dispara mesmo com
  o PokeMMO em foco. Fica salvo em `%LOCALAPPDATA%\PrestreloAjuda\settings.json`.
