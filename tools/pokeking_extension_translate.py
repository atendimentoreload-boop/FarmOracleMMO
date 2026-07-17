#!/usr/bin/env python3
"""Traduz o texto BRUTO do Pokeking igual a uma extensão de tradução do navegador:
maior-correspondência (greedy longest-match) usando tools/pokeking-dictionary.json.
O que o dicionário conhece vira inglês; emoji/números/o que não conhece ficam como estão
-> resultado 'inglês misturado com chinês', do jeito que aparece no site traduzido."""
import json, re

_DICT = None
_MAXLEN = 1

def _load():
    global _DICT, _MAXLEN
    if _DICT is None:
        _DICT = json.load(open("tools/pokeking-dictionary.json", encoding="utf-8"))
        _MAXLEN = max(len(k) for k in _DICT)

def translate(s):
    """Traduz string igual extensão. Emoji e chars desconhecidos passam intactos."""
    _load()
    if not s:
        return s
    out = []
    i = 0
    n = len(s)
    while i < n:
        matched = None
        # tenta a maior chave possível a partir de i
        hi = min(_MAXLEN, n - i)
        for L in range(hi, 0, -1):
            frag = s[i:i + L]
            if frag in _DICT:
                matched = (frag, _DICT[frag])
                break
        if matched:
            out.append(_DICT[matched[0]])
            i += len(matched[0])
        else:
            out.append(s[i])
            i += 1
    # limpa espaço duplicado que o dicionário (com sufixos ' ') gera
    return re.sub(r"[ ]{2,}", " ", "".join(out)).strip()

if __name__ == "__main__":
    samples = [
        "钉出鸭子，👻2出乘龙，🦂22",
        "【意外】鸭子不走",
        "切💧切🥚等鸭子",
        "赖场生蛋",
        "冰光切🦋切💧对快龙，冰出乘龙，🦂22",
        "水炮切嘟电，切🦋对尼多？",
    ]
    for s in samples:
        print(repr(s))
        print("   ->", translate(s))
