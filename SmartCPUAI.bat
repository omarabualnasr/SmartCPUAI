@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "ENGINE=%~dp0SmartCPUAI.ps1"
if not exist "%ENGINE%" (
  echo ERROR: SmartCPUAI.ps1 is missing.
  echo Keep SmartCPUAI.bat and SmartCPUAI.ps1 in the same folder.
  pause
  exit /b 2
)
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found. This script requires Windows PowerShell 5.1 or newer.
  pause
  exit /b 3
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo Smart CPU AI exited with code %RC%. See the log folder under %%LOCALAPPDATA%%\SmartCPUAI\logs.
  pause
)
exit /b %RC%
