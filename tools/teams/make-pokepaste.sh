#!/usr/bin/env bash
# make-pokepaste.sh — cria um Poképaste no pokepast.es COM sprites dos Pokémon.
#
# ⚠️ PONTO CRÍTICO: o pokepast.es só separa os mons (e mostra sprite de cada um)
# se o corpo do paste for enviado com quebras CRLF (\r\n). Com LF puro (\n) ele
# junta tudo num bloco único com sprite "0-0.png" (desconhecido). Este script
# converte pra CRLF automaticamente antes de enviar.
#
# Uso:
#   ./make-pokepaste.sh --paste corpo.txt [--title "T"] [--author "A"] [--notes notas.txt]
#
#   --paste   (obrigatório) arquivo .txt no formato Showdown (1 set por mon,
#             separados por LINHA EM BRANCO). Escreva com LF normal; o script
#             converte pra CRLF.
#   --title   título do paste (opcional)
#   --author  autor "by ..." (opcional)
#   --notes   arquivo .txt com as notas/descrição (opcional)
#
# Saída: imprime a URL nova e roda a verificação (nº de mons x nº de articles,
# lista de sprites, e alerta se algum ficou "0-0.png" = não reconhecido).
set -euo pipefail

PASTE="" TITLE="" AUTHOR="" NOTES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --paste)  PASTE="$2"; shift 2;;
    --title)  TITLE="$2"; shift 2;;
    --author) AUTHOR="$2"; shift 2;;
    --notes)  NOTES="$2"; shift 2;;
    *) echo "arg desconhecido: $1" >&2; exit 2;;
  esac
done
[ -n "$PASTE" ] && [ -f "$PASTE" ] || { echo "erro: --paste <arquivo> é obrigatório e deve existir" >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# LF -> CRLF (idempotente: normaliza pra LF primeiro, tira \n final, e converte)
to_crlf() { python3 -c "import sys;d=open(sys.argv[1],'r',encoding='utf-8').read().replace('\r\n','\n').rstrip('\n').replace('\n','\r\n');open(sys.argv[2],'wb').write(d.encode('utf-8'))" "$1" "$2"; }

to_crlf "$PASTE" "$TMP/paste.txt"
ARGS=(--data-urlencode "paste@$TMP/paste.txt")
[ -n "$TITLE" ]  && ARGS+=(--data-urlencode "title=$TITLE")
[ -n "$AUTHOR" ] && ARGS+=(--data-urlencode "author=$AUTHOR")
if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then to_crlf "$NOTES" "$TMP/notes.txt"; ARGS+=(--data-urlencode "notes@$TMP/notes.txt"); fi

curl -s -D "$TMP/h.txt" -o /dev/null -X POST "https://pokepast.es/create" "${ARGS[@]}"
LOC="$(grep -i '^location:' "$TMP/h.txt" | tr -d '\r' | awk '{print $2}')"
[ -n "$LOC" ] || { echo "erro: pokepast.es não retornou Location. Headers:" >&2; cat "$TMP/h.txt" >&2; exit 1; }
URL="https://pokepast.es${LOC}"
echo "✅ Poképaste criado: $URL"

# --- verificação ---
curl -s "$URL" -o "$TMP/page.html"
python3 - "$TMP/page.html" "$TMP/paste.txt" <<'PY'
import re,sys,html
page=open(sys.argv[1],encoding='utf-8').read()
body=open(sys.argv[2],encoding='utf-8').read()
esperado=len([b for b in re.split(r'(?:\r?\n){2,}', body) if b.strip()])
articles=len(re.findall(r'<article', page))
sprites=re.findall(r'img-pokemon" src="([^"]+)"', page)
desconhecidos=[s for s in sprites if re.search(r'/0-0\.png$', s)]
print(f"   mons esperados: {esperado} | articles renderizados: {articles}")
print(f"   sprites: {sprites}")
ok = (esperado==articles) and not desconhecidos
if desconhecidos: print(f"   ⚠️ sprite(s) desconhecido(s) 0-0.png: {desconhecidos}")
print("   RESULTADO:", "OK ✅ (todos os mons com sprite)" if ok else "⚠️ REVISAR (contagem ou sprite errado)")
PY
