@echo off
title Servidor B2B Personal IA
chcp 65001 >nul
cd /d "%~dp0"

echo =======================================================
echo  INICIANDO SERVIDOR BACKEND FASTAPI (0.0.0.0:8000)
echo =======================================================
echo.

call .venv\Scripts\activate.bat
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

echo.
echo [AVISO] Servidor finalizado.
pause
