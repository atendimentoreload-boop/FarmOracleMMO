# Changelog

Todas as mudanças relevantes do **Prestrelo Ajuda** ficam registradas aqui.
Cada versão lançada vira uma seção; o conteúdo da seção vira as **notas da Release**.

Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/).
Versionamento em [VERSIONING.md](VERSIONING.md) (semântico: MAJOR.MINOR.PATCH).

> Como usar: enquanto trabalha, vá anotando as mudanças em **[Não lançado]**.
> Na hora do release, renomeie esse bloco para a nova versão + data.

## [Não lançado]

---

## [1.7.0] — 2026-07-13

### Adicionado
- **Guia "Como ler o overlay" (nas 3 plataformas).** Um cartão de boas-vindas abre sozinho
  na primeira vez que você usa o app (depois do idioma) e explica o essencial: a **seta verde**
  aponta a próxima ação, os ícones (↩️ 🗡️ 👏) estão no glossário do modo, e você clica na opção
  que apareceu no jogo. Depois disso ele só reabre pelo botão **"?"**.
- **Aviso "Novo na Elite 4?" (nas 3 plataformas).** Dentro do mesmo guia, um alerta explica que
  **antes da 5ª vitória** (enquanto a liga ainda não está no nível 100) o jogo troca níveis e
  times, então as instruções podem não bater — da 5ª vez em diante ficam certeiras.
- **Feedback "funcionou / não funcionou" no Gym Rerun (nas 3 plataformas).** O mesmo botão de
  feedback da Elite 4 agora aparece no fim de **cada ginásio** do Gym Rerun.

### Alterado
- **Six Pillars (BASIC) — Striaton agora são os 3 líderes em sequência** (Chili → Cilan → Cress,
  ordem Veteran), em vez de "escolha 1". Bate com o rerun real do ginásio.
- **Opção "Demais times / Other" sempre usa a Master Ball** (nas 3 plataformas) — não herda mais,
  por engano, o item do oponente ativo.
