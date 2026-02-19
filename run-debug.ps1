# Run GreenGains on connected phone in debug mode (hot reload enabled)
# Usage: .\run-debug.ps1
#
# Requires:
#   - Android phone connected via USB with USB debugging enabled
#   - dart_defines.json in project root
#   - flutter on PATH

param(
    [switch]$LogOnly  # Pass -LogOnly to just stream logcat without building
)

$AppId = "com.eremat.greengains"
$LogTags = "GreenGainsFGService", "NativeBackendUploader", "BatteryStateMonitor", "NetworkStateMonitor", "SensorQualityAnalyzer", "flutter"

if ($LogOnly) {
    Write-Host "Streaming logcat for $AppId..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
    $tagFilter = ($LogTags | ForEach-Object { "$_`:*" }) -join " "
    adb logcat -v time -s $tagFilter
    exit
}

# Check device connected
Write-Host "Checking for connected devices..." -ForegroundColor Cyan
$devices = adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "No device connected. Connect your phone and enable USB debugging." -ForegroundColor Red
    exit 1
}
Write-Host "Device found." -ForegroundColor Green

# Clear old logcat so output starts fresh
adb logcat -c

Write-Host ""
Write-Host "Starting debug build + install (hot reload enabled)..." -ForegroundColor Green
Write-Host "Tip: press 'r' to hot reload, 'R' to hot restart, 'q' to quit" -ForegroundColor DarkGray
Write-Host ""

flutter run --dart-define-from-file=dart_defines.json
