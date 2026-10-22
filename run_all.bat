@echo off
chcp 65001 > nul
title منصة القليسي - تشغيل النظام بالكامل على واندوز
echo ===================================================
echo [منصة القليسي] تشغيل خادم Backend وتطبيق Windows
echo ===================================================
echo.

cd /d "%~dp0"

echo [1] تشغيل خادم FastAPI في نافذة جديدة...
start "Alqulaisi FastAPI Backend" cmd /k "run_backend.bat"

echo.
echo [2] الانتظار 3 ثوانٍ لاكتمال تشغيل الخادم...
timeout /t 3 /nobreak > nul

echo.
echo [3] تشغيل تطبيق Flutter Desktop على Windows...
start "Alqulaisi Flutter Windows App" cmd /k "run_windows.bat"

echo.
echo تم إطلاق خادم الخلفية وتطبيق الويندوز بنجاح!
