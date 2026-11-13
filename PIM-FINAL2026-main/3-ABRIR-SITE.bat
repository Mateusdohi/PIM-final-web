@echo off
chcp 65001 >nul
title 3 - SITE (deixe esta janela aberta)
cd /d "%~dp0"

echo.
echo ==============================================================
echo  3/4 - ABRIR O SITE
echo ==============================================================
echo.

rem A pasta do site tem acento no nome ("aplicacao web"): procura por padrao.
set "SITE="
for /d %%D in ("%~dp0aplica*web") do set "SITE=%%~fD"
if not defined SITE (
  echo ERRO: nao achei a pasta do site ao lado deste arquivo.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing http://localhost:5080/health -TimeoutSec 3).StatusCode | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo AVISO: a API ainda nao responde em http://localhost:5080.
  echo O site abre, mas o captcha e o login so funcionam depois do 2-LIGAR-SERVIDOR.bat.
  echo.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor-site.ps1" -Root "%SITE%" -Port 5500
echo.
echo O site foi encerrado.
pause
