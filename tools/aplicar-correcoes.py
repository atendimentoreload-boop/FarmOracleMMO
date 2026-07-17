#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Aplica correções de tradução (match exato normalizado) em todas as solves de TEXTO,
   e renomeia as opções '?' que apontam para 'Oponente está usando o time X' -> 'Time X'.
   NÃO deleta nada (as 69 '?' vazias ficam pra confirmação)."""
import json, glob, re, unicodedata

def norm(s):
    s = unicodedata.normalize('NFC', s or '')
    s = s.replace('’',"'").replace('‘',"'").replace('“','"').replace('”','"')
    s = re.sub(r'\s+',' ', s).strip()
    return s

# [original, novo] — tom fiel/enxuto, padrões do glossário
CORR = [
 # Reversed Fate · Hoenn
 ["Be wary of hp. See how low you pode go. No Sucker Punch 21.8%",
  "Cuidado com o HP — veja quão baixo dá pra ir. Não leve Sucker Punch; cure com Max Potion se abaixo de 21,8%."],
 ["It will Full Restore", "Ele vai usar Full Restore."],
 ["Star dies · Dragonite[+1 Ataque, +2 Velocidade] pressione till u see Dusknoir/Absol/Houndoom/krow then Max Potion",
  "Se o Jirachi morrer · Dragonite[+1 Ataque, +2 Velocidade] · pressione até ver Dusknoir/Absol/Houndoom/Murkrow, então Max Potion."],
 ["troque para Umbreon continuar · Max Potion before pressione se below 60%",
  "Troque para Umbreon e continue · Max Potion antes de pressionar se abaixo de 60%."],
 ["X Velocidade primeiro · Encore then hone claws. Wary of health",
  "X Velocidade primeiro · Encore, depois Hone Claws · cuidado com o HP."],
 ["X Velocidade primeiro cura se you precisa. Only vswitches on Dragonite",
  "X Velocidade primeiro · cure se precisar · só dá Volt Switch no Dragonite."],
 ["May precisa Max Potion b4 pressione", "Pode precisar de Max Potion antes de pressionar."],
 ["See how HP baixo pode be. Take Max Potion? Energy Root?",
  "Veja quão baixo o HP pode ficar · cure com Max Potion ou Energy Root."],
 ["Jirachi die Scrafty Encore · Chandelure[+2 Ataque Especial, +2 Velocidade] . Scrafty lives crítico",
  "Se o Jirachi morrer · Scrafty entra e dá Encore · Chandelure[+2 Ataque Especial, +2 Velocidade] · Scrafty sobrevive ao crítico."],
 ["Dark pluse Scrafty[2x Dragon Dance (+2 Ataque +2 Velocidade)] /try hard swap para save money",
  "Dark Pulse · Scrafty[2x Dragon Dance (+2 Ataque, +2 Velocidade)] · dá pra tentar troca direta (hard swap) pra economizar cura."],
 ["Scrafty is slower than Gyarados. Uses Aqua Tail on Chandelure. testar se Dragonite is faster than Gyarados",
  "Scrafty é mais lento que Gyarados · usa Aqua Tail no Chandelure · testar se Dragonite é mais rápido que Gyarados."],
 ["precisa para see what happens when Jirachi is para",
  "Veja o que acontece com o Jirachi: se ele der Encore, o Pikachu entra sem Encore; se morrer primeiro, o Pikachu entra e dá Encore."],
 # Cross-file (padrões repetidos, confiantes)
 ["See what happens", "Veja o que acontece."],
 ["See what comes next", "Veja o que vem a seguir."],
 ["não usa sacrifica see below", "Não usa; sacrifica — veja a solve abaixo."],
 ["May precisa para be higher than 2?", "Pode precisar ser maior que 2?"],
 ["testar se you pode live wo healing Toxic", "Testar se dá pra sobreviver ao Toxic sem curar."],
 ["May precisa para u turn out", "Pode precisar dar U-turn pra sair."],
 ["crítico Veja abaixo/ testar hard swap Gallade",
  "Crítico — veja abaixo / testar troca direta (hard swap) pro Gallade."],
 ["Gallade[Encore, +2 Ataque, +2 Velocidade] pode die from crítico from Spiritomb",
  "Gallade[Encore, +2 Ataque, +2 Velocidade] pode morrer pro crítico do Spiritomb."],
 ["Scrafty Earthquake die · Jirachi Encore", "Scrafty Earthquake morre · Jirachi Encore."],
 ["Probably don't precisa pot", "Provavelmente não precisa de poção."],
 ["May precisa Max Potion b4 pressione", "Pode precisar de Max Potion antes de pressionar."],
]
CMAP = { norm(o): n for o,n in CORR }

files = [f for f in glob.glob('data/teams/**/*.json',recursive=True) if '/emoji/' not in f] + ['data/red.json','data/veteran.json']
hit = {k:0 for k in CMAP}
relabel = 0
for f in files:
    d = json.load(open(f, encoding='utf-8')); nodes = d['nodes']; changed=False
    for nid,n in nodes.items():
        for s in n.get('steps',[]):
            k = norm(s.get('text'))
            if k in CMAP and s.get('text') != CMAP[k]:
                s['text'] = CMAP[k]; hit[k]+=1; changed=True
        b = n.get('branch')
        if b and b.get('kind')=='choice':
            for o in b.get('options',[]):
                if (o.get('label') or '').strip()=='?':
                    tgt = nodes.get(o.get('nodeId'),{})
                    txts=[(x.get('text') or '') for x in tgt.get('steps',[])]
                    m = next((re.search(r'time (\d+)', t) for t in txts if re.search(r'time (\d+)', t)), None)
                    if m:
                        o['label'] = f"Time {m.group(1)}"; relabel+=1; changed=True
    if changed:
        json.dump(d, open(f,'w',encoding='utf-8'), ensure_ascii=False, indent=1)

print("=== correções de texto aplicadas ===")
tot=0
for k,c in hit.items():
    tot+=c
    print(f"  {c:3d}×  {CMAP[k][:60]}")
print(f"TOTAL ocorrências: {tot}")
print(f"opções '?' renomeadas p/ 'Time X': {relabel}")
nf=[CORR[i][0] for i,k in enumerate(CMAP) if hit[k]==0]
if nf:
    print("\n!!! NÃO ENCONTRADOS (revisar):")
    for x in nf: print("   -", x[:70])
