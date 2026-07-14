@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3 serve_web.py --directory . --open-browser
) else (
    python serve_web.py --directory . --open-browser
)

exit /b %errorlevel%
