#!/usr/bin/env bash
# Vanish Mode Dedicated Dispatcher
# Routes keybinds exclusively when Vanish Mode (nucleus) is active.
# Keeps standard desktop modes (Pill, Notch, Minimal) completely unhindered.

ACTION="$1"
MODE_FILE="$HOME/.config/hypr/carbon-bar-mode.json"

CURRENT_MODE="nucleus"
if [ -f "$MODE_FILE" ]; then
    CURRENT_MODE=$(python3 -c "import json; print(json.load(open('$MODE_FILE')).get('mode', 'nucleus'))" 2>/dev/null || echo "nucleus")
fi

if [ "$CURRENT_MODE" != "nucleus" ]; then
    # In non-vanish modes, vanish shortcuts do not trigger, preventing key collisions
    exit 0
fi

case "$ACTION" in
    toggle-hub)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus toggle"
        ;;
    launcher)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus launcher"
        ;;
    lyrics)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus lyrics"
        ;;
    wallpaper)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus wallpapers"
        ;;
    focus-connect)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus focus connect"
        ;;
    focus-spaces)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus focus spaces"
        ;;
    focus-alerts)
        sh "$HOME/.config/hypr/scripts/carbon-ipc.sh" "nucleus focus alerts"
        ;;
    *)
        exit 0
        ;;
esac
