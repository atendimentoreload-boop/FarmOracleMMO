#!/usr/bin/env python3
"""Converte routers do Pokeking (já traduzidos) para o nosso formato de solve JSON.

Entrada: um dict { regiao, champions: { nomeCampeao: { leadLabel: routerResult, ... } } }
onde routerResult é o `result` de um findRouter (traduzido pelo translate.py).

Saída: solve JSON no nosso formato (groups = campeões, entries = leads, nodes = árvore).
"""
import json, re, sys, os

_SPRITES = None
def _is_bare_mon(word):
    """True se `word` é um nome de Pokémon pelado (uma palavra que casa com um sprite).
    Usado pra NÃO separar 'sacrifice, <Mon>' em duas ações (Backlog #1)."""
    global _SPRITES
    if _SPRITES is None:
        d = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "sprites")
        _SPRITES = {f[:-4].lower() for f in os.listdir(d) if f.endswith(".png")} if os.path.isdir(d) else set()
    return bool(re.fullmatch(r"[A-Za-z][a-zA-Z]+", word or "")) and (word or "").lower() in _SPRITES

def _is_need_data(label):
    """Rótulo placeholder vazio ('need data'/'precisa data') que o autor do Pokeking não preencheu."""
    return bool(re.fullmatch(r"\s*(need\s*data|precisa\s*data)\s*", (label or ""), re.I))

def split_actions(operate):
    # separa por vírgulas (normal e chinesa) em ações distintas
    parts = [p.strip() for p in re.split(r"[，,]", operate or "") if p.strip()]
    # ...mas "sacrifice, <Mon>" é UMA instrução (sacrificar o mon), não duas ações — a vírgula
    # nesse caso não separa ação. Sem isto, o card fica "sacrifice" + "Politoed" em 2 linhas (#1).
    out = []
    i = 0
    while i < len(parts):
        if (i + 1 < len(parts) and parts[i].lower() in ("sacrifice", "sacrifique")
                and _is_bare_mon(parts[i + 1])):
            out.append(parts[i] + " " + parts[i + 1]); i += 2
        else:
            out.append(parts[i]); i += 1
    return out

def convert_router(root, out_nodes):
    """Converte um nó de router do Pokeking em nó(s) nosso(s). Retorna o id do nó raiz."""
    nid = str(root["id"])
    steps = []
    for a in split_actions(root.get("operate", "")):
        steps.append({"id": nid + "_a" + str(len(steps)), "kind": "action", "text": a})
    att = (root.get("attention") or "").strip()
    if att:
        steps.append({"id": nid + "_n", "kind": "note", "text": att})
    line = root.get("lineList") or []
    if line:
        steps.append({"id": nid + "_t", "kind": "setup",
                      "text": "Use o time " + " / ".join(str(x) for x in line)})

    # Ignora galhos "need data"/"precisa data": placeholders vazios que o autor do Pokeking
    # criou sem preencher (misclick). Viravam opções mortas — o usuário escolhia e não ia a
    # lugar útil. Sem galho real → nó vira terminal, "acaba no válido" (Backlog #9p3).
    children = [c for c in (root.get("children") or []) if not _is_need_data(c.get("label"))]
    if children:
        options = []
        for c in children:
            options.append({"label": (c.get("label") or "?").strip(), "nodeId": str(c["id"])})
            convert_router(c, out_nodes)
        branch = {"kind": "choice", "prompt": "O que o oponente colocou / fez?", "options": options}
    else:
        branch = None

    out_nodes[nid] = {
        "id": nid,
        "title": (root.get("label") or "").strip() or None,
        "steps": steps if steps else [{"id": nid + "_x", "kind": "note", "text": "Siga o time indicado."}],
        "branch": branch,
    }
    return nid

def build_solve(data):
    nodes = {}
    groups = []
    for champ, leads in data["champions"].items():
        entries = []
        for lead_label, router in leads.items():
            root_id = convert_router(router, nodes)
            entries.append({"label": lead_label, "nodeId": root_id})
        groups.append({"name": champ, "entries": entries})

    return {
        "id": data["id"],
        "title": data["title"],
        "revealAll": True,
        "lead": "Escolha o campeão e o Pokémon que ele iniciou. Siga os passos.",
        "groups": groups,
        "nodes": nodes,
    }

if __name__ == "__main__":
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(build_solve(data), ensure_ascii=False, indent=2))
