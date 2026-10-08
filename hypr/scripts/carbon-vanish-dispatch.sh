#!/usr/bin/env bash
# Vanish Mode Dedicated Dispatcher
# Routes keybinds exclusively when Vanish Mode (nucleus) is active.
# Keeps standard desktop modes (Pill, Notch, Minimal) completely unhindered.

ACTION="$1"
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
if [ ! -d "$CONFIG_DIR" ] && [ -d "$HOME/.config/hypr" ]; then
    CONFIG_DIR="$HOME/.config/hypr"
fi
MODE_FILE="$CONFIG_DIR/carbon-bar-mode.json"

CURRENT_MODE="nucleus"
if [ -f "$MODE_FILE" ]; then
    CURRENT_MODE=$(python3 -c "import json; print(json.load(open('$MODE_FILE')).get('mode', 'nucleus'))" 2>/dev/null || echo "nucleus")
fi

if [ "$CURRENT_MODE" != "nucleus" ]; then
    # In non-vanish modes, vanish shortcuts do not trigger, preventing key collisions
    exit 0
fi

IPC_SCRIPT="$CONFIG_DIR/scripts/carbon-ipc.sh"
[ -f "$IPC_SCRIPT" ] || IPC_SCRIPT="$HOME/.config/hypr/scripts/carbon-ipc.sh"

case "$ACTION" in
    toggle-hub)
        sh "$IPC_SCRIPT" "nucleus toggle"
        ;;
    launcher)
        sh "$IPC_SCRIPT" "nucleus launcher"
        ;;
    lyrics)
        sh "$IPC_SCRIPT" "nucleus lyrics"
        ;;
    wallpaper)
        sh "$IPC_SCRIPT" "nucleus wallpapers"
        ;;
    focus-connect)
        sh "$IPC_SCRIPT" "nucleus focus connect"
        ;;
    focus-spaces)
        sh "$IPC_SCRIPT" "nucleus focus spaces"
        ;;
    focus-alerts)
        sh "$IPC_SCRIPT" "nucleus focus alerts"
        ;;
    *)
        exit 0
        ;;
esac
