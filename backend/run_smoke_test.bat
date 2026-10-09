@echo off
echo ==========================================================
echo   Mr. Coach - Execucao de Smoke Test Pos-Deploy
echo ==========================================================

set TARGET_URL=%1
if "%TARGET_URL%"=="" set TARGET_URL=http://localhost:8000

echo Target URL: %TARGET_URL%
echo.

if exist .venv\Scripts\python.exe (
    .venv\Scripts\python.exe scripts\smoke_test.py --url %TARGET_URL%
) else (
    python scripts\smoke_test.py --url %TARGET_URL%
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [FALHA] Smoke test identificou erros na implantacao.
    exit /b 1
)

echo.
echo [SUCESSO] Smoke test validado com exito!

