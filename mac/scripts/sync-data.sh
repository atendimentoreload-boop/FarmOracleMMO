#!/bin/bash
# Sincroniza os dados de jogo (fonte única em /data) para os Resources do app Mac.
# Os JSON e as pastas de imagens NÃO ficam versionados dentro de mac/ — eles vivem
# em /data e são copiados aqui na hora de compilar, pra não duplicar entre plataformas.
set -euo pipefail

cd "$(dirname "$0")/.."            # -> mac/
SRC="../data"
DST="Sources/DestruidorDeRed/Resources"

if [ ! -d "$SRC" ]; then
  echo "ERRO: pasta de dados '$SRC' não encontrada (rode a partir do monorepo)." >&2
  exit 1
fi

mkdir -p "$DST"

# JSON das lutas/rotas da raiz (red, veteran) + manifesto de times (teams.json)
cp "$SRC"/*.json "$DST"/

# Variantes traduzidas (EN) dos roteiros da raiz (en/red, en/veteran)
rm -rf "$DST/en"
[ -d "$SRC/en" ] && cp -R "$SRC/en" "$DST/en"

# Soluções por time (Elite 4 de cada time + variação emoji + en/) — árvore inteira
rm -rf "$DST/teams"
cp -R "$SRC/teams" "$DST/teams"

# Pastas de imagens (substitui inteiras para refletir remoções)
for d in sprites trainers regions items; do
  rm -rf "$DST/$d"
  cp -R "$SRC/$d" "$DST/$d"
done

echo "✓ dados sincronizados de /data para $DST"
