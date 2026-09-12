#!/usr/bin/env python3
"""Carbon theme generator with Matugen integration.

Reads the current wallpaper and generates an intelligent Material You palette
using Matugen and PIL analysis.
Properly maintains high contrast for all text elements and ensures vibrant,
harmonious accent colors across Quickshell, GTK, Fuzzel, and Hyprland.

Usage: theme-mk.py [/path/to/wallpaper]
"""

import colorsys
import json
import os
import subprocess
import sys
from PIL import Image

JSON_PATH = os.path.expanduser("~/.config/hypr/theme.json")
CACHE_DIR = os.path.expanduser("~/.cache/carbon")

OK = "#a6e3a1"
WARN = "#f9e2af"
ERR = "#f38ba8"


def to_255(v):
    return max(0, min(255, int(round(v))))


def hexs(rgb):
    return "#%02X%02X%02X" % tuple(to_255(c) for c in rgb)


def alpha(hexc, a):
    return "#%02X%s" % (int(round(a * 255)), hexc.lstrip("#"))


def get_luminance(hex_str):
    h = hex_str.lstrip("#")
    if len(h) < 6:
        return 0.5
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def resolve_source_wallpaper():
    # 1. Command-line argument
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        return os.path.abspath(sys.argv[1])

    # 2. current_wallpaper_path file
    path_file = os.path.expanduser("~/.config/hypr/current_wallpaper_path")
    if os.path.isfile(path_file):
        try:
            with open(path_file, "r", encoding="utf-8") as f:
                p = f.read().strip()
            if os.path.isfile(p):
                return p
        except Exception:
            pass

    # 3. current_wallpaper symlink
    sym = os.path.expanduser("~/.config/hypr/current_wallpaper")
    if os.path.exists(sym):
        real = os.path.realpath(sym)
        if os.path.isfile(real):
            return real

    # 4. Cached scaled wallpaper
    scaled = os.path.expanduser("~/.cache/carbon/wallpaper_scaled.jpg")
    if os.path.isfile(scaled):
        return scaled

    return None


def get_image_frame_for_analysis(src_path):
    """If the wallpaper is a video or gif, return a static frame path."""
    ext = os.path.splitext(src_path)[1].lower()
    if ext in {".mp4", ".m4v", ".webm", ".mkv", ".gif"}:
        thumb = os.path.join(CACHE_DIR, "wp_temp_frame.jpg")
        if os.path.isfile(thumb) and os.path.getsize(thumb) > 0:
            return thumb
        try:
            if ext == ".gif":
                subprocess.run(["magick", f"{src_path}[0]", "-resize", "800x", thumb], timeout=3.0)
            else:
                subprocess.run(
                    ["ffmpeg", "-y", "-i", src_path, "-vframes", "1", "-ss", "00:00:00.500", thumb],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0
                )
            if os.path.isfile(thumb):
                return thumb
        except Exception:
            pass
    return src_path


def get_matugen_palette(src_path):
    """Extract Material You colors using matugen non-interactively in dark mode."""
    try:
        cmd = [
            "matugen", "image", src_path,
            "--source-color-index", "0",
            "--prefer", "saturation",
            "-m", "dark",
            "-j", "hex"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=3.0)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return None


def get_rgb_pixels(small_img):
    try:
        raw = list(small_img.get_flattened_data())
    except AttributeError:
        raw = list(small_img.getdata())

    if raw and isinstance(raw[0], (int, float)):
        return [(raw[i], raw[i+1], raw[i+2]) for i in range(0, len(raw)-2, 3)]
    elif raw and isinstance(raw[0], (tuple, list)):
        return [(p[0], p[1], p[2]) for p in raw]
    return []


