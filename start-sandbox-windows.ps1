param(
    [string]$JavaDirectory = (Join-Path $PSScriptRoot '../.tools/jdk-17.0.19+10'),
    [string]$SdkDirectory = (Join-Path $env:APPDATA 'daml/sdk/3.4.11')
)
$ErrorActionPreference = 'Stop'
$java = Join-Path $JavaDirectory 'bin/java.exe'
if (-not (Test-Path -LiteralPath $java)) { throw 'Supply -JavaDirectory pointing to an OpenJDK installation.' }
$assistant = Join-Path $SdkDirectory 'daml/daml.exe'
$previousJava = $env:JAVA_HOME
$previousPath = $env:PATH
$previousVersion = $env:DAML_SDK_VERSION
Push-Location $PSScriptRoot
try {
    $env:JAVA_HOME = (Resolve-Path $JavaDirectory).Path
    $env:PATH = "$env:JAVA_HOME/bin;$previousPath"
    $env:DAML_SDK_VERSION = '3.4.11'
    # Disposable in-memory sandbox, separate from Quickstart and hosted networks.
    & $assistant sandbox --static-time --port 16865 --admin-api-port 16866 --sequencer-public-port 16867 --sequencer-admin-port 16868 --mediator-admin-port 16869 --json-api-port 16870 --dar .daml/dist/clearroute-service-0.1.0.dar
    if ($LASTEXITCODE -ne 0) { throw 'Sandbox stopped with an error.' }
} finally {
    $env:JAVA_HOME = $previousJava
    $env:PATH = $previousPath
    $env:DAML_SDK_VERSION = $previousVersion
    Pop-Location
}
