#!/usr/bin/env python3
"""Converte pokeking_full.json -> 5 solves (um por região) no formato do Prestrelo Ajuda.
Usa clear_translate p/ português claro. Cada campeão = grupo; cada lead = entrada.

Uso: python3 build_elite4.py [entrada.json] [dir_saida]
  entrada.json  (default: tools/pokeking_full.json)  — dump cru do Pokeking (ver README).
  dir_saida     (default: data/)                     — onde gravar elite4_<regiao>.json."""
import json, re, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from clear_translate import translate_field, full_tr

BASE = os.path.dirname(__file__)
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, 'pokeking_full.json')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BASE, '..', 'data')
REGIONS = {'GUANDU':'Kanto','FENGYUAN':'Hoenn','HEZHONG':'Unova','SHENAO':'Sinnoh','CHENGDU':'Johto'}

# Estrutura (prosa fixa) por idioma. Os nomes de Pokémon/golpe ficam em inglês nos dois;
# só estes textos de UI mudam. Para PT, rode depois o traduzir-roteiros.py (gíria EN->PT).
# Para EN, NÃO rode o traduzir-roteiros.py (o glossário do build já sai em inglês).
LANG = os.environ.get('POKEKING_LANG', 'pt').lower()
STR = {
    'pt': {
        'line':        'Oponente está usando o time {nums}',
        'branchPrompt':'O que o oponente fez / colocou em campo?',
        'fallback':    'Siga conforme a situação.',
        'lead':        'Escolha o campeão e o Pokémon que o oponente começou. Siga os passos.',
        'homePrompt':  'Campeão → lead do oponente',
        'groupPrompt': 'Escolha o campeão:',
    },
    'en': {
        'line':        'Opponent is using team {nums}',
        'branchPrompt':"What did the opponent do / send out?",
        'fallback':    'Follow the situation.',
        'lead':        'Choose the champion and the Pokémon the opponent led with. Follow the steps.',
        'homePrompt':  "Champion → opponent's lead",
        'groupPrompt': 'Choose the champion:',
    },
}[LANG]

# palavras PT (minúsculas) que NÃO devem ser capitalizadas; o resto (nomes em inglês) capitaliza
PT_STOP = set("""a o e de do da em no na se com para os as veja item oponente habilidade golpe
situacao situação hp use troque sai nocauteie fique campo stall troca dupla force trocar novo
deixe fugir sacrifique tome todos time ataque velocidade defesa atencao atenção confirma saudavel
saudável ainda assim penultimo penúltimo escolha cuidado adapte basta repetidamente seguido foi
bloqueado quanto mais facil fácil dois vezes set tabela ramos abaixo cima continue aparecer tem ou
nao não pressao pressão sem dominio domínio suficiente por conta propria própria precisa buffar
varra empurre ate até reponha ja já economia depois flinch forca força igual morre surpresa chance
alta evitar vantagem tipo quebre total sobreviveu desmaiou seguro priorizar inesperado cheio passo
anterior volte eletrico elétrico travar que na the to of then not run see push dont kill x""".split())

def titleize(text):
    def cap(m):
        w = m.group(0)
        if w.lower() in PT_STOP or not w[0].islower(): return w
        return w[0].upper() + w[1:]
    return re.sub(r"[A-Za-z][A-Za-z'-]*", cap, text)

def name_tr(s):
    # usa o tradutor completo (com a gíria/prosa), não só o dicionário
    txt = ' '.join(translate_field(s)) if s else ''
    return titleize(txt.strip()) or '?'

def steps_for(node):
    steps = []
    for i, a in enumerate(translate_field(node.get('operate', ''))):
        steps.append({"id": f"a{i}", "kind": "action", "text": titleize(a)})
    ll = node.get('lineList')
    if ll:
        nums = ', '.join(str(x) for x in ll)
        steps.append({"id": "ln", "kind": "setup", "text": STR['line'].format(nums=nums)})
    att = node.get('attention')
    if att and att.strip():
        txt = ' · '.join(titleize(a) for a in translate_field(att))
        if txt.strip():
            steps.append({"id": "nt", "kind": "note", "text": txt})
    return steps

def convert(node, npc, nodes):
    nid = f"n{npc}_{node['id']}"
    steps = steps_for(node)
    branch = None
    kids = node.get('children') or []
    if kids:
        opts = []
        for ch in kids:
            opts.append({"label": name_tr(ch.get('label')), "nodeId": f"n{npc}_{ch['id']}"})
            convert(ch, npc, nodes)
        branch = {"kind": "choice", "prompt": STR['branchPrompt'], "options": opts}
    if not steps and not branch:
        steps = [{"id": "x", "kind": "note", "text": STR['fallback']}]
    nodes[nid] = {"id": nid, "title": None, "steps": steps, "branch": branch}
    return nid

def build_region(code, regdata):
    nodes, groups = {}, []
    for champ in regdata['champions']:
        r = champ.get('routers')
        if not r or not r.get('children'): continue
        entries = []
        for lead in r['children']:
            root = convert(lead, champ['id'], nodes)
            entries.append({"label": name_tr(lead.get('label')), "nodeId": root})
        # leads em ordem alfabética
        entries.sort(key=lambda e: e['label'].lower())
        cname = name_tr(champ['name'])
        # retrato do campeão = nome em minúsculas (arquivo em Resources/trainers)
        portrait = re.sub(r'[^a-z]', '', cname.lower())
        groups.append({"name": cname, "entries": entries, "portrait": portrait})
    return {
        "id": f"elite4_{REGIONS[code].lower()}",
        "title": f"Elite 4 — {REGIONS[code]}",
        "revealAll": True,
        "lead": STR['lead'],
        "homePrompt": STR['homePrompt'],
        "groupPrompt": STR['groupPrompt'],
        "groups": groups,
        "nodes": nodes,
    }

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    os.makedirs(OUT, exist_ok=True)
    data = json.load(open(SRC, encoding='utf-8'))
    by_code = {r['code']: r for r in data['regions']}
    summary = []
    for code, name in REGIONS.items():
        solve = build_region(code, by_code[code])
        path = os.path.join(OUT, f"elite4_{name.lower()}.json")
        json.dump(solve, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
        summary.append((name, len(solve['groups']), sum(len(g['entries']) for g in solve['groups']), len(solve['nodes']), os.path.getsize(path)))
    print(f"{'Região':<8} {'camp':>4} {'leads':>5} {'nós':>5} {'KB':>6}")
    for n,c,l,nd,sz in summary:
        print(f"{n:<8} {c:>4} {l:>5} {nd:>5} {sz/1024:>6.1f}")
