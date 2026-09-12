#!/bin/sh
# hyprlock image reload_cmd: prints the path of the next ornament frame.
I=$(cat /tmp/lock-ornament-idx 2>/dev/null)
[ -z "$I" ] && I=0
idx=$(( (I + 1) % 12 ))
echo "$idx" > /tmp/lock-ornament-idx
printf '/home/shogun/.config/hypr/lock-ornament/orn_%02d.png' "$idx"