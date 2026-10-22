@echo off
chcp 65001 > nul
title منصة القليسي - خادم FastAPI Backend
echo ===================================================
echo [منصة القليسي] جاري تشغيل خادم Python FastAPI Backend
echo ===================================================
echo.

cd /d "%~dp0"

echo [1/2] التثبيت المباشر للمكتبات المطلوبة...
python -m pip install -r backend/requirements.txt

echo.
echo [2/2] تشغيل الخادم على http://127.0.0.1:8000 ...
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000

pause
