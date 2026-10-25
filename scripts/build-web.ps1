$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$wrapper = Join-Path $projectRoot 'work/flutter.ps1'
Push-Location (Join-Path $projectRoot 'apps/web')
try {
  if (Test-Path -LiteralPath $wrapper) {
    & $wrapper pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
    & $wrapper build web --release --no-web-resources-cdn
  } else {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
    & flutter build web --release --no-web-resources-cdn
  }
  if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
} finally { Pop-Location }
& (Join-Path $PSScriptRoot 'prepare-web.ps1')
$staticRoot = Join-Path $projectRoot 'server/src/main/resources/static'
New-Item -ItemType Directory -Path $staticRoot -Force | Out-Null
Copy-Item -Path (Join-Path $projectRoot 'apps/web/build/web/*') -Destination $staticRoot -Recurse -Force
Write-Output 'Web build copied into Spring Boot. Run scripts/start-server.ps1 for a local preview.'
