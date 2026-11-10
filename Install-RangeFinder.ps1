[CmdletBinding()]
param(
    [string]$AddOnsPath = 'D:\World of Warcraft\_forever_\Interface\AddOns'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
        throw "WoW AddOns directory was not found: $AddOnsPath"
    }

    $destination = Join-Path $AddOnsPath 'RangeFinder'
    if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
        New-Item -ItemType Directory -Path $destination | Out-Null
    }

    foreach ($file in 'RangeFinder.toc', 'Range.lua', 'Display.lua', 'Options.lua', 'Core.lua', 'Bootstrap.lua') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $destination $file) -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Libs') -Destination $destination -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSES') -Destination $destination -Recurse -Force

    $libraryPath = Join-Path $destination 'Libs\LibRangeCheck-3.0\LibRangeCheck-3.0.lua'
    $releaseLines = [System.Collections.Generic.List[string]]::new()
    $developmentBlock = $false
    foreach ($line in Get-Content -LiteralPath $libraryPath) {
        if ($line.Trim() -eq '--@do-not-package@') {
            if ($developmentBlock) {
                throw 'Nested development block in LibRangeCheck.'
            }
            $developmentBlock = $true
        }
        elseif ($line.Trim() -eq '--@end-do-not-package@') {
            if (-not $developmentBlock) {
                throw 'Unmatched development block end in LibRangeCheck.'
            }
            $developmentBlock = $false
        }
        elseif (-not $developmentBlock) {
            $releaseLines.Add($line)
        }
    }
    if ($developmentBlock) {
        throw 'Unclosed development block in LibRangeCheck.'
    }
    [System.IO.File]::WriteAllLines($libraryPath, $releaseLines, [System.Text.UTF8Encoding]::new($false))

    $obsoleteModule = Join-Path $destination 'EditMode.lua'
    if (Test-Path -LiteralPath $obsoleteModule -PathType Leaf) {
        Remove-Item -LiteralPath $obsoleteModule
    }

    Write-Host "Installed RangeFinder to $destination"
    Write-Host 'Enable RangeFinder at character select, then log in to test the display and Options > AddOns > RangeFinder font-size slider.'
}
catch {
    Write-Error "RangeFinder installation failed. $($_.Exception.Message)"
    exit 1
}
