@echo off
setlocal
cd /d "%~dp0"
echo Starting Al Qulaisi admin dashboard on http://localhost:5500/index.html
where py >nul 2>&1
if not errorlevel 1 (
  start "Al Qulaisi Dashboard Server" /D "%~dp0" cmd /k py -3 -m http.server 5500 --directory admin_dashboard
) else (
  where python >nul 2>&1
  if errorlevel 1 (
    echo Python was not found. Install Python 3.12 and add it to PATH.
    pause
    exit /b 1
  )
  start "Al Qulaisi Dashboard Server" /D "%~dp0" cmd /k python -m http.server 5500 --directory admin_dashboard
)
timeout /t 2 /nobreak >nul
start "" "http://localhost:5500/index.html"
echo The server window must remain open while you use the dashboard.
endlocal
