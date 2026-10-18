#!/usr/bin/env bash

export PATH="$HOME/.local/bin:$PATH"

pkill -x waybar
pkill -x waybar-bin
pkill -x swaync

MODE_FILE="$HOME/.config/carbon/carbon-bar-mode.json"
if [ -f "$MODE_FILE" ]; then
    CURR_MODE=$(python3 -c "import json; print(json.load(open('$MODE_FILE')).get('mode', 'pill'))" 2>/dev/null || echo "pill")
    if [ "$CURR_MODE" != "pill" ]; then
        exit 0
    fi
fi

WAYBAR_BIN="$(command -v waybar)"
SWAYNC_BIN="$(command -v swaync)"

if [ -n "$WAYBAR_BIN" ]; then
    setsid -f "$WAYBAR_BIN" -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/tmp/waybar.log 2>&1
fi

if [ -n "$SWAYNC_BIN" ]; then
    setsid -f "$SWAYNC_BIN" >/dev/null 2>&1
fi
