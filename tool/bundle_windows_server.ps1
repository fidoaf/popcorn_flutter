param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\windows-server')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
if ((Test-Path $output) -and (Get-ChildItem $output -Force | Select-Object -First 1)) {
    throw "Bundle output already exists: $output. Choose an empty output directory or remove the previous bundle explicitly."
}
New-Item -ItemType Directory -Path $output -Force | Out-Null

$node = (Get-Command node.exe -ErrorAction Stop).Source
if ((& $node -p process.platform) -ne 'win32' -or (& $node -p process.arch) -ne 'x64') {
    throw 'The Windows server bundle requires Windows x64 Node.js.'
}
$version = & $node -p 'process.version'
$archiveName = "node-$version-win-x64.zip"
$archive = Join-Path $output $archiveName
$checksums = (Invoke-WebRequest "https://nodejs.org/dist/$version/SHASUMS256.txt" -UseBasicParsing).Content
Invoke-WebRequest "https://nodejs.org/dist/$version/$archiveName" -OutFile $archive -UseBasicParsing
$expected = ($checksums -split "`n" | Where-Object { $_.Trim().EndsWith("  $archiveName") }) -split '\s+'
if (!$expected -or (Get-FileHash $archive -Algorithm SHA256).Hash -ne $expected[0]) {
    throw 'Official Node.js archive checksum verification failed.'
}
Expand-Archive $archive -DestinationPath $output
$distribution = Join-Path $output "node-$version-win-x64"
Copy-Item (Join-Path $distribution 'node.exe') (Join-Path $output 'node.exe')
Copy-Item (Join-Path $distribution 'LICENSE') (Join-Path $output 'NODE-LICENSE')
Remove-Item $archive
Remove-Item $distribution -Recurse

$server = Join-Path $output 'server'
New-Item -ItemType Directory -Path $server | Out-Null
foreach ($name in @('server.js', 'package.json', 'package-lock.json', 'src', 'config', 'public')) {
    $source = Join-Path $root "server\$name"
    if (Test-Path $source) { Copy-Item $source (Join-Path $server $name) -Recurse }
}

$previousSkip = $env:PUPPETEER_SKIP_DOWNLOAD
$previousCache = $env:PUPPETEER_CACHE_DIR
try {
    $env:PUPPETEER_SKIP_DOWNLOAD = 'true'
    & npm.cmd ci --omit=dev --prefix $server
    if ($LASTEXITCODE -ne 0) { throw 'Installing bundled server dependencies failed.' }
    $env:PUPPETEER_CACHE_DIR = Join-Path $output 'browser'
    $env:PUPPETEER_SKIP_DOWNLOAD = 'false'
    & node (Join-Path $server 'node_modules\puppeteer\lib\cjs\puppeteer\node\cli.js') browsers install chrome
    if ($LASTEXITCODE -ne 0) { throw 'Installing bundled Chromium failed.' }
    $chrome = & node -e 'console.log(require(process.argv[1]).executablePath())' (Join-Path $server 'node_modules\puppeteer')
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $chrome)) { throw 'Bundled Chromium executable was not found.' }
    [IO.File]::WriteAllText((Join-Path $output 'chrome-path.txt'), $chrome.Substring($output.Length + 1))
} finally {
    $env:PUPPETEER_SKIP_DOWNLOAD = $previousSkip
    $env:PUPPETEER_CACHE_DIR = $previousCache
}
Write-Host "Windows server bundle ready: $output"
