#!/usr/bin/env python3
"""Aplica o PADRAO-DE-TRADUCAO.md aos roteiros (data/teams/...).

Traduz para PT-BR mantendo em inglês APENAS nomes de Pokémon, golpes e itens —
e ainda CORRIGE esses nomes para o inglês oficial (caixa/grafia/abreviação).

Passos por texto:
  1) conserta leads com label "?" (formas do Rotom);
  2) glossário: traduz termos e expande abreviações de golpe/Pokémon;
  3) normaliza ITENS, GOLPES e POKÉMON para o nome oficial em inglês;
  4) limpa espaços duplicados.

Uso: python3 tools/traduzir-roteiros.py data/teams/reversed_fate/elite4_sinnoh.json [...]
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- glossário
# Ordem IMPORTA: frases primeiro. Substituição em PT.
RULES = [
    (r"\bNo life orb\b", "Sem Life Orb"),
    (r"\bMisses superpower\b", "Erra o Superpower"),
    (r"\bSuper ?power\b", "Superpower"),
    (r"\bX scissors\b", "X-Scissor"),
    (r"\bStay and continue until item reveal\b", "Fica e continua até revelar o item"),
    (r"\bStill Stay\b", "Fica"),
    (r"\bSee under\b", "Veja abaixo"),
    (r"\bFull health\b", "Vida cheia"),
    (r"\bLow health\b", "Vida baixa"),
    (r"\bLow HP\b", "HP baixo"),
    (r"\bHeal Full\b", "cura total"),
    (r"\bMight just be\b", "Pode ser só"),
    (r"\bself[ -]lock\b", "travado no golpe"),
    (r"\bgoes under\b", "vai por baixo do"),
    (r"\bwent last\b", "foi por último"),
    (r"\brun to\b", "troque para"),
    (r"\bwill fix mb\b", "corrijo depois"),
    (r"\bwill confirm later\b", "confirmo depois"),
    (r"\bconfirm later\b", "confirmo depois"),
    (r"\bfix mb\b", "corrijo depois"),
    (r"\bdoesn[’'`]?t\b", "não usa"),

    # abreviações de GOLPE -> nome oficial em inglês
    (r"\bTbolt\b", "Thunderbolt"),
    (r"\bEq\b", "Earthquake"),
    (r"\bDrush\b", "Dragon Rush"),
    (r"\bMax pot\b", "Max Potion"),

    # abreviações / grafias erradas de POKÉMON -> nome oficial em inglês
    (r"\bChomp\b", "Garchomp"),
    (r"\bDnite\b", "Dragonite"),
    (r"\bTtar\b", "Tyranitar"),
    (r"\bHydregion\b", "Hydreigon"),
    (r"\bBrongzong\b", "Bronzong"),
    (r"\bKrookdile\b", "Krookodile"),
    (r"\bEmopleon\b", "Empoleon"),
    (r"\bNinetails\b", "Ninetales"),

    # atributos (só abreviações; NÃO traduzir "Attack"/"Defense" p/ não quebrar item "X Attack")
    (r"\bSp\.?\s?Atk\b", "Ataque Especial"),
    (r"\bSp\.?\s?Def\b", "Defesa Especial"),
    (r"\bAtk\b", "Ataque"),
    (r"\bDef\b", "Defesa"),
    (r"\bSpeed\b", "Velocidade"),

    # ações / estados
    (r"\bStay\b", "Fica"),
    (r"\bsack\b", "sacrifica"),
    (r"\bswitch\b", "troca"),
    (r"\bkill\b", "nocauteia"),
    (r"\bheal\b", "cura"),
    (r"\bpush\b", "pressione"),
    (r"\bfacing\b", "contra"),
    (r"\bneeded\b", "precisa"),
    (r"\bneed\b", "precisa"),
    (r"\btest\b", "testar"),
    (r"\bcontinue\b", "continuar"),
    (r"\bmoves\b", "golpes"),
    (r"\bcrit\b", "crítico"),
    (r"\bfirst\b", "primeiro"),
    (r"\bafter\b", "depois"),

    # conectores seguros (não colidem com PT)
    (r"\bif\b", "se"),
    (r"\band\b", "e"),
    (r"\bor\b", "ou"),
    (r"\bto\b", "para"),
    (r"\bcan\b", "pode"),
]
COMPILED = [(re.compile(p, re.IGNORECASE), r) for p, r in RULES]

# ---------------------------------------------------------------- nomes oficiais
# GOLPES (caixa/grafia oficial). Frases longas primeiro.
MOVES = [
    "Stealth Rock", "Shadow Ball", "Shadow Claw", "Close Combat", "Dragon Rush",
    "Dragon Dance", "Dragon Claw", "Dragon Pulse", "Draco Meteor", "Earth Power",
    "Thunder Punch", "Thunder Wave", "Fire Blast", "Fire Punch", "Flare Blitz",
    "Hydro Pump", "Ice Beam", "Ice Punch", "Ice Shard", "Psycho Cut", "Aura Sphere",
    "Sacred Sword", "Leaf Blade", "Leaf Storm", "Energy Ball", "Power Gem",
    "Focus Blast", "Focus Punch", "Sludge Wave", "Sludge Bomb", "Iron Head",
    "Heavy Slam", "Stone Edge", "Rock Slide", "Bullet Punch", "Sucker Punch",
    "Calm Mind", "Swords Dance", "Nasty Plot", "Seed Bomb", "Giga Drain",
    "Bug Buzz", "Air Slash", "Brave Bird", "Aqua Tail", "Power Whip", "Gunk Shot",
    "Zen Headbutt", "Wild Charge", "Volt Switch", "Rapid Spin", "Knock Off",
    "Play Rough", "Body Slam", "Hammer Arm", "Sky Attack", "Stored Power",
    "Shell Smash", "Quiver Dance", "Will-O-Wisp", "Soft-Boiled", "Self-Destruct",
    "U-turn", "X-Scissor",
    "Encore", "Earthquake", "Thunderbolt", "Flamethrower", "Psychic", "Crunch",
    "Surf", "Waterfall", "Outrage", "Superpower", "Toxic", "Recover", "Roost",
    "Roar", "Whirlwind", "Protect", "Substitute", "Pursuit", "Spore", "Moonblast",
    "Hurricane", "Megahorn", "Discharge", "Overheat", "Counter", "Thunder",
]

# ITENS (caixa/grafia oficial). Frases longas primeiro.
ITEMS = [
    "Choice Scarf", "Choice Band", "Choice Specs", "Rocky Helmet", "Focus Sash",
    "Max Potion", "Hyper Potion", "Full Restore", "Energy Root", "Energy Powder",
    "Sitrus Berry", "Lum Berry", "Black Sludge", "Assault Vest", "Light Clay",
    "Air Balloon", "Expert Belt", "Life Orb", "Leftovers", "Eviolite",
]

# HABILIDADES (caixa/grafia oficial em inglês). Frases longas primeiro.
# Regra do usuário: HABILIDADE NÃO se traduz (igual nome de golpe/Pokémon/item).
# Só as 5 abaixo aparecem hoje nos roteiros; as demais ficam pra blindar o
# shadow_scale e futuras extrações sem precisar mexer no script de novo.
ABILITIES = [
    "Pressure", "Mold Breaker", "Intimidate", "Flash Fire", "Cursed Body",
    "Levitate", "Sturdy", "Multiscale", "Magic Bounce", "Regenerator",
    "Technician", "Speed Boost", "Huge Power", "Adaptability", "Rough Skin",
    "Iron Barbs", "Thick Fat", "Water Absorb", "Volt Absorb", "Storm Drain",
    "Lightning Rod", "Unaware", "Magic Guard", "Clear Body", "Sand Veil",
    "Solid Rock", "Prankster", "Serene Grace", "Shadow Tag", "Arena Trap",
    "Sheer Force", "Marvel Scale", "Sand Stream", "Drought", "Drizzle",
    "Snow Warning", "Natural Cure", "Synchronize", "Sap Sipper",
]

# Reparo de corrupções pré-existentes do shadow_scale: uma versão ANTIGA do
# tradutor verteu a habilidade "Pressure" para "apertão/aperteão/aperteure"
# (errado — habilidade fica em inglês). NÃO toca em "aperte" (verbo "press").
REPAIR = [
    (re.compile(r"\baperte[ãa]o\b", re.IGNORECASE), "Pressure"),
    (re.compile(r"\baperteure\b", re.IGNORECASE), "Pressure"),
]

# "have / no" do oponente: o usuário pediu traduzir "have" -> "tem" e
# "no/sem <habilidade>" -> "não tem <habilidade>". Frases primeiro.
HAVE_PRE = [
    (re.compile(r"\bMust Have\b", re.IGNORECASE), "precisa ter"),
    (re.compile(r"\bHave (?:sem|no)\b", re.IGNORECASE), "não tem"),
]
HAVE_RX = re.compile(r"\bhave\b", re.IGNORECASE)


def _name_rx(names):
    """Regex que casa qualquer nome (com \b), preferindo o mais longo."""
    ordered = sorted(names, key=len, reverse=True)
    alts = [re.escape(n) for n in ordered]
    return re.compile(r"\b(" + "|".join(alts) + r")\b", re.IGNORECASE)


MOVES_BY_KEY = {m.lower(): m for m in MOVES}
ITEMS_BY_KEY = {i.lower(): i for i in ITEMS}
ABIL_BY_KEY = {a.lower(): a for a in ABILITIES}
MOVES_RX = _name_rx(MOVES)
ITEMS_RX = _name_rx(ITEMS)
ABIL_RX = _name_rx(ABILITIES)

# "no/sem <habilidade>" -> "não tem <habilidade>" (depois de normalizar a caixa).
ABIL_ALT = "|".join(re.escape(a) for a in sorted(ABILITIES, key=len, reverse=True))
ABIL_NEG = re.compile(r"\b(?:sem|no)\s+(" + ABIL_ALT + r")\b", re.IGNORECASE)

# POKÉMON canônicos a partir dos sprites (nomes single-token, minúsculos).
SPRITES = {f[:-4].lower() for f in os.listdir(os.path.join(ROOT, "data", "sprites"))
           if f.endswith(".png")}
TOKEN_RX = re.compile(r"[A-Za-z]+")

ROTOM_FORMS = ("wash", "frost", "fan", "heat")


def normalize_names(text):
    text = ITEMS_RX.sub(lambda m: ITEMS_BY_KEY[m.group(0).lower()], text)
    text = MOVES_RX.sub(lambda m: MOVES_BY_KEY[m.group(0).lower()], text)
    text = ABIL_RX.sub(lambda m: ABIL_BY_KEY[m.group(0).lower()], text)

    def fix_pokemon(m):
        w = m.group(0)
        return w.capitalize() if w.lower() in SPRITES else w
    text = TOKEN_RX.sub(fix_pokemon, text)
    return text


def translate(text):
    if not text:
        return text
    # 0) conserta corrupções antigas de habilidade (aperteão -> Pressure)
    for rx, rep in REPAIR:
        text = rx.sub(rep, text)
    # 1) "Must Have"/"Have no|sem" antes do glossário (frases)
    for rx, rep in HAVE_PRE:
        text = rx.sub(rep, text)
    # 2) glossário geral
    for rx, rep in COMPILED:
        text = rx.sub(rep, text)
    # 3) nomes oficiais (itens, golpes, HABILIDADES, Pokémon)
    text = normalize_names(text)
    # 4) "no/sem <habilidade>" -> "não tem <habilidade>" (caixa já oficial)
    text = ABIL_NEG.sub(lambda m: "não tem " + m.group(1), text)
    # 5) "have" remanescente -> "tem" (oponente possui X)
    text = HAVE_RX.sub("tem", text)
    text = re.sub(r"  +", " ", text).strip()
    return text


def translate_option_label(text):
    """Como translate(), mas se o label for EXATAMENTE uma habilidade
    (resposta afirmativa "tem <habilidade>" num branch tipo Pressure/No Pressure),
    prefixa "tem ". Ex.: opção "Pressure" -> "tem Pressure"."""
    out = translate(text)
    if out.lower() in ABIL_BY_KEY:
        return "tem " + ABIL_BY_KEY[out.lower()]
    return out


def rotom_label_from_node(node):
    blob = " ".join(str(s.get("text", "")) for s in node.get("steps", [])).lower()
    if "rotom" not in blob:
        return None
    for form in ROTOM_FORMS:
        if form in blob:
            return f"{form.capitalize()} Rotom"
    return None


def process(path):
    d = json.load(open(path, encoding="utf-8"))
    nodes = d.get("nodes", {})

    fixed_rotom = 0
    for g in d.get("groups", []):
        for e in g.get("entries", []):
            if str(e.get("label", "")) == "?":
                lbl = rotom_label_from_node(nodes.get(e.get("nodeId"), {}))
                if lbl:
                    e["label"] = lbl
                    fixed_rotom += 1

    for nid, n in nodes.items():
        if n.get("title"):
            n["title"] = translate(n["title"])
        for s in n.get("steps", []):
            if "text" in s:
                s["text"] = translate(s["text"])
        b = n.get("branch")
        if b:
            if b.get("prompt"):
                b["prompt"] = translate(b["prompt"])
            for o in b.get("options", []):
                if "label" in o:
                    o["label"] = translate_option_label(o["label"])
                if o.get("note"):
                    o["note"] = translate(o["note"])

    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"  ok: {path}  (rotom corrigidos: {fixed_rotom})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        process(p)
