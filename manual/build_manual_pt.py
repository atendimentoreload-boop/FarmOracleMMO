# -*- coding: utf-8 -*-
import base64, os
SCR="/private/tmp/claude-501/-Users-vinysa-Desktop-projetos-Destruidor-de-Red/1c473908-9768-4253-a0d3-2667eb2417ee/scratchpad"
ROOT="/Users/vinysa/Desktop/projetos/Destruidor de Red"
def durl(p,m): return f"data:{m};base64,"+base64.b64encode(open(p,"rb").read()).decode()
ICON=durl(os.path.join(ROOT,"android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"),"image/png")
HOME=durl(os.path.join(SCR,"man_img/shot-001.jpg"),"image/jpeg")
BATTLE=durl(os.path.join(SCR,"man_img/shot-003.jpg"),"image/jpeg")
TEAMS=durl(os.path.join(SCR,"man_img/shot-008.jpg"),"image/jpeg")

CSS = open(os.path.join(ROOT,"manual/FarmOracleMMO-Guide-EN.html"),encoding="utf-8").read()
CSS = CSS[CSS.index("<style>"):CSS.index("</style>")+8]  # reuse exact same styles

HTML = r"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FarmOracleMMO — Guia Completo</title>
__CSS__
</head>
<body>

<header class="hero">
  <div class="wrap">
    <img class="logo" src="__ICON__" alt="FarmOracleMMO">
    <div>
      <h1>Farm<span>Oracle</span>MMO</h1>
      <div class="tag">Ajudante turno a turno para PokeMMO &mdash; Red, Farm de Gin&aacute;sios, Cynthia &amp; Morimoto, Ho-Oh e a Elite 4</div>
      <span class="vpill">&#128218; GUIA COMPLETO &middot; VERS&Atilde;O 1.6.0</span>
    </div>
  </div>
</header>

