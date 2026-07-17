#!/usr/bin/env python3
"""Resolve as GÍRIAS de tipo que sobram do build (tradução caractere-a-caractere)
trocando-as pelo Pokémon REAL, deduzido pelo ROSTER do campeão (data/elite4-opponents.json).

Ex.: "Bug Grass" na Bertha → o único Inseto/Planta do roster dela = Parasect.
     "Nido" na Caitlin → o único Nido do roster = Nidoqueen.
Onde o roster tem 2+ candidatos do mesmo tipo (ambíguo), NÃO troca e reporta pra
revisão/comunidade (#traduções-pendentes).

Roda DEPOIS do build_elite4.py e ANTES do traduzir-roteiros.py (os nomes ficam em inglês
nos dois idiomas, então serve pro PT e pro EN). Edita os arquivos no lugar.

Uso: python3 tools/resolve_e4_nicknames.py <dir_com_elite4_*.json>
"""
import json, re, os, sys, glob, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OPP = json.load(open(os.path.join(ROOT, "data", "elite4-opponents.json"), encoding="utf-8"))["regions"]
REGF = {'kanto': 'Kanto', 'hoenn': 'Hoenn', 'unova': 'Unova', 'sinnoh': 'Sinnoh', 'johto': 'Johto'}
CHAMP_ALIAS = {'Gary': 'Blue'}  # nome no build → chave no roster

# slang (regex) → candidatos plausíveis. Ordem: específicos primeiro; genéricos herdam a "família".
# família: genérico compartilha resolução com o específico do mesmo grupo dentro do campeão.
SLANG = [
    # (chave, regex, candidatos, família). Específicos ANTES dos genéricos; e nomes "fortes"
    # (Bug Grass = Parasect) antes de genéricos que poderiam disputar o mesmo mon (Mushroom).
    ('rock_crab',       r'\bRock Crab\b',        ['Crustle'], 'crab'),
    ('bug_grass',       r'\bBug Grass\b',        ['Parasect', 'Leavanny', 'Wormadam', 'Beautifly', 'Dustox'], 'buggrass'),
    ('bug_steel',       r'\bBug Steel\b',        ['Forretress', 'Durant', 'Escavalier', 'Scizor', 'Genesect'], 'bugsteel'),
    ('shield_mushroom', r'\bShield Mushroom\b',  ['Amoonguss', 'Breloom'], 'mushroom'),  # 盾菇 = defensivo, NÃO Parasect
    ('crab',            r'\bCrab\b',             ['Crustle', 'Crawdaunt', 'Kingler', 'Kabutops', 'Clawitzer', 'Crabominable'], 'crab'),
    ('mushroom',        r'\bMushroom\b',         ['Amoonguss', 'Breloom', 'Parasect', 'Shiinotic', 'Foongus'], 'mushroom'),
    ('monkey',          r'\bMonkey\b',           ['Infernape', 'Primeape', 'Simisage', 'Simisear', 'Simipour',
                                                  'Oranguru', 'Passimian', 'Aipom', 'Ambipom', 'Mankey'], 'monkey'),
    ('nido',            r'\bNido\b(?!king|queen)', ['Nidoking', 'Nidoqueen'], 'nido'),
]


# preferência quando há 2+ candidatos (regra do usuário): Bug Steel = Durant se o campeão tiver Durant.
PREFER = {'bug_steel': ['Durant']}
# gírias que, AMBÍGUAS, ficam como estão de PROPÓSITO (não vão pra comunidade):
# "Nido" num campeão que tem Nidoking E Nidoqueen = genérico, o usuário interpreta na hora.
SILENT_IF_AMBIG = {'nido'}
# overrides por campeão (regra explícita do usuário), keyed (região, nome-no-build).
CHAMP_OVERRIDE = {('Kanto', 'Gary'): {'nido': 'Nidoking'},
                  ('Johto', 'Koga'): {'bug_steel': 'Scizor'}}  # user 05/07: Koga bug_steel = Scizor


def roster_for(region, build_champ):
    champs = OPP.get(region, {})
    key = CHAMP_ALIAS.get(build_champ, build_champ)
    if key in champs:
        cand = key
    elif f"{key} ({region})" in champs:
        cand = f"{key} ({region})"
    else:
        cand = next((k for k in champs if k.split(' (')[0] == key), None)
    if not cand:
        return None
    mons = set()
    for team in champs[cand]:
        for p in team.get('pokemon', []):
            if isinstance(p, dict):
                mons.add(p['pokemon'])
    return mons


