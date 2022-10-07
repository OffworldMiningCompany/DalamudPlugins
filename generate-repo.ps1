function ExitWithCode($code) {
  $host.SetShouldExit($code)
  exit $code
}
$pluginsOut = @()

$pluginList = Get-Content '.\plugins.json' | ConvertFrom-Json

foreach ($plugin in $pluginList) {
  $username = $plugin.username
  $repo = $plugin.repo
  $branch = $plugin.branch
  $configFolder = $plugin.configFolder

  $data = Invoke-WebRequest -Uri "https://api.github.com/repos/$($username)/$($repo)/releases/latest"
  $json = ConvertFrom-Json $data.content

  $count = $json.assets[0].download_count
  $download = $json.assets[0].browser_download_url
  $time = [Int](New-TimeSpan -Start (Get-Date "01/01/1970") -End ([DateTime]$json.published_at)).TotalSeconds

  $configData = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$($username)/$($repo)/$($branch)/$($configFolder)/$($repo).json"
  $config = ConvertFrom-Json $configData.content

  if ($null -eq $config) {
    Write-Error "Config for plugin $($plugin) is null!"
    ExitWithCode(1)
  }

  $config | Add-Member -Name "IsHide" -MemberType NoteProperty -Value "False"
  $config | Add-Member -Name "IsTestingExclusive" -MemberType NoteProperty -Value "False"
  $config | Add-Member -Name "LastUpdated" -MemberType NoteProperty -Value $time
  $config | Add-Member -Name "RepoUrl" -MemberType NoteProperty -Value "https://github.com/$($username)/$($repo)"
  $config | Add-Member -Name "DownloadCount" -MemberType NoteProperty -Value $count
  $config | Add-Member -Name "DownloadLinkInstall" -MemberType NoteProperty -Value $download
  $config | Add-Member -Name "DownloadLinkTesting" -MemberType NoteProperty -Value $download
  $config | Add-Member -Name "DownloadLinkUpdate" -MemberType NoteProperty -Value $download

  $pluginsOut += $config
}

$pluginsJson = ConvertTo-Json $pluginsOut

if ((Test-Path -Path '.\repo.json' -PathType Leaf) -and -not (Compare-Object $pluginsJson (Get-Content '.\repo.json' -Raw))) {
  ExitWithCode(0)
}

Set-Content -Path "repo.json" -Value $pluginsJson -NoNewline
