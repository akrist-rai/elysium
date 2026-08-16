# Installs the Odin compiler on Windows.
# Idempotent: safe to re-run.
#
#   powershell -ExecutionPolicy Bypass -File tools\setup_odin.ps1
#
# Unlike the Linux path there is no clang shim to arrange: Odin ships the
# `radlink` linker, which run.ps1 and build.ps1 both pass explicitly so that a
# full Visual Studio install is not required.

$ErrorActionPreference = "Stop"

$OdinVersion = if ($env:ODIN_VERSION) { $env:ODIN_VERSION } else { "dev-2026-08" }
$OdinHome    = if ($env:ODIN_HOME)    { $env:ODIN_HOME }    else { "$env:LOCALAPPDATA\odin" }
$Zip         = "odin-windows-amd64-$OdinVersion.zip"
$Url         = "https://github.com/odin-lang/Odin/releases/download/$OdinVersion/$Zip"

if (Test-Path "$OdinHome\odin.exe") {
    Write-Host "odin: already installed at $OdinHome"
} else {
    Write-Host "odin: fetching $OdinVersion"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $archive = Join-Path $tmp $Zip
        Invoke-WebRequest -Uri $Url -OutFile $archive
        Expand-Archive -Path $archive -DestinationPath $tmp -Force

        # The release zip may or may not wrap everything in a folder.
        $exe = Get-ChildItem -Path $tmp -Filter odin.exe -Recurse | Select-Object -First 1
        if (-not $exe) { throw "could not locate odin.exe inside $Zip" }

        New-Item -ItemType Directory -Path $OdinHome -Force | Out-Null
        Copy-Item -Path (Join-Path $exe.DirectoryName '*') -Destination $OdinHome -Recurse -Force
        Write-Host "odin: installed to $OdinHome"
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# raylib is vendored by the Odin distribution; nothing to install separately.
# On Windows the bindings link windows\raylib.lib statically, so there is no
# DLL to place next to the executable.
if (Test-Path "$OdinHome\vendor\raylib\windows\raylib.lib") {
    Write-Host "raylib: vendored static library present"
} else {
    Write-Warning "raylib: $OdinHome\vendor\raylib\windows\raylib.lib is missing"
}

# Fonts ship in assets\fonts, so there is no font copying step on Windows.
$fonts = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\fonts\body.ttf"
if (Test-Path $fonts) {
    Write-Host "assets: fonts present"
} else {
    Write-Warning "assets: assets\fonts\body.ttf missing - the game will fall back to raylib's builtin font"
}

Write-Host ""
Write-Host "Add this to your PATH if it is not already there:"
Write-Host "    $OdinHome"
Write-Host ""
& "$OdinHome\odin.exe" version
