param(
  [switch]$Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$exeName = 'flutter_application_1.exe'
$buildRoot = Join-Path $projectRoot 'build\windows'
$exePath = Join-Path $projectRoot "build\windows\x64\runner\Debug\$exeName"

Push-Location $projectRoot
try {
  if (Test-Path $buildRoot) {
    Write-Host 'Removing previous Windows build output...' -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildRoot
  }

  Write-Host 'Building Windows debug artifact...' -ForegroundColor Cyan
  flutter build windows --debug
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows --debug failed with exit code $LASTEXITCODE"
  }

  if (-not (Test-Path $exePath)) {
    throw "Windows debug executable not found: $exePath"
  }

  $workingDir = Split-Path -Parent $exePath
  Write-Host "Starting $exeName" -ForegroundColor Green
  Write-Host "Path: $exePath"

  if ($Wait) {
    & $exePath
    exit $LASTEXITCODE
  }

  Start-Process -FilePath $exePath -WorkingDirectory $workingDir | Out-Null
}
finally {
  Pop-Location
}