def resolve_champ(region, champ, texts):
    """Decide o mapeamento slang→Pokémon p/ este campeão. Retorna (mapping, flagged)."""
    roster = roster_for(region, champ)
    if roster is None:
        return {}, [(champ, 'SEM ROSTER', '')]
    blob = " ".join(texts)
    override = CHAMP_OVERRIDE.get((region, champ), {})
    fam = {}        # família → Pokémon já resolvido
    mapping = {}    # regex → Pokémon
    claimed = set() # mons já atribuídos a outra gíria neste campeão
    flagged = []
    for key, rx, cands, family in SLANG:
        if not re.search(rx, blob, re.I):
            continue
        if family in fam:                     # herda do específico já resolvido
            mapping[rx] = fam[family]
            continue
        if key in override:                   # regra explícita do usuário
            mon = override[key]
            mapping[rx] = mon; fam[family] = mon; claimed.add(mon)
            continue
        hit = (roster & set(cands)) - claimed
        if len(hit) > 1 and key in PREFER:     # preferência (ex.: Bug Steel → Durant)
            pref = [p for p in PREFER[key] if p in hit]
            if len(pref) == 1:
                hit = {pref[0]}
        if len(hit) > 1:
            # desempate: o nome COMPLETO aparece na própria árvore do campeão?
            # (ex.: 尼多王→"Nidoking" no texto desambigua "Nido" → Nidoking)
            present = {c for c in hit if re.search(r'\b' + re.escape(c) + r'\b', blob)}
            if len(present) == 1:
                hit = present
        if len(hit) == 1:
            mon = next(iter(hit))
            mapping[rx] = mon
            fam[family] = mon
            claimed.add(mon)
        elif key in SILENT_IF_AMBIG:
            pass  # por design fica "Nido" — o usuário interpreta na hora
        else:
            flagged.append((champ, key, ', '.join(sorted(hit)) or '(nenhum no roster)'))
    return mapping, flagged


def apply_to_node(node, mapping):
    n = 0
    def fix(t):
        nonlocal n
        for rx, mon in mapping.items():
            t, c = re.subn(rx, mon, t, flags=re.I)
            n += c
        return t
    for s in node.get('steps', []):
        if 'text' in s and s['text']:
            s['text'] = fix(s['text'])
    b = node.get('branch')
    if b:
        if b.get('prompt'):
            b['prompt'] = fix(b['prompt'])
        for o in b.get('options', []):
            if o.get('label'):
                o['label'] = fix(o['label'])
    return n


def process(path):
    d = json.load(open(path, encoding='utf-8'))
    region = REGF[os.path.basename(path).split('elite4_')[1].split('.')[0]]
    champ_of = {}
    by_champ = collections.defaultdict(list)
    for g in d['groups']:
        for e in g['entries']:
            champ_of[e['nodeId'].split('_')[0]] = g['name']
            by_champ[g['name']].append(e.get('label') or '')  # leads ajudam no desempate por nome
    # agrupa textos por campeão p/ decidir o mapeamento
    for nid, n in d['nodes'].items():
        champ = champ_of.get(nid.split('_')[0], '?')
        for s in n.get('steps', []):
            by_champ[champ].append(s.get('text') or '')
        b = n.get('branch')
        if b:
            by_champ[champ].append(b.get('prompt') or '')
            for o in (b.get('options') or []):
                by_champ[champ].append(o.get('label') or '')
    champ_map, all_flagged = {}, []
    for champ, texts in by_champ.items():
        m, fl = resolve_champ(region, champ, texts)
        champ_map[champ] = m
        all_flagged += [(region,) + f for f in fl]
    repl = 0
    for nid, n in d['nodes'].items():
        champ = champ_of.get(nid.split('_')[0], '?')
        repl += apply_to_node(n, champ_map.get(champ, {}))
    json.dump(d, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    return repl, champ_map, all_flagged


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'data')
    files = sorted(glob.glob(os.path.join(d, 'elite4_*.json')))
    total, flagged = 0, []
    print("== resolvidos (slang → Pokémon, por campeão) ==")
    for f in files:
        repl, cmap, fl = process(f)
        total += repl
        flagged += fl
        for champ, m in cmap.items():
            if m:
                pretty = {re.sub(r'\\b|\(\?!.*?\)', '', k).strip(): v for k, v in m.items()}
                print(f"  {os.path.basename(f).split('elite4_')[1][:6]:6s} {champ:10s} {pretty}")
    print(f"\nTotal de trechos trocados: {total}")
    if flagged:
        print("\n== AMBÍGUOS / sem resolução (pra #traduções-pendentes) ==")
        for reg, champ, key, hit in flagged:
            print(f"  {reg} · {champ}: '{key}' → candidatos: {hit}")
