@echo off
title B2B Personal IA - Servidor Backend
chcp 65001 >nul

:: Ativar o ambiente virtual onde o FastAPI e Uvicorn estão instalados
if exist "%~dp0backend\.venv\Scripts\activate.bat" (
    call "%~dp0backend\.venv\Scripts\activate.bat"
) else if exist "%~dp0.venv\Scripts\activate.bat" (
    call "%~dp0.venv\Scripts\activate.bat"
)

:: Entrar na pasta backend
cd /d "%~dp0backend"

:MENU
cls
echo =======================================================
echo        B2B PERSONAL IA - CONTROLE DO SERVIDOR
echo =======================================================
echo.
echo   [1] Iniciar Servidor FastAPI (0.0.0.0:8000)
echo   [2] Parar / Desligar Servidor
echo   [3] Ver Meu IP Local (para o Celular)
echo   [4] Abrir Documentacao Swagger no Navegador
echo   [0] Sair
echo.
echo =======================================================
set /p OPCAO="Escolha uma opcao [0-4]: "

if "%OPCAO%"=="1" goto INICIAR
if "%OPCAO%"=="2" goto PARAR
if "%OPCAO%"=="3" goto VER_IP
if "%OPCAO%"=="4" goto ABRIR_DOCS
if "%OPCAO%"=="0" goto SAIR

echo Opcao invalida!
timeout /t 2 >nul
goto MENU

:INICIAR
cls
echo =======================================================
echo  INICIANDO SERVIDOR FASTAPI...
echo =======================================================
echo.
echo O servidor ficara ouvindo em 0.0.0.0:8000
echo Mantenha esta janela aberta enquanto testa no celular.
echo Para parar o servidor, pressione CTRL + C.
echo.
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
echo.
echo [AVISO] O servidor parou de executar.
pause
goto MENU

:PARAR
cls
echo =======================================================
echo  ENCERRANDO SERVIDOR...
echo =======================================================
echo.
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":8000 " ^| findstr "LISTENING"') do (
    echo Finalizando processo PID %%a na porta 8000...
    taskkill /F /PID %%a >nul 2>&1
)
taskkill /F /IM uvicorn.exe >nul 2>&1
echo [OK] Servidor desligado com sucesso.
pause
goto MENU

:VER_IP
cls
echo =======================================================
echo  SEU ENDERECO IP LOCAL NA REDE WI-FI:
echo =======================================================
echo.
ipconfig | findstr /i "IPv4"
echo.
echo -------------------------------------------------------
echo  Copie o IP acima (ex: 192.168.1.15) e digite no App:
echo     http://SEU_IP:8000/api/v1
echo -------------------------------------------------------
echo.
pause
goto MENU

:ABRIR_DOCS
start http://localhost:8000/docs
goto MENU

:SAIR
exit
