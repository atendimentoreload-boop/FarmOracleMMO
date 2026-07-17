#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 5: Electric Cure->Thunder Punch, Goldfish->Goldeen, conserta Power Gem grudado."""
import json, glob, re
SUBS=[
 ("Electric Cure","Thunder Punch"),
 ("Goldfish","Goldeen"),
 ("Power Gemfacing","Power Gem · contra "),
 ("Power Gemneed","Power Gem · precisa"),
 ("Power Gem · contra  ","Power Gem · contra "),
 ("Cannot ","não consegue "),
 ("Cannot","não consegue"),
]
n_changes=0
for f in glob.glob('data/teams/shadow_scale/*.json'):
    d=json.load(open(f,encoding='utf-8')); ch=False
    for n in d['nodes'].values():
        for s in n.get('steps',[]):
            t=s.get('text')
            if not t: continue
            nt=t
            for a,b in SUBS: nt=nt.replace(a,b)
            nt=re.sub(r'\s{2,}',' ',nt).strip()
            if nt!=t: s['text']=nt; n_changes+=1; ch=True
    if ch: json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print("passos alterados:",n_changes)
