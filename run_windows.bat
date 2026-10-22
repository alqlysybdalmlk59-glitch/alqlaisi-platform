@echo off
chcp 65001 > nul
title منصة القليسي - تطبيق Windows
echo ===================================================
echo [منصة القليسي] جاري تشغيل تطبيق Flutter على واندوز
echo ===================================================
echo.

cd /d "%~dp0"

echo جاري بناء وتشغيل التطبيق على منصة Windows Desktop...
flutter run -d windows

pause
