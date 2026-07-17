#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 4: 1 straggler do RF + limpeza confiável de artefatos do Shadow Scale."""
import json, glob, re, unicodedata
def norm(s):
    s=unicodedata.normalize('NFC',s or '').replace('’',"'").replace('‘',"'")
    return re.sub(r'\s+',' ',s).strip()

# match exato (RF + SS frases inteiras)
EXACT = {
 "wary of espeed. testar how HP baixo pode be": "Cuidado com o Extreme Speed · testar quão baixo o HP pode ficar",
 "Consume Pp": "Esgote o PP dele",
 "Consume para 50%": "Esgote o PP dele (~50%)",
}
EXACT = { norm(k):v for k,v in EXACT.items() }

# substituições de substring SÓ em shadow_scale (artefatos confiáveis)
SUBS = [
 ("Pray garantido","garantido"),
 ("CTfirst","crítico primeiro"),
 ("CTstay","crítico, fica"),
 ("Mantine Still","Mantine permanece"),
 ("Still ·","Permanece ·"),
 ("Remaining Close Combat","Close Combat no resto do time"),
 ("①/②","1º/2º"),
 ("①","1º "),("②","2º "),
 (":Coloque",": Coloque"),
]

files=[f for f in glob.glob('data/teams/**/*.json',recursive=True) if '/emoji/' not in f]
ex_hit=0; sub_hit=0
for f in files:
    d=json.load(open(f,encoding='utf-8')); ch=False; is_ss='shadow_scale' in f
    for n in d['nodes'].values():
        for s in n.get('steps',[]):
            t=s.get('text')
            if not t: continue
            k=norm(t)
            if k in EXACT and t!=EXACT[k]: s['text']=EXACT[k]; ex_hit+=1; ch=True; continue
            if is_ss:
                nt=t
                for a,b in SUBS: nt=nt.replace(a,b)
                nt=re.sub(r'\s{2,}',' ',nt).strip()
                if nt!=t: s['text']=nt; sub_hit+=1; ch=True
    if ch: json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print(f"exatas: {ex_hit} | shadow_scale limpos: {sub_hit}")
