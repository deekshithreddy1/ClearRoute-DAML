param(
    [string]$SdkDirectory = (Join-Path $env:APPDATA 'daml/sdk/3.4.11'),
    [string]$ProductionSdkDirectory = (Join-Path $env:APPDATA 'daml/sdk/3.4.11')
)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $SdkDirectory 'damlc/damlc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw "Installed compiler not found: $compiler. Supply -SdkDirectory for your installed SDK."
}
$previousSdk = $env:DAML_SDK
Push-Location $PSScriptRoot
try {
    $productionCompiler = Join-Path $ProductionSdkDirectory 'damlc/damlc.exe'
    $env:DAML_SDK = $ProductionSdkDirectory
    & $productionCompiler build --enable-multi-package=no --package-root $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'ClearRoute DAR build failed.' }
    $dar = Join-Path $PSScriptRoot '.daml/dist/clearroute-service-0.1.0.dar'
    & $productionCompiler validate-dar $dar
    if ($LASTEXITCODE -ne 0) { throw 'DAR validation failed.' }
    $env:DAML_SDK = $SdkDirectory
    $evidence = Join-Path $PSScriptRoot 'evidence'
    New-Item -ItemType Directory -Force -Path $evidence | Out-Null
    & $productionCompiler inspect-dar $dar --json | Set-Content -Encoding utf8 (Join-Path $evidence 'dar-inspection.json')
    if ($LASTEXITCODE -ne 0) { throw 'DAR inspection failed.' }
    Push-Location (Join-Path $PSScriptRoot 'tests')
    try {
        & $compiler build --enable-multi-package=no
        if ($LASTEXITCODE -ne 0) { throw 'Test DAR build failed.' }
        & $compiler test --package-root (Join-Path $PSScriptRoot 'tests') --all --show-coverage --save-coverage (Join-Path $evidence 'coverage.bin') --junit (Join-Path $evidence 'unit-tests.xml') | Tee-Object -FilePath (Join-Path $evidence 'coverage.txt')
        if ($LASTEXITCODE -ne 0) { throw 'ClearRoute Daml tests failed.' }
    } finally { Pop-Location }
    Get-FileHash -Algorithm SHA256 $dar | Select-Object Algorithm, Hash, Path | ConvertTo-Json | Set-Content (Join-Path $evidence 'dar-sha256.json')
} finally {
    $env:DAML_SDK = $previousSdk
    Pop-Location
}
