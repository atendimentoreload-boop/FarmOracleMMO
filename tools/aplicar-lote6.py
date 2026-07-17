#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lote 6: combos recorrentes (exato) + glossário no nível de TOKEN (global) no Reversed Fate."""
import json, glob, re, unicodedata
def norm(s):
    s=unicodedata.normalize('NFC',s or '').replace('’',"'").replace('‘',"'")
    return re.sub(r'\s+',' ',s).strip()

# combos repetidos (match exato)
EXACT = {
 "No star Encore · Scrafty Encore": "Jirachi sem Encore · Scrafty dá Encore",
 "No star Encore · Scrafty Encore .": "Jirachi sem Encore · Scrafty dá Encore",
 "Star no Encore · Scrafty Encore": "Jirachi sem Encore · Scrafty dá Encore",
 "No Encore star · Scrafty Encore": "Jirachi sem Encore · Scrafty dá Encore",
 "No star Encore · Pikachu Encore": "Jirachi sem Encore · Pikachu dá Encore",
 "crítico on star · Scrafty Encore": "Se o Jirachi tomar crítico · Scrafty dá Encore",
 "HP baixo star Encore sacrifica": "Jirachi com HP baixo · Encore e sacrifica",
 "crítico · Scrafty cura star · star Encore": "Se tomar crítico · Scrafty cura o Jirachi · Jirachi dá Encore",
 "Encore goes last": "Encore vai por último",
 "Encore goes primeiro": "Encore vai primeiro",
 "any work": "funciona?",
 "💫alive": "Jirachi vivo",
}
EXACT = { norm(k):v for k,v in EXACT.items() }

# token-level (regex, global no reversed_fate) — só glossário confirmado
TOK = [
 (r'\bstar\b', "Jirachi"),
 (r'\bespeed\b', "Extreme Speed"),
 (r'\bvwave\b', "Volt Switch"),
 (r'\bvswitch\b', "Volt Switch"),
 (r'goes last', "vai por último"),
 (r'goes primeiro', "vai primeiro"),
 (r'goes first', "vai primeiro"),
 (r'comes in last', "entra por último"),
 (r'comes in', "entra"),
 (r'comes out', "entra"),
 (r'comes last', "entra por último"),
 (r'comes next', "vem a seguir"),
 (r'\balive\b', "vivo"),
 (r'strengthening', "bufando"),
 (r'strengthen', "bufar"),
 (r'\bstrength\b', "bufar"),
 (r"can't kill instantly", "não mata na hora"),
 (r"cant kill instantly", "não mata na hora"),
 (r'pay attention', "preste atenção"),
 (r'choice item', "item Choice"),
 (r'\bworks\b', "funciona"),
 (r'won.?t work', "não funciona"),
 (r'doesn.?t work', "não funciona"),
 (r'não usa work', "não funciona"),
 (r'usa work', "não funciona"),
 (r'\bstays\b', "fica"),
 (r'\bb4\b', "antes"),
 (r'\bwo\b', "sem"),
 (r'Save \$', "Economizar"),
 (r'save \$', "economizar"),
 (r'save money', "economizar"),
]
TOK = [(re.compile(p, re.I), r) for p,r in TOK]

files=[f for f in glob.glob('data/teams/reversed_fate/*.json')]
ex_hit=0; tok_hit=0
for f in files:
    d=json.load(open(f,encoding='utf-8')); ch=False
    for n in d['nodes'].values():
        for s in n.get('steps',[]):
            t=s.get('text')
            if not t: continue
            k=norm(t)
            if k in EXACT and t!=EXACT[k]: s['text']=EXACT[k]; ex_hit+=1; ch=True; continue
            nt=t
            for rx,rep in TOK: nt=rx.sub(rep,nt)
            nt=re.sub(r'\s{2,}',' ',nt).strip()
            if nt!=t: s['text']=nt; tok_hit+=1; ch=True
    if ch: json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print(f"combos exatos: {ex_hit} | passos com token traduzido: {tok_hit}")
