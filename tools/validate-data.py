#!/usr/bin/env python3
"""
Valida a fonte única de dados (/data) ANTES de qualquer build.

Roda no CI como portão: se um JSON estiver malformado, sem um campo obrigatório do modelo
`Solve`, ou apontando pra um nó inexistente, este script sai com código != 0 e o build/release
inteiro é abortado — em vez de publicar um app que abre e morre por dado quebrado.

Espelha os campos NÃO-opcionais do modelo (mac/.../Model/Solve.swift). Faltando => o
JSONDecoder/kotlinx.serialization lança em runtime => app não abre.
"""
import json
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

STEP_KINDS = {"action", "note", "setup", "conditional"}
BRANCH_KINDS = {"choice", "goto"}

# Modos que TODO time precisa ter (a biblioteca do app monta exatamente estes).
SHARED_MODES = ["red", "veteran"]
ELITE4_MODES = ["elite4_kanto", "elite4_hoenn", "elite4_unova", "elite4_sinnoh", "elite4_johto"]

errs = []


def err(msg):
    errs.append(msg)


def check_solve(path, d):
    for k in ("id", "title", "nodes"):
        if k not in d:
            err(f"{path}: Solve sem campo obrigatório '{k}'")
    nodes = d.get("nodes")
    if not isinstance(nodes, dict):
        err(f"{path}: 'nodes' ausente ou não é objeto")
        return
    for nid, n in nodes.items():
        if "id" not in n:
            err(f"{path} node[{nid}]: sem 'id'")
        if "steps" not in n:
            err(f"{path} node[{nid}]: sem 'steps'")
            continue
        for i, s in enumerate(n.get("steps", [])):
            if "id" not in s:
                err(f"{path} node[{nid}].steps[{i}]: sem 'id'")
            kind = s.get("kind")
            if kind is None:
                err(f"{path} node[{nid}].steps[{i}]: sem 'kind'")
            elif kind not in STEP_KINDS:
                err(f"{path} node[{nid}].steps[{i}]: kind inválido '{kind}'")
            if kind == "conditional":
                t = s.get("table")
                if not t or "rows" not in t:
                    err(f"{path} node[{nid}].steps[{i}]: conditional sem table.rows")
        b = n.get("branch")
        if b is not None and b.get("kind") not in BRANCH_KINDS:
            err(f"{path} node[{nid}].branch: kind inválido '{b.get('kind')}'")
    # Toda entrada (entryPoints/groups) precisa apontar pra um nó existente.
    refs = []
    for ep in d.get("entryPoints") or []:
        refs.append((ep.get("label"), ep.get("nodeId")))
    for g in d.get("groups") or []:
        for ep in g.get("entries", []):
            refs.append((ep.get("label"), ep.get("nodeId")))
    for lbl, nid in refs:
        if nid not in nodes:
            err(f"{path}: entrada '{lbl}' aponta nodeId inexistente '{nid}'")


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        err(f"{path}: JSON inválido: {e}")
        return None


def main():
    if not os.path.isdir(DATA):
        print(f"ERRO: pasta de dados não encontrada: {DATA}", file=sys.stderr)
        return 1

    # 1) Todo JSON em /data precisa ser sintaticamente válido e (se for Solve) bater no modelo.
    for path in sorted(glob.glob(os.path.join(DATA, "**", "*.json"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        d = load(path)
        if d is None:
            continue
        if os.path.basename(path) == "teams.json":
            for k in ("default", "teamScopedModes", "teams"):
                if k not in d:
                    err(f"{rel}: manifesto sem campo '{k}'")
            continue
        # Catálogo de adversários (overlay "Ver times") — NÃO é um Solve; valida só a casca.
        if os.path.basename(path) == "elite4-opponents.json":
            if not isinstance(d.get("regions"), dict):
                err(f"{rel}: catálogo de adversários sem 'regions' (objeto)")
            continue
        # Catálogo de cooldowns/berries (#33) — NÃO é um Solve; valida só a casca.
        if os.path.basename(path) == "cooldowns.json":
            for k in ("battleTasks", "berries"):
                if not isinstance(d.get(k), list):
                    err(f"{rel}: catálogo de cooldowns sem '{k}' (lista)")
            continue
        check_solve(rel, d)

    # 2) O manifesto de times precisa existir e cada time precisa ter TODOS os modos que o
    #    app vai tentar carregar (red, veteran na raiz + os 5 Elite 4 na pasta do time).
    teams_path = os.path.join(DATA, "teams.json")
    if os.path.isfile(teams_path):
        cfg = load(teams_path) or {}
        for m in SHARED_MODES:
            if not os.path.isfile(os.path.join(DATA, f"{m}.json")):
                err(f"data/{m}.json: modo compartilhado ausente")
        scoped = cfg.get("teamScopedModes", [])
        for team in cfg.get("teams", []):
            tid = team.get("id", "")
            if not tid:
                continue
            visuals = [""] + (["emoji"] if team.get("hasEmoji") else [])
            for v in visuals:
                base = os.path.join(DATA, "teams", tid, v) if v else os.path.join(DATA, "teams", tid)
                for m in ELITE4_MODES:
                    if m in scoped and not os.path.isfile(os.path.join(base, f"{m}.json")):
                        err(f"time '{tid}'{' (emoji)' if v else ''}: falta {m}.json em {os.path.relpath(base, ROOT)}")
    else:
        err("data/teams.json: manifesto de times ausente")

    if errs:
        print("❌ VALIDAÇÃO DE DADOS FALHOU:", file=sys.stderr)
        for e in errs:
            print("  -", e, file=sys.stderr)
        return 1
    print("✓ dados ok: todos os JSON válidos e todos os modos de todos os times presentes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
