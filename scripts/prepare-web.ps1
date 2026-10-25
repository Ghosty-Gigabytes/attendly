$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$bundlePath = (Resolve-Path (Join-Path $projectRoot 'apps/web/build/web')).Path
$files = @(Get-ChildItem -LiteralPath $bundlePath -Recurse -File | Where-Object { $_.Name -notin @('service-worker.js','precache-manifest.json','flutter_service_worker.js') -and $_.Extension -ne '.map' })
$relativeFiles = @($files | ForEach-Object { './' + $_.FullName.Substring($bundlePath.Length + 1).Replace([char]92, [char]47) })
$hashInput = ($files | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($bundlePath.Length) + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "`n"
$sha = [System.Security.Cryptography.SHA256]::Create()
try { $buildId = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashInput)))).Replace('-','').Substring(0,16).ToLowerInvariant() } finally { $sha.Dispose() }
$worker = [IO.File]::ReadAllText((Join-Path $projectRoot 'apps/web/web/service-worker.js')).Replace('__BUILD_ID__',$buildId)
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $bundlePath 'service-worker.js'),$worker,$utf8)
[IO.File]::WriteAllText((Join-Path $bundlePath 'precache-manifest.json'),(ConvertTo-Json -InputObject $relativeFiles),$utf8)
Write-Output "Prepared offline shell $buildId ($($files.Count) files)."

