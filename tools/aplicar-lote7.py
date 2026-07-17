#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 7: tokens reais restantes do RF (faint, full cura, at X%, how low...pode be, dies...)."""
import json, glob, re
TOK = [
 (r'💫faint', "Jirachi morre"),
 (r'\bfaints\b', "desmaia"),
 (r'\bno faint\b', "sem desmaiar"),
 (r'\bfaint\b', "morre"),
 (r'\bfull cura\b', "cura total"),
 (r'\bfull restored\b', "curou tudo"),
 (r'Full restored', "Curou tudo"),
 (r'\bat (\d)', r'a \1'),
 (r'how HP baixo pode be', "quão baixo o HP pode ficar"),
 (r'how low special attack pode be', "quão baixo o Ataque Especial pode ficar"),
 (r'how low (\w+) pode be', r'quão baixo o \1 pode ficar'),
 (r'how low pode be', "quão baixo dá pra ir"),
 (r'Depends on situation', "depende da situação"),
 (r'depends on situation', "depende da situação"),
 (r'Depends on team', "depende do time"),
 (r'depends on team', "depende do time"),
 (r'\bdies para\b', "morre pro"),
 (r'\bdies\b', "morre"),
 (r'bullet punches', "dá Bullet Punch"),
 (r'vaccum wave', "Vacuum Wave"),
 (r'Has vaccum wave', "Tem Vacuum Wave"),
 (r'\btill\b', "até"),
 (r'one hit', "um hit"),
 (r'used fire move', "usou golpe de fogo"),
 (r'\bx accuracy\b', "X Precisão"),
 (r'setup up', "setup"),
 (r'foul play', "Foul Play"),
 (r'\bMeta bullet', "Metagross dá Bullet"),
 (r'para faint it', "pra derrubá-lo"),
 (r'\btakes\b', "aguenta"),
]
TOK=[(re.compile(p,re.I),r) for p,r in TOK]
n=0
for f in glob.glob('data/teams/reversed_fate/*.json'):
    d=json.load(open(f,encoding='utf-8')); ch=False
    for nd in d['nodes'].values():
        for s in nd.get('steps',[]):
            t=s.get('text')
            if not t: continue
            nt=t
            for rx,rep in TOK: nt=rx.sub(rep,nt)
            nt=re.sub(r'\s{2,}',' ',nt).strip()
            if nt!=t: s['text']=nt; n+=1; ch=True
    if ch: json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print("passos alterados:",n)
