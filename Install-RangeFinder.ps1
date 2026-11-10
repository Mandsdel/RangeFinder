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

    foreach ($file in 'RangeFinder.toc', 'Range.lua', 'Display.lua', 'EditMode.lua', 'Options.lua', 'Core.lua', 'Bootstrap.lua') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $destination $file) -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Libs') -Destination $destination -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LICENSES') -Destination $destination -Recurse -Force

    Write-Host "Installed RangeFinder to $destination"
    Write-Host 'Enable RangeFinder at character select, then log in to test the display and Options > AddOns > RangeFinder font-size slider.'
}
catch {
    Write-Error "RangeFinder installation failed. $($_.Exception.Message)"
    exit 1
}
