#!/usr/bin/env python3
"""Rebuild completo de UM time da Elite 4 (PT + EN) a partir do CN bruto do Pokeking.

Pipeline por idioma:
  build_elite4.py (POKEKING_LANG)  ->  resolve_e4_nicknames.py  ->  [só PT: traduzir-roteiros.py]
  -> injeta sequentialGroups + warning -> grava em data/teams/<id>/ (PT) e data/teams/<id>/en/ (EN).

Uso: python3 tools/rebuild_team.py <team_id> <raw.json> [pokeking_team_key]
  team_id            pasta em data/teams/ (ex.: dingxianyou)
  raw.json           dump cru do Pokeking (extract-pokeking-console.js)
  pokeking_team_key  chave em clear_translate TEAMS (default = team_id)
"""
import json, os, sys, subprocess, glob, tempfile, shutil

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
PY = sys.executable
WARN = {
    'pt': '⚠️ A Elite 4 só funciona 100% a partir da 5ª vez que você derrota essa mesma Elite 4. Antes disso, os times do oponente podem ser diferentes (e muitas vezes serão) — então o guia pode não bater.',
    'en': "⚠️ The Elite 4 only works 100% from the 5th time you beat this same Elite 4. Before that, the opponent's teams may be different (and often will be) — so the guide may not match.",
}
ORDER = ['id', 'title', 'sequentialGroups', 'warning', 'revealAll', 'lead', 'homePrompt', 'groupPrompt', 'groups', 'nodes']


def run(args, env=None):
    r = subprocess.run([PY] + args, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit(f"FALHOU: {' '.join(args)}")
    return r.stdout


def build_lang(team_id, raw, pk_team, lang):
    tmp = tempfile.mkdtemp(prefix=f'e4_{lang}_')
    env = dict(os.environ, POKEKING_TEAM=pk_team, POKEKING_LANG=lang)
    run([os.path.join(BASE, 'build_elite4.py'), raw, tmp], env=env)
    resolve_out = run([os.path.join(BASE, 'resolve_e4_nicknames.py'), tmp])
    files = sorted(glob.glob(os.path.join(tmp, 'elite4_*.json')))
    if lang == 'pt':
        run([os.path.join(BASE, 'traduzir-roteiros.py')] + files)
    else:  # EN: vira a prosa/gíria PT do clear_translate pro inglês
        run([os.path.join(BASE, 'en_normalize.py'), tmp])
    dest = os.path.join(ROOT, 'data', 'teams', team_id) if lang == 'pt' \
        else os.path.join(ROOT, 'data', 'teams', team_id, 'en')
    os.makedirs(dest, exist_ok=True)
    for f in files:
        d = json.load(open(f, encoding='utf-8'))
        d['sequentialGroups'] = True
        d['warning'] = WARN[lang]
        d.setdefault('revealAll', True)
        d = {k: d[k] for k in ORDER if k in d}
        json.dump(d, open(os.path.join(dest, os.path.basename(f)), 'w', encoding='utf-8'),
                  ensure_ascii=False, separators=(',', ':'))
    shutil.rmtree(tmp)
    return resolve_out, dest


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        raise SystemExit(1)
    team_id, raw = sys.argv[1], sys.argv[2]
    pk_team = sys.argv[3] if len(sys.argv) > 3 else team_id
    print(f"== rebuild {team_id} (pokeking_team={pk_team}) ==")
    for lang in ('pt', 'en'):
        rout, dest = build_lang(team_id, raw, pk_team, lang)
        print(f"\n--- {lang.upper()} → {dest.replace(ROOT + '/', '')} ---")
        # mostra só o bloco de ambíguos do resolvedor (1×, idêntico nos 2 idiomas)
        if lang == 'pt' and 'AMBÍGUOS' in rout:
            print(rout[rout.index('== resolvidos'):])
    print("\n✓ pronto. Rode o selftest do Mac p/ validar.")
