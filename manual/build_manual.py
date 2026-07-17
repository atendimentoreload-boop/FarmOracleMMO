# -*- coding: utf-8 -*-
import base64, io, os
SCR="/private/tmp/claude-501/-Users-vinysa-Desktop-projetos-Destruidor-de-Red/1c473908-9768-4253-a0d3-2667eb2417ee/scratchpad"
ROOT="/Users/vinysa/Desktop/projetos/Destruidor de Red"

def durl(path, mime):
    b=base64.b64encode(open(path,"rb").read()).decode()
    return f"data:{mime};base64,{b}"

ICON = durl(os.path.join(ROOT,"android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"),"image/png")
HOME = durl(os.path.join(SCR,"man_img/shot-001.jpg"),"image/jpeg")
BATTLE = durl(os.path.join(SCR,"man_img/shot-003.jpg"),"image/jpeg")
TEAMS = durl(os.path.join(SCR,"man_img/shot-008.jpg"),"image/jpeg")

HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FarmOracleMMO — Complete Guide</title>
<style>
  :root{
    --ink:#1b1630; --mut:#5b5470; --dim:#8b84a0; --line:#e6e1f2;
    --purple:#6d4fd0; --purple2:#8b6cf0; --gold:#e0a92e; --gold2:#f5c451;
    --green:#1f9d63; --amber:#b9791a; --bg:#faf9fe; --panel:#ffffff;
    --mac:#2f7dd1; --win:#2f7dd1; --and:#1f9d63;
  }
  *{box-sizing:border-box}
  html,body{margin:0}
  body{font-family:'Segoe UI',-apple-system,BlinkMacSystemFont,Inter,Roboto,Helvetica,Arial,sans-serif;
    color:var(--ink); background:var(--bg); line-height:1.55; -webkit-font-smoothing:antialiased;}
  a{color:var(--purple); text-decoration:none}
  .wrap{max-width:960px; margin:0 auto; padding:0 34px 60px}

  header.hero{background:linear-gradient(120deg,#1a1330,#2a1e52 60%,#3a2b70); color:#fff; padding:30px 0 26px; margin-bottom:8px}
  header.hero .wrap{display:flex; align-items:center; gap:20px; padding-top:8px; padding-bottom:8px}
  .logo{width:78px;height:78px;flex:0 0 auto;object-fit:contain;filter:drop-shadow(0 6px 16px rgba(120,90,240,.55))}
  header.hero h1{margin:0;font-size:30px;letter-spacing:.3px}
  header.hero h1 span{color:var(--gold2)}
  header.hero .tag{color:#cfc7ea;font-size:15px;margin-top:3px}
  .vpill{display:inline-flex;margin-top:9px;align-items:center;gap:7px;padding:5px 13px;border-radius:999px;font-weight:800;font-size:12.5px;
    background:rgba(245,196,81,.16);border:1px solid rgba(245,196,81,.5);color:var(--gold2);letter-spacing:.5px}

  h2{font-size:20px;margin:34px 0 4px;color:#2a1e52;display:flex;align-items:center;gap:10px}
  h2 .n{display:inline-grid;place-items:center;width:26px;height:26px;border-radius:8px;background:linear-gradient(180deg,var(--purple2),var(--purple));color:#fff;font-size:14px;font-weight:800}
  h2::after{content:"";flex:1;height:2px;background:linear-gradient(90deg,var(--gold2),transparent);border-radius:2px;margin-left:4px}
  h3{font-size:15px;margin:16px 0 4px;color:#3a2b70}
  p{margin:6px 0}
  .lead{color:var(--mut);font-size:15px}
  section{page-break-inside:avoid}
  b,strong{color:var(--ink)}
  .mut{color:var(--mut)}

  table{width:100%;border-collapse:collapse;margin:10px 0;font-size:13.5px}
  th,td{border:1px solid var(--line);padding:9px 11px;vertical-align:top;text-align:left}
  th{background:#f3f0fb;color:#2a1e52;font-size:12px;text-transform:uppercase;letter-spacing:.5px}

  .row{display:flex;gap:22px;align-items:flex-start;flex-wrap:wrap}
  .col{flex:1 1 300px;min-width:280px}
  .shot{flex:0 0 auto;background:#0e0b16;border:6px solid #0e0b16;border-radius:22px;box-shadow:0 10px 30px rgba(30,20,60,.22);overflow:hidden}
  .shot img{display:block;width:224px;height:auto;border-radius:16px}
  .shot.wide img{width:250px}
  .cap{font-size:11.5px;color:var(--dim);text-align:center;margin-top:7px}

  ul.feat{list-style:none;padding:0;margin:8px 0}
  ul.feat li{position:relative;padding:5px 0 5px 24px;font-size:14px}
  ul.feat li::before{content:"▸";position:absolute;left:4px;color:var(--purple2);font-weight:800}
  ul.feat li b{color:#2a1e52}

  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .card{border:1px solid var(--line);border-radius:12px;padding:12px 14px;background:var(--panel)}
  .card h4{margin:0 0 3px;font-size:14px;color:#2a1e52}
  .card p{margin:0;font-size:13px;color:var(--mut)}
  .chip{display:inline-block;font-size:11.5px;font-weight:700;padding:2px 8px;border-radius:999px;background:#f0ecfb;border:1px solid var(--line);color:var(--purple)}

  .tip{background:linear-gradient(180deg,#fff8e8,#fffdf6);border:1px solid #f0deae;border-left:4px solid var(--gold);border-radius:10px;padding:11px 14px;margin:14px 0;font-size:13.5px;color:#5a4a20}
  .tip b{color:#7a5a10}

  .links{list-style:none;padding:0;margin:8px 0}
  .links li{padding:5px 0;font-size:14px}
  .links li b{color:#2a1e52}

  footer{margin-top:34px;border-top:1px solid var(--line);padding-top:14px;color:var(--dim);font-size:12.5px;text-align:center}

  @page{size:A4;margin:14mm}
  @media print{ body{background:#fff} header.hero{-webkit-print-color-adjust:exact;print-color-adjust:exact} }
</style>
</head>
<body>

<header class="hero">
  <div class="wrap">
    <img class="logo" src="__ICON__" alt="FarmOracleMMO">
    <div>
      <h1>Farm<span>Oracle</span>MMO</h1>
      <div class="tag">Turn-by-turn helper for PokeMMO &mdash; Red, Gym Farm, Cynthia &amp; Morimoto, Ho-Oh and the Elite 4</div>
      <span class="vpill">&#128218; COMPLETE GUIDE &middot; VERSION 1.6.0</span>
    </div>
  </div>
</header>

<div class="wrap">

  <section>
    <h2><span class="n">1</span>What it is</h2>
    <p class="lead">FarmOracleMMO is a helper that sits in a <b>floating window/bubble</b> over the game and tells you, <b>turn by turn</b>, exactly what to do to win the game's hardest, most repeatable fights: <b>Red</b>, the <b>Gym Farm</b> (gym re-battles), <b>Cynthia &amp; Morimoto</b>, <b>Ho-Oh</b> and the <b>Elite 4</b> across all 5 regions. It <b>narrows the possibilities as the battle goes</b> &mdash; you tell it what the opponent did, and it walks you to the exact winning line.</p>
    <p>It is <b>not</b> an automation/bot &mdash; you play; it just shows the optimal script. Available for <b>Windows, macOS and Android</b>, all shipping the <b>same version with the same features</b>.</p>
  </section>

  <section>
    <h2><span class="n">2</span>Install</h2>
    <p>Download the latest version at: <a href="https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest">github.com/&hellip;/prestrelo-ajuda-download/releases/latest</a></p>
    <table>
      <tr><th>Windows</th><th>macOS</th><th>Android</th></tr>
      <tr>
        <td>Download the <b>.zip</b>, extract and open the <b>.exe</b>.</td>
        <td>Open the <b>.app</b>. On macOS Sequoia (15+), use the included one-click opener if Gatekeeper blocks it the first time.</td>
        <td>Install the <b>.apk</b> and grant the <b>overlay</b> permission (&ldquo;draw over other apps&rdquo;).</td>
      </tr>
    </table>
    <div class="tip">&#128161; <b>Language:</b> the app is fully bilingual. On first launch you pick <b>English</b> or Portuguese, and there is a one-tap <b>PT&#8644;EN</b> chip on the home screen to switch anytime.</div>
  </section>

  <section>
    <h2><span class="n">3</span>The home menu</h2>
    <div class="row">
      <div class="shot"><img src="__HOME__" alt="Home menu"><div class="cap">Home menu &mdash; pick a mode</div></div>
      <div class="col">
        <p>Every fight the app helps with is one tap away. Each mode has a <b>&#9654; start</b> button and a <b>? Pok&eacute;paste</b> button (the exact team to build).</p>
        <ul class="feat">
          <li><b>Elite 4</b> &mdash; all 5 regions (Kanto, Hoenn, Sinnoh, Unova, Johto).</li>
          <li><b>Gym Farm</b> &mdash; re-battle gym leaders in double battles (18h cooldown) for big money. Routes: <b>Six Pillars</b> (Veteran &amp; BASIC) and <b>Lucky Girl</b> (Seven Hells).</li>
          <li><b>Cynthia &amp; Morimoto</b> &mdash; the post-league double fight.</li>
          <li><b>Red</b> &mdash; the Mt. Silver fight (multiple selectable strategies).</li>
          <li><b>Ho-Oh</b> &mdash; the legendary rematch (incl. a Trick Room strategy).</li>
          <li><b>Menu</b> &mdash; teams, Pok&eacute;pastes, sources and settings.</li>
        </ul>
        <p class="mut">The footer shows the version, credits and quick links to the <b>Discord</b> and <b>YouTube</b>.</p>
      </div>
    </div>
    <p class="cap" style="text-align:left">Screenshots in this guide are from the Android build (shown in Portuguese); every screen is identical in English once you set the language.</p>
  </section>

  <section>
    <h2><span class="n">4</span>How the turn-by-turn works</h2>
    <div class="row">
      <div class="col">
        <p>Pick a mode, then pick your <b>lead / region</b>. The guide shows the current <b>node</b> and walks the fight with you:</p>
        <ul class="feat">
          <li><b>Opponent on field</b> &mdash; a header shows which Pok&eacute;mon you are facing.</li>
          <li><b>Turn steps</b> &mdash; the exact actions (T1, T2&hellip;), with move names <b>colour-coded</b> and important <b>warning notes</b> highlighted in amber.</li>
          <li><b>&ldquo;What did the opponent do?&rdquo;</b> &mdash; choice buttons; tap the answer and the guide <b>narrows to the exact winning line</b>.</li>
          <li><b>See teams</b> &mdash; shows the opponent's <b>possible teams</b> (item, ability and all four moves), narrowing as the fight goes.</li>
          <li><b>Progress</b> &mdash; a &ldquo;step x / y&rdquo; indicator, plus <b>Next</b>, <b>Back</b> (undo), <b>Reset</b> and <b>Skip this stop</b>.</li>
          <li><b>Elite 4 sequence</b> &mdash; at the end of a fight it jumps straight to the next trainer in the run.</li>
        </ul>
      </div>
      <div class="shot wide"><img src="__BATTLE__" alt="Turn-by-turn overlay"><div class="cap">The overlay during a fight (Ho-Oh)</div></div>
    </div>
  </section>

  <section>
    <h2><span class="n">5</span>The floating overlay &amp; controls</h2>
    <p class="lead">The panel floats over the game so you never alt-tab. Everything about it is adjustable:</p>
    <div class="grid2">
      <div class="card"><h4>Minimize to a bubble</h4><p>Collapse to a small Ball anywhere on screen; tap to reopen exactly where you left off.</p></div>
      <div class="card"><h4>Always on top</h4><p>Stays above the game window at all times.</p></div>
      <div class="card"><h4>Drag &amp; resize</h4><p>Move the window/bubble anywhere; resize the panel from the corner grip.</p></div>
      <div class="card"><h4>Opacity</h4><p>A slider sets how transparent the panel is over the game.</p></div>
      <div class="card"><h4>Font size &mdash; A&minus; / A / A+</h4><p>A chip on the title bar scales the whole panel up or down for readability.</p></div>
      <div class="card"><h4>Keyboard shortcuts (desktop)</h4><p>A global &ldquo;Next step&rdquo; hotkey works even with the game focused, plus <b>F1&ndash;F12</b> to pick the choices.</p></div>
      <div class="card"><h4>Search / filter</h4><p>Filter long lists (leads, cities) to find what you need fast.</p></div>
      <div class="card"><h4>Android extras</h4><p>&ldquo;Open here&rdquo; (no overlay) mode, foreground service and system notifications.</p></div>
    </div>
  </section>

  <section>
    <h2><span class="n">6</span>Teams, strategies &amp; sources</h2>
    <div class="row">
      <div class="shot"><img src="__TEAMS__" alt="Teams and options"><div class="cap">Menu &mdash; teams, strategies &amp; source buttons</div></div>
      <div class="col">
        <p>Open <b>Menu</b> to manage everything. Teams are grouped by mode, and you can <b>select a team or strategy directly</b>:</p>
        <ul class="feat">
          <li><b>Strategy selector</b> &mdash; e.g. Red has multiple teams, Ho-Oh has a <b>Trick Room</b> line, Cynthia &amp; Morimoto has variants, the Elite 4 has several full teams (Shadow Scale, Reversed Fate, Dingxianyou, Starlight, Ghost Dance, Sacred Inferno&hellip;).</li>
          <li><b>Per-team source buttons</b> &mdash; <span class="chip">&#9654; video</span> <span class="chip">&#128196; document</span> <span class="chip">&#9432; Pokeking CODE</span> (copy the code and build the exact team in-game).</li>
          <li><b>Pok&eacute;paste button</b> &mdash; the full team with items, abilities, IVs and moves.</li>
          <li><b>Emoji mode</b> &mdash; when a team ships an emoji version, view the fight in the author's original notation.</li>
          <li><b>Language</b> &mdash; PT/EN selector, remembered between sessions.</li>
        </ul>
      </div>
    </div>
  </section>

  <section>
    <h2><span class="n">7</span>Gym Farm &mdash; Six Pillars &amp; Lucky Girl</h2>
    <p>The <b>Gym Farm</b> mode is a money-maker: you re-battle gym leaders in <b>double battles</b> on an 18-hour cooldown for a large payout. The app carries full step-by-step routes:</p>
    <ul class="feat">
      <li><b>Six Pillars</b> &mdash; a fixed 6-mon team with two selectable routes: <b>Veteran</b> and <b>BASIC</b> (27 gyms, transcribed from the official docs).</li>
      <li><b>Lucky Girl (Seven Hells)</b> &mdash; an alternative farm route (Meloetta-based).</li>
    </ul>
    <p class="mut">Routes are grouped in a per-team submenu, each with its own Pok&eacute;paste and source document.</p>
  </section>

  <section>
    <h2><span class="n">8</span>Cooldown &amp; farming timer</h2>
    <p class="lead">New in 1.6.0. A clock button opens a <b>timer hub</b> so you never lose track of your farm loops &mdash; especially useful if you run many alts.</p>
    <ul class="feat">
      <li><b>Register your characters (alts)</b> and track <b>battle cooldowns</b>: Elite 4, farm routes, Red and Cynthia &amp; Morimoto.</li>
      <li><b>Berry timers</b> &mdash; the plant &rarr; water &rarr; harvest cycle, so you know exactly when to come back.</li>
      <li><b>System alarm</b> &mdash; a banner + sound notification fires at the exact time, <b>even with the app closed</b>.</li>
    </ul>
    <div class="tip">&#128161; A <b>sync (PC &#8646; phone)</b> mode is on the way, so a timer you start on one device shows up on the other.</div>
  </section>

  <section>
    <h2><span class="n">9</span>Feedback, updates &amp; help</h2>
    <ul class="feat">
      <li><b>&ldquo;Worked / Didn't work&rdquo;</b> &mdash; one-tap feedback on Elite 4 fights; &ldquo;Didn't work&rdquo; opens a box so you can tell us what happened.</li>
      <li><b>Update checker</b> &mdash; the app tells you when a new version is out; critical releases can require an update before continuing.</li>
      <li><b>Credits &amp; links</b> &mdash; a footer with the version and shortcuts to the community.</li>
    </ul>
  </section>

  <section>
    <h2><span class="n">10</span>Live updates site (roadmap)</h2>
    <p>Want to see what we're building in real time? We keep a <b>public, live roadmap</b> page:</p>
    <p style="font-size:16px"><b>&#128279; <a href="https://farmoracle-roadmap.pages.dev/">farmoracle-roadmap.pages.dev</a></b></p>
    <ul class="feat">
      <li><b>Solved</b> &mdash; everything that's already fixed, and in which version.</li>
      <li><b>In progress</b> &mdash; what's being worked on right now.</li>
      <li><b>Every request</b> &mdash; all community suggestions/bugs that are logged.</li>
      <li><b>Platform parity</b> &mdash; what's ready on Mac, Windows and Android.</li>
      <li><b>Version history</b> &mdash; what shipped in each release.</li>
    </ul>
    <p class="mut">The page updates in real time &mdash; the moment we fix or log something, it shows up.</p>
  </section>

  <section>
    <h2><span class="n">11</span>Discord community &mdash; how it works</h2>
    <div class="row">
      <div class="col">
        <h3>Separated by language (PT / EN)</h3>
        <p>When you join, pick your language in <span class="chip">#language</span> (react with a flag). <b>English</b> members see only the English channels; Portuguese members see only the Portuguese ones. You can pick both.</p>
        <h3>Dual posting</h3>
        <p>Every announcement, update or new route goes out <b>in both languages</b> &mdash; never only one. You never miss anything because of language.</p>
      </div>
      <div class="col">
        <h3>Main channels</h3>
        <ul class="feat">
          <li><span class="chip">#dev-diary</span> the work in real time (what changes each update).</li>
          <li><span class="chip">#suggestions</span> request a feature or a new team/route.</li>
          <li><span class="chip">#bug-report</span> found a bug? report it and we fix it next update.</li>
          <li><span class="chip">#translations-pending</span> help confirm Pokeking terms.</li>
        </ul>
        <div class="tip" style="margin-top:6px">&#128172; <b>Join:</b> <a href="https://discord.gg/9jCuB6BDBC">discord.gg/9jCuB6BDBC</a></div>
      </div>
    </div>
  </section>

  <section>
    <h2><span class="n">12</span>Official links</h2>
    <ul class="links">
      <li>&#128172; <b>Discord:</b> <a href="https://discord.gg/9jCuB6BDBC">discord.gg/9jCuB6BDBC</a></li>
      <li>&#11015;&#65039; <b>Download (Win/Mac/Android):</b> <a href="https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest">github.com/&hellip;/prestrelo-ajuda-download/releases/latest</a></li>
      <li>&#128279; <b>Live updates site:</b> <a href="https://farmoracle-roadmap.pages.dev/">farmoracle-roadmap.pages.dev</a></li>
      <li>&#9654;&#65039; <b>YouTube:</b> <a href="https://youtu.be/geaZukOUq4w">@FarmOracleMMO</a></li>
      <li>&#128499;&#65039; <b>PokeMMO forum thread:</b> <a href="https://forums.pokemmo.com/index.php?/topic/198436-farmoraclemmo-a-turn-by-turn-battle-helper-for-red-gym-farm-the-elite-4-windows-%C2%B7-mac-%C2%B7-android/">forums.pokemmo.com</a></li>
    </ul>
  </section>

  <footer>FarmOracleMMO v1.6.0 &middot; Windows &middot; macOS &middot; Android &mdash; a community-driven, turn-by-turn battle helper. Made by Prestrelo with the PokeMMO community.</footer>
</div>
</body>
</html>
"""

HTML = (HTML.replace("__ICON__",ICON).replace("__HOME__",HOME)
            .replace("__BATTLE__",BATTLE).replace("__TEAMS__",TEAMS))
open(os.path.join(SCR,"FarmOracleMMO-Guide-EN.html"),"w",encoding="utf-8").write(HTML)
print("manual escrito:", len(HTML), "bytes")
