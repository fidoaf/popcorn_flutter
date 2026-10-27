param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$output = Join-Path $root 'build\installer'
$staleLocalServer = Join-Path $root 'build\windows\x64\runner\Release\local_server'
if (Test-Path $staleLocalServer) { Remove-Item $staleLocalServer -Recurse -Force }

Push-Location $root
try {
    $version = ((Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Matches[0].Groups[1].Value)
    if (!$version) { throw 'Could not read the version from pubspec.yaml.' }

    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $arguments = @('run', 'msix:create', '--version', "$version.0", '--output-path', $output,
        '--output-name', "Popcorn-$version-Windows-x64", '--install-certificate', 'false')
    if ($SkipBuild) { $arguments += '--build-windows', 'false' }
    & dart.bat @arguments
    if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }

    $certPfx = Get-ChildItem "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\msix-*\lib\assets\test_certificate.pfx" |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($certPfx) {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPfx.FullName, '1234')
        Export-Certificate -Cert $cert -FilePath (Join-Path $output 'Popcorn-test-certificate.cer') | Out-Null
    }
    Write-Host "MSIX written to $output\Popcorn-$version-Windows-x64.msix"
} finally {
    Pop-Location
}
