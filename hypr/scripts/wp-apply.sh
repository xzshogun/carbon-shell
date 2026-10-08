#!/bin/bash

# Carbon wallpaper APPLY: re-point current_wallpaper, regenerate the
# monitor-sized copy, rebuild the shell theme from the image palette
# (light/dark detected automatically) and restart the shell so the new
# palette takes effect. Usage: wp-apply.sh /path/to/wallpaper

WALL_IN="$1"
[ -z "$WALL_IN" ] && exit 1

WALL="$(readlink -f -- "$WALL_IN")"
[ -f "$WALL" ] || exit 1

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
mkdir -p "$CONFIG_DIR"
TARGET_WALL="$CONFIG_DIR/current_wallpaper"
CACHE_DIR="$HOME/.cache/carbon"
mkdir -p "$CACHE_DIR"

EXT="${WALL##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

SCALED="$CACHE_DIR/wpscale/$(basename "$WALL" | tr '.' '_').jpg"
mkdir -p "$CACHE_DIR/wpscale"

if [ -s "$SCALED" ] && [ "$SCALED" -nt "$WALL" ]; then
    cp -f "$SCALED" "$CACHE_DIR/wallpaper_scaled.jpg"
else
    read -r LW LH < <(hyprctl monitors -j | python3 -c \
        'import json,sys; m=json.load(sys.stdin)[0]; print(round(m["width"]/m["scale"]), round(m["height"]/m["scale"]))' 2>/dev/null)
    LW="${LW:-2049}"; LH="${LH:-1152}"

    FRAME_SRC="$WALL"
    if [ "$EXT" = "mp4" ] || [ "$EXT" = "m4v" ] || [ "$EXT" = "webm" ] || [ "$EXT" = "mkv" ]; then
        ffmpeg -y -i "$WALL" -vframes 1 -ss 00:00:00.500 "$CACHE_DIR/wp_temp_frame.jpg" 2>/dev/null || ffmpeg -y -i "$WALL" -vframes 1 "$CACHE_DIR/wp_temp_frame.jpg" 2>/dev/null
        FRAME_SRC="$CACHE_DIR/wp_temp_frame.jpg"
    elif [ "$EXT" = "gif" ]; then
        FRAME_SRC="${WALL}[0]"
    fi

    magick "$FRAME_SRC" -auto-orient -resize "${LW}x${LH}^" -gravity south -extent "${LW}x${LH}" \
        -quality 90 "$SCALED" 2>/dev/null || exit 1
    cp -f "$SCALED" "$CACHE_DIR/wallpaper_scaled.jpg"
fi

cp -f "$WALL" "$TARGET_WALL"
echo "$WALL" > "$CONFIG_DIR/current_wallpaper_path"

# Rebuild the shell theme from the new palette (updates theme.json, GTK, Fuzzel, and Hyprland dynamically).
THEME_SCRIPT="$CONFIG_DIR/scripts/theme-mk.py"
if [ ! -f "$THEME_SCRIPT" ]; then
    THEME_SCRIPT="$HOME/.config/carbon/scripts/theme-mk.py"
fi
if [ -f "$THEME_SCRIPT" ]; then
    python3 "$THEME_SCRIPT" "$WALL" 2>/dev/null
fi

echo "applied: $WALL"