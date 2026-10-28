$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $env:WEB_ORIGIN) { $env:WEB_ORIGIN = 'http://localhost:8080' }
Push-Location (Join-Path $projectRoot 'server')
try {
  & ./mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
} finally { Pop-Location }
