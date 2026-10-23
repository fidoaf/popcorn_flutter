param(
    [Parameter(Mandatory)]
    [string[]]$AssetPaths
)

$ErrorActionPreference = 'Stop'

if (!$env:GH_TOKEN) { throw 'GH_TOKEN is required to publish GitHub Release assets.' }
if (!$env:GH_REPO) { throw 'GH_REPO must be set to owner/repository.' }
if (!$env:GITHUB_SHA) { throw 'GITHUB_SHA must be set to the workflow commit.' }

$versionMatch = Select-String -Path (Join-Path $PSScriptRoot '..\pubspec.yaml') -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' |
    Select-Object -First 1
if (!$versionMatch) { throw 'Could not read the app version from pubspec.yaml.' }
$version = $versionMatch.Matches[0].Groups[1].Value
$tag = "v$version"
$headers = @{
    Authorization = "Bearer $env:GH_TOKEN"
    Accept        = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$releaseUri = "https://api.github.com/repos/$env:GH_REPO/releases/tags/$tag"

function Get-VersionRelease {
    try {
        Invoke-RestMethod -Uri $releaseUri -Headers $headers -Method Get
    }
    catch {
        if ([int]$_.Exception.Response.StatusCode -eq 404) { return $null }
        throw
    }
}

$release = Get-VersionRelease
if (!$release) {
    $body = @{
        tag_name         = $tag
        target_commitish = $env:GITHUB_SHA
        name             = "Popcorn $version"
        body             = "Windows installers for Popcorn $version. The Inno Setup installer is unsigned and requires manual updates. The MSIX uses a development signing certificate. Its App Installer feed remains available on GitHub Pages."
        draft            = $false
        prerelease       = $false
        make_latest      = 'true'
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$env:GH_REPO/releases" -Headers $headers -Method Post -Body $body -ContentType 'application/json' | Out-Null
    }
    catch {
        $release = Get-VersionRelease
        if (!$release) { throw }
    }
}

$resolvedAssets = @($AssetPaths | ForEach-Object {
    $path = [IO.Path]::GetFullPath($_)
    if (!(Test-Path $path -PathType Leaf)) { throw "Release asset not found: $path" }
    $path
})
if (!$resolvedAssets.Count) { throw 'At least one release asset is required.' }

& gh release upload $tag @resolvedAssets --clobber --repo $env:GH_REPO
if ($LASTEXITCODE -ne 0) { throw "Uploading assets to GitHub Release $tag failed." }
Write-Host "Published assets to https://github.com/$env:GH_REPO/releases/tag/$tag"
