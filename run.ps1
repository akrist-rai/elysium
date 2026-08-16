# Debug build and run on Windows.
#
#   powershell -ExecutionPolicy Bypass -File run.ps1
#   powershell -ExecutionPolicy Bypass -File run.ps1 --test
#
# `-linker:radlink` uses the linker Odin ships with, so Visual Studio Build
# Tools are not required. Drop the flag to use the system linker instead.

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

& $odin build "$Root\src" -out:"$Root\build\hacktheplot.exe" -debug -linker:radlink
if ($LASTEXITCODE -ne 0) { throw "build failed" }

& "$Root\build\hacktheplot.exe" @args
exit $LASTEXITCODE
