param(
    [string]$CompilerPath,
    [string]$VcRuntimeDirectory,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$release = Join-Path $root 'build\windows\x64\runner\Release'

if (!$CompilerPath) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compiler) { $CompilerPath = $compiler.Source }
    foreach ($directory in @(
        "${env:ProgramFiles(x86)}\Inno Setup 6",
        "$env:ProgramFiles\Inno Setup 6",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6"
    )) {
        if (!$CompilerPath -and (Test-Path "$directory\ISCC.exe")) { $CompilerPath = "$directory\ISCC.exe" }
    }
}
if (!$CompilerPath -or !(Test-Path $CompilerPath)) {
    throw 'Install Inno Setup 6, or pass -CompilerPath with the path to ISCC.exe.'
}

if (!$VcRuntimeDirectory) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($visualStudio) {
            $redist = Join-Path $visualStudio 'VC\Redist\MSVC'
            $VcRuntimeDirectory = Get-ChildItem $redist -Directory |
                Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
                Sort-Object { [version]$_.Name } -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        }
    }
}
if (!$VcRuntimeDirectory -or !(Test-Path (Join-Path $VcRuntimeDirectory 'msvcp140.dll'))) {
    throw 'Pass -VcRuntimeDirectory pointing to the Visual Studio x64 Microsoft.VC143.CRT redistributable directory.'
}

Push-Location $root
try {
    if (!$SkipBuild) {
        if (!(Test-Path 'build\windows-server\chrome-path.txt')) {
            throw 'Prepare the local server first with .\tool\bundle_windows_server.ps1.'
        }
        & flutter.bat build windows --release --target lib\main_windows.dart
        if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }
    }
    foreach ($file in @('popcorn_flutter.exe', 'local_server\node.exe', 'local_server\server\server.js', 'local_server\chrome-path.txt')) {
        if (!(Test-Path (Join-Path $release $file))) { throw "Release bundle is missing $file." }
    }
    $chrome = (Get-Content (Join-Path $release 'local_server\chrome-path.txt') -Raw).Trim()
    if (!(Test-Path (Join-Path $release "local_server\$chrome"))) { throw 'Release bundle is missing Chromium.' }
    & $CompilerPath /Qp "/DReleaseDir=$release" "/DVcRuntimeDir=$VcRuntimeDirectory" (Join-Path $PSScriptRoot 'windows_installer.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
} finally {
    Pop-Location
}
