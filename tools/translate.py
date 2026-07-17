#!/usr/bin/env python3
"""Traduz strings de um JSON do Pokeking usando o dicionário CN->EN da extensão.

Mesma lógica do content.js: substituição de substrings, chaves mais longas primeiro.
Uso: python3 translate.py <arquivo.json>
"""
import json, sys, re, os

DICT = json.load(open(os.path.join(os.path.dirname(__file__), "pokeking-dictionary.json"), encoding="utf-8"))
# chaves mais longas primeiro (igual content.js)
KEYS = sorted(DICT.keys(), key=len, reverse=True)
PATTERN = re.compile("|".join(re.escape(k) for k in KEYS))

def tr(s):
    if not isinstance(s, str) or not s.strip():
        return s
    return PATTERN.sub(lambda m: DICT[m.group(0)], s)

def walk(obj):
    if isinstance(obj, dict):
        return {k: (tr(v) if isinstance(v, str) else walk(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [walk(x) for x in obj]
    return obj

if __name__ == "__main__":
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(walk(data), ensure_ascii=False, indent=2))
