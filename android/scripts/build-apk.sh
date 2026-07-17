#!/bin/bash
# Gera o APK (debug, assinado com a chave de debug — serve pra sideload) e copia
# pra Área de Trabalho com um nome amigável, pra você mandar pro celular.
set -euo pipefail

cd "$(dirname "$0")/.."            # -> android/
export JAVA_HOME="${JAVA_HOME:-$(brew --prefix openjdk@17)}"

echo "==> Sincronizando dados de /data..."
bash scripts/sync-data.sh

echo "==> Compilando APK..."
./gradlew assembleDebug

SRC="app/build/outputs/apk/debug/app-debug.apk"
DST="${HOME}/Desktop/FarmOracleMMO.apk"
cp "$SRC" "$DST"
echo "==> Pronto: $DST ($(du -h "$DST" | cut -f1))"
echo "    Mande esse arquivo pro celular e instale (permita 'fontes desconhecidas')."
