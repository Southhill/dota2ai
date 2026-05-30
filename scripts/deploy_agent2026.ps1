<#
.SYNOPSIS
  Deploy Agent2026 Bot AI to Dota2 (local test using bots folder)
.DESCRIPTION
  Deploys source code to Dota2 vscripts/bots directory for local testing.
  Use 'Agent2026' name when uploading to Steam Workshop later.
#>

$STEAM_PATH = "D:\SteamLibrary"
$DEST_DIR = "$STEAM_PATH\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots"
$SRC_DIR = Join-Path (Split-Path $PSScriptRoot -Parent) "src"

Write-Host "========================================"
Write-Host "  Deploy Bot AI to Dota2 (Local Test)" -ForegroundColor Cyan
Write-Host "========================================"
Write-Host ""
Write-Host "Source: $SRC_DIR"
Write-Host "Target: $DEST_DIR"
Write-Host ""

# Check Steam path
if (-not (Test-Path $STEAM_PATH)) {
    Write-Host "[WARNING] Steam path not found: $STEAM_PATH" -ForegroundColor Yellow
    $STEAM_PATH = Read-Host "Enter your Steam installation path"
    $DEST_DIR = "$STEAM_PATH\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots"
}

# Create target directory
if (-not (Test-Path $DEST_DIR)) {
    New-Item -ItemType Directory -Path $DEST_DIR -Force | Out-Null
    Write-Host "[OK] Directory created" -ForegroundColor Green
}

# Count source files before copy
$fileCount = (Get-ChildItem -Recurse -File "$SRC_DIR").Count
$luaFileCount = (Get-ChildItem -Recurse -Filter "*.lua" "$SRC_DIR").Count

# Copy all files from src/
try {
    Copy-Item -Recurse -Force "$SRC_DIR\*" $DEST_DIR
    Write-Host "[OK] $fileCount files (including $luaFileCount .lua) copied successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Copy failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Deploy Complete!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "  Summary:"
Write-Host "    Source files : $fileCount"
Write-Host "    Lua scripts  : $luaFileCount"
Write-Host "    Destination  : $DEST_DIR"
Write-Host ""
Write-Host "  Next steps:"
Write-Host "  1. Launch Dota2"
Write-Host "  2. Create Practice Lobby"
Write-Host "  3. Select 'Local Dev Script' as bot option"
Write-Host "  4. Start the game!"
Write-Host ""
Write-Host "  [TIP] In-game: dota_bot_reload_scripts to reload without restart" -ForegroundColor Cyan
Write-Host "  [TIP] Use 'Agent2026' name when uploading to Workshop later" -ForegroundColor Cyan
