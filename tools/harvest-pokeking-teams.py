#!/usr/bin/env python3
"""Colhe TODOS os times da Elite 4 do Pokeking — SEM filtro de CODE.

Fonte: endpoint autenticado `player/findById?id=N`, que devolve UMA linha (um
Pokémon de um time de um treinador) da tabela global, independente do CODE aplicado:
  {id, area, npc, fullName, name, characteristic(habilidade), prop(item),
   skillA..D(golpes), note}
  fullName ex.: "成都阿渡5号队伍快龙" = área + treinador + "N号队伍" + Pokémon.

Como não há endpoint de "listar tudo", varremos id=1..MAX e agrupamos por
(área, treinador, time#). A tabela tem buracos (Kanto–Sinnoh ~1–989, Johto ~1100–1600),
então NÃO paramos em NULLs consecutivos — varremos o range inteiro.

Saída: tools/pokeking_teams_raw.json  (cru, em chinês — traduz depois).

Uso: WEB_TOKEN='eyJ...' python3 tools/harvest-pokeking-teams.py [MAX]
"""
import json
import os
import re
import sys
import time
import urllib.request

B = "http://backend.pokeking.icu/api/"
TOKEN = os.environ.get("WEB_TOKEN", "").strip()
MAX_ID = int(sys.argv[1]) if len(sys.argv) > 1 else 1700
# area/npc vêm NULOS na resposta — extraímos do fullName:
#   "成都阿渡5号队伍快龙" = área(成都) + treinador(阿渡) + "N号队伍" + Pokémon(快龙)
AREAS = ["关都", "丰源", "合众", "神奥", "成都"]
FULL_RX = re.compile(r"^(" + "|".join(AREAS) + r")(.+?)(\d+)号队伍(.+)$")


def get(path):
    req = urllib.request.Request(B + path, headers={
        "Origin": "http://pokeking.icu", "Referer": "http://pokeking.icu/",
        "Cookie": "web-token=" + TOKEN,
    })
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if attempt == 2:
                return {"_error": str(e)}
            time.sleep(0.8)


def main():
    if not TOKEN:
        print("Defina WEB_TOKEN no ambiente."); return
    # teams[(area, npc, team#)] = {"area","npc","team","mons":[...]}
    teams = {}
    rows = errors = nulls = 0
    for i in range(1, MAX_ID + 1):
        j = get("player/findById?id=%d" % i)
        if "_error" in j:
            errors += 1
        r = (j or {}).get("result")
        if not isinstance(r, dict):
            nulls += 1
        else:
            rows += 1
            full = r.get("fullName") or ""
            m = FULL_RX.match(full)
            area = m.group(1) if m else (r.get("area") or "?")
            npc = m.group(2) if m else (r.get("npc") or "?")
            team_no = int(m.group(3)) if m else 0
            key = (area, npc, team_no)
            t = teams.setdefault(key, {"area": area, "npc": npc, "team": team_no, "mons": []})
            t["mons"].append({
                "id": r.get("id"), "name": r.get("name"), "fullName": full,
                "ability": r.get("characteristic"), "item": r.get("prop"),
                "moves": [r.get("skillA"), r.get("skillB"), r.get("skillC"), r.get("skillD")],
                "note": r.get("note"),
            })
        if i % 100 == 0:
            print("  id %d/%d · linhas=%d times=%d nulls=%d" % (i, MAX_ID, rows, len(teams), nulls))
        time.sleep(0.08)

    out = {"source": "player/findById (sem filtro de CODE)", "maxIdScanned": MAX_ID,
           "teams": sorted(teams.values(), key=lambda t: (t["area"] or "", t["npc"] or "", t["team"]))}
    path = os.path.join(os.path.dirname(__file__), "pokeking_teams_raw.json")
    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # resumo por treinador
    by_npc = {}
    for t in out["teams"]:
        by_npc.setdefault((t["area"], t["npc"]), set()).add(t["team"])
    print("=== %d linhas · %d times · %d treinadores · erros=%d ===" %
          (rows, len(out["teams"]), len(by_npc), errors))
    for (area, npc), nums in sorted(by_npc.items()):
        print("  %s · %s → times %s" % (area, npc, sorted(nums)))
    print("salvo em", path)


if __name__ == "__main__":
    main()
