$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
git config user.name 'qBittorrent Custom Builder'
git config user.email 'custom-builder@users.noreply.github.com'
git remote add upstream https://github.com/qbittorrent/qBittorrent.git
$release = gh api repos/qbittorrent/qBittorrent/releases/latest | ConvertFrom-Json
$tag = $release.tag_name
if ($release.prerelease -or $release.draft -or $tag -notmatch '^release-\d+\.\d+\.\d+$') {
    throw "Unexpected upstream release: $tag"
}
git fetch upstream "refs/tags/${tag}:refs/tags/${tag}"
git merge --no-edit $tag
$sourceCommit = (git rev-parse HEAD).Trim()
$releaseTag = 'custom-' + $sourceCommit.Substring(0, 12)
$published = gh api "repos/$env:GITHUB_REPOSITORY/releases?per_page=100" | ConvertFrom-Json
$exists = @($published | Where-Object tag_name -eq $releaseTag).Count -gt 0
"build=$((-not $exists).ToString().ToLowerInvariant())" >> $env:GITHUB_OUTPUT
"commit=$sourceCommit" >> $env:GITHUB_OUTPUT
"tag=$releaseTag" >> $env:GITHUB_OUTPUT
"upstream=$tag" >> $env:GITHUB_OUTPUT
"Official release: $tag. Candidate: $sourceCommit. Already published: $exists"
