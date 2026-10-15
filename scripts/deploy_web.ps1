# ==============================================================================
# Script de Build & Deploy Web com Versionamento Automatico PWA (Firebase Hosting)
# Uso:
#   .\scripts\deploy_web.ps1
#   .\scripts\deploy_web.ps1 -Bump "patch"
#   .\scripts\deploy_web.ps1 -SetVersion "1.4.0" -Notes "Nova Release"
# ==============================================================================
param (
    [string]$Bump = "",
    [string]$SetVersion = "",
    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
Set-Location $root

$splat = @{}
if ($Bump) { $splat["Bump"] = $Bump }
if ($SetVersion) { $splat["SetVersion"] = $SetVersion }
if ($Notes) { $splat["Notes"] = $Notes }

& "$PSScriptRoot\build_web.ps1" @splat
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha na etapa de build!"
    exit $LASTEXITCODE
}

Write-Host "Publicando no Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no deploy do Firebase Hosting!"
    exit $LASTEXITCODE
}

Write-Host "Deploy no Firebase Hosting realizado com sucesso!" -ForegroundColor Green

