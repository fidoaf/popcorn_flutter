param(
    [Parameter(Mandatory)]
    [string]$InstallDirectory
)

$ErrorActionPreference = 'Stop'
$nodePath = [IO.Path]::GetFullPath((Join-Path $InstallDirectory 'local_server\node.exe'))
$serverPath = [IO.Path]::GetFullPath((Join-Path $InstallDirectory 'local_server\server\server.js'))

if (!(Test-Path $nodePath) -or !(Test-Path $serverPath)) {
    exit 0
}

$serverProcesses = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'node.exe'" |
    Where-Object {
        $_.ExecutablePath -and
        $_.ExecutablePath.Equals($nodePath, [StringComparison]::OrdinalIgnoreCase) -and
        $_.CommandLine -and
        $_.CommandLine.IndexOf($serverPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
    })

foreach ($serverProcess in $serverProcesses) {
    & "$env:SystemRoot\System32\taskkill.exe" /PID $serverProcess.ProcessId /T /F | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $stillRunning = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($serverProcess.ProcessId)" -ErrorAction SilentlyContinue
        if ($stillRunning) {
            throw "Could not stop the bundled player server process $($serverProcess.ProcessId). Close Popcorn and retry."
        }
    }
}

$deadline = [DateTime]::UtcNow.AddSeconds(10)
do {
    $remaining = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'node.exe'" |
        Where-Object {
            $_.ExecutablePath -and
            $_.ExecutablePath.Equals($nodePath, [StringComparison]::OrdinalIgnoreCase) -and
            $_.CommandLine -and
            $_.CommandLine.IndexOf($serverPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    if (!$remaining.Count) {
        exit 0
    }
    Start-Sleep -Milliseconds 200
} while ([DateTime]::UtcNow -lt $deadline)

throw 'The bundled player server is still running. Close Popcorn and retry.'
