@echo off
chcp 65001 >nul
title 4 - DESLIGAR TUDO
cd /d "%~dp0.."

echo.
echo ==============================================================
echo  4/4 - DESLIGAR O SERVIDOR
echo ==============================================================
echo  Os dados do banco continuam guardados para a proxima vez.
echo  Se a janela do site ^(3-ABRIR-SITE^) estiver aberta, feche-a.
echo.

docker compose down
echo.
echo Servidor desligado.
echo.
echo Para apagar TAMBEM os dados do banco e recomecar do zero, rode:
echo     docker compose down -v
echo.
pause
