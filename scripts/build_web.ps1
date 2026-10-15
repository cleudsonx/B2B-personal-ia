# ==============================================================================
# Script de Build Web com Versionamento Automatico PWA
# Uso:
#   .\scripts\build_web.ps1
#   .\scripts\build_web.ps1 -Bump "patch"
#   .\scripts\build_web.ps1 -Bump "minor"
#   .\scripts\build_web.ps1 -SetVersion "1.4.0" -Notes "Nova Release"
# ==============================================================================
param (
    [string]$Bump = "",
    [string]$SetVersion = "",
    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"

Write-Host "Iniciando processo de Auto-Versionamento..." -ForegroundColor Cyan

$root = Resolve-Path "$PSScriptRoot\.."
Set-Location "$root\mobile"

$dartArgs = @("run", "tool/update_version.dart")
if ($Bump) { $dartArgs += "--bump=$Bump" }
if ($SetVersion) { $dartArgs += "--set-version=$SetVersion" }
if ($Notes) { $dartArgs += "--notes=$Notes" }

& dart @dartArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao rodar o script de auto-versionamento!"
    exit $LASTEXITCODE
}

Write-Host "Compilando Flutter Web Release..." -ForegroundColor Yellow
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no build do Flutter Web!"
    exit $LASTEXITCODE
}

# Garante que version.json esteja sincronizado na pasta de build
Copy-Item -Path "web\version.json" -Destination "build\web\version.json" -Force

Write-Host "Build Web concluido com sucesso e versionado!" -ForegroundColor Green
Set-Location $root

