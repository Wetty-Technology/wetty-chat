param(
  [switch]$Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $projectRoot 'build\windows'
$flutterArgs = @('run', '-d', 'windows', '--debug')

Push-Location $projectRoot
try {
  if (Test-Path $buildRoot) {
    Write-Host 'Removing previous Windows build output...' -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildRoot
  }

  Write-Host 'Starting Flutter Windows app in debug mode...' -ForegroundColor Cyan
  Write-Host ('Command: flutter ' + ($flutterArgs -join ' '))

  if ($Wait) {
    & flutter @flutterArgs
    exit $LASTEXITCODE
  }

  $argList = @(
    '-NoExit'
    '-Command'
    "Set-Location '$projectRoot'; flutter $($flutterArgs -join ' ')"
  )
  Start-Process -FilePath 'powershell.exe' -ArgumentList $argList | Out-Null
}
finally {
  Pop-Location
}
