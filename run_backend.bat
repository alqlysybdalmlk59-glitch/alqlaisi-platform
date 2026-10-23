@echo off
setlocal
chcp 65001 > nul
title منصة القليسي - خادم FastAPI Backend
cd /d "%~dp0"

echo ===================================================
echo [منصة القليسي] إعداد وتشغيل خادم FastAPI
echo ===================================================
echo.

if not exist ".venv\Scripts\python.exe" (
    echo [1/4] إنشاء بيئة Python مستقلة...
    py -3.12 -m venv .venv >nul 2>&1
)
if not exist ".venv\Scripts\python.exe" (
    py -3 -m venv .venv >nul 2>&1
)
if not exist ".venv\Scripts\python.exe" (
    python -m venv .venv
)
if not exist ".venv\Scripts\python.exe" (
    echo [خطأ] لم يتم العثور على Python. ثبّت Python 3.12 مع تفعيل خيار Add Python to PATH ثم أعد المحاولة.
    pause
    exit /b 1
)

set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"

echo [2/4] تثبيت مكتبات الخادم من backend\requirements.txt...
"%PYTHON_EXE%" -m pip install --disable-pip-version-check -r backend\requirements.txt
if errorlevel 1 goto :install_failed

echo.
echo [3/4] إعداد .env محلي آمن عند أول تشغيل...
"%PYTHON_EXE%" -m backend.setup_dev
if errorlevel 1 goto :setup_failed

echo.
echo [4/4] تشغيل FastAPI على http://127.0.0.1:8000 ...
echo فحص الصحة: http://127.0.0.1:8000/health
echo توثيق API للتطوير: http://127.0.0.1:8000/docs
echo لإيقاف الخادم اضغط Ctrl+C.
echo.

"%PYTHON_EXE%" -m uvicorn backend.app.main:app --reload --host 127.0.0.1 --port 8000
goto :end

:install_failed
echo.
echo [خطأ] فشل تثبيت مكتبات Python. اقرأ رسالة pip أعلاه وتحقق من الاتصال بالإنترنت.
pause
exit /b 1

:setup_failed
echo.
echo [خطأ] تعذر إعداد .env. راجع الرسالة أعلاه ولا تشارك ملف .env أو أسراره.
pause
exit /b 1

:end
pause
