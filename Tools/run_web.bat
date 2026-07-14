@echo off
setlocal
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 "%~dp0run_web.py" %*
) else (
    python "%~dp0run_web.py" %*
)
exit /b %errorlevel%
