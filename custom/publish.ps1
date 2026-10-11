param([Parameter(Mandatory)][string]$SourceCommit,
      [Parameter(Mandatory)][string]$ReleaseTag,
      [Parameter(Mandatory)][string]$UpstreamTag)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$package = Join-Path $PWD 'custom-package'
New-Item -ItemType Directory -Path $package -Force | Out-Null
Copy-Item build/qbittorrent.exe,dist/windows/qt.conf -Destination $package
& "$env:Qt_ROOT_DIR/bin/windeployqt.exe" --release --compiler-runtime --dir $package "$package/qbittorrent.exe"
# Deploy the app-local Microsoft runtime as well, without running an installer.
$crt = Get-ChildItem "$env:VCToolsRedistDir/x64" -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
if (-not $crt) { throw 'MSVC app-local runtime not found' }
Copy-Item "$($crt.FullName)/*.dll" -Destination $package
Copy-Item COPYING,COPYING.GPLv2,COPYING.GPLv3 -Destination $package
$manifest = [ordered]@{
    schemaVersion = 1
    repository = $env:GITHUB_REPOSITORY
    sourceCommit = $SourceCommit
    upstreamTag = $UpstreamTag
    releaseTag = $ReleaseTag
    builtAt = [DateTime]::UtcNow.ToString('o')
    platform = 'windows-x64'
    testsPassed = $true
}
$manifest | ConvertTo-Json | Set-Content "$package/custom-build.json" -Encoding utf8
$env:QT_PLUGIN_PATH = "$package/plugins"
$probe = Start-Process "$package/qbittorrent.exe" -ArgumentList '--custom-build-check' -WindowStyle Hidden -PassThru
if (-not $probe.WaitForExit(15000)) {
    & taskkill.exe /PID $probe.Id /T /F | Out-Null
    throw 'Packaged application check timed out'
}
if ($probe.ExitCode -ne 0) { throw "Packaged application check failed: $($probe.ExitCode)" }
$archive = Join-Path $PWD 'qbittorrent-custom-windows-x64.zip'
Compress-Archive -Path "$package/*" -DestinationPath $archive -Force
$manifest.archive = [IO.Path]::GetFileName($archive)
$manifest.sha256 = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest | ConvertTo-Json | Set-Content custom-update.json -Encoding utf8
# Fast-forward only: if someone edits the branch during the build, publication stops.
git push origin 'HEAD:refs/heads/custom/rss-feed-path'
$existing = @(gh api "repos/$env:GITHUB_REPOSITORY/releases?per_page=100" | ConvertFrom-Json) | Where-Object tag_name -eq $ReleaseTag
if ($existing) {
    if (-not $existing.draft) { throw 'Refusing to modify an already published release' }
} else {
    gh release create $ReleaseTag --draft --repo $env:GITHUB_REPOSITORY --target $SourceCommit --title "qBittorrent $UpstreamTag + RSS folders" --notes "Custom RSS subscription folders. Windows x64 build and tests passed. Source: $SourceCommit. Upstream: $UpstreamTag."
}
# Draft assets can be retried after interrupted uploads; published assets remain immutable.
gh release upload $ReleaseTag $archive custom-update.json --clobber --repo $env:GITHUB_REPOSITORY
gh release edit $ReleaseTag --draft=false --latest --repo $env:GITHUB_REPOSITORY
