#!/usr/bin/env python3
"""Traduz o catálogo cru de adversários (CN) para inglês e estrutura por região/treinador.

Entrada: tools/pokeking_teams_raw.json  (cru, chinês — de harvest-pokeking-teams.py)
Saída:   tools/elite4-opponents.json    (estruturado, nomes em inglês oficial)
         tools/_catalog-missing.txt      (termos sem tradução — revisar, NÃO chutar)

Regra (igual ao PADRAO-DE-TRADUCAO): Pokémon/golpe/item/habilidade em inglês oficial.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, "tools")

DICT = {k.strip(): (v.strip() if isinstance(v, str) else v)
        for k, v in json.load(open(os.path.join(T, "pokeking-dictionary.json"))).items()}
RAW = json.load(open(os.path.join(T, "pokeking_teams_raw.json")))["teams"]

ANNO = re.compile(r"[【（(].*?[】）)]")
TYPES = {"火": "Fire", "水": "Water", "电": "Electric", "冰": "Ice", "岩": "Rock",
         "草": "Grass", "恶": "Dark", "格斗": "Fighting", "格": "Fighting", "飞": "Flying",
         "地": "Ground", "超": "Psychic", "龙": "Dragon", "虫": "Bug", "毒": "Poison",
         "钢": "Steel", "妖": "Fairy", "普": "Normal", "鬼": "Ghost"}
ROTOM = {"清洗": "Wash", "加热": "Heat", "结冰": "Frost", "切割": "Mow", "旋转": "Fan"}

# Suplemento p/ termos que o dicionário não tem (confiáveis). Os AMBÍGUOS ficam de fora
# de propósito (entram em _catalog-missing.txt p/ revisão — não chutar).
SUPP = {
    "电灯怪": "Lanturn", "无道具": "", "直冲钻": "Drill Run", "超级角击": "Megahorn",
    "污泥浆": "Black Sludge", "光璧": "Light Screen", "生命宝玉": "Life Orb",
    "磷火": "Will-O-Wisp", "靜电": "Static", "静电": "Static", "压迫感": "Pressure",
    "茂盛": "Overgrow", "激流": "Torrent", "沙隐": "Sand Veil", "拨沙": "Sand Rush",
    "雨盘": "Rain Dish", "硬壳盔甲": "Shell Armor", "叶绿素": "Chlorophyll",
    "毒手": "Poison Touch", "睡眠果": "Chesto Berry", "沙麟果": "Salac Berry",
    "蓄水": "Storm Drain", "咒术": "Curse", "V热焰": "V-create", "变色": "Color Change",
    "气闸": "Air Lock", "蘑菇袍子": "Spore", "蘑菇孢子": "Spore", "多重鳞片": "Multiscale",
}

missing = set()


def titlecase(s):
    """Title Case preservando colchetes/hífen (Hidden Power [Ice], Will-O-Wisp)."""
    return s.title() if s else s


def one(term):
    """Traduz UM termo simples (sem '/') para inglês oficial em Title Case."""
    if not term or not term.strip():
        return ""
    t = term.strip()
    # Hidden Power ANTES de remover parênteses (o tipo às vezes está neles).
    if "觉醒" in t:
        for cn, ty in sorted(TYPES.items(), key=lambda kv: -len(kv[0])):
            if cn in t:
                return "Hidden Power [%s]" % ty
    if t in DICT:
        return titlecase(DICT[t])
    base = ANNO.sub("", t).replace("\t", "").strip()
    if base in DICT:
        return titlecase(DICT[base])
    if base in SUPP:
        return titlecase(SUPP[base])
    # Rotom forms 清洗洛托姆 etc.
    if base.endswith("洛托姆"):
        form = ROTOM.get(base[:-3])
        if form:
            return "%s Rotom" % form
    missing.add(term.strip())
    return base  # devolve o CN-limpo como fallback (marcado em missing)


def tr(term):
    """Traduz, tratando duplas separadas por '/'."""
    if term and "/" in term:
        return " / ".join(one(p) for p in term.split("/"))
    return one(term)


REGION = {"关都": "Kanto", "丰源": "Hoenn", "合众": "Unova", "神奥": "Sinnoh", "成都": "Johto"}
TRAINER = {
    "科拿": "Lorelei", "希巴": "Bruno", "菊子": "Agatha", "渡": "Lance", "小茂": "Blue",
    "花月": "Sidney", "芙蓉": "Phoebe", "波妮": "Glacia", "源治": "Drake", "米可利": "Wallace",
    "式美": "Shauntal", "基玛": "Grimsley", "卡特莉亚": "Caitlin", "练武": "Marshal", "阿迪克": "Alder",
    "阿柳": "Aaron", "菊野": "Bertha", "奥巴": "Flint", "五洋": "Lucian", "希罗娜": "Cynthia",
    "一树": "Will", "阿桔": "Koga", "席巴": "Bruno (Johto)", "梨花": "Karen", "阿渡": "Lance (Johto)",
}


def main():
    by_region = {}
    for t in RAW:
        if t["npc"] in (None, "?"):
            continue  # Other (Red / Rei Abóbora) — fora da E4
        region = REGION.get(t["area"], t["area"])
        trainer = TRAINER.get(t["npc"], t["npc"])
        mons = [{
            "pokemon": tr(m["name"]),
            "ability": tr(m["ability"]),
            "item": tr(m["item"]),
            "moves": [tr(x) for x in m["moves"] if x and x.strip()],
        } for m in t["mons"]]
        by_region.setdefault(region, {}).setdefault(trainer, []).append(
            {"team": t["team"], "pokemon": mons})

    out = {"source": "Pokeking player/findById (sem filtro de CODE)",
           "regions": {r: {tr_: sorted(ts, key=lambda x: x["team"])
                           for tr_, ts in sorted(npcs.items())}
                       for r, npcs in sorted(by_region.items())}}
    json.dump(out, open(os.path.join(ROOT, "data", "elite4-opponents.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

    with open(os.path.join(T, "_catalog-missing.txt"), "w", encoding="utf-8") as f:
        for term in sorted(missing):
            f.write(term + "\n")

    n_teams = sum(len(ts) for npcs in by_region.values() for ts in npcs.values())
    print("OK: %d regiões · %d treinadores · %d times" %
          (len(by_region), sum(len(n) for n in by_region.values()), n_teams))
    print("termos SEM tradução (revisar, não chutar):", len(missing))
    for m in sorted(missing):
        print("   ", m)


if __name__ == "__main__":
    main()
