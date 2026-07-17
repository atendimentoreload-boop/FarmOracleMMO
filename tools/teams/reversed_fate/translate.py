#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tradutor do time **Reversed Fate** (Jirachi/Pikachu/Chandelure/Dragonite/Gallade/Scrafty).

Decodifica a notação do autor (emojis + números de buff) para PT. Usado pelo build.py
deste time. A legenda foi validada com o autor (ver tools/README.md / pokeking-extraction).

  Emojis Pokémon:  💫 Jirachi · 🕯️ Chandelure · 🐲 Dragonite · 👊 Scrafty · 🗡️ Gallade · 🐭 Pikachu
  Ações:           👏 Encore · 📌 Stealth Rock · 💀 sacrifica · ↪ U-turn
  Números 'A+B':   +A no ataque (Atk; Sp.Atk p/ Pikachu/Chandelure) e +B em Velocidade.
"""
import json, re, os

BASE = os.path.dirname(__file__)
# dicionário CN->EN/PT compartilhado (nomes de oponentes em chinês que sobrarem)
DICT = json.load(open(os.path.join(BASE, '..', '..', 'pokeking-dictionary.json'), encoding='utf-8'))
DPAT = re.compile('|'.join(re.escape(k) for k in sorted(DICT, key=len, reverse=True)))

MON = {'💫': 'Jirachi', '🌟': 'Jirachi', '🕯': 'Chandelure', '🐲': 'Dragonite',
       '👊': 'Scrafty', '🗡': 'Gallade', '⚔': 'Gallade', '🐭': 'Pikachu'}
ACT = {'👏': 'Encore', '📌': 'Stealth Rock', '💀': 'sacrifica', '↪': 'U-turn'}

OFFENSIVE = {'Dragonite': 'Atk', 'Scrafty': 'Atk', 'Gallade': 'Atk', 'Jirachi': 'Atk',
             'Pikachu': 'Sp.Atk', 'Chandelure': 'Sp.Atk'}

PHRASES = [
    (r'self\s*lo[oc]k', 'Choice (preso num golpe)'),
    (r'x\s*sp\s*d(?:ef)?\b', 'X Sp.Def'),
    (r'x\s*def\b', 'X Def'),
    (r'\bxdef\b', 'X Def'),
]

WORDMON_MAP = {'dragonite': 'Dragonite', 'nite': 'Dragonite', 'pikachu': 'Pikachu', 'pika': 'Pikachu',
               'chandelure': 'Chandelure', 'chande': 'Chandelure', 'gallade': 'Gallade',
               'scrafty': 'Scrafty', 'scraft': 'Scrafty', 'jirachi': 'Jirachi'}
WORDMON = '|'.join(sorted(WORDMON_MAP, key=len, reverse=True))


def num_expand(mon, num):
    off = OFFENSIVE.get(mon, 'Atk')
    if '+' not in num:                      # ex.: 👊2 = N Dragon Dances
        n = int(num) if num.isdigit() else 0
        return f'{n}x Dragon Dance (+{n} Atk +{n} Speed)' if (mon in ('Scrafty', 'Dragonite') and n) else num
    a, _, b = num.partition('+')
    ai = int(a) if a.isdigit() else -1
    bi = int(b) if b.isdigit() else -1
    if ai < 0 or bi < 0:
        return num
    parts = ([f'+{ai} {off}'] if ai else []) + ([f'+{bi} Speed'] if bi else [])
    return ', '.join(parts) or 'sem buff'


def translate(s):
    """Tradução completa (combate em PT). Para o MODO TEXTO."""
    if not s:
        return s
    s = s.replace('️', '')
    s = re.sub(r'(?i)encore', '👏', s)
    for pat, rep in PHRASES:
        s = re.sub('(?i)' + pat, rep, s)
    monpat = '|'.join(re.escape(e) for e in ['🕯', '🗡', '⚔', '🐭', '👊', '🐲'])

    def mon_num(m):
        mon = MON[m.group(1)]
        pre = 'Encore, ' if m.group(2) else ''
        pos = ', Encore' if m.group(4) else ''
        return f'{mon}[{pre}{num_expand(mon, m.group(3))}{pos}] '
    s = re.sub(rf'({monpat})\s*(👏)?\s*(\d(?:\+\d)?)\s*(👏)?', mon_num, s)
    for e, name in {**MON, **ACT}.items():
        s = s.replace(e, name + ' ')
    s = DPAT.sub(lambda m: DICT[m.group(0)], s)

    def word_num(m):
        mon = WORDMON_MAP[m.group(1).lower()]
        mid = re.sub(r'(?i)\s*,?\s*(?:👏|encore)\s*,?', ' ', m.group(2)).strip()
        enc = 'Encore, ' if re.search(r'👏|encore', m.group(2), re.I) else ''
        mid = (mid + ' ') if mid else ''
        return f'{mon} {mid}[{enc}{num_expand(mon, m.group(3))}]'
    s = re.sub(rf'(?i)\b({WORDMON})([^0-9\[\]]{{0,16}}?)(\d\+\d)', word_num, s)
    return re.sub(r'\s+', ' ', s).strip()


def raw(s):
    """MODO EMOJI: mantém os emojis do autor; só limpa variation selectors e traduz
    nomes de oponentes em chinês que sobrarem (estrutura legível, combate no original)."""
    if not s:
        return s
    s = s.replace('️', '')
    s = DPAT.sub(lambda m: DICT[m.group(0)], s)
    return re.sub(r'\s+', ' ', s).strip()


def tr_name(s):
    """Nome (oponente/treinador/lead): só dicionário CN->EN. Igual nos 2 modos."""
    if not s:
        return s
    s = DPAT.sub(lambda m: DICT[m.group(0)], s.replace('️', ''))
    return re.sub(r'\s+', ' ', s).strip()


def split_field(text, emoji_mode):
    """Quebra um 'operate' em ações (por vírgula CN/normal) e traduz cada parte.
    emoji_mode=True -> mantém emojis; False -> traduz pra texto."""
    fn = raw if emoji_mode else translate
    parts = re.split(r'[，,]', text or '')
    return [p for p in (fn(x.strip()) for x in parts) if p]
