#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Converte o dump cru do Pokeking (pokeking_full.json deste time) nos 5 solves da
Elite 4 do **Reversed Fate**, em DOIS modos:
  - Texto: data/teams/reversed_fate/<elite4_regiao>.json        (combate traduzido)
  - Emoji: data/teams/reversed_fate/emoji/<elite4_regiao>.json  (combate com emojis do autor)

Uso:  python tools/teams/reversed_fate/build.py
Fonte: tools/teams/reversed_fate/pokeking_full.json (extraído com extract-pokeking-console.js).
"""
import json, os, re, sys

BASE = os.path.dirname(__file__)
sys.path.insert(0, BASE)
from translate import translate, raw, tr_name, split_field

SRC = os.path.join(BASE, 'pokeking_full.json')
ROOT = os.path.join(BASE, '..', '..', '..')           # raiz do repo
OUT_TXT = os.path.join(ROOT, 'data', 'teams', 'reversed_fate')
OUT_EMO = os.path.join(OUT_TXT, 'emoji')

REGIONS = {'GUANDU': 'Kanto', 'FENGYUAN': 'Hoenn', 'HEZHONG': 'Unova', 'SHENAO': 'Sinnoh', 'CHENGDU': 'Johto'}

LEAD = 'Escolha o campeão e o Pokémon que o oponente começou. Siga os passos.'
HOME_PROMPT = 'Campeão → lead do oponente'
GROUP_PROMPT = 'Escolha o campeão:'
WARNING = ('⚠️ A Elite 4 só funciona 100% a partir da 5ª vez que você derrota essa mesma Elite 4. '
           'Antes disso, os times do oponente podem ser diferentes (e muitas vezes serão) — então o guia pode não bater.')


def steps_for(node, emoji):
    steps = []
    for i, a in enumerate(split_field(node.get('operate', ''), emoji)):
        steps.append({"id": f"a{i}", "kind": "action", "text": a})
    ll = node.get('lineList')
    if ll:
        steps.append({"id": "ln", "kind": "setup",
                      "text": "Oponente está usando o time " + ", ".join(str(x) for x in ll)})
    att = (node.get('attention') or '').strip()
    if att:
        txt = ' · '.join(split_field(att, emoji))
        if txt.strip():
            steps.append({"id": "nt", "kind": "note", "text": txt})
    return steps


def convert(node, npc, nodes, emoji):
    nid = f"n{npc}_{node['id']}"
    steps = steps_for(node, emoji)
    branch = None
    kids = node.get('children') or []
    if kids:
        opts = []
        for ch in kids:
            opts.append({"label": tr_name(ch.get('label') or '?'), "nodeId": f"n{npc}_{ch['id']}"})
            convert(ch, npc, nodes, emoji)
        branch = {"kind": "choice", "prompt": "O que o oponente fez / colocou em campo?", "options": opts}
    if not steps and not branch:
        steps = [{"id": "x", "kind": "note", "text": "Siga conforme a situação."}]
    nodes[nid] = {"id": nid, "title": None, "steps": steps, "branch": branch}
    return nid


def build_region(code, regdata, emoji):
    nodes, groups = {}, []
    for champ in regdata['champions']:
        r = champ.get('routers')
        if not r or not r.get('children'):
            continue
        entries = []
        for lead in r['children']:
            root = convert(lead, champ['id'], nodes, emoji)
            entries.append({"label": tr_name(lead.get('label') or '?'), "nodeId": root})
        entries.sort(key=lambda e: e['label'].lower())
        cname = tr_name(champ.get('name') or '?').title()
        portrait = re.sub(r'[^a-z]', '', cname.lower())
        groups.append({"name": cname, "entries": entries, "portrait": portrait})
    name = REGIONS[code]
    return {
        "id": f"elite4_{name.lower()}",
        "title": f"Elite 4 — {name}",
        "sequentialGroups": True,
        "warning": WARNING,
        "revealAll": True,
        "lead": LEAD,
        "homePrompt": HOME_PROMPT,
        "groupPrompt": GROUP_PROMPT,
        "groups": groups,
        "nodes": nodes,
    }


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    os.makedirs(OUT_TXT, exist_ok=True)
    os.makedirs(OUT_EMO, exist_ok=True)
    data = json.load(open(SRC, encoding='utf-8'))
    by_code = {r['code']: r for r in data['regions']}
    print(f"{'Região':<8} {'camp':>4} {'leads':>5} {'nós':>5}  {'txt KB':>7} {'emo KB':>7}")
    for code, name in REGIONS.items():
        row = [name]
        for emoji, outdir in [(False, OUT_TXT), (True, OUT_EMO)]:
            solve = build_region(code, by_code[code], emoji)
            path = os.path.join(outdir, f"elite4_{name.lower()}.json")
            json.dump(solve, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
            if not emoji:
                row += [len(solve['groups']), sum(len(g['entries']) for g in solve['groups']), len(solve['nodes'])]
            row.append(os.path.getsize(path) / 1024)
        print(f"{row[0]:<8} {row[1]:>4} {row[2]:>5} {row[3]:>5}  {row[4]:>7.1f} {row[5]:>7.1f}")
    print("OK -> data/teams/reversed_fate/ (+ emoji/)")
