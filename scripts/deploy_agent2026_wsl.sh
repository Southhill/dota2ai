#!/usr/bin/env bash
# Deploy Agent2026 bot scripts from src/ to Dota2 vscripts/bots using WSL
# Usage: ./deploy_agent2026_wsl.sh [--steam-path <path>] [--dry-run]

set -euo pipefail

# Defaults: map common Windows drive mount for Steam on WSL (/mnt/d/SteamLibrary)
STEAM_PATH_DEFAULT="/mnt/d/SteamLibrary"
DRY_RUN=0

print_usage() {
  cat <<EOF
Usage: $0 [--steam-path <path>] [--dry-run]

Options:
  --steam-path PATH  Use PATH as Steam installation path (default: $STEAM_PATH_DEFAULT)
  --dry-run          Print actions without copying files
EOF
}

# Parse args
STEAM_PATH="$STEAM_PATH_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --steam-path)
      STEAM_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
done

SRC_DIR="$(dirname "$(realpath "$0")")/../src"
DEST_DIR="$STEAM_PATH/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"

echo "========================================"
echo "  Deploy Bot AI to Dota2 (WSL)"
echo "========================================"
echo "Source: $SRC_DIR"
echo "Target: $DEST_DIR"

# Validate source
if [[ ! -d "$SRC_DIR" ]]; then
  echo "[ERROR] Source directory not found: $SRC_DIR"
  exit 1
fi

# Check steam path
if [[ ! -d "$STEAM_PATH" ]]; then
  echo "[WARNING] Steam path not found: $STEAM_PATH"
  read -rp "Enter your Steam installation path (WSL path): " STEAM_PATH
  DEST_DIR="$STEAM_PATH/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"
fi

# Create destination if needed
if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "$DEST_DIR"
  echo "[OK] Directory ensured: $DEST_DIR"
else
  echo "[DRY-RUN] Would ensure directory: $DEST_DIR"
fi

# Count files
fileCount=$(find "$SRC_DIR" -type f | wc -l)
luaFileCount=$(find "$SRC_DIR" -type f -name "*.lua" | wc -l)

# Copy files with rsync fallback logic
if [[ $DRY_RUN -eq 0 ]]; then
  # Preferred: use a temp dir under /tmp (writable on WSL) to avoid mkstemp errors on NTFS mounts
  mkdir -p /tmp/rsync-temp
  # Use conservative rsync flags on NTFS mounts: avoid preserving perms/owner/group/times
  RSYNC_OPTS=("-r" "--delete" "--exclude=.git" "--no-perms" "--no-owner" "--no-group" "--no-times" "--omit-dir-times")
  if command -v rsync >/dev/null 2>&1; then
    if rsync "${RSYNC_OPTS[@]}" --temp-dir=/tmp/rsync-temp "$SRC_DIR/" "$DEST_DIR/"; then
      echo "[OK] $fileCount files (including $luaFileCount .lua) copied successfully (rsync with temp-dir)"
    else
      echo "[WARN] rsync with temp-dir failed, retrying with --inplace"
      if rsync "${RSYNC_OPTS[@]}" --inplace "$SRC_DIR/" "$DEST_DIR/"; then
        echo "[OK] $fileCount files copied successfully (rsync --inplace)"
      else
        echo "[WARN] rsync --inplace also failed, falling back to cp -a"
        # fallback copy without preserving timestamps/ownership to avoid permission errors on NTFS
        cp -r --no-preserve=mode,ownership,timestamps "$SRC_DIR/." "$DEST_DIR/"
        echo "[OK] $fileCount files copied with cp -r (no preserve)"
      fi
    fi
  else
    echo "[WARN] rsync not found, using cp -a"
    cp -r --no-preserve=mode,ownership,timestamps "$SRC_DIR/." "$DEST_DIR/"
    echo "[OK] $fileCount files copied with cp -r (no preserve)"
  fi
else
  echo "[DRY-RUN] rsync --temp-dir=/tmp/rsync-temp -av --delete --exclude=.git $SRC_DIR/ $DEST_DIR/"
fi

echo ""
echo "========================================"
echo "  Deploy Complete!"
echo "========================================"
echo ""
echo "  Summary:"
echo "    Source files : $fileCount"
echo "    Lua scripts  : $luaFileCount"
echo "    Destination  : $DEST_DIR"
echo ""
echo "  Next steps:"
echo "  1. Launch Dota2"
echo "  2. Create Practice Lobby"
echo "  3. Select 'Agent2026' as bot option or use Local Dev Script"

echo ""
echo "  [TIP] In-game: dota_bot_reload_scripts to reload without restart"

echo ""
