#!/bin/sh
# Carbon IPC client: send one command to the shell over its unix socket.
# Commands: wallpaper, launcher, toggle-launcher.
# No socat/nc on this box, so a tiny python client does the writing.
cmd="$*"
[ -z "$cmd" ] && cmd="toggle-launcher"

# If theme-reload was triggered, re-run theme generator first so colors update on disk
if [ "$cmd" = "theme-reload" ] || [ "$cmd" = "reload-theme" ]; then
    if [ -z "$CARBON_IPC_NO_REBUILD" ]; then
        export CARBON_IPC_NO_REBUILD=1
        CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
        THEME_SCRIPT="$CONFIG_DIR/scripts/theme-mk.py"
        [ -f "$THEME_SCRIPT" ] || THEME_SCRIPT="$HOME/.config/hypr/scripts/theme-mk.py"
        if [ -f "$THEME_SCRIPT" ]; then
            python3 "$THEME_SCRIPT" 2>/dev/null || true
        fi
    fi
fi
exec python3 -c '
import socket, sys
cmd = sys.argv[1]
path = "/tmp/carbon-shell.sock"
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    s.connect(path)
    s.sendall((cmd + "\n").encode())
    s.close()
except OSError:
    sys.exit(1)
' "$cmd"