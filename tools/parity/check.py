#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Validador de PARIDADE entre plataformas (FarmOracleMMO).

O que faz:
  1. Le a matriz canonica em tools/parity/features.json.
  2. Para cada feature x plataforma, confere a ASSINATURA (`sig`) no codigo-fonte
     daquela plataforma (casamento com FRONTEIRA DE PALAVRA, nao substring cru):
        - status "done"      -> a assinatura PRECISA existir (senao a matriz mente).
        - status todo/na/excluded com sig -> a assinatura NAO pode existir
          (se existir, a feature ja foi feita: reclassifique pra "done").
        - "manual": true      -> pula a verificacao de codigo (diferenca comportamental).
  3. Aplica a REGRA DE PARIDADE: se ao menos uma plataforma tem "done", todas as
     outras precisam ser "done", "excluded" ou "na". Qualquer "todo" = pendencia.
  4. Gera PARIDADE.md (matriz legivel) na raiz do repo.

Uso:
  python3 tools/parity/check.py                 # relatorio completo + regenera PARIDADE.md
  python3 tools/parity/check.py --gate windows  # portao ESCOPADO ao Windows (pra rodar antes
                                                 # de portar/lancar): exit 1 so por problemas do
                                                 # proprio Windows; inconsistencias de outras
                                                 # plataformas viram AVISO nao-fatal.
  python3 tools/parity/check.py --no-md          # nao regenera o PARIDADE.md
  python3 tools/parity/check.py --quiet          # so o resumo + issues

