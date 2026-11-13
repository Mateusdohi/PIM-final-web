@echo off
chcp 65001 >nul
title 2 - LIGAR SERVIDOR (banco + API)
cd /d "%~dp0"

echo.
echo ==============================================================
echo  2/4 - LIGAR O SERVIDOR (banco de dados + API)
echo ==============================================================
echo  A primeira vez baixa e monta tudo: pode levar de 5 a 15 minutos.
echo  Precisa de internet. Nao feche esta janela ate aparecer "API NO AR".
echo.

if not exist ".env" (
  echo ERRO: falta o arquivo .env. Rode antes o 1-PREPARAR.bat
  echo.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo ERRO: o Docker nao esta ligado. Abra o Docker Desktop, espere ficar verde e tente de novo.
  echo.
  pause
  exit /b 1
)

docker compose up -d --build
if errorlevel 1 (
  echo.
  echo ERRO ao ligar o servidor. Leia a mensagem acima.
  echo Causa comum: porta ocupada ^(1433, 5080 ou 8080^). Feche o programa que usa a porta e tente de novo.
  echo.
  pause
  exit /b 1
)

echo.
echo Esperando a API responder ^(pode levar ate 5 minutos na primeira vez^)...
powershell -NoProfile -Command "$ok=$false; 1..100 | ForEach-Object { try { if((Invoke-WebRequest -UseBasicParsing http://localhost:5080/health -TimeoutSec 3).StatusCode -eq 200){ $ok=$true; break } } catch {}; Start-Sleep -Seconds 3 }; if($ok){ exit 0 } else { exit 1 }"
if errorlevel 1 (
  echo.
  echo A API nao respondeu a tempo. Veja o que aconteceu com:  docker compose logs api
  echo.
  pause
  exit /b 1
)

echo.
echo ==============================================================
echo  API NO AR
echo    API do site ........ http://localhost:5080
echo    Documentacao ....... http://localhost:5080/swagger
echo  Agora rode o 3-ABRIR-SITE.bat
echo ==============================================================
echo.
pause
