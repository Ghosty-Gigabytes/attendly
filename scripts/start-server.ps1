param([switch]$Google)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $env:WEB_ORIGIN) { $env:WEB_ORIGIN = 'http://localhost:8080' }
$profiles = if ($Google) { 'local,google' } else { 'local' }
if ($Google -and (-not $env:GOOGLE_CLIENT_ID -or -not $env:GOOGLE_CLIENT_SECRET)) { throw 'Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in this shell before starting with -Google.' }
Push-Location (Join-Path $projectRoot 'server')
try {
  & ./mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=$profiles"
} finally { Pop-Location }