def extract_vibrant_fallback(img_path):
    """Extract highest vibrancy color from image using PIL."""
    try:
        im = Image.open(img_path).convert("RGB")
        small = im.resize((64, 36), Image.LANCZOS)
        px = get_rgb_pixels(small)

        candidates = []
        for r, g, b in px:
            h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            if s > 0.20 and 0.22 < l < 0.85:
                # Score favors high saturation with comfortable midtone lightness
                score = s * (1.0 - abs(l - 0.55) * 0.7)
                candidates.append((score, (r, g, b)))

        if candidates:
            candidates.sort(key=lambda x: x[0], reverse=True)
            return hexs(candidates[0][1])
    except Exception:
        pass
    return "#38BDF8"  # Clean sky blue default


def is_monochrome_image(img_path):
    """Check if an image has very low midtone color saturation."""
    try:
        im = Image.open(img_path).convert("RGB")
        small = im.resize((48, 27), Image.LANCZOS)
        px = get_rgb_pixels(small)

        mid_sats = []
        for r, g, b in px:
            mx = max(r, g, b)
            mn = min(r, g, b)
            if 25 < mx < 230:
                sat = (mx - mn) / float(mx)
                mid_sats.append(sat)
        if mid_sats:
            mean_sat = sum(mid_sats) / len(mid_sats)
            return mean_sat < 0.08
        return True  # Extreme low/high contrast without midtones
    except Exception:
        pass
    return False


