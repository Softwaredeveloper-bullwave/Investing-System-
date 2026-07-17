# Quick fix when Flutter cannot delete locked build/ or ios ephemeral folders.
# Usage: .\clean_build.ps1

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Stop-FlutterDevProcesses {
    Write-Host "Stopping Dart/Chrome dev processes..." -ForegroundColor Cyan
    @("dart", "dartaotruntime", "flutter_tester") | ForEach-Object {
        Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-Process chrome -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowTitle -match 'localhost|BullWave|flutter|Dart' -or
            $_.Path -match 'flutter_tools'
        } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Remove-LockedPath {
    param(
        [string]$Path,
        [int]$Retries = 5
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

Stop-FlutterDevProcesses

$paths = @(
    "build\flutter_assets",
    "build",
    "ios\Flutter\ephemeral",
    ".dart_tool\flutter_build"
)

$failed = @()
foreach ($rel in $paths) {
    $full = Join-Path $PSScriptRoot $rel
    if (-not (Test-Path $full)) { continue }
    Write-Host "Removing $rel ..." -ForegroundColor Cyan
    if (-not (Remove-LockedPath -Path $full)) {
        $failed += $rel
    }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILED to remove:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Fix:" -ForegroundColor Yellow
    Write-Host "  1. Close ALL Chrome windows" -ForegroundColor Yellow
    Write-Host "  2. Right-click OneDrive tray icon -> Pause syncing -> 2 hours" -ForegroundColor Yellow
    Write-Host "  3. Run .\clean_build.ps1 again" -ForegroundColor Yellow
    Write-Host "  4. Long-term: move project to C:\dev\app-2 (outside OneDrive)" -ForegroundColor Yellow
    exit 1
}

flutter pub get 2>$null | Out-Null
Write-Host "Done. Run: .\run_chrome.ps1" -ForegroundColor Green
