$ErrorActionPreference = 'Stop'

$serviceName = 'postgresql-x64-18'
$hbaPath = 'C:\Program Files\PostgreSQL\18\data\pg_hba.conf'
$psqlPath = 'D:\Program Files\PostgreSQL\18\bin\psql.exe'
$envPath = Join-Path (Get-Location).Path '.env'
$roleName = 'rivora_local_app'
$dbName = 'rivora_local'

if (!(Test-Path -LiteralPath $hbaPath) -or !(Test-Path -LiteralPath $psqlPath) -or !(Test-Path -LiteralPath $envPath)) {
  throw 'PostgreSQL 18 files or project .env were not found; no setup was performed.'
}

$envText = [IO.File]::ReadAllText($envPath)
if ([regex]::Matches($envText, '(?m)^\s*DATABASE_URL\s*=').Count -ne 1) {
  throw 'Expected exactly one DATABASE_URL in project .env; no setup was performed.'
}

$originalHbaBytes = [IO.File]::ReadAllBytes($hbaPath)
$originalHbaText = [IO.File]::ReadAllText($hbaPath)
$loopbackRulePattern = '(?m)^(host\s+all\s+all\s+(?:127\.0\.0\.1/32|::1/128)\s+)scram-sha-256(?=\s*(?:#.*)?$)'
if ([regex]::Matches($originalHbaText, $loopbackRulePattern).Count -ne 2) {
  throw 'Expected exactly two loopback-only SCRAM rules; stopped without changing PostgreSQL.'
}

$temporaryAuthApplied = $false
try {
  $temporaryHbaText = [regex]::Replace($originalHbaText, $loopbackRulePattern, '${1}trust')
  [IO.File]::WriteAllText($hbaPath, $temporaryHbaText, (New-Object Text.UTF8Encoding($false)))
  $temporaryAuthApplied = $true
  Restart-Service -Name $serviceName -Force

  $ready = $false
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $probe = & $psqlPath -X -A -t -h 127.0.0.1 -U postgres -d postgres -c 'SELECT 1' 2>$null
    if ($LASTEXITCODE -eq 0 -and (($probe -join '').Trim() -eq '1')) { $ready = $true; break }
    Start-Sleep -Seconds 2
  }
  if (!$ready) { throw 'PostgreSQL did not become ready; original authentication rules will be restored.' }

  $existing = & $psqlPath -X -A -t -h 127.0.0.1 -U postgres -d postgres -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname='$roleName')::text || ':' || (SELECT count(*) FROM pg_database WHERE datname='$dbName')::text" 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Could not safely check whether the new local role/database names are available.' }
  if ((($existing -join '').Trim() -ne '0:0')) { throw 'The local role or database name already exists. Existing PostgreSQL data was left untouched.' }

  $random = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    [byte[]]$secretBytes = New-Object byte[] 32
    $random.GetBytes($secretBytes)
    $password = -join ($secretBytes | ForEach-Object { $_.ToString('x2') })
  } finally { $random.Dispose() }

  $startInfo = New-Object Diagnostics.ProcessStartInfo
  $startInfo.FileName = $psqlPath
  $startInfo.Arguments = '-X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d postgres'
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $process = New-Object Diagnostics.Process
  $process.StartInfo = $startInfo
  [void]$process.Start()
  $process.StandardInput.WriteLine("CREATE ROLE $roleName WITH LOGIN PASSWORD '$password';")
  $process.StandardInput.WriteLine("CREATE DATABASE $dbName OWNER $roleName;")
  $process.StandardInput.Close()
  $null = $process.StandardOutput.ReadToEnd()
  $null = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $exitCode = $process.ExitCode
  $process.Dispose()
  if ($exitCode -ne 0) { throw 'PostgreSQL could not create the new local app database. Existing data was not changed.' }

  $newUrl = "postgresql://${roleName}:${password}@127.0.0.1:5432/${dbName}?schema=public"
  $updatedEnv = [regex]::Replace($envText, '(?m)^\s*DATABASE_URL\s*=.*$', "DATABASE_URL=`"$newUrl`"", 1)
  [IO.File]::WriteAllText($envPath, $updatedEnv, (New-Object Text.UTF8Encoding($false)))
  Write-Output 'Created a separate local app database and login. Updated only DATABASE_URL in the project .env; the generated password was not displayed.'
} finally {
  if ($temporaryAuthApplied) {
    [IO.File]::WriteAllBytes($hbaPath, $originalHbaBytes)
    Restart-Service -Name $serviceName -Force
    $restoredReady = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
      $probe = & $psqlPath -X -A -t -h 127.0.0.1 -U postgres -d postgres -c 'SELECT 1' 2>$null
      if ($LASTEXITCODE -eq 0 -and (($probe -join '').Trim() -eq '1')) { $restoredReady = $true; break }
      Start-Sleep -Seconds 2
    }
    if (!$restoredReady) { throw 'Original PostgreSQL authentication rules were restored, but service readiness needs attention.' }
    Write-Output 'Restored the original PostgreSQL authentication rules; the service is running.'
  }
}
