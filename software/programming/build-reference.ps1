param([string]$ProjectDirectory = (Join-Path $PSScriptRoot 'esp-drone-source'))
$ErrorActionPreference = 'Stop'
$archive = Join-Path $PSScriptRoot 'esp-drone-source-9d5a4f8.zip'
if (!(Test-Path -LiteralPath $archive)) { throw 'The pinned upstream source archive is missing.' }
if (!(Get-Command idf.py -ErrorAction SilentlyContinue)) {
    throw 'Open an ESP-IDF release/v5.5 PowerShell environment first. See PROGRAMMING.txt. No build or flash was performed.'
}
if (Test-Path -LiteralPath $ProjectDirectory) {
    throw 'Choose a new empty ProjectDirectory. Existing source folders are not overwritten.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $ProjectDirectory
Push-Location -LiteralPath $ProjectDirectory
try {
    [IO.File]::WriteAllText((Join-Path (Get-Location).Path 'sdkconfig.bench.defaults'), "CONFIG_MOTORS_STARTUP_TEST=n`n", [Text.UTF8Encoding]::new($false))
    & idf.py set-target esp32s2
    if ($LASTEXITCODE -ne 0) { throw 'set-target failed.' }
    & idf.py '-DSDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.defaults.esp32s2;sdkconfig.bench.defaults' reconfigure
    if ($LASTEXITCODE -ne 0) { throw 'reconfigure failed.' }
    & idf.py build
    if ($LASTEXITCODE -ne 0) { throw 'Build failed. Read the ESP-IDF diagnostic above.' }
    Write-Output 'Build completed. Nothing was flashed. Check the exact board and motor configuration before choosing a serial port.'
} finally { Pop-Location }
