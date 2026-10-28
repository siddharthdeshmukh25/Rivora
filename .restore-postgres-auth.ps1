$ErrorActionPreference = 'Stop'
$hbaPath = 'C:\Program Files\PostgreSQL\18\data\pg_hba.conf'
$serviceName = 'postgresql-x64-18'
$pgIsReady = 'D:\Program Files\PostgreSQL\18\bin\pg_isready.exe'
if (!(Test-Path -LiteralPath $hbaPath) -or !(Test-Path -LiteralPath $pgIsReady)) { throw 'PostgreSQL 18 files missing; no restoration was attempted.' }
$text = [IO.File]::ReadAllText($hbaPath)
$pattern = '(?m)^(host\s+all\s+all\s+(?:127\.0\.0\.1/32|::1/128)\s+)trust(?=\s*(?:#.*)?$)'
if ([regex]::Matches($text, $pattern).Count -ne 2) { throw 'Expected exactly two loopback trust rules; refusing to alter PostgreSQL config.' }
$restored = [regex]::Replace($text, $pattern, '${1}scram-sha-256')
[IO.File]::WriteAllText($hbaPath, $restored, (New-Object Text.UTF8Encoding($false)))
Restart-Service -Name $serviceName -Force
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  & $pgIsReady -h 127.0.0.1 -p 5432 | Out-Null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 2
}
if (!$ready) { throw 'Original loopback password-authentication rules are restored, but PostgreSQL is not ready.' }
Write-Output 'Restored loopback SCRAM password authentication and verified PostgreSQL is accepting connections.'
