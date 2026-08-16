# Optimised build on Windows. Use run.ps1 for the debug build.
#
#   powershell -ExecutionPolicy Bypass -File build.ps1

$ErrorActionPreference = "Stop"

$Root     = $PSScriptRoot
$OdinHome = if ($env:ODIN_HOME) { $env:ODIN_HOME } else { "$env:LOCALAPPDATA\odin" }

$odin = if (Get-Command odin -ErrorAction SilentlyContinue) {
    "odin"
} elseif (Test-Path "$OdinHome\odin.exe") {
    "$OdinHome\odin.exe"
} else {
    throw "odin not found - run tools\setup_odin.ps1 first"
}

New-Item -ItemType Directory -Path "$Root\build" -Force | Out-Null

# -subsystem:windows suppresses the console window for a release build.
& $odin build "$Root\src" -out:"$Root\build\hacktheplot.exe" -o:speed -linker:radlink @args
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host "built $Root\build\hacktheplot.exe"
