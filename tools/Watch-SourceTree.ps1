#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot),
    [ValidateRange(250, 10000)]
    [int]$IntervalMilliseconds = 1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
Write-Host "Watching source-tree timestamps under: $resolvedPath" -ForegroundColor Cyan
Write-Host 'This tool only reads metadata. Press Ctrl+C to stop.' -ForegroundColor DarkGray
Write-Host

function Get-Snapshot {
    Get-ChildItem -LiteralPath $resolvedPath -Recurse -File -Force |
        ForEach-Object {
            [PSCustomObject]@{
                FullName = $_.FullName
                LastWriteTimeUtc = $_.LastWriteTimeUtc
                Length = $_.Length
            }
        }
}

$previous = @{}
Get-Snapshot | ForEach-Object { $previous[$_.FullName] = $_ }

while ($true) {
    Start-Sleep -Milliseconds $IntervalMilliseconds
    $current = @{}
    Get-Snapshot | ForEach-Object { $current[$_.FullName] = $_ }

    foreach ($pathKey in @($current.Keys)) {
        if ($previous.ContainsKey($pathKey)) {
            $before = $previous[$pathKey]
            $after = $current[$pathKey]
            if ($before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc -or $before.Length -ne $after.Length) {
                Write-Host ("CHANGED  {0}" -f $pathKey) -ForegroundColor Yellow
                Write-Host ("         Time: {0} -> {1} | Length: {2} -> {3}" -f $before.LastWriteTimeUtc.ToString('o'), $after.LastWriteTimeUtc.ToString('o'), $before.Length, $after.Length) -ForegroundColor DarkYellow
            }
        }
        else {
            Write-Host ("CREATED  {0}" -f $pathKey) -ForegroundColor Yellow
        }
    }

    foreach ($pathKey in @($previous.Keys)) {
        if (-not $current.ContainsKey($pathKey)) {
            Write-Host ("REMOVED  {0}" -f $pathKey) -ForegroundColor Red
        }
    }

    $previous = $current
}
