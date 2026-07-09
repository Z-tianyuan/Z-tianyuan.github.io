@echo off
chcp 65001 >nul
set PYTHON=C:\Users\14940\AppData\Local\Python\bin\python.exe

cd /d D:\NucleiAI

echo ============================================
echo   NucleiAI - Vuln Management Platform
echo ============================================
echo.
echo [1/2] Starting vuln target on port 9999 (background)...
start "NucleiAI-Target" /min cmd /c "cd /d D:\NucleiAI\test-target && %PYTHON% vuln_server.py 9999"

echo [2/2] Starting web dashboard on port 8000...
timeout /t 2 /nobreak >nul
start http://127.0.0.1:8000
%PYTHON% -m uvicorn web.app:app --host 127.0.0.1 --port 8000
pause
