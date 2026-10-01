@echo off
setlocal

if "%~1"=="" (
    echo Usage: TypeVault-Setup.cmd PROFILE
    exit /b 2
)

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell 7 ^(pwsh.exe^) was not found.
    echo Install PowerShell 7 and run this file again.
    exit /b 1
)

pwsh.exe -NoProfile -File "%~dp0TypeVault.ps1" -Action Setup -Profile "%~1"
exit /b %errorlevel%
