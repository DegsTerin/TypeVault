@echo off
setlocal EnableExtensions

pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo Unable to access the TypeVault folder.
    pause
    exit /b 1
)

where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo PowerShell 7 ^(pwsh.exe^) was not found.
    echo Install PowerShell 7 and run TypeVault again.
    pause
    popd
    exit /b 1
)

pwsh.exe -NoProfile -File "%~dp0TypeVault.ps1" -Action Menu
set "EXIT_CODE=%ERRORLEVEL%"

popd
exit /b %EXIT_CODE%
