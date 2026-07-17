#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 2: traduz Reversed Fate (didático, glossário aplicado) + limpa '；' do Shadow Scale."""
import json, glob, re, unicodedata

def norm(s):
    s = unicodedata.normalize('NFC', s or '')
    s = s.replace('’',"'").replace('‘',"'").replace('“','"').replace('”','"')
    return re.sub(r'\s+',' ', s).strip()

CORR = [
 # ===== REVERSED FATE · HOENN =====
 ["testar se it's a roll para die by Flamethrower/runs para gyara Veja abaixo b4 setup complete",
  "Testar: dependendo do HP, o Electivire pode não morrer pro Flamethrower. Se ele trocar pro Gyarados, veja a solve abaixo — antes de completar o setup."],
 ["run see above", "Se ele fugir, volte para a solve anterior (veja para qual Pokémon ele voltou)."],
 ["See run under. precisa para solve for Jirachi . Grass knot Froslass",
  "Se ele fugir, veja a solve do Jirachi abaixo. Se não fugir, use Grass Knot no Froslass (depois dos buffs)."],
 ["testar para see se X Defesa prevents Dusknoir from coming",
  "Testar se o X Defesa segura o dano do Dusknoir (Shadow Sneak é o golpe de prioridade dele)."],
 ["Jirachi dies · Gallade[Encore, +2 Ataque, +2 Velocidade] Max Potion contra lanturn/Gallade depends on team. Psycho Skarmory 2nd hit. Will add them soon Aqua jet crítico · Dragonite[+2 Ataque]",
  "Se o Jirachi morrer · Gallade[Encore, +2 Ataque, +2 Velocidade] · use Max Potion contra Lanturn/Gallade (depende do time) · Psycho Cut nocauteia o Skarmory no 2º hit · se tomar Aqua Jet crítico · Dragonite[+2 Ataque]."],
 ["Encore sacrifica star below 20% · don't tem but para be safe u pode. Ai might be weird e use a different move",
  "Encore e sacrifica o Jirachi se ficar abaixo de 20% · não é obrigatório, mas pra garantir você pode · a IA pode agir estranho e usar um golpe diferente."],
 ["Runs para Nidoqueen see solve", "Se ele trocar pro Nidoqueen, veja a solve do Nidoqueen."],
 ["Sacred Sword then psycho Skarmory. Max Potion contra Gallade/lanturn depends on team will add soon",
  "Sacred Sword, depois Psycho Cut no Skarmory · use Max Potion contra Gallade/Lanturn (depende do time)."],
 ["See who", "Veja qual Pokémon ele coloca em campo e siga a solve correspondente."],
 ["Jirachi não usa die ok · used vswitch on Chandelure",
  "Se o Jirachi não morrer · ele usou Volt Switch no Chandelure (vai ter que trocar)."],
 ["testar para see se Gallade kills meta/ precisa crítico solve for Lucario e Velocidade/ testar se Psycho Cut nocauteia amp",
  "Testar se o Gallade mata o Metagross · precisa de solve pra caso de crítico no Lucario e empate de Velocidade · testar se o Psycho Cut nocauteia o Ampharos."],
 ["Idk se it's a Velocidade tie Pikachu não usa die Encore",
  "Sem certeza se é empate de Velocidade · se o Pikachu não morrer, dá Encore."],
 ["Pikachu die · Scrafty[Encore, +2 Ataque, +2 Velocidade] . No helmet on Milo",
  "Se o Pikachu morrer · Scrafty[Encore, +2 Ataque, +2 Velocidade] · o Milotic não tem Rocky Helmet."],
 ["Pika die · Scrafty[Encore, +4 Ataque, +2 Velocidade] ?testar se Thunderbolt is a roll on Chandelure pika pode't nocauteia Gardevoir",
  "Se o Pikachu morrer · Scrafty[Encore, +4 Ataque, +2 Velocidade] · testar se o Thunderbolt mata o Chandelure (roll) · o Pikachu não consegue nocautear a Gardevoir."],
 ["Runs para lanturn see lanturn solve / regi pode nocauteia at45% wary of hp. cura se precisa",
  "Se ele trocar pro Lanturn, veja a solve do Lanturn · o Regi pode nocautear a 45% · cuidado com o HP, cure se precisar."],
 ["Remove burn then continuar??? Maybe Full Restore se hp really low??",
  "Tire a queimadura e continue · ele pode usar Full Restore se o HP estiver muito baixo."],
 ["testar with Hyper Potion? ou anything cheaper that gives 100 ou more hp. Don't think it needs para be Max Potion.",
  "Testar com Hyper Potion ou qualquer cura mais barata que dê 100+ de HP · provavelmente não precisa ser Max Potion."],
 ["No priority golpes. cura se precisa. Earthquake lanturn. Missed hydro ? Hard troca · X Velocidade primeiro",
  "Sem golpes de prioridade · cure se precisar · Earthquake no Lanturn · se ele errar o Hydro · troca direta (hard) · X Velocidade primeiro."],
 # ===== REVERSED FATE · JOHTO =====
 ["testar only ss nocauteia see what happens", "Testar se só o Stealth Rock nocauteia · veja o que acontece."],
 ["Hp ghost. crítico no Stealth Rock see below max nocauteia Gengar",
  "HP do Gengar (ghost) · se tomar crítico no Stealth Rock, veja abaixo · nocauteia o Gengar."],
 ["Psycho Poliwrath/ Lucario Shadow Ball crítico will nocauteia",
  "Psycho Cut no Poliwrath/Lucario · Shadow Ball crítico nocauteia."],
 ["Scrafty Earthquake die · star Encore · psycho Dragonite",
  "Scrafty usa Earthquake e morre · Jirachi dá Encore · Psycho Cut no Dragonite."],
 ["See situation e Chandelure pressione se precisa",
  "Veja a situação e use o Chandelure · continue pressionando se precisar."],
 # ===== REVERSED FATE · KANTO =====
 ["Star não usa die hard swap Gallade e x Velocidade primeiro then Encore ?",
  "Se o Jirachi não morrer · troca direta (hard swap) pro Gallade · X Velocidade primeiro, depois Encore."],
 ["see damage", "Veja o dano."],
 ["testar (4+0) may precisa Max Potion", "Testar (4+0) · talvez precise de Max Potion."],
 ["X special primeiro/ runs para Lapras pressione contra Dragonite depois x Velocidade · cura then pressione",
  "X Ataque Especial primeiro · se ele trocar pro Lapras, continue pressionando · contra o Dragonite, depois X Velocidade · cure e continue pressionando."],
 ["Miss Stone Edge · Gallade[+2 Ataque, +2 Velocidade, Encore] wary of hp. Gallade Will die in 4hits",
  "Se errar o Stone Edge · Gallade[+2 Ataque, +2 Velocidade, Encore] · cuidado com o HP · o Gallade morre em 4 hits."],
 ["testar For Stone Edge/cross chop solve nocauteia hairyama e see what comes in. se toge comes in troca Jirachi · Thunderbolt · Encore sacrifica · Chandelure[+2 Ataque Especial, +2 Velocidade]",
  "Testar a solve pra Stone Edge/Cross Chop · nocauteia o Hariyama e veja quem entra · se o Togekiss entrar, troca pro Jirachi · Thunderbolt · Encore e sacrifica · Chandelure[+2 Ataque Especial, +2 Velocidade]."],
 ["Faced hairyama below 24% Max Potion. See se pode use anything cheaper",
  "Se enfrentar o Hariyama abaixo de 24%, use Max Potion · veja se dá pra usar algo mais barato."],
 ["May precisa para use root b4 Stealth Rock ??", "Talvez precise usar Energy Root antes do Stealth Rock."],
 ["Probably won't work may be a roll. Chandelure fire nocauteia see what comes in",
  "Provavelmente não funciona (pode ser roll) · o fogo do Chandelure nocauteia · veja quem entra."],
 ["não usa leave se para. continuar as normal. Flash Fire may be precisa precisa crítico solve.",
  "Não deixa fugir · continue normalmente · Flash Fire · talvez precise de uma solve pra caso de crítico."],
 ["pode u turn into Dragonite . crítico star no Stealth Rock · Dragonite[+2 Ataque, +4 Velocidade]",
  "Dá pra dar U-turn pro Dragonite · se o Jirachi tomar crítico no Stealth Rock · Dragonite[+2 Ataque, +4 Velocidade]."],
 ["Pikachu dies para flame thrower. Go para Jirachi Stealth Rock Encore sacrifica · gets hit by electric move see se you pode setup",
  "O Pikachu morre pro Flamethrower · vá de Jirachi · Stealth Rock · Encore e sacrifica · se tomar golpe elétrico, veja se dá pra fazer setup."],
 ["Boosted Pikachu see below", "Pikachu bufado · veja abaixo."],
 ["Remove poison before pressione", "Tire o veneno antes de continuar pressionando."],
 ["Arbok primeiro contra then psycho nocauteia Gengar · se not Leaf Blade",
  "Arbok primeiro · depois Psycho Cut nocauteia o Gengar · se não, Leaf Blade."],
 ["Jirachi cura with anything that keeps you above 50%",
  "Cure o Jirachi com qualquer item que mantenha acima de 50%."],
 ["beat up disabled see below/ pode setup with Dragonite high chance of fainting",
  "Se o Beat Up for desabilitado, veja abaixo · dá pra fazer setup com o Dragonite, mas com alta chance de desmaiar."],
 ["Star no Encore · Gallade Encore into Scrafty X Defesa Especial+2. precisa crítico solve",
  "Jirachi sem Encore · Gallade dá Encore · entra o Scrafty · X Defesa Especial +2 · precisa de solve pra caso de crítico."],
 ["see skill", "Veja a habilidade."],
 ["Unsure of this solve precisa feedback. May tem para Stealth Rock Encore ?",
  "Sem certeza dessa solve, precisa de feedback · talvez precise de Stealth Rock + Encore."],
 ["Needs a better solve. não usa die Veja abaixo", "Precisa de uma solve melhor · se não morrer, veja abaixo."],
 ["Life Orb Earthquake will Earthquake again se star se HP baixo",
  "Com Life Orb, ele usa Earthquake de novo · se o Jirachi estiver com HP baixo."],
 ["See damage under", "Veja o dano abaixo."],
 ["Don't use touching golpes on Ampharos", "Não use golpes de contato no Ampharos."],
 ["Dragon Rush Steelix then Earthquake", "Dragon Rush no Steelix, depois Earthquake."],
 ["Pikachu die Veja abaixo", "Se o Pikachu morrer, veja abaixo."],
 ["Fica Thunderbolt · cura hp. Star may not precisa para Encore ???",
  "Fica · Thunderbolt · cure o HP · o Jirachi talvez não precise dar Encore."],
 ["pode also Dragonite[Encore, +3 Ataque, +2 Velocidade] runs para skar continuar",
  "Dá pra usar Dragonite[Encore, +3 Ataque, +2 Velocidade] também · se ele trocar pro Skarmory, continue."],
 # ===== REVERSED FATE · SINNOH =====
 ["HP baixo Max Potion before Encore ends", "HP baixo: use Max Potion antes do Encore acabar."],
 ["See damage", "Veja o dano."],
 ["Energy Root before pressione ? Testing", "Energy Root antes de pressionar? (testando)"],
 ["Scrafty contra Gliscor then Encore", "Scrafty contra o Gliscor, depois Encore."],
 ["testar se Leaf Blade kills Gengar. HP baixo star · Encore sacrifica se so don't Encore with Gallade",
  "Testar se o Leaf Blade mata o Gengar · se o Jirachi estiver com HP baixo · Encore e sacrifica · nesse caso não dê Encore com o Gallade."],
 ["HP baixo star Encore sacrifica · no precisa para Encore Gallade . testar se you pode nocauteia wo Encore",
  "Jirachi com HP baixo · Encore e sacrifica · não precisa dar Encore com o Gallade · testar se dá pra nocautear sem Encore."],
 ["se Scrafty lives don't Encore sacrifica Jirachi", "Se o Scrafty sobreviver, não dê Encore nem sacrifique o Jirachi."],
 ["Max Potion see skill", "Max Potion · veja a habilidade."],
 ["U turn causes faint. Hard troca para avoid it but must Encore depois stat boost",
  "O U-turn causa desmaio · faça troca direta (hard) pra evitar, mas precisa dar Encore depois do buff."],
 ["Max Potion before pressione ou early se precisa", "Max Potion antes de pressionar, ou mais cedo se precisar."],
 ["Psycho Cut then Sacred Sword", "Psycho Cut, depois Sacred Sword."],
 ["See se you pode nocauteia wo Encore", "Veja se dá pra nocautear sem Encore."],
 ["foretress comes out see below", "Se o Forretress entrar, veja abaixo."],
 ["pressione para Magmortar e then x Velocidade.", "Continue pressionando até o Magmortar, depois X Velocidade."],
 ["testar Chandelure fire nocauteia Lucario. See what comes in",
  "Testar se o fogo do Chandelure nocauteia o Lucario · veja quem entra."],
 ["Might not work. Don't know Stone Edge damage on Scrafty. Sacred fire did 82.7",
  "Pode não funcionar · não sei o dano do Stone Edge no Scrafty · o Sacred Fire deu 82,7%."],
 ["Runs para Mismagius continuar strengthen · face Empoleon Max Potion · see se ghost has ice HP",
  "Se ele trocar pro Mismagius, continue bufando · contra o Empoleon use Max Potion · veja se o ghost tem HP pra aguentar Ice."],
 ["Star faint/crítico · Gallade Encore . testar se you pode use Scrafty instead of Gallade",
  "Se o Jirachi desmaiar/tomar crítico · Gallade dá Encore · testar se dá pra usar o Scrafty no lugar do Gallade."],
 ["HP baixo star · Encore sacrifica · Max Potion precisa for Gallade maybe ???",
  "Jirachi com HP baixo · Encore e sacrifica · talvez precise de Max Potion pro Gallade."],
 ["Might run ?? precisa data. Lapras Ice Shard · se crítico e die Gallade nocauteia",
  "Ele pode fugir (falta testar) · Lapras Ice Shard · se tomar crítico e morrer, o Gallade nocauteia."],
 ["testar hard swap into Gallade", "Testar troca direta (hard swap) pro Gallade."],
 ["Dragonite cura Jirachi se Dragonite não usa die hard swap Gallade[+2 Ataque, +2 Velocidade]",
  "Dragonite cura o Jirachi · se o Dragonite não morrer · troca direta (hard swap) pro Gallade[+2 Ataque, +2 Velocidade]."],
 ["Psycho Cut Garchomp · Sacred Sword then psycho zong",
  "Psycho Cut no Garchomp · Sacred Sword, depois Psycho Cut no Bronzong."],
 # ===== REVERSED FATE · UNOVA =====
 ["testar nocauteia frog with Chandelure see what comes next",
  "Testar se nocauteia o Toxicroak (frog) com o Chandelure · veja quem vem a seguir."],
 ["Shadow Ball nocauteia (see what comes next)", "Shadow Ball nocauteia (veja quem vem a seguir)."],
 ["se Shadow Ball disabled ou not see below", "Se o Shadow Ball estiver desabilitado ou não, veja abaixo."],
 ["Solve não usa work see below for testar solves", "Essa solve não funciona · veja abaixo as solves de teste."],
 ["may troque para Golurk Dragonite/Gallade Encore 22 se crítico use Max Potion/ may precisa cura for star troca in",
  "Talvez troque pro Golurk · Dragonite/Gallade · Encore [+2/+2] · se tomar crítico, use Max Potion · talvez precise curar pra trazer o Jirachi."],
 ["testar se Iron Head will nocauteia", "Testar se o Iron Head nocauteia."],
 ["não usa die troca para Chandelure[+2 Ataque Especial, +2 Velocidade]",
  "Se não morrer, troca pro Chandelure[+2 Ataque Especial, +2 Velocidade]."],
 ["Probably will Earthquake", "Ele provavelmente vai usar Earthquake."],
 ["não usa work Bisharp will Sucker Punch", "Não funciona · o Bisharp vai usar Sucker Punch."],
 ["grass knot Froslass/ testar se you pode Stealth Rock then Chandelure se not it's a roll para live",
  "Grass Knot no Froslass · testar se dá pra usar Stealth Rock e depois Chandelure · se não, é roll pra sobreviver."],
 ["Dragonite[Encore, +3 Ataque, +2 Velocidade] para save $ · Earthquake Golurk e then Encore se no nocauteia",
  "Dragonite[Encore, +3 Ataque, +2 Velocidade] pra economizar · Earthquake no Golurk e depois Encore se não nocautear."],
 ["x Velocidade primeiro · then Encore Dragonite para save money/ fast hone claws +x Velocidade will u turn out",
  "X Velocidade primeiro · depois Encore · Dragonite pra economizar · com Hone Claws rápido + X Velocidade ele dá U-turn pra sair."],
 ["unsure se rocks are precisa · try hard swap para chande",
  "Sem certeza se precisa de Stealth Rock · tente troca direta (hard swap) pro Chandelure."],
 ["Annoying solve precisa para fix. pode no Stealth Rock Flinch with HP baixo Max Potion. Beat up Gliscor",
  "Solve chata, precisa ajustar · pode dar Stealth Rock · Flinch com HP baixo, use Max Potion · Beat Up no Gliscor."],
 ["testar u turn into Chandelure[+2 Ataque Especial, +2 Velocidade]",
  "Testar U-turn pro Chandelure[+2 Ataque Especial, +2 Velocidade]."],
 ["se burnt Encore then jirachi contra Staraptor Choice (preso num golpe) chande 22",
  "Se queimado · Encore · depois Jirachi contra o Staraptor (preso no golpe pela Choice) · Chandelure [+2/+2]."],
 ["Fire Blast miss Encore with star then nocauteia with chande see solves below. tomb pode shadow sneak sometimes precisa crítico solve",
  "Se o Fire Blast errar · Encore com o Jirachi · depois nocauteia com o Chandelure · veja as solves abaixo · o Spiritomb pode usar Shadow Sneak às vezes · precisa de solve pra caso de crítico."],
 ["testar para see se crítico will nocauteia/ beat up Garchomp",
  "Testar se o crítico nocauteia · Beat Up no Garchomp."],
 ["precisa data se you're faster than Garchomp. se not x Velocidade primeiro ?",
  "Falta testar se você é mais rápido que o Garchomp · se não, X Velocidade primeiro."],
 ["X Velocidade Dragonite primeiro · then Encore . No star Encore · Chandelure cura star. Reset pressione",
  "X Velocidade no Dragonite primeiro · depois Encore · Jirachi sem Encore · Chandelure cura o Jirachi · reinicie e continue pressionando."],
 ["May be faster than Dragonite Encore Ice Beam see below",
  "Ele pode ser mais rápido que o Dragonite · Encore · Ice Beam · veja abaixo."],
 ["Lives ball · go Scrafty · Life Orb nocauteia · testar hard troca into chande no sacrifica",
  "Sobrevive (ball) · vá de Scrafty · Life Orb nocauteia · testar troca direta (hard) pro Chandelure sem sacrificar."],
 ["See se beat up kills Milotic. Beat up meta. Wary of hp. crítico will nocauteia",
  "Veja se o Beat Up mata o Milotic · Beat Up no Metagross · cuidado com o HP · crítico nocauteia."],
 ["Velocidade tie with Dragonite · Encore Ice Beam see below",
  "Empate de Velocidade com o Dragonite · Encore · Ice Beam · veja abaixo."],
 ["contra Metagross · chande fire nocauteia · contra Emolga see above",
  "Contra o Metagross · o fogo do Chandelure nocauteia · contra o Emolga, veja acima."],
 ["swap until it dies from high jump kick", "Troque até ele morrer pro High Jump Kick."],
 ["Dragon Rush then Earthquake meta. Rock Slide 65%",
  "Dragon Rush, depois Earthquake no Metagross · Rock Slide dá 65%."],
 ["extreme Velocidade hits jirachi 12%/ scared fire misses see below",
  "Extreme Speed acerta o Jirachi (12%) · se o Sacred Fire errar, veja abaixo."],
 ["Velocidade tie. se Ice Beam see below", "Empate de Velocidade · se usar Ice Beam, veja abaixo."],
 ["Sacred fire misses see below", "Se o Sacred Fire errar, veja abaixo."],
 ["Scrafty alive see below. Shadow Ball Machamp · Scrafty no Encore use Pikachu",
  "Se o Scrafty estiver vivo, veja abaixo · Shadow Ball no Machamp · se o Scrafty não der Encore, use o Pikachu."],
 ["Tpunch see below/ pode't setup fully cura on Toxicroak then finish setup",
  "Thunder Punch · veja abaixo · não dá pra fazer setup completo · cure no Toxicroak e termine o setup."],
 ["Max Potion se precisa 23%. Sandstorm damage also",
  "Max Potion se precisar (23%) · cuidado também com o dano da Sandstorm."],
 ["Runs para exca ou miss HJK see below", "Se ele trocar pro Excadrill ou errar o High Jump Kick, veja abaixo."],
 ["May not precisa pot?", "Talvez não precise de poção."],
 ["May not precisa pot ?", "Talvez não precise de poção."],
 ["para see skill", "Veja a habilidade."],
 ["Wait till it firey dances · don't Encore Bug Buzz?? · x Velocidade primeiro??",
  "Espere ele usar Fiery Dance · não dê Encore no Bug Buzz · X Velocidade primeiro."],
 ["beat up · then drain punch exca. precisa better solve flame body proc here",
  "Beat Up · depois Drain Punch no Excadrill · precisa de uma solve melhor (o Flame Body pode ativar aqui)."],
 ["Conkledurr U-turn / testar Stealth Rock into Scrafty se Fica",
  "Conkeldurr · U-turn · testar Stealth Rock e entrar com o Scrafty se ele ficar."],
 ["Energy Root before pressione/ no pot Chandelure die · pressione Dragonite Encore · hone claws 3+0? testar",
  "Energy Root antes de pressionar · sem poção o Chandelure morre · continue com o Dragonite · Encore · Hone Claws [3+0]? testar."],
 ["Insta ko Chandelure see below", "Nocaute imediato · Chandelure · veja abaixo."],
]
CMAP = { norm(o): n for o,n in CORR }

