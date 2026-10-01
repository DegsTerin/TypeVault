@echo off
setlocal

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell 7 ^(pwsh.exe^) was not found.
    exit /b 1
)

if "%~1"=="" (
    pwsh.exe -NoProfile -File "%~dp0TypeVault.ps1" -Action Menu
) else (
    pwsh.exe -NoProfile -File "%~dp0TypeVault.ps1" -Action Type -Profile "%~1"
)
exit /b %errorlevel%
