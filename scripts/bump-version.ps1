#!/usr/bin/env pwsh
# Bump da versão ÚNICA dos 3 apps (Mac / Windows / Android) a partir de /VERSION.
#
# Uso:
#   ./scripts/bump-version.ps1 1.2.0     # define a versão exata
#   ./scripts/bump-version.ps1 patch     # 1.1.0 -> 1.1.1
#   ./scripts/bump-version.ps1 minor     # 1.1.0 -> 1.2.0
#   ./scripts/bump-version.ps1 major     # 1.1.0 -> 2.0.0
#
# Atualiza: /VERSION, windows .csproj <Version>, android versionName+versionCode,
# e mac Version.swift. SEMPRE teste antes de compilar/release nos 3.
param([Parameter(Mandatory = $true)][string]$Target)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false

function ReadText($p) { [IO.File]::ReadAllText($p) }
function WriteText($p, $s) { [IO.File]::WriteAllText($p, $s, $utf8) }

$versionFile = Join-Path $root 'VERSION'
$current = (ReadText $versionFile).Trim()
if ($current -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION atual inválido: '$current'" }
$p = $current.Split('.') | ForEach-Object { [int]$_ }

switch ($Target) {
    'major' { $new = "$($p[0] + 1).0.0" }
    'minor' { $new = "$($p[0]).$($p[1] + 1).0" }
    'patch' { $new = "$($p[0]).$($p[1]).$($p[2] + 1)" }
    default {
        if ($Target -notmatch '^\d+\.\d+\.\d+$') {
            throw "Alvo inválido: '$Target'. Use X.Y.Z, ou patch / minor / major."
        }
        $new = $Target
    }
}
$np = $new.Split('.') | ForEach-Object { [int]$_ }
$code = $np[0] * 10000 + $np[1] * 100 + $np[2]

# 1) Fonte única
WriteText $versionFile "$new`n"

# 2) Windows (.csproj)
$csproj = Join-Path $root 'windows/PrestreloAjuda/PrestreloAjuda.csproj'
WriteText $csproj ((ReadText $csproj) -replace '<Version>[^<]*</Version>', "<Version>$new</Version>")

# 3) Android (build.gradle.kts)
$gradle = Join-Path $root 'android/app/build.gradle.kts'
$g = ReadText $gradle
$g = $g -replace 'versionCode = \d+', "versionCode = $code"
$g = $g -replace 'versionName = "[^"]*"', "versionName = `"$new`""
WriteText $gradle $g

# 4) Mac (Version.swift)
$swift = Join-Path $root 'mac/Sources/DestruidorDeRed/Version.swift'
WriteText $swift ((ReadText $swift) -replace 'static let current = "[^"]*"', "static let current = `"$new`"")

# 5) version.json — campo "latest" (NÃO mexe em "minimum"; forçar update é ação separada)
$verJson = Join-Path $root 'version.json'
WriteText $verJson ((ReadText $verJson) -replace '"latest"\s*:\s*"[^"]*"', "`"latest`": `"$new`"")

Write-Host "Versao: $current -> $new   (versionCode Android = $code)"
Write-Host "Atualizados: VERSION, .csproj, build.gradle.kts, Version.swift, version.json (latest)"
Write-Host "Para FORÇAR atualizacao: edite 'minimum' em version.json e faca commit/push."
Write-Host "Lembrete: TESTAR antes de compilar/release nos 3 (Mac, Windows, Android)."
