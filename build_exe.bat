@echo off
setlocal
cd /d "%~dp0"
echo ========================================================
echo   Ember - Standalone Windows Release Builder
echo ========================================================
echo.

where py >nul 2>nul
if %errorlevel%==0 (
    set "PY=py -3"
) else (
    set "PY=python"
)

echo [1/3] Generating icon asset...
%PY% -c "from PyQt6.QtWidgets import QApplication; import sys; app = QApplication(sys.argv); from ember.tray import write_icon; write_icon('ember.ico', 256)"

echo [2/3] Compiling standalone Ember.exe with PyInstaller...
%PY% -m PyInstaller ember.spec --clean --noconfirm

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed! Check the output above.
    pause
    exit /b 1
)

echo.
echo [3/3] Success! Standalone executable is ready at:
echo       dist\Ember.exe
echo ========================================================
echo.
pause
endlocal
