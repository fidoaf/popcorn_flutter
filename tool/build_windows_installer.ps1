param(
    [string]$CompilerPath,
    [string]$VcRuntimeDirectory,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$release = Join-Path $root 'build\windows\x64\runner\Release'
$staleLocalServer = Join-Path $release 'local_server'
if (Test-Path $staleLocalServer) { Remove-Item $staleLocalServer -Recurse -Force }

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
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if (!$SkipBuild) {
        Write-Host 'Building the Windows release application...'
        & flutter.bat build windows --release --target lib\main_windows.dart
        if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }
        Write-Host "Windows release build finished in $([math]::Round($timer.Elapsed.TotalSeconds)) seconds."
    }
    if (!(Test-Path (Join-Path $release 'popcorn_flutter.exe'))) { throw 'Release bundle is missing popcorn_flutter.exe.' }
    Write-Host 'Inno Setup is compressing the release files.'
    $iss = Join-Path $PSScriptRoot 'windows_installer.iss'
    $arguments = '/Qp "/DReleaseDir={0}" "/DVcRuntimeDir={1}" "{2}"' -f $release, $VcRuntimeDirectory, $iss
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $CompilerPath
    $startInfo.Arguments = $arguments
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (!$process.Start()) { throw 'Could not start the Inno Setup compiler.' }
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        while (!$process.WaitForExit(30000)) {
            Write-Host "Inno Setup is still compiling ($([math]::Round($timer.Elapsed.TotalSeconds)) seconds elapsed)."
        }
        $process.WaitForExit()
        $compilerOutputText = $outputTask.GetAwaiter().GetResult()
        $compilerErrorText = $errorTask.GetAwaiter().GetResult()
        if ($compilerOutputText) { Write-Host $compilerOutputText.TrimEnd() }
        if ($compilerErrorText) { Write-Error $compilerErrorText.TrimEnd() -ErrorAction Continue }
        if ($process.ExitCode -ne 0) { throw "Inno Setup compilation failed with exit code $($process.ExitCode)." }
        Write-Host "Installer compiled in $([math]::Round($timer.Elapsed.TotalSeconds)) seconds."
    } finally {
        $process.Dispose()
    }
} finally {
    Pop-Location
}