<div class="wrap">

  <section>
    <h2><span class="n">1</span>O que &eacute;</h2>
    <p class="lead">O FarmOracleMMO &eacute; um ajudante que fica numa <b>janela/bolha flutuante</b> por cima do jogo e te diz, <b>turno a turno</b>, exatamente o que fazer pra vencer as lutas mais dif&iacute;ceis e repet&iacute;veis do jogo: <b>Red</b>, o <b>Farm de Gin&aacute;sios</b> (rebatalhas de l&iacute;deres), <b>Cynthia &amp; Morimoto</b>, <b>Ho-Oh</b> e a <b>Elite 4</b> nas 5 regi&otilde;es. Ele vai <b>afunilando as possibilidades conforme a batalha anda</b> &mdash; voc&ecirc; diz o que o oponente fez e ele te leva at&eacute; a linha exata da vit&oacute;ria.</p>
    <p><b>N&atilde;o</b> &eacute; automa&ccedil;&atilde;o/bot &mdash; voc&ecirc; joga; ele s&oacute; mostra o roteiro &oacute;timo. Dispon&iacute;vel para <b>Windows, macOS e Android</b>, todos com a <b>mesma vers&atilde;o e as mesmas fun&ccedil;&otilde;es</b>.</p>
  </section>

  <section>
    <h2><span class="n">2</span>Instala&ccedil;&atilde;o</h2>
    <p>Baixe a vers&atilde;o mais recente em: <a href="https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest">github.com/&hellip;/prestrelo-ajuda-download/releases/latest</a></p>
    <table>
      <tr><th>Windows</th><th>macOS</th><th>Android</th></tr>
      <tr>
        <td>Baixe o <b>.zip</b>, extraia e abra o <b>.exe</b>.</td>
        <td>Abra o <b>.app</b>. No macOS Sequoia (15+), use o abridor de 1 clique inclu&iacute;do se o Gatekeeper bloquear na primeira vez.</td>
        <td>Instale o <b>.apk</b> e conceda a permiss&atilde;o de <b>sobreposi&ccedil;&atilde;o</b> (&ldquo;desenhar sobre outros apps&rdquo;).</td>
      </tr>
    </table>
    <div class="tip">&#128161; <b>Idioma:</b> o app &eacute; totalmente bil&iacute;ngue. Na primeira vez voc&ecirc; escolhe <b>Portugu&ecirc;s</b> ou Ingl&ecirc;s, e tem um chip <b>PT&#8644;EN</b> na tela inicial pra trocar quando quiser.</div>
  </section>

  <section>
    <h2><span class="n">3</span>O menu inicial</h2>
    <div class="row">
      <div class="shot"><img src="__HOME__" alt="Menu inicial"><div class="cap">Menu inicial &mdash; escolha um modo</div></div>
      <div class="col">
        <p>Toda luta que o app ajuda est&aacute; a um toque. Cada modo tem um bot&atilde;o <b>&#9654; iniciar</b> e um bot&atilde;o <b>? Pok&eacute;paste</b> (o time exato pra montar).</p>
        <ul class="feat">
          <li><b>Elite 4</b> &mdash; todas as 5 regi&otilde;es (Kanto, Hoenn, Sinnoh, Unova, Johto).</li>
          <li><b>Farm de Gin&aacute;sios</b> &mdash; rebata os l&iacute;deres em batalhas em dupla (cooldown 18h) por muito dinheiro. Rotas: <b>Six Pillars</b> (Veteran &amp; BASIC) e <b>Lucky Girl</b> (Seven Hells).</li>
          <li><b>Cynthia &amp; Morimoto</b> &mdash; a luta dupla p&oacute;s-liga.</li>
          <li><b>Red</b> &mdash; a luta do Monte Silver (v&aacute;rias estrat&eacute;gias selecion&aacute;veis).</li>
          <li><b>Ho-Oh</b> &mdash; a rebatalha lend&aacute;ria (inclui uma estrat&eacute;gia de Trick Room).</li>
          <li><b>Menu</b> &mdash; times, Pok&eacute;pastes, fontes e ajustes.</li>
        </ul>
        <p class="mut">O rodap&eacute; mostra a vers&atilde;o, os cr&eacute;ditos e atalhos r&aacute;pidos pro <b>Discord</b> e o <b>YouTube</b>.</p>
      </div>
    </div>
  </section>

  <section>
    <h2><span class="n">4</span>Como funciona o turno a turno</h2>
    <div class="row">
      <div class="col">
        <p>Escolha um modo, depois escolha seu <b>lead / regi&atilde;o</b>. O guia mostra o <b>n&oacute;</b> atual e conduz a luta com voc&ecirc;:</p>
        <ul class="feat">
          <li><b>Oponente no campo</b> &mdash; um cabe&ccedil;alho mostra qual Pok&eacute;mon voc&ecirc; est&aacute; enfrentando.</li>
          <li><b>A&ccedil;&otilde;es do turno</b> &mdash; as a&ccedil;&otilde;es exatas (T1, T2&hellip;), com nomes de golpe <b>coloridos</b> e <b>avisos</b> importantes destacados em &acirc;mbar.</li>
          <li><b>&ldquo;O que o oponente fez?&rdquo;</b> &mdash; bot&otilde;es de escolha; toque na resposta e o guia <b>afunila at&eacute; a linha exata</b> da vit&oacute;ria.</li>
          <li><b>Ver times</b> &mdash; mostra os <b>times poss&iacute;veis</b> do oponente (item, habilidade e os 4 golpes), estreitando conforme a luta anda.</li>
          <li><b>Progresso</b> &mdash; indicador &ldquo;passo x / y&rdquo;, al&eacute;m de <b>Pr&oacute;ximo</b>, <b>Voltar</b> (desfaz), <b>Reiniciar</b> e <b>Pular esta parada</b>.</li>
          <li><b>Sequ&ecirc;ncia da Elite 4</b> &mdash; no fim de uma luta ele j&aacute; pula pro pr&oacute;ximo treinador da fila.</li>
        </ul>
      </div>
      <div class="shot wide"><img src="__BATTLE__" alt="Overlay turno a turno"><div class="cap">O overlay durante uma luta (Ho-Oh)</div></div>
    </div>
  </section>

  <section>
    <h2><span class="n">5</span>O overlay flutuante &amp; controles</h2>
    <p class="lead">O painel flutua sobre o jogo, ent&atilde;o voc&ecirc; nunca precisa alt-tab. Tudo nele &eacute; ajust&aacute;vel:</p>
    <div class="grid2">
      <div class="card"><h4>Minimizar pra bolinha</h4><p>Recolha numa Bolinha em qualquer lugar da tela; toque pra reabrir exatamente onde parou.</p></div>
      <div class="card"><h4>Sempre no topo</h4><p>Fica acima da janela do jogo o tempo todo.</p></div>
      <div class="card"><h4>Arrastar &amp; redimensionar</h4><p>Mova a janela/bolha pra qualquer lugar; redimensione o painel pela al&ccedil;a do canto.</p></div>
      <div class="card"><h4>Opacidade</h4><p>Um slider define a transpar&ecirc;ncia do painel sobre o jogo.</p></div>
      <div class="card"><h4>Tamanho da fonte &mdash; A&minus; / A / A+</h4><p>Um chip na barra de t&iacute;tulo aumenta/diminui o painel inteiro pra leitura.</p></div>
      <div class="card"><h4>Atalhos de teclado (desktop)</h4><p>Um atalho global &ldquo;Pr&oacute;ximo passo&rdquo; funciona at&eacute; com o jogo em foco, al&eacute;m das <b>F1&ndash;F12</b> pra escolher as op&ccedil;&otilde;es.</p></div>
      <div class="card"><h4>Busca / filtro</h4><p>Filtre listas longas (leads, cidades) pra achar r&aacute;pido.</p></div>
      <div class="card"><h4>Extras do Android</h4><p>Modo &ldquo;Abrir aqui&rdquo; (sem overlay), servi&ccedil;o em primeiro plano e notifica&ccedil;&otilde;es do sistema.</p></div>
    </div>
  </section>

  <section>
    <h2><span class="n">6</span>Times, estrat&eacute;gias &amp; fontes</h2>
    <div class="row">
      <div class="shot"><img src="__TEAMS__" alt="Times e op&ccedil;&otilde;es"><div class="cap">Menu &mdash; times, estrat&eacute;gias &amp; bot&otilde;es de fonte</div></div>
      <div class="col">
        <p>Abra o <b>Menu</b> pra gerenciar tudo. Os times s&atilde;o agrupados por modo, e voc&ecirc; pode <b>selecionar um time ou estrat&eacute;gia diretamente</b>:</p>
        <ul class="feat">
          <li><b>Seletor de estrat&eacute;gia</b> &mdash; ex.: o Red tem v&aacute;rios times, o Ho-Oh tem uma linha de <b>Trick Room</b>, Cynthia &amp; Morimoto tem variantes, a Elite 4 tem v&aacute;rios times completos (Shadow Scale, Reversed Fate, Dingxianyou, Starlight, Ghost Dance, Sacred Inferno&hellip;).</li>
          <li><b>Bot&otilde;es de fonte por time</b> &mdash; <span class="chip">&#9654; v&iacute;deo</span> <span class="chip">&#128196; documento</span> <span class="chip">&#9432; CODE do Pokeking</span> (copie o c&oacute;digo e monte o time exato no jogo).</li>
          <li><b>Bot&atilde;o de Pok&eacute;paste</b> &mdash; o time completo com itens, habilidades, IVs e golpes.</li>
          <li><b>Modo Emoji</b> &mdash; quando um time traz a vers&atilde;o emoji, veja a luta na nota&ccedil;&atilde;o original do autor.</li>
          <li><b>Idioma</b> &mdash; seletor PT/EN, lembrado entre sess&otilde;es.</li>
        </ul>
      </div>
    </div>
  </section>

  <section>
    <h2><span class="n">7</span>Farm de Gin&aacute;sios &mdash; Six Pillars &amp; Lucky Girl</h2>
    <p>O modo <b>Farm de Gin&aacute;sios</b> &eacute; um gerador de dinheiro: voc&ecirc; rebate os l&iacute;deres em <b>batalhas em dupla</b>, num cooldown de <b>18 horas</b>, por um pagamento grande. O app traz rotas passo a passo completas:</p>
    <ul class="feat">
      <li><b>Six Pillars</b> &mdash; um time fixo de 6 com duas rotas selecion&aacute;veis: <b>Veteran</b> e <b>BASIC</b> (27 gin&aacute;sios, transcritas dos docs oficiais).</li>
      <li><b>Lucky Girl (Seven Hells)</b> &mdash; uma rota de farm alternativa (baseada em Meloetta).</li>
    </ul>
    <p class="mut">As rotas ficam agrupadas num submenu por time, cada uma com seu Pok&eacute;paste e documento de fonte.</p>
  </section>

  <section>
    <h2><span class="n">8</span>Timer de cooldown &amp; farm</h2>
    <p class="lead">Novidade na 1.6.0. Um bot&atilde;o de rel&oacute;gio abre um <b>hub de timers</b> pra voc&ecirc; nunca perder o fio dos seus ciclos de farm &mdash; especialmente &uacute;til se voc&ecirc; roda muitas alts.</p>
    <ul class="feat">
      <li><b>Cadastre seus personagens (alts)</b> e acompanhe os <b>cooldowns de batalha</b>: Elite 4, rotas de farm, Red e Cynthia &amp; Morimoto.</li>
      <li><b>Timers de berry</b> &mdash; o ciclo <b>plantar &rarr; regar &rarr; colher</b>, pra saber exatamente quando voltar.</li>
      <li><b>Alarme do sistema</b> &mdash; uma notifica&ccedil;&atilde;o (banner + som) dispara na hora exata, <b>mesmo com o app fechado</b>.</li>
    </ul>
    <div class="tip">&#128161; Um modo de <b>sincroniza&ccedil;&atilde;o (PC &#8646; celular)</b> est&aacute; a caminho, pra um timer que voc&ecirc; come&ccedil;a num aparelho aparecer no outro.</div>
  </section>

  <section>
    <h2><span class="n">9</span>Feedback, updates &amp; ajuda</h2>
    <ul class="feat">
      <li><b>&ldquo;Funcionou / N&atilde;o funcionou&rdquo;</b> &mdash; feedback de um toque nas lutas da Elite 4; &ldquo;N&atilde;o funcionou&rdquo; abre uma caixa pra voc&ecirc; contar o que aconteceu.</li>
      <li><b>Verificador de atualiza&ccedil;&atilde;o</b> &mdash; o app avisa quando sai uma vers&atilde;o nova; releases cr&iacute;ticas podem exigir a atualiza&ccedil;&atilde;o pra continuar.</li>
      <li><b>Cr&eacute;ditos &amp; links</b> &mdash; um rodap&eacute; com a vers&atilde;o e atalhos pra comunidade.</li>
    </ul>
  </section>

  <section>
    <h2><span class="n">10</span>Site de atualiza&ccedil;&otilde;es ao vivo (roadmap)</h2>
    <p>Quer ver o que a gente est&aacute; construindo em tempo real? Mantemos uma p&aacute;gina de <b>roadmap p&uacute;blica e ao vivo</b>:</p>
    <p style="font-size:16px"><b>&#128279; <a href="https://farmoracle-roadmap.pages.dev/">farmoracle-roadmap.pages.dev</a></b></p>
    <ul class="feat">
      <li><b>Resolvido</b> &mdash; tudo que j&aacute; foi corrigido, e em qual vers&atilde;o.</li>
      <li><b>Em andamento</b> &mdash; o que est&aacute; sendo feito agora.</li>
      <li><b>Todo pedido</b> &mdash; todas as sugest&otilde;es/bugs da comunidade cadastrados.</li>
      <li><b>Paridade por plataforma</b> &mdash; o que est&aacute; pronto no Mac, Windows e Android.</li>
      <li><b>Hist&oacute;rico de vers&otilde;es</b> &mdash; o que entrou em cada release.</li>
    </ul>
    <p class="mut">A p&aacute;gina atualiza em tempo real &mdash; assim que a gente resolve ou cadastra algo, aparece l&aacute;.</p>
  </section>

  <section>
    <h2><span class="n">11</span>Comunidade no Discord &mdash; como funciona</h2>
    <div class="row">
      <div class="col">
        <h3>Separada por idioma (PT / EN)</h3>
        <p>Ao entrar, escolha seu idioma no <span class="chip">#idioma</span> (reaja com uma bandeira). Quem &eacute; <b>Portugu&ecirc;s</b> v&ecirc; s&oacute; os canais em portugu&ecirc;s; quem &eacute; Ingl&ecirc;s v&ecirc; s&oacute; os em ingl&ecirc;s. Voc&ecirc; pode escolher os dois.</p>
        <h3>Postagem dupla</h3>
        <p>Todo an&uacute;ncio, atualiza&ccedil;&atilde;o ou rota nova sai <b>nos dois idiomas</b> &mdash; nunca s&oacute; um. Voc&ecirc; nunca perde nada por causa de idioma.</p>
      </div>
      <div class="col">
        <h3>Canais principais</h3>
        <ul class="feat">
          <li><span class="chip">#di&aacute;rio-do-dev</span> o trabalho em tempo real (o que muda a cada update).</li>
          <li><span class="chip">#sugest&otilde;es</span> pe&ccedil;a uma fun&ccedil;&atilde;o ou um time/rota novo.</li>
          <li><span class="chip">#bug-report</span> achou um bug? reporte e a gente corrige no pr&oacute;ximo update.</li>
          <li><span class="chip">#tradu&ccedil;&otilde;es-pendentes</span> ajude a confirmar termos do Pokeking.</li>
        </ul>
        <div class="tip" style="margin-top:6px">&#128172; <b>Entre:</b> <a href="https://discord.gg/9jCuB6BDBC">discord.gg/9jCuB6BDBC</a></div>
      </div>
    </div>
  </section>

  <section>
    <h2><span class="n">12</span>Links oficiais</h2>
    <ul class="links">
      <li>&#128172; <b>Discord:</b> <a href="https://discord.gg/9jCuB6BDBC">discord.gg/9jCuB6BDBC</a></li>
      <li>&#11015;&#65039; <b>Download (Win/Mac/Android):</b> <a href="https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest">github.com/&hellip;/prestrelo-ajuda-download/releases/latest</a></li>
      <li>&#128279; <b>Site de atualiza&ccedil;&otilde;es:</b> <a href="https://farmoracle-roadmap.pages.dev/">farmoracle-roadmap.pages.dev</a></li>
      <li>&#9654;&#65039; <b>YouTube:</b> <a href="https://youtu.be/geaZukOUq4w">@FarmOracleMMO</a></li>
      <li>&#128499;&#65039; <b>T&oacute;pico no f&oacute;rum do PokeMMO:</b> <a href="https://forums.pokemmo.com/index.php?/topic/198436-farmoraclemmo-a-turn-by-turn-battle-helper-for-red-gym-farm-the-elite-4-windows-%C2%B7-mac-%C2%B7-android/">forums.pokemmo.com</a></li>
    </ul>
  </section>

  <footer>FarmOracleMMO v1.6.0 &middot; Windows &middot; macOS &middot; Android &mdash; um ajudante de batalha turno a turno, feito com a comunidade do PokeMMO. Feito pelo Prestrelo.</footer>
</div>
</body>
</html>
"""
HTML=(HTML.replace("__CSS__",CSS).replace("__ICON__",ICON).replace("__HOME__",HOME)
          .replace("__BATTLE__",BATTLE).replace("__TEAMS__",TEAMS))
open(os.path.join(SCR,"FarmOracleMMO-Guia-PT.html"),"w",encoding="utf-8").write(HTML)
print("guia PT escrito:",len(HTML),"bytes")
