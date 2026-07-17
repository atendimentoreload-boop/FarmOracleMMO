#!/bin/bash
# Copia os dados de jogo (fonte única em /data) para os assets do app Android.
# Igual ao sync do Mac: os dados vivem em /data e são copiados na hora de compilar.
set -euo pipefail

cd "$(dirname "$0")/.."            # -> android/
SRC="../data"
DST="app/src/main/assets/data"

if [ ! -d "$SRC" ]; then
  echo "ERRO: pasta de dados '$SRC' não encontrada." >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST"

cp "$SRC"/*.json "$DST"/
# Variantes traduzidas dos roteiros da raiz (red/veteran em inglês), em data/en/.
[ -d "$SRC/en" ] && cp -R "$SRC/en" "$DST/en"
# Soluções por time (Elite 4 de cada time + variação emoji, incl. subpastas en/)
[ -d "$SRC/teams" ] && cp -R "$SRC/teams" "$DST/teams"
for d in sprites trainers regions items; do
  [ -d "$SRC/$d" ] && cp -R "$SRC/$d" "$DST/$d"
done

echo "✓ dados sincronizados de /data para $DST"
