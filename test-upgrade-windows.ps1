param([string]$SdkDirectory = (Join-Path $env:APPDATA 'daml/sdk/3.4.11'))
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $SdkDirectory 'damlc/damlc.exe'
$baseline = Join-Path $PSScriptRoot '.daml/dist/clearroute-service-0.1.0.dar'
if (-not (Test-Path -LiteralPath $baseline)) { throw 'Run test-windows.ps1 first.' }
$stage = Join-Path $PSScriptRoot ('evidence/upgrade-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'daml') | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'daml/*') -Destination (Join-Path $stage 'daml') -Recurse
$yaml = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'daml.yaml') -Raw).Replace('version: 0.1.0', 'version: 0.1.1')
[IO.File]::WriteAllText((Join-Path $stage 'daml.yaml'), $yaml)
$receiptPath = Join-Path $stage 'daml/ClearRoute/FundingReceipt.daml'
$receipt = Get-Content -LiteralPath $receiptPath -Raw
[IO.File]::WriteAllText($receiptPath, $receipt.Replace('    completedAt : Time', "    completedAt : Time`n    auditNote : Optional Text"))
$previousSdk = $env:DAML_SDK
$env:DAML_SDK = $SdkDirectory
Push-Location $stage
try {
    & $compiler build --enable-multi-package=no --upgrades $baseline -o compatible.dar
    if ($LASTEXITCODE -ne 0) { throw 'Compatible optional-field upgrade was rejected.' }
    [IO.File]::WriteAllText($receiptPath, $receipt.Replace('    completedAt : Time', "    completedAt : Time`n    auditNote : Text"))
    # Native diagnostics are expected here; inspect both the exit code and message.
    $ErrorActionPreference = 'Continue'
    $diagnostics = & $compiler build --enable-multi-package=no --upgrades $baseline -o incompatible.dar 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $diagnostics | ForEach-Object { $_.ToString() } | Set-Content (Join-Path $stage 'expected-rejection.log')
    if ($code -eq 0 -or ($diagnostics -join "`n") -notmatch 'optional|Optional') {
        throw 'Required-field upgrade did not fail for the expected compatibility reason.'
    }
    [ordered]@{
        testedAtUtc = [DateTime]::UtcNow.ToString('o')
        baselineSha256 = (Get-FileHash -Algorithm SHA256 $baseline).Hash
        optionalFieldUpgrade = 'passed'
        requiredFieldUpgrade = 'rejected as expected'
        fixtureDirectory = $stage
        note = 'Compiler compatibility test only; fixture DARs are not release artifacts.'
    } | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'evidence/upgrade-results.json')
    Write-Host 'Upgrade checks passed: optional field accepted; required field rejected.'
} finally {
    $env:DAML_SDK = $previousSdk
    Pop-Location
}
