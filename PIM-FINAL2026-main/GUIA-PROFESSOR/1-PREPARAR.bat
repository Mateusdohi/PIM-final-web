@echo off
chcp 65001 >nul
title 1 - PREPARAR (conferir Docker, portas e arquivo .env)
cd /d "%~dp0.."

echo.
echo ==============================================================
echo  1/4 - PREPARAR
echo ==============================================================
echo.

if not exist "docker-compose.yml" (
  echo ERRO: este arquivo precisa ficar na pasta GUIA-PROFESSOR, dentro da pasta do projeto, onde esta o docker-compose.yml.
  echo Pasta atual: %cd%
  echo.
  pause
  exit /b 1
)

echo [1/3] Conferindo se o Docker esta instalado e ligado...
docker info >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERRO: o Docker nao esta ligado ou nao esta instalado.
  echo   - Instalado? Baixe o Docker Desktop em https://www.docker.com/products/docker-desktop
  echo   - Instalado? Abra o Docker Desktop e espere ficar verde ^("Engine running"^).
  echo Depois rode este arquivo de novo.
  echo.
  pause
  exit /b 1
)
echo       Docker OK.

echo.
echo [2/3] Conferindo o arquivo .env ^(senhas e chaves do sistema^)...
if exist ".env" (
  echo       Ja existe um .env. Vou usar o que esta nele.
) else (
  copy /y ".env.example" ".env" >nul
  echo       Criei o .env a partir do .env.example.
  echo       Os valores de exemplo servem para a demonstracao no seu computador.
)

echo.
echo [3/3] Conferindo se as portas estao livres...
powershell -NoProfile -Command "$ocupadas=@(); foreach($p in 1433,5080,8080,5500){ if(Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue){ $ocupadas += $p } }; if($ocupadas.Count -gt 0){ Write-Host ('       AVISO: portas em uso: ' + ($ocupadas -join ', ')); Write-Host '       Se for de outro programa que voce nao precisa, feche-o antes do passo 2.' } else { Write-Host '       Portas 1433, 5080, 8080 e 5500 livres.' }"

echo.
echo ==============================================================
echo  Pronto. Agora rode o 2-LIGAR-SERVIDOR.bat
echo ==============================================================
echo.
pause
