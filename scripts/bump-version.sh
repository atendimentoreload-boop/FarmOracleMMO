#!/usr/bin/env bash
# Bump da versão ÚNICA dos 3 apps (Mac / Windows / Android) a partir de /VERSION.
#
# Uso:
#   ./scripts/bump-version.sh 1.2.0     # define a versão exata
#   ./scripts/bump-version.sh patch     # 1.1.0 -> 1.1.1
#   ./scripts/bump-version.sh minor     # 1.1.0 -> 1.2.0
#   ./scripts/bump-version.sh major     # 1.1.0 -> 2.0.0
#
# Atualiza: /VERSION, windows .csproj <Version>, android versionName+versionCode,
# e mac Version.swift. SEMPRE teste antes de compilar/release nos 3.
set -euo pipefail

target="${1:-}"
[ -z "$target" ] && { echo "Uso: bump-version.sh <X.Y.Z|patch|minor|major>" >&2; exit 1; }

root="$(cd "$(dirname "$0")/.." && pwd)"
current="$(tr -d '[:space:]' < "$root/VERSION")"
[[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION atual inválido: '$current'" >&2; exit 1; }

IFS='.' read -r MA MI PA <<< "$current"
case "$target" in
  major) new="$((MA + 1)).0.0" ;;
  minor) new="${MA}.$((MI + 1)).0" ;;
  patch) new="${MA}.${MI}.$((PA + 1))" ;;
  *)
    [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Alvo inválido: '$target' (use X.Y.Z, ou patch/minor/major)" >&2; exit 1; }
    new="$target" ;;
esac

IFS='.' read -r NA NI NP <<< "$new"
code=$(( NA * 10000 + NI * 100 + NP ))

# Edição in-place portável (cria .bak e remove).
sedi() { sed -i.bak "$1" "$2" && rm -f "$2.bak"; }

# 1) Fonte única
printf '%s\n' "$new" > "$root/VERSION"

# 2) Windows (.csproj)
sedi "s#<Version>[^<]*</Version>#<Version>${new}</Version>#" "$root/windows/PrestreloAjuda/PrestreloAjuda.csproj"

# 3) Android (build.gradle.kts)
sedi "s/versionCode = [0-9]*/versionCode = ${code}/" "$root/android/app/build.gradle.kts"
sedi "s/versionName = \"[^\"]*\"/versionName = \"${new}\"/" "$root/android/app/build.gradle.kts"

# 4) Mac (Version.swift)
sedi "s/static let current = \"[^\"]*\"/static let current = \"${new}\"/" "$root/mac/Sources/DestruidorDeRed/Version.swift"

# 5) version.json — campo "latest" (NÃO mexe em "minimum"; forçar update é ação separada)
sedi "s/\"latest\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"latest\": \"${new}\"/" "$root/version.json"

echo "Versao: ${current} -> ${new}   (versionCode Android = ${code})"
echo "Atualizados: VERSION, .csproj, build.gradle.kts, Version.swift, version.json (latest)"
echo "Para FORCAR atualizacao: edite 'minimum' em version.json e faca commit/push."
echo "Lembrete: TESTAR antes de compilar/release nos 3 (Mac, Windows, Android)."