- **Atalho "Pular parada" (Mac e Windows).** Um segundo atalho de teclado pula a parada atual.
- **Fontes das rotas de farm (#14).** Seis rotas ganharam o link do documento/guia de origem.

---

## [1.6.0] — 2026-07-06

### Adicionado
- **Hub de timers.** Um botão de relógio abre um painel de cronômetros para você não perder o fio
  dos ciclos de farm — útil quando roda várias alts.

---

## [1.5.0] — 2026-06-28

### Adicionado
- **Dois modos novos:** *Cynthia & Morimoto* (estratégia Swellow + Garchomp) e *Ho-Oh*.
- **Menu inicial repaginado.**
- **Rodapé de créditos** no menu inicial e nas Configurações (nas 3 plataformas), com
  atalhos clicáveis para o **Discord** e o **YouTube** do FarmOracleMMO.

### Corrigido
- **Minimizar (Mac/Windows):** ao reabrir, a janela não volta mais para a posição antiga,
  e o duplo-clique não fecha a sobreposição sozinho na sequência.
- **Android:** a bolinha minimizada agora usa o **ícone atual do app** (antes mostrava a
  Master Ball antiga).
- **Elite 4:** times re-extraídos e re-traduzidos da fonte — o modo em **inglês** não mostra
  mais trechos em português nem apelidos/gírias errados.

---

## [1.4.0] — 2026-06-14

### Adicionado
- **Nova identidade visual nas 3 plataformas.** Ícone próprio (pokébola + moeda) no Mac,
  Windows e Android, e a bolinha de minimizar combinando. O **Android agora tem ícone
  próprio** (antes usava o genérico do sistema).
- **"Ver times" do oponente no Windows e no Android** (antes só no Mac). Mostra os times
  possíveis do adversário — item, habilidade e os 4 golpes de cada Pokémon — estreitando as
  possibilidades conforme a luta avança.
- **Android em paridade com Mac/Windows:** tabelas condicionais (golpe → alvos), legenda/
  glossário do modo, marcar paradas para pular (skip) e dicas de "próximo lead/ginásio".
- **Windows — legenda/glossário do modo** agora renderizada.

### Corrigido
- (14 trechos do Elite 4 ainda em revisão com a fonte)

---

## [1.3.3] — 2026-06-12

### Adicionado
- **Android — controle de tamanho (A− / A / A+).** Um botão na barra de título da
  sobreposição aumenta/diminui painel, sprites e textos juntos, em 3 níveis (Compacto,
  Normal, Grande). Fica salvo. Resolve a leitura ruim dos nomes de Pokémon **sem precisar
  mexer no DPI/fonte do celular inteiro**.
- **Mac — alça de redimensionar no canto.** Igual à "bordinha" do app de Windows: arraste o
  canto inferior-direito do painel para ajustar largura e altura.

### Corrigido
- **Android — minimizar não perde mais o lugar.** Ao recolher a bolha e reabrir, a
  sobreposição volta exatamente onde você estava (modo, região, líder e o turno do roteiro),
  em vez de cair no menu inicial.
- **Android — modo horizontal (landscape).** Em telas deitadas (altura baixa) o painel se
  adapta à tela e nunca mais corta o rodapé (Voltar/Reiniciar); o conteúdo rola por dentro.

---

## [1.3.2] — 2026-06-12

### Corrigido
- **Mac não abria após atualizar.** A release do Mac empacotava o bundle de recursos só em
  `Contents/MacOS/`, mas o `Bundle.module` gerado pelo toolchain do CI procura na raiz do
  `.app`. Resultado: o app baixado abria e morria na hora (`could not load resource bundle`).
  Agora o bundle é copiado para os três locais possíveis, à prova de toolchain.
- **"Está danificado" no Mac.** Como o app não é notarizado, todo download vinha com a
  quarentena do Gatekeeper. O zip do Mac agora inclui um abridor de 1 clique
  (`Abrir FarmOracleMMO (1a vez).command`) que libera e abre — sem comando no Terminal.

### Garantias (pra não repetir os erros de hoje)
- **CI agora reprova release quebrada antes de publicar:** valida `/data` contra o modelo,
  abre o `.app` do Mac de verdade (`--selftest` headless) e confere que o APK Android
  embarcou os roteiros. Qualquer falha aborta a publicação.
- Build de Teste do Android passou a sincronizar `/data` (não saía mais sem roteiros).

---

## [1.3.1] — 2026-06-11

### Adicionado
- **Segundo time: Reversed Fate.** Seletor de time (⇄) no topo do menu alterna entre
  **Shadow Scale** e **Reversed Fate**, cada um com suas próprias soluções de Elite 4
  e Poképaste. A preferência fica salva entre sessões.
- **Modo Emoji** (toggle ON/OFF) no Reversed Fate: mostra o combate na notação
  original do autor (emojis) em vez do texto traduzido.

### Corrigido
- **Android: APK do CI saía sem os dados de jogo** (o job de release não sincronizava
  `/data` para os assets), fazendo o app fechar ao abrir qualquer modo. Agora o CI
  roda o `sync-data.sh` antes de compilar o APK.

---

## [1.2.0] — 2026-06-11

### Mudado
- **Novo nome: FarmOracleMMO** (antes "Prestrelo Ajuda"). IDs internos e repositórios
  seguem iguais — atualização instala por cima normalmente.

### Adicionado
- **Foto do oponente no topo** em todos os modos durante a luta ("ENFRENTANDO …"):
  Elite/​campeão na E4, líder de ginásio na rota de farm, Red na luta do Red.
- **Elite 4 em sequência:** ao terminar cada luta, botão **"Próximo: <treinador>"**
  que leva direto à seleção de leads do próximo da ordem (Lorelei → … → campeão).
  No campeão, vira **"Liga concluída — escolher outra"** (volta ao menu de modos).
- **Aviso da Elite 4:** banner âmbar avisando que o guia só vale 100% a partir da
  5ª vitória contra aquela mesma Elite (antes disso os times variam).
- **Feedback "Funcionou / Não funcionou"** (só na E4), acima do "Próximo". "Não funcionou"
  abre uma caixa para descrever. Envia para uma planilha do Google (Apps Script).
  Ligar a URL em `FeedbackClient` de cada app (ver `tools/feedback-apps-script.gs`).

### Corrigido
- **Windows:** "Reiniciar" na Elite 4 agora volta para a seleção de **treinadores**
  (campeões), e não para a lista de Pokémon do grupo atual. Mesmo comportamento nos 3 apps.

---

## [1.1.1] — 2026-06-10

### Corrigido
- **Roteiros do Elite 4:** corrigida a maior parte das traduções quebradas que vieram
  da tradução automática (Chinês→Inglês→PT). Ex.: `Ball Mushroom`→Amoonguss,
  `Claydol Skill`→Habilidade do Claydol, `Killed`→nocauteado, `Damage`→dano,
  `Hippodon`→Hippowdon, `Low HP`→HP baixo, e dezenas de outros termos.

---

## [1.1.0] — 2026-06-10

### Adicionado
- **Windows:** busca nas listas, atalho configurável do botão "Próximo" (global),
  cores por Pokémon nos textos, e menu de modos com ícone/play/Poképaste — paridade com o Mac.
- **Versão única** dos 3 apps via `/VERSION` + `scripts/bump-version.*` (rodapé `vX.Y.Z`).
- **Bloqueio de versão obrigatória** nos 3 apps (lê `version.json` do repo público; fail-open).
- **Arquitetura de 2 repositórios:** código privado (`prestrelo-ajuda`) +
  distribuição pública (`prestrelo-ajuda-download`).
- **Robô de release (GitHub Actions):** tag `vX.Y.Z` compila os 3 na nuvem e publica.

### Notas
- O bloqueio de versão só vale nas builds **distribuídas (release)**; builds de
  **desenvolvimento (debug)** nunca bloqueiam — dá pra rodar/testar local à vontade.
