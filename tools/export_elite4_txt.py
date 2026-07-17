#!/usr/bin/env python3
"""Gera os Elite4-<Regiao>.txt (árvore completa para conferência) no Desktop.
Uso: python3 tools/export_elite4_txt.py
Lê data/elite4_*.json e percorre a árvore a partir das entries de cada grupo."""
import json, glob, os

REG = {"kanto":"KANTO","hoenn":"HOENN","sinnoh":"SINNOH","johto":"JOHTO","unova":"UNOVA"}
NAME = {"kanto":"Kanto","hoenn":"Hoenn","sinnoh":"Sinnoh","johto":"Johto","unova":"Unova"}
DATA = os.path.join(os.path.dirname(__file__), "..", "data")
DESKTOP = os.path.expanduser("~/Desktop")

def render(path):
    d = json.load(open(path)); nodes = d["nodes"]
    region = os.path.basename(path).replace("elite4_","").replace(".json","")
    L = [f"ELITE 4 — {REG[region]}  (árvore completa para conferência)",
         f"Fonte: data/elite4_{region}.json  |  Gerado pelo Prestrelo Ajuda",
         "="*64, ""]
    def emit(nid, depth, seen):
        ind = " "*(3*depth); n = nodes.get(nid)
        if not n: return
        for s in (n.get("steps") or []):
            t = (s.get("text") or "").strip()
            if not t: continue
            if t.startswith("Oponente está usando o time"):
                L.append(ind+"  [pós-luta] "+t)
            else:
                L.append(ind+"• "+t)
        b = n.get("branch")
        if not b: return
        if b.get("kind") == "goto":
            tgt = b.get("nodeId")
            if tgt and tgt not in seen: emit(tgt, depth, seen|{tgt})
            return
        if b.get("kind") == "choice":
            L.append(ind+"? "+(b.get("prompt") or "O que o oponente fez?"))
            for o in b.get("options", []):
                L.append(ind+"  ┗ SE: "+(o.get("label") or "?"))
                tgt = o.get("nodeId")
                if tgt and tgt not in seen: emit(tgt, depth+1, seen|{tgt})
    for g in d.get("groups", []):
        entries = g.get("entries", [])
        L += ["#"*64, f"# CAMPEÃO: {g['name'].upper()}   ({len(entries)} leads)", "#"*64, ""]
        for e in entries:
            L.append(f"—— LEAD: {e['label']} "+"-"*33)
            emit(e["nodeId"], 0, {e["nodeId"]})
            L.append("")
        L.append("")
    return "\n".join(L)

if __name__ == "__main__":
    for region in REG:
        txt = render(os.path.join(DATA, f"elite4_{region}.json"))
        out = os.path.join(DESKTOP, f"Elite4-{NAME[region]}.txt")
        open(out, "w").write(txt)
        print(f"  {out}  ({len(txt.splitlines())} linhas)")
    print("OK")
