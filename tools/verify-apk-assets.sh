#!/bin/bash
# Verifica que um APK realmente EMBARCOU os dados de jogo (assets/data/...).
# Foi exatamente este buraco que deixou sair a 1.3.0 do Android "sem roteiros": o APK
# compilava e publicava sem a pasta /data, e o app crashava ao abrir. Rode no CI logo
# após assembleRelease; se faltar algum asset, sai != 0 e a publicação é abortada.
#
# Uso: tools/verify-apk-assets.sh <caminho-do-apk>
set -euo pipefail

APK="${1:?uso: verify-apk-assets.sh <apk>}"
[ -f "$APK" ] || { echo "ERRO: APK não encontrado: $APK" >&2; exit 1; }

# Lista dos assets que o app SEMPRE tenta abrir (data/<nome>.json em SolveLoader/TeamsConfig).
# Mantido em sincronia com data/teams.json: red, veteran + os 5 Elite 4 de cada time/visual.
required=(
  "assets/data/teams.json"
  "assets/data/red.json"
  "assets/data/veteran.json"
  "assets/data/teams/shadow_scale/elite4_kanto.json"
  "assets/data/teams/shadow_scale/elite4_hoenn.json"
  "assets/data/teams/shadow_scale/elite4_unova.json"
  "assets/data/teams/shadow_scale/elite4_sinnoh.json"
  "assets/data/teams/shadow_scale/elite4_johto.json"
  "assets/data/teams/reversed_fate/elite4_kanto.json"
  "assets/data/teams/reversed_fate/emoji/elite4_kanto.json"
)

listing="$(unzip -Z1 "$APK")"
missing=0
for f in "${required[@]}"; do
  if ! grep -qxF "$f" <<<"$listing"; then
    echo "❌ FALTA no APK: $f" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "APK incompleto — dados de jogo não foram embarcados. Publicação abortada." >&2
  exit 1
fi
echo "✓ APK ok: dados de jogo presentes em assets/data/."
