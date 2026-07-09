@echo off
chcp 65001 >nul
set PYTHON=C:\Users\14940\AppData\Local\Python\bin\python.exe

cd /d E:\py\流量分析

echo ============================================
echo   Traffic Analysis - AI Network Monitor
echo ============================================
echo.
echo Starting Streamlit app on port 8501...
%PYTHON% -m streamlit run 流量分析.py --server.port 8501
pause
