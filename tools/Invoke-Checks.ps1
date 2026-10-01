#requires -Version 7.2
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectRoot 'TypeVault.ps1'
$testPath = Join-Path $projectRoot 'Tests'
$launcherPath = Join-Path $projectRoot 'TypeVault.py'

Write-Host 'TypeVault verification' -ForegroundColor Cyan
Write-Host ('=' * 62) -ForegroundColor DarkGray

# PowerShell parser validation without executing the application.
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    foreach ($errorRecord in $errors) {
        Write-Host "PowerShell parse error: $($errorRecord.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PowerShell syntax: PASS' -ForegroundColor Green

if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
    Invoke-ScriptAnalyzer -Path $scriptPath -Severity Error
    Write-Host 'PSScriptAnalyzer errors: PASS' -ForegroundColor Green
}
else {
    Write-Host 'PSScriptAnalyzer: SKIPPED (not installed)' -ForegroundColor Yellow
}

if (Get-Command Invoke-Pester -ErrorAction SilentlyContinue) {
    $result = Invoke-Pester -Path $testPath -PassThru
    if ($result.FailedCount -ne 0) {
        Write-Host "Pester: FAIL ($($result.FailedCount) failed)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Pester: PASS ($($result.PassedCount) passed)" -ForegroundColor Green
}
else {
    Write-Host 'Pester: SKIPPED (not installed)' -ForegroundColor Yellow
}

if (Get-Command python.exe -ErrorAction SilentlyContinue) {
    $pythonCheck = @'
import ast
from pathlib import Path
path = Path(r"$launcherPath")
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
print("Python launcher syntax: PASS")
'@
    $pythonCheck = $pythonCheck.Replace('$launcherPath', $launcherPath.Replace('"','""'))
    python.exe -c $pythonCheck
}
else {
    Write-Host 'Python launcher syntax: SKIPPED (python.exe not found)' -ForegroundColor Yellow
}

$forbiddenRuntimeFiles = @(
    Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.pyc', '.pyo') -or $_.Name -eq 'Settings.json' -or $_.Extension -eq '.tmp' }
)
if ($forbiddenRuntimeFiles.Count -gt 0) {
    $forbiddenRuntimeFiles | ForEach-Object { Write-Host "Unexpected runtime file: $($_.FullName)" -ForegroundColor Red }
    exit 1
}
Write-Host 'Source-tree runtime-file check: PASS' -ForegroundColor Green
Write-Host 'Release checks completed.' -ForegroundColor Cyan
