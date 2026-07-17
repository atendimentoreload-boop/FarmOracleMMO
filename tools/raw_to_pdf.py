#!/usr/bin/env python3
"""Renderiza o dump BRUTO do Pokeking (tools/_raw_*.json) em HTML — 100% fiel.
NADA traduzido, NADA adicionado por nós: só o conteúdo do site (chinês + emoji).
Chrome headless converte pra PDF."""
import json, sys, html, os
from pokeking_extension_translate import translate as _tr

TRANSLATE = os.environ.get("TRANSLATE", "1") != "0"

def esc(s):
    return html.escape(s or "")

def tr(s):
    return _tr(s) if TRANSLATE else (s or "")

def render_node(n, depth=0):
    label = tr(n.get("label", ""))
    op = tr(n.get("operate", ""))
    att = tr(n.get("attention", ""))
    parts = ['<div class="node">']
    line = '<div class="row">'
    if label:
        line += f'<span class="label">{esc(label)}</span>'
    if op:
        line += f'<span class="op">{esc(op)}</span>'
    if not label and not op:
        line += '<span class="op muted">—</span>'
    line += '</div>'
    parts.append(line)
    if att:
        parts.append(f'<div class="att">⚠️ {esc(att)}</div>')
    kids = n.get("children") or []
    if kids:
        parts.append('<div class="children">')
        for c in kids:
            parts.append(render_node(c, depth + 1))
        parts.append('</div>')
    parts.append('</div>')
    return "".join(parts)

def build_html(data, title):
    regions = data["regions"]
    body = []
    for r in regions:
        body.append(f'<h2 class="region">{esc(r["code"])}</h2>')
        for ch in r["champions"]:
            body.append('<section class="champ">')
            body.append(f'<h3 class="champ-name">{esc(tr(ch.get("name","")))}</h3>')
            rt = ch.get("routers") or {}
            for c in (rt.get("children") or []):
                body.append(render_node(c))
            body.append('</section>')
    css = """
    @page { size: A4 portrait; margin: 12mm 10mm; }
    * { box-sizing: border-box; }
    body { font-family: "Arial Unicode MS","Apple Color Emoji",sans-serif;
           color:#1a1a1a; font-size:11px; line-height:1.5; margin:0; padding:0; }
    h2.region { font-size:15px; background:#222; color:#fff; padding:5px 10px;
                border-radius:5px; margin:16px 0 8px; page-break-after:avoid; }
    section.champ { margin:0 0 10px; padding:6px 0 6px 0; page-break-inside:avoid;
                    border-bottom:1px dashed #ddd; }
    h3.champ-name { font-size:13px; color:#b4232a; margin:4px 0 4px; page-break-after:avoid; }
    .node { margin:1px 0; }
    .children { margin-left:14px; padding-left:8px; border-left:2px solid #e4e4ea; }
    .row { display:block; }
    .label { display:inline-block; background:#eef3fb; color:#2456a6; border:1px solid #d3e0f2;
             border-radius:4px; padding:0 5px; margin-right:5px; font-size:10px; font-weight:600; }
    .op { color:#111; }
    .op.muted { color:#bbb; }
    .att { color:#a8630a; background:#fff6e6; border-left:3px solid #f0a020;
           padding:1px 6px; margin:1px 0 1px 2px; border-radius:0 4px 4px 0; font-size:10px; }
    """
    return f"""<!doctype html><html lang="zh"><head><meta charset="utf-8">
<title>{esc(title)}</title><style>{css}</style></head><body>
{''.join(body)}
</body></html>"""

TITLES = {
    "dingxianyou": "Dingxianyou",
    "ghost_dance": "Ghost Dance",
    "sacred_inferno": "Sacred Inferno",
}

def main():
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    for key, title in TITLES.items():
        src = f"tools/_raw_{key}.json"
        data = json.load(open(src, encoding="utf-8"))
        htmlout = os.path.join(outdir, f"{key}.html")
        with open(htmlout, "w", encoding="utf-8") as f:
            f.write(build_html(data, title))
        print(htmlout)

if __name__ == "__main__":
    main()
