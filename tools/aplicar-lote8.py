#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 8: últimos 10 do RF (notas do autor) + tokens finais do SS (Remaining, CT, Small At)."""
import json, glob, re, unicodedata
def norm(s):
    s=unicodedata.normalize('NFC',s or '').replace('’',"'").replace('‘',"'")
    return re.sub(r'\s+',' ',s).strip()

RF_EXACT = {
 "Any work": "Funciona?",
 "Any work · crítico Jirachi · Scrafty Encore · cura Jirachi · x Velocidade Jirachi · Encore · Max Potion ·":
   "Funciona? · se o Jirachi tomar crítico · Scrafty dá Encore · cure o Jirachi · X Velocidade no Jirachi · Encore · Max Potion",
 "Beat up locked drain punch snake": "Beat Up · preso no Drain Punch · (snake = cobra?)",
 "Fire Blast miss Veja abaixo/ testar se x Velocidade pode beat all":
   "Se o Fire Blast errar, veja abaixo · testar se X Velocidade ganha de todos",
 "Fire Blast solves precisa work": "As solves de Fire Blast precisam de ajuste",
 "Has Vacuum Wave Jirachi morre pro Aura Sphere · Chandelure[+2 Ataque Especial, +2 Velocidade]":
   "Tem Vacuum Wave · o Jirachi morre pro Aura Sphere · Chandelure[+2 Ataque Especial, +2 Velocidade]",
 "More feed back on team": "Mais feedback sobre o time (a confirmar)",
 "No para on Jirachi para work": "Não dá pra fazer funcionar com o Jirachi (a revisar)",
 "precisa better solve run pode be ruined by Cursed Body Gengar":
   "Precisa de solve melhor · a sequência pode ser arruinada pelo Cursed Body do Gengar",
 "precisa feedback on situation": "Precisa de feedback sobre a situação",
}
RF_EXACT={ norm(k):v for k,v in RF_EXACT.items() }

SS_SUBS=[
 ("Remaining Thunder Punch","Thunder Punch no resto do time"),
 ("Remaining","resto do time"),
 ("CTsmall","crítico baixo"),
 ("Small At","baixo a"),
 ("pode not","não pode"),
 ("Contra Contra","Contra"),
 ("%pode","% · pode"),
]
SS_CT=re.compile(r'\bCT\b')

rf=0; ss=0
for f in glob.glob('data/teams/**/*.json',recursive=True):
    if '/emoji/' in f: continue
    d=json.load(open(f,encoding='utf-8')); ch=False
    is_rf='reversed' in f; is_ss='shadow_scale' in f
    for n in d['nodes'].values():
        for s in n.get('steps',[]):
            t=s.get('text')
            if not t: continue
            if is_rf:
                k=norm(t)
                if k in RF_EXACT and t!=RF_EXACT[k]: s['text']=RF_EXACT[k]; rf+=1; ch=True
            elif is_ss:
                nt=t
                for a,b in SS_SUBS: nt=nt.replace(a,b)
                nt=SS_CT.sub('crítico',nt)
                nt=re.sub(r'\s{2,}',' ',nt).strip()
                if nt!=t: s['text']=nt; ss+=1; ch=True
    if ch: json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print(f"RF: {rf} | SS: {ss}")
