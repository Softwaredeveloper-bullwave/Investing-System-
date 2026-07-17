# BullWave — reliable Flutter web launch on Windows (fixes locked build/ folder).
# Common cause: OneDrive sync or a leftover Dart/Chrome dev process.
# Usage: .\run_chrome.ps1

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$WebPort = 7357

function Stop-FlutterDevProcesses {
    Write-Host "Stopping leftover Dart/Flutter dev processes..." -ForegroundColor Cyan
    @("dart", "dartaotruntime", "flutter_tester") | ForEach-Object {
        Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    # Chrome instances launched by `flutter run -d chrome` often lock build\flutter_assets.
    Get-Process chrome -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match "BullWave|localhost:$WebPort|flutter" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Remove-LockedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Retries = 6
    )
    if (-not (Test-Path $Path)) { return $true }

    for ($i = 0; $i -lt $Retries; $i++) {
        Stop-FlutterDevProcesses
        cmd /c "rmdir /s /q `"$Path`"" 2>$null | Out-Null
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $Path)) { return $true }
        Start-Sleep -Seconds (1 + $i)
    }
    return -not (Test-Path $Path)
}

Write-Host "Unlocking build folders..." -ForegroundColor Cyan
Stop-FlutterDevProcesses

# Only remove build/ and ios ephemeral — flutter clean also hits .dart_tool and fails while IDE is open.
$pathsToClear = @(
    (Join-Path $PSScriptRoot "build"),
    (Join-Path $PSScriptRoot "ios\Flutter\ephemeral")
)
$failed = @()
foreach ($p in $pathsToClear) {
    if (-not (Test-Path $p)) { continue }
    if (-not (Remove-LockedPath -Path $p)) { $failed += $p }
}
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Could not delete locked folders:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Try:" -ForegroundColor Yellow
    Write-Host "  1. Close Chrome windows opened by Flutter" -ForegroundColor Yellow
    Write-Host "  2. Pause OneDrive sync (project is in OneDrive\Desktop)" -ForegroundColor Yellow
    Write-Host "  3. Close other terminals running flutter run" -ForegroundColor Yellow
    Write-Host "  4. Re-run: .\run_chrome.ps1" -ForegroundColor Yellow
    exit 1
}

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Launching on Chrome (port $WebPort)..." -ForegroundColor Green
flutter run -d chrome --web-port=$WebPort
