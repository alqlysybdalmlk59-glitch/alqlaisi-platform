@echo off
setlocal EnableExtensions
chcp 65001 > nul
title منصة القليسي - تشغيل النظام المحلي
cd /d "%~dp0"

echo ===================================================
echo [منصة القليسي] تشغيل الخادم وتطبيق Windows
echo ===================================================
echo.
echo [1/3] تشغيل خادم FastAPI في نافذة مستقلة...
start "Alqulaisi FastAPI Backend" cmd /k "run_backend.bat"

echo.
echo [2/3] انتظار جاهزية الخادم بدلاً من الانتظار لثوانٍ ثابتة...
set /a attempts=0
:wait_for_backend
powershell -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8000/health' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto :backend_ready
set /a attempts+=1
if %attempts% GEQ 120 goto :backend_timeout
timeout /t 2 /nobreak >nul
goto :wait_for_backend

:backend_ready
echo [نجاح] الخادم جاهز ويستجيب على /health.
echo.
echo [3/3] تشغيل تطبيق Flutter Desktop على Windows...
start "Alqulaisi Flutter Windows App" cmd /k "run_windows.bat"
echo.
echo تم بدء الخادم وتطبيق Windows.
goto :end

:backend_timeout
echo.
echo [خطأ] لم يستجب الخادم خلال المهلة. راجع نافذة خادم FastAPI؛ قد يكون تثبيت المكتبات فشل.
echo لم يتم تشغيل التطبيق تلقائياً لتجنب ظهور خطأ اتصال مضلل.
pause
exit /b 1

:end
pause
