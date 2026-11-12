@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem MDM Unified NATIVE Manager b1r3. Script derives its own location.
rem Do not pass %%~dp0 as a PowerShell argument (trailing-backslash issue).
set "SCRIPT=%~dp0Manager.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Manager.ps1 is missing beside Mister-Manager.cmd.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Action Menu
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo Manager returned an error ^(exit code %RC%^).
echo.
pause
exit /b %RC%