Codigo de saida: 0 = ok; 1 = erro de assinatura/status ou pendencia de paridade.
O portao BLOQUEANTE da release e o job `verify-parity` no CI (.github/workflows/release.yml),
que roda o modo COMPLETO (sem --gate). Sem dependencias externas (so a stdlib do Python 3).
"""

import argparse
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FEATURES = os.path.join(REPO, "tools", "parity", "features.json")
MD_OUT = os.path.join(REPO, "PARIDADE.md")
SKIP_DIRS = {"bin", "obj", ".build", "build", ".gradle", ".idea", "DerivedData",
             "Pods", "node_modules", ".git", "dist"}
OK, TODO, NA, EXC = "done", "todo", "na", "excluded"
VALID_STATUS = {OK, TODO, NA, EXC}

# Cores ANSI (desligadas se a saida nao for um terminal)
_tty = sys.stdout.isatty()
def c(txt, code): return f"\033[{code}m{txt}\033[0m" if _tty else txt
def red(t): return c(t, "31")
def grn(t): return c(t, "32")
def yel(t): return c(t, "33")
def bold(t): return c(t, "1")

ICON = {OK: "OK", TODO: "..", NA: "--", EXC: "no"}
MD_ICON = {OK: "✅", TODO: "⏳", NA: "➖", EXC: "🚫"}

_WORD = "A-Za-z0-9_"


def load():
    with open(FEATURES, encoding="utf-8") as f:
        return json.load(f)


def sig_present(sig, blob):
    """Casa a assinatura com FRONTEIRA DE PALAVRA quando a borda for alfanumerica.

    Evita que um sig curto (ex.: `lucky_girl`, `onKeyDown`) case como substring de um
    token maior. Sigs terminados/iniciados em pontuacao (ex.: `func setTeam(`, `Load("veteran"`)
    nao ganham fronteira naquele lado (ficaria impossivel casar)."""
    if not sig:
        return False
    pat = re.escape(sig)
    if sig[0] in "_" or sig[0].isalnum():
        pat = r"(?<![" + _WORD + r"])" + pat
    if sig[-1] in "_" or sig[-1].isalnum():
        pat = pat + r"(?![" + _WORD + r"])"
    return re.search(pat, blob) is not None


def read_platform_sources(root, exts):
    """Concatena o codigo-fonte de uma plataforma (por extensao) num unico blob.

    Retorna (blob, existe, n_arquivos). followlinks=True para nao ignorar dirs simbolicos."""
    blob = []
    n = 0
    base = os.path.join(REPO, root)
    if not os.path.isdir(base):
        return "", False, 0
    for dirpath, dirnames, filenames in os.walk(base, followlinks=True):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if any(fn.endswith(e) for e in exts):
                try:
                    with open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace") as f:
                        blob.append(f.read())
                    n += 1
                except OSError:
                    pass
    return "\n".join(blob), True, n


def main():
    ap = argparse.ArgumentParser(description="Validador de paridade entre plataformas.")
    ap.add_argument("--gate", metavar="PLATAFORMA",
                    help="Modo portao ESCOPADO: falha so por problemas desta plataforma.")
    ap.add_argument("--no-md", action="store_true", help="Nao regenera PARIDADE.md.")
    ap.add_argument("--quiet", action="store_true", help="So o resumo e os problemas.")
    args = ap.parse_args()

    data = load()
    platforms = data["platforms"]
    pkeys = list(platforms.keys())

    if args.gate and args.gate not in platforms:
        print(red(f"Plataforma desconhecida: {args.gate}. Use uma de: {', '.join(pkeys)}"))
        return 2

    # Carrega o codigo de cada plataforma uma vez.
    sources = {}
    empty_src = set()   # pasta existe mas 0 arquivos de codigo (checkout incompleto?)
    for pk in pkeys:
        blob, found, nfiles = read_platform_sources(platforms[pk]["root"], platforms[pk]["exts"])
        if not found:
            print(yel(f"AVISO: pasta da plataforma {pk} nao encontrada ({platforms[pk]['root']})."))
        elif nfiles == 0:
            empty_src.add(pk)
            print(red(f"AVISO: pasta de {pk} existe mas nao tem arquivos de codigo "
                      f"({platforms[pk]['root']}) — checkout incompleto? Sigs 'done' vao falhar."))
        sources[pk] = blob

    sig_errors = []   # (feature, plat, msg) - matriz nao bate com o codigo
    gaps = []         # (feature, plat) - existe em outra e falta nesta (todo)
    meta_errors = []  # status invalido / excluded-na sem reason / entrada ausente

    for feat in data["features"]:
        fid = feat["id"]
        any_done = any(feat.get(pk, {}).get("status") == OK for pk in pkeys)

        for pk in pkeys:
            entry = feat.get(pk)
            if not entry:
                meta_errors.append((fid, pk, "sem entrada pra esta plataforma na matriz"))
                continue
            status = entry.get("status")
            sig = entry.get("sig")
            manual = entry.get("manual", False)

            if status not in VALID_STATUS:
                meta_errors.append((fid, pk, f"status invalido '{status}' (use {'/'.join(sorted(VALID_STATUS))})"))
                continue

            if status in (NA, EXC) and not entry.get("reason"):
                meta_errors.append((fid, pk, f"status '{status}' exige 'reason'"))

            # Verificacao da assinatura no codigo (fronteira de palavra)
            if not manual and sig:
                present = sig_present(sig, sources.get(pk, ""))
                if status == OK and not present:
                    extra = " (fonte ausente — checkout incompleto?)" if pk in empty_src else ""
                    sig_errors.append((fid, pk,
                        f"declarado 'done' mas a assinatura NAO foi achada no codigo: «{sig}»{extra}"))
                elif status in (TODO, NA, EXC) and present:
                    sig_errors.append((fid, pk,
                        f"declarado '{status}' mas a assinatura FOI achada no codigo: «{sig}» "
                        f"(a feature parece existir; reclassifique pra 'done')"))

            if any_done and status == TODO:
                gaps.append((fid, pk))

    # ---- Saida ----
    if not args.quiet:
        print(bold("\n=== MATRIZ DE PARIDADE ===\n"))
        hdr = f"{'feature':32} " + " ".join(f"{platforms[p]['label']:>8}" for p in pkeys)
        print(hdr)
        print("-" * len(hdr))
        area = None
        for feat in data["features"]:
            if feat["area"] != area:
                area = feat["area"]
                print(bold(f"\n[{area}]"))
            cells = []
            for pk in pkeys:
                st = feat.get(pk, {}).get("status", "?")
                token = ICON.get(st, "??")
                cells.append(grn(f"{token:>8}") if st == OK
                             else red(f"{token:>8}") if st == TODO
                             else f"{token:>8}")
            print(f"{feat['id']:32} " + " ".join(cells))

    print(bold("\n=== RESULTADO ===\n"))

    if args.gate:
        target = args.gate
        tgt_sig = [e for e in sig_errors if e[1] == target]
        tgt_meta = [e for e in meta_errors if e[1] == target]
        tgt_gaps = [g for g in gaps if g[1] == target]
        other_issues = [e for e in (sig_errors + meta_errors) if e[1] != target]

        for label, items in (("assinatura x codigo", tgt_sig), ("meta/status", tgt_meta)):
            if items:
                print(red(f"[{len(items)}] problema(s) de {label} no {platforms[target]['label']}:"))
                for fid, pk, msg in items:
                    print(f"   - {fid}: {msg}")

        if tgt_gaps:
            print(red(f"\n[PORTAO {platforms[target]['label']}] "
                      f"{len(tgt_gaps)} feature(s) existem em outra plataforma e faltam aqui:"))
            for fid, _ in tgt_gaps:
                feat = next(f for f in data["features"] if f["id"] == fid)
                donein = [platforms[p]["label"] for p in pkeys if feat.get(p, {}).get("status") == OK]
                note = feat.get(target, {}).get("note", "")
                print(f"   - {bold(fid)} ({feat['name']}) — feito em: {', '.join(donein)}")
                if note:
                    print(f"       {note}")
            print(yel("\n   -> Porte estas features OU marque 'excluded'/'na' (com reason) "
                      "em tools/parity/features.json antes de liberar a release."))

        if other_issues:
            print(yel(f"\n(aviso nao-fatal) {len(other_issues)} inconsistencia(s) em OUTRAS plataformas "
                      f"— nao bloqueiam o portao do {platforms[target]['label']}, mas conserte:"))
            for fid, pk, msg in other_issues:
                print(f"   - {fid} / {pk}: {msg}")

        problems = bool(tgt_sig or tgt_meta or tgt_gaps)
        if not problems:
            print(grn(f"[PORTAO {platforms[target]['label']}] OK — sem pendencia de paridade nem erro proprio."))
    else:
        problems = bool(sig_errors or meta_errors or gaps)
        if meta_errors:
            print(red(f"[{len(meta_errors)}] problema(s) de meta/status:"))
            for fid, pk, msg in meta_errors:
                print(f"   - {fid} / {pk}: {msg}")
        if sig_errors:
            print(red(f"[{len(sig_errors)}] assinatura x codigo NAO batem:"))
            for fid, pk, msg in sig_errors:
                print(f"   - {fid} / {pk}: {msg}")
        if gaps:
            by_plat = {}
            for fid, pk in gaps:
                by_plat.setdefault(pk, []).append(fid)
            print(red(f"[{len(gaps)}] pendencia(s) de paridade (feito numa plataforma, 'todo' em outra):"))
            for pk, fids in by_plat.items():
                print(f"   {bold(platforms[pk]['label'])}: {', '.join(fids)}")
        if not problems:
            print(grn("Tudo certo: matriz bate com o codigo e nao ha pendencia de paridade."))

    # ---- Gera o PARIDADE.md ----
    if not args.no_md:
        write_md(data, pkeys, gaps)
        if not args.quiet:
            print(f"\n(PARIDADE.md atualizado: {MD_OUT})")

    return 1 if problems else 0


def write_md(data, pkeys, gaps):
    platforms = data["platforms"]
    lines = []
    lines.append("# Paridade entre plataformas — FarmOracleMMO\n")
    lines.append("> Gerado por `tools/parity/check.py`. **Nao edite a mao** — edite "
                 "`tools/parity/features.json` e rode o script. O CI confere que este arquivo "
                 "esta em sincronia (job `verify-parity`).\n")
    lines.append(f"Legenda: {MD_ICON[OK]} feito · {MD_ICON[TODO]} pendente · "
                 f"{MD_ICON[EXC]} excluido de proposito · {MD_ICON[NA]} nao se aplica\n")

    gapset = set(gaps)
    if gaps:
        lines.append("## ⚠️ Pendencias de paridade\n")
        lines.append("Features feitas numa plataforma e faltando em outra (sem marcacao de exclusao):\n")
        lines.append("| Feature | Falta em | Feito em |")
        lines.append("|---|---|---|")
        seen = set()
        for fid, pk in gaps:
            if fid in seen:
                continue
            seen.add(fid)
            feat = next(f for f in data["features"] if f["id"] == fid)
            miss = [platforms[p]["label"] for p in pkeys if (fid, p) in gapset]
            donein = [platforms[p]["label"] for p in pkeys if feat.get(p, {}).get("status") == OK]
            lines.append(f"| **{feat['name']}** (`{fid}`) | {', '.join(miss)} | {', '.join(donein)} |")
        lines.append("")
    else:
        lines.append("## ✅ Sem pendencias de paridade\n")

    lines.append("## Matriz completa\n")
    area = None
    for feat in data["features"]:
        if feat["area"] != area:
            area = feat["area"]
            lines.append(f"\n### {area}\n")
            lines.append("| Feature | " + " | ".join(platforms[p]["label"] for p in pkeys) + " |")
            lines.append("|---" * (len(pkeys) + 1) + "|")
        cells = []
        for pk in pkeys:
            st = feat.get(pk, {}).get("status", "?")
            cells.append(MD_ICON.get(st, "?"))
        lines.append(f"| {feat['name']} | " + " | ".join(cells) + " |")

    lines.append("\n## Exclusoes intencionais (por design)\n")
    lines.append("| Feature | Plataforma | Motivo |")
    lines.append("|---|---|---|")
    for feat in data["features"]:
        for pk in pkeys:
            e = feat.get(pk, {})
            if e.get("status") in (NA, EXC) and e.get("reason"):
                lines.append(f"| {feat['name']} | {platforms[pk]['label']} | {e['reason']} |")
    lines.append("")

    with open(MD_OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())