files = [f for f in glob.glob('data/teams/**/*.json',recursive=True) if '/emoji/' not in f] + ['data/red.json','data/veteran.json']
hit = {k:0 for k in CMAP}; sc_clean=0
for f in files:
    d=json.load(open(f,encoding='utf-8')); changed=False
    is_shadow = 'shadow_scale' in f
    for n in d['nodes'].values():
        for s in n.get('steps',[]):
            t=s.get('text')
            if not t: continue
            k=norm(t)
            if k in CMAP and t!=CMAP[k]:
                s['text']=CMAP[k]; hit[k]+=1; changed=True; continue
            if is_shadow and '；' in t:
                nt=t.replace('；',' · ')
                nt=re.sub(r'\s*·\s*(·\s*)+',' · ', nt)      # colapsa separadores repetidos
                nt=re.sub(r'\s{2,}',' ', nt).strip(' ·')
                nt=nt.replace('use foi derrotado','foi derrotado').replace('Pray garantido','garantido')
                if nt!=t: s['text']=nt; sc_clean+=1; changed=True
    if changed:
        json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)

tot=sum(hit.values())
print(f"Reversed Fate traduzidas: {tot}/{len(CORR)}")
print(f"Shadow Scale '；' limpos: {sc_clean}")
nf=[o for o,k in zip([c[0] for c in CORR],CMAP) if hit[k]==0]
if nf:
    print("\nNÃO ENCONTRADOS:")
    for x in nf: print("  -", x[:75])
