param(
    [string]$JavaDirectory = (Join-Path $PSScriptRoot '../.tools/jdk-17.0.19+10'),
    [string]$SdkDirectory = (Join-Path $env:APPDATA 'daml/sdk/3.4.11')
)
$ErrorActionPreference = 'Stop'
$assistant = Join-Path $SdkDirectory 'daml/daml.exe'
$compiler = Join-Path $SdkDirectory 'damlc/damlc.exe'
$dar = Join-Path $PSScriptRoot '.daml/dist/clearroute-service-0.1.0.dar'
$testDar = Join-Path $PSScriptRoot 'tests/.daml/dist/clearroute-tests-0.1.0.dar'
$evidence = Join-Path $PSScriptRoot 'evidence'
$unitHash = Get-Content (Join-Path $evidence 'dar-sha256.json') -Raw | ConvertFrom-Json
$actualHash = (Get-FileHash -Algorithm SHA256 $dar).Hash
if ($actualHash -ne $unitHash.Hash) { throw 'DAR changed since unit tests. Rerun test-windows.ps1.' }
[xml]$unitResults = Get-Content (Join-Path $evidence 'unit-tests.xml') -Raw
if ([int]$unitResults.testsuites.failures -ne 0 -or [int]$unitResults.testsuites.errors -ne 0) { throw 'Unit tests must pass first.' }
$expected = [int]$unitResults.testsuites.tests
$package = & $compiler inspect-dar $dar --json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect production DAR.' }
$tests = & $compiler inspect-dar $testDar --json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or ($tests.packages.PSObject.Properties.Name -notcontains $package.main_package_id)) {
    throw 'Test DAR does not contain the production package.'
}
$previousJava = $env:JAVA_HOME
$previousPath = $env:PATH
$previousVersion = $env:DAML_SDK_VERSION
Push-Location $PSScriptRoot
try {
    $env:JAVA_HOME = (Resolve-Path $JavaDirectory).Path
    $env:PATH = "$env:JAVA_HOME/bin;$previousPath"
    $env:DAML_SDK_VERSION = '3.4.11'
    # Only the disposable loopback sandbox is allowed; never run this on NODERS.
    $ErrorActionPreference = 'Continue'
    $output = & $assistant script --dar $testDar --all --ledger-host 127.0.0.1 --ledger-port 16865 --static-time --upload-dar yes 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $lines = @($output | ForEach-Object { $_.ToString() })
    $lines | Set-Content (Join-Path $evidence 'ledger-tests.log')
    $passed = @($lines | Where-Object { $_ -match '^ClearRoute\..+ SUCCESS$' }).Count
    $failed = @($lines | Where-Object { $_ -match '^ClearRoute\..+ FAILURE' }).Count
    [ordered]@{
        testedAtUtc = [DateTime]::UtcNow.ToString('o')
        endpoint = '127.0.0.1:16865'
        sdk = '3.4.11'
        darSha256 = $actualHash
        expected = $expected
        passed = $passed
        failed = $failed
        exitCode = $code
        scope = 'Canton sandbox Ledger API; no Splice, token transfers, hosted auth or Devnet'
    } | ConvertTo-Json | Set-Content (Join-Path $evidence 'ledger-results.json')
    $lines | Write-Output
    if ($code -ne 0 -or $failed -ne 0 -or $passed -ne $expected) { throw 'Ledger integration gate failed; see evidence/ledger-tests.log.' }
} finally {
    $env:JAVA_HOME = $previousJava
    $env:PATH = $previousPath
    $env:DAML_SDK_VERSION = $previousVersion
    Pop-Location
}
