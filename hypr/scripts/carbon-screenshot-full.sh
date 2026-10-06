#!/usr/bin/env bash
# Fullscreen screenshot: capture all visible outputs, save a timestamped PNG
# to ~/Pictures/Screenshots, copy it to clipboard as image/png, and notify the user.
set -e

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png"

grim "$FILE"
wl-copy --type image/png < "$FILE"
notify-send -a "Carbon Screenshot" -i "$FILE" "Screenshot Taken" "Full screen saved to $(basename "$FILE") and copied to clipboard" 2>/dev/null || true