def update_fastfetch_logo(accent_hex, fg_hex):
    """Generate theme-sensitive ANSI Bohr atom logo for fastfetch."""
    try:
        h = accent_hex.lstrip("#")
        if len(h) >= 6:
            r = int(h[0:2], 16)
            g = int(h[2:4], 16)
            b = int(h[4:6], 16)
        else:
            r, g, b = (56, 189, 248)

        # Ring orbit color (subtle, dimmed accent)
        rr, rg, rb = int(r * 0.55), int(g * 0.55), int(b * 0.55)

        DOT = f"\033[1;38;2;{r};{g};{b}m●\033[0m"
        RING = f"\033[38;2;{rr};{rg};{rb}m"
        GLYPH = f"\033[1;37mC\033[0m"
        RST = "\033[0m"

        lines = [
            f"           {DOT}           ",
            f"       {RING}╭───────╮{RST}       ",
            f"     {RING}╭─╯{RST}   {DOT}   {RING}╰─╮{RST}     ",
            f"    {RING}╭╯   ╭───╮   ╰╮{RST}    ",
            f"  {DOT} {RING}│    │{RST} {GLYPH} {RING}│    │{RST} {DOT}  ",
            f"    {RING}╰╮   ╰───╯   ╭╯{RST}    ",
            f"     {RING}╰─╮{RST}   {DOT}   {RING}╭─╯{RST}     ",
            f"       {RING}╰───────╯{RST}       ",
            f"           {DOT}           ",
        ]

        logo_path = os.path.expanduser("~/.config/fastfetch/carbon-bohr.txt")
        os.makedirs(os.path.dirname(logo_path), exist_ok=True)
        with open(logo_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    except Exception as e:
        print(f"theme-mk: fastfetch logo update failed: {e}", file=sys.stderr)


def main():
    src_wp = resolve_source_wallpaper()
    if not src_wp or not os.path.exists(src_wp):
        print("theme-mk: no valid wallpaper source found", file=sys.stderr)
        sys.exit(0)

    analysis_img = get_image_frame_for_analysis(src_wp)
    is_mono = is_monochrome_image(analysis_img)
    wp_lower = os.path.basename(src_wp).lower()
    if "carbon" in wp_lower or "black" in wp_lower or "mono" in wp_lower:
        is_mono = True

    mat_data = get_matugen_palette(analysis_img)

    # Base dark carbon palette defaults
    bg_hex = "#121214"
    bg_alt_hex = "#1E1E22"
    fg_hex = "#F4F4F6"
    accent_hex = "#38BDF8"
    accent_lit_hex = "#7DD3FC"
    outline_hex = "#4A4A52"

    if mat_data and not is_mono:
        colors = mat_data.get("colors", {})

        def get_col(name, fallback):
            c = colors.get(name, {})
            val = c.get("dark", {}).get("color") or c.get("default", {}).get("color")
            return val if val else fallback

        # Extract accent from primary
        cand_accent = get_col("primary", accent_hex)
        cand_lit = get_col("primary_container", accent_lit_hex)
        cand_outline = get_col("outline", outline_hex)
        cand_fg = get_col("on_surface", fg_hex)

        # Check if primary is sufficiently saturated, otherwise augment with vibrant color
        cand_lum = get_luminance(cand_accent)
        h, l, s = colorsys.rgb_to_hls(
            int(cand_accent[1:3], 16) / 255.0,
            int(cand_accent[3:5], 16) / 255.0,
            int(cand_accent[5:7], 16) / 255.0,
        )

        if s < 0.20:
            pil_accent = extract_vibrant_fallback(analysis_img)
            if pil_accent and pil_accent != "#38BDF8":
                cand_accent = pil_accent

        accent_hex = cand_accent
        accent_lit_hex = cand_lit
        outline_hex = cand_outline

        # Text color sense: ensure fg is ALWAYS high-contrast (> 0.80 luminance)
        fg_lum = get_luminance(cand_fg)
        if fg_lum >= 0.78:
            fg_hex = cand_fg
        else:
            fg_hex = "#F4F4F6"

    elif is_mono:
        # Pure specular white highlights and high contrast for monochrome wallpapers
        accent_hex = "#FFFFFF"
        accent_lit_hex = "#FFFFFF"
        outline_hex = "#52525B"
        fg_hex = "#FFFFFF"

    else:
        # Fallback to PIL vibrant extraction
        accent_hex = extract_vibrant_fallback(analysis_img)
        accent_lit_hex = "#7DD3FC"
        outline_hex = "#4A4A52"
        fg_hex = "#F4F4F6"

    # Ensure fg_hex is always crisp and bright
    if get_luminance(fg_hex) < 0.80:
        fg_hex = "#F4F4F6"

    palette_dict = {
        "bg": alpha(bg_hex, 0.92),
        "bgAlt": alpha(bg_alt_hex, 0.24),
        "bgHover": alpha(accent_hex, 0.18),
        "bgActive": alpha(accent_hex, 0.32),
        "fg": fg_hex,
        "fgDim": alpha(fg_hex, 0.70),    # Clear, readable secondary text (70% opacity)
        "fgFaint": alpha(fg_hex, 0.42),  # Subtle separators & placeholders (42% opacity)
        "accent": accent_hex,
        "accentLit": accent_lit_hex,
        "outline": alpha(outline_hex, 0.38),
        "ok": OK,
        "warn": WARN,
        "err": ERR,
        "isDark": True,
    }

    # Write theme.json atomically
    json_tmp = JSON_PATH + ".tmp"
    with open(json_tmp, "w", encoding="utf-8") as f:
        json.dump(palette_dict, f, indent=2)
    os.replace(json_tmp, JSON_PATH)

    # Update theme-sensitive Fastfetch Bohr atom logo
    update_fastfetch_logo(accent_hex, fg_hex)

    # Generate desktop and GTK themes via matugen in dark mode
    try:
        if is_mono:
            subprocess.run(
                ["matugen", "color", "hex", "ffffff", "-t", "scheme-monochrome", "-m", "dark"],
                capture_output=True,
                timeout=3.0
            )
        else:
            subprocess.run(
                ["matugen", "image", analysis_img, "--source-color-index", "0", "--prefer", "saturation", "-m", "dark"],
                capture_output=True,
                timeout=3.0
            )
    except Exception:
        pass

    # Ensure system color-scheme is set to prefer-dark
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"],
        capture_output=True
    )

    # Reload hyprland active border colors
    subprocess.run(["hyprctl", "reload"], capture_output=True)

    print(f"theme-mk: updated theme (accent={accent_hex}, fg={fg_hex}, src={os.path.basename(src_wp)})")


if __name__ == "__main__":
    main()
