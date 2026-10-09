@echo off
echo ==========================================================
echo   Mr. Coach - Execucao de Testes de Carga e Stress (k6)
echo ==========================================================

where k6 >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] k6 nao encontrado no PATH do sistema.
    echo Instale o k6 via: winget install k6 --source winget
    exit /b 1
)

set TARGET_URL=%1
if "%TARGET_URL%"=="" set TARGET_URL=http://localhost:8000

echo Target URL: %TARGET_URL%
echo.

echo [1/2] Executando Stress Test de Leitura e Healthcheck...
k6 run tests\performance\health_and_public_stress.js -e TARGET_URL=%TARGET_URL%
if %ERRORLEVEL% NEQ 0 (
    echo [FALHA] Teste de leitura apresentou taxa de erro acima do limite.
    exit /b 1
)

echo.
echo [2/2] Executando Stress Test de Webhooks e Anti-duplicacao...
k6 run tests\performance\webhook_stress.js -e TARGET_URL=%TARGET_URL%
if %ERRORLEVEL% NEQ 0 (
    echo [FALHA] Teste de webhook apresentou taxa de erro acima do limite.
    exit /b 1
)

echo.
echo ==========================================================
echo   Todos os testes de carga e stress foram APROVADOS!
echo ==========================================================
