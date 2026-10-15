# Zelda3 DS - Windows entry point (no make required): runs each step inside the Docker container.
# Usage:
#   .\build.ps1 image            # once: build the image
#   .\build.ps1 all              # fetch + build + package
#   .\build.ps1 assets           # generate zelda3_assets.dat from rom\zelda3.sfc
#   .\build.ps1 deploy -DeviceIp 192.168.1.50 [-DevicePass rocknix]
#   .\build.ps1 shell
param(
  [Parameter(Position = 0)]
  [ValidateSet('image', 'fetch', 'build', 'assets', 'package', 'deploy', 'shell', 'all', 'clean')]
  [string]$Task = 'all',
  [string]$DeviceIp,
  [string]$DeviceUser = 'root',
  [string]$DevicePass,
  [string]$Rom
)
$ErrorActionPreference = 'Stop'
$Image = 'zelda3-ds-builder:bookworm'
$Root = $PSScriptRoot

function Invoke-InContainer([string]$Script, [string[]]$ScriptArgs = @(), [switch]$Interactive) {
  $envArgs = @()
  if ($DeviceIp)   { $envArgs += @('-e', "DEVICE_IP=$DeviceIp") }
  if ($DeviceUser) { $envArgs += @('-e', "DEVICE_USER=$DeviceUser") }
  if ($DevicePass) { $envArgs += @('-e', "DEVICE_PASS=$DevicePass") }
  $tty = if ($Interactive) { '-it' } else { '-t' }
  & docker run --rm $tty -v "${Root}:/work" -w /work @envArgs $Image bash $Script @ScriptArgs
  if ($LASTEXITCODE -ne 0) { throw "Failed: $Script" }
}

switch ($Task) {
  'image'   { & docker build -t $Image (Join-Path $Root 'docker'); if ($LASTEXITCODE) { throw 'docker build failed' } }
  'fetch'   { Invoke-InContainer 'scripts/fetch-sources.sh' }
  'build'   { Invoke-InContainer 'scripts/build.sh' }
  'assets'  { $a = @(); if ($Rom) { $a = @($Rom -replace '\\', '/') }; Invoke-InContainer 'scripts/extract-assets.sh' $a }
  'package' { Invoke-InContainer 'scripts/package.sh' }
  'deploy'  { if (-not $DeviceIp) { throw 'Specify -DeviceIp' }; Invoke-InContainer 'scripts/deploy.sh' }
  'shell'   { & docker run --rm -it -v "${Root}:/work" -w /work $Image bash }
  'clean'   { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $Root 'build'), (Join-Path $Root 'dist') }
  'all'     { Invoke-InContainer 'scripts/fetch-sources.sh'; Invoke-InContainer 'scripts/build.sh'; Invoke-InContainer 'scripts/package.sh' }
}
