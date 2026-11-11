@echo off
setlocal
rem Explicitly pass the script folder, not the current working directory.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manager.ps1" -Action Menu -AppRoot "%~dp0."
if errorlevel 1 echo Native manager returned an error.
echo.
pause
