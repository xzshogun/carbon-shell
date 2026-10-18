#!/usr/bin/env python3
"""Carbon theme generator with intelligent Material You wallpaper adaptation.

Reads the current wallpaper and generates an intelligent Material You palette
using PIL color analysis (with fallback to matugen/caelestia if present).
Ensures vibrant, harmonious accent colors across Quickshell, GTK, Hyprland,
and terminal.

Usage: theme-mk.py [/path/to/wallpaper]
"""

import colorsys
import json
import os
import re
import subprocess
import sys
from PIL import Image

CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
HYPR_CONFIG_DIR = os.path.expanduser("~/.config/hypr")
JSON_PATH = os.path.join(CARBON_CONFIG_DIR, "theme.json")
HYPR_JSON_PATH = os.path.join(HYPR_CONFIG_DIR, "theme.json")
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
    # 1. Command-line argument (ignoring flags)
    for arg in sys.argv[1:]:
        if not arg.startswith("-") and os.path.isfile(arg):
            return os.path.realpath(os.path.abspath(arg))

    # 2. current_wallpaper_path file
    for p_dir in [CARBON_CONFIG_DIR, os.path.expanduser("~/.config/carbon"), os.path.expanduser("~/.config/hypr")]:
        path_file = os.path.join(p_dir, "current_wallpaper_path")
        if os.path.isfile(path_file):
            try:
                with open(path_file, "r", encoding="utf-8") as f:
                    p = f.read().strip()
                if p and os.path.isfile(p):
                    return os.path.realpath(p)
            except Exception:
                pass

    # 3. current_wallpaper symlink or copy
    for p_dir in [CARBON_CONFIG_DIR, os.path.expanduser("~/.config/carbon"), os.path.expanduser("~/.config/hypr")]:
        c_wall = os.path.join(p_dir, "current_wallpaper")
        if os.path.exists(c_wall):
            real_p = os.path.realpath(c_wall)
            if os.path.isfile(real_p):
                return real_p

    # 4. Check active external wallpaper daemons (swww, awww, hyprpaper)
    try:
        r = subprocess.run(["swww", "query"], capture_output=True, text=True, timeout=1.0)
        if r.returncode == 0 and r.stdout:
            m = re.search(r"image:\s*(.+)$", r.stdout.strip(), re.MULTILINE)
            if m:
                cand = m.group(1).strip()
                if os.path.isfile(cand):
                    return os.path.realpath(cand)
    except Exception:
        pass

    try:
        r = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1.0)
        if r.returncode == 0 and r.stdout:
            for line in r.stdout.splitlines():
                parts = line.strip().split()
                if parts and os.path.isfile(parts[-1]):
                    return os.path.realpath(parts[-1])
    except Exception:
        pass

    try:
        r = subprocess.run(["hyprctl", "hyprpaper", "listloaded"], capture_output=True, text=True, timeout=1.0)
        if r.returncode == 0 and r.stdout:
            lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
            if lines and os.path.isfile(lines[-1]):
                return os.path.realpath(lines[-1])
    except Exception:
        pass

    # 5. Cached scaled wallpaper
    scaled = os.path.expanduser("~/.cache/carbon/wallpaper_scaled.jpg")
    if os.path.isfile(scaled):
        return scaled

    return None


def resolve_mode():
    for i, arg in enumerate(sys.argv):
        if arg in ("--light", "-l"):
            return "light"
        if arg in ("--dark", "-d"):
            return "dark"
        if arg in ("--mode", "-m") and i + 1 < len(sys.argv):
            m = sys.argv[i + 1].lower()
            if m in ("light", "dark"):
                return m
    # Fallback to existing theme.json
    try:
        if os.path.isfile(JSON_PATH):
            with open(JSON_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                if "mode" in d and d["mode"] in ("light", "dark"):
                    return d["mode"]
                if "isDark" in d:
                    return "dark" if d["isDark"] else "light"
    except Exception:
        pass
    return "dark"


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


def is_monochrome_image(img_path):
    """Check if an image has very low midtone color saturation."""
    try:
        im = Image.open(img_path).convert("RGB")
        small = im.resize((48, 27), Image.LANCZOS)
        try:
            px = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())
        except Exception:
            return False

        mid_sats = []
        for r, g, b in px:
            mx = max(r, g, b)
            mn = min(r, g, b)
            if 20 < mx < 235:
                sat = (mx - mn) / float(mx) if mx > 0 else 0
                mid_sats.append(sat)
        if mid_sats:
            mean_sat = sum(mid_sats) / len(mid_sats)
            return mean_sat < 0.14
        return True
    except Exception:
        pass
    return False


def find_vibrant_accent(img_path):
    """Scan the wallpaper for a concentrated secondary vibrant accent (calipers, decal, trim)."""
    try:
        im = Image.open(img_path).convert("RGB")
        small = im.resize((160, 90), Image.LANCZOS)
        try:
            px = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())
        except Exception:
            return None

        accent_bins = {}
        for r, g, b in px:
            h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            if s > 0.32 and 0.18 < l < 0.82:
                hb = round(h * 36) % 36
                if hb not in accent_bins:
                    accent_bins[hb] = []
                accent_bins[hb].append((r, g, b, h, l, s))

        if not accent_bins:
            return None

        sorted_bins = sorted(accent_bins.values(), key=len, reverse=True)
        top_cluster = sorted_bins[0]
        if len(top_cluster) >= 8:
            avg_r = int(sum(x[0] for x in top_cluster) / len(top_cluster))
            avg_g = int(sum(x[1] for x in top_cluster) / len(top_cluster))
            avg_b = int(sum(x[2] for x in top_cluster) / len(top_cluster))
            return f"#{avg_r:02x}{avg_g:02x}{avg_b:02x}"
        return None
    except Exception:
        return None


def extract_wallpaper_palette(img_path):
    """Extract an intelligent Material You style palette from wallpaper using PIL."""
    im = Image.open(img_path).convert("RGB")
    small = im.resize((120, 120), Image.LANCZOS)
    try:
        raw = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())
    except Exception:
        raw = []

    bins = {}
    for r, g, b in raw:
        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        if s > 0.16 and 0.12 < l < 0.88:
            hb = round(h * 36) % 36
            score = (s ** 1.2) * (1.0 - abs(l - 0.55) * 0.6)
            if hb not in bins:
                bins[hb] = [0, 0.0, []]
            bins[hb][0] += 1
            bins[hb][1] += score
            if len(bins[hb][2]) < 60:
                bins[hb][2].append((h, s, l))

    if not bins:
        return {
            "accent": "#BFC7D5",
            "accentLit": "#D7E3F8",
            "tertiary": "#BBC7DB",
            "onAccent": "#29313C",
            "bg": "#131314",
            "bgAlt": "#1B1B1D",
            "fg": "#E1E2E8",
            "outline": "#43474E",
            "isDark": True,
            "h_pri": 0.0
        }

    top_bucket = sorted(bins.values(), key=lambda x: x[1], reverse=True)[0]
    samples = top_bucket[2]
    h_pri = sum(x[0] for x in samples) / len(samples)
    s_pri = sum(x[1] for x in samples) / len(samples)

    # Accent (primary): High-legibility, vibrant dark mode color (L: 0.72)
    sat = min(0.92, max(0.58, s_pri * 1.25))
    r, g, b = colorsys.hls_to_rgb(h_pri, 0.72, sat)
    accent_hex = hexs((r * 255, g * 255, b * 255))

    # AccentLit (primary_container): Lighter pastel tint (L: 0.86)
    r, g, b = colorsys.hls_to_rgb(h_pri, 0.86, min(0.85, sat * 0.90))
    accent_lit_hex = hexs((r * 255, g * 255, b * 255))

    # OnAccent (on_primary): Dark text on bright accent
    lum = get_luminance(accent_hex)
    on_accent_hex = "#101116" if lum > 0.45 else "#FFFFFF"

    # Surface & background subtly tinted with wallpaper's dominant hue
    bg_sat = min(0.32, max(0.18, sat * 0.38))
    r, g, b = colorsys.hls_to_rgb(h_pri, 0.08, bg_sat)
    bg_hex = hexs((r * 255, g * 255, b * 255))

    r, g, b = colorsys.hls_to_rgb(h_pri, 0.13, min(0.30, bg_sat * 0.90))
    bg_alt_hex = hexs((r * 255, g * 255, b * 255))

    fg_hex = "#E6E4F0"

    # Outline
    r, g, b = colorsys.hls_to_rgb(h_pri, 0.28, min(0.30, bg_sat * 0.90))
    outline_hex = hexs((r * 255, g * 255, b * 255))

    # Tertiary: Harmonious secondary hue (+55° hue shift) for vibrant multi-color accents
    h_ter = (h_pri + 0.15) % 1.0
    r, g, b = colorsys.hls_to_rgb(h_ter, 0.76, min(0.85, sat * 0.90))
    tertiary_hex = hexs((r * 255, g * 255, b * 255))

    return {
        "accent": accent_hex,
        "accentLit": accent_lit_hex,
        "tertiary": tertiary_hex,
        "onAccent": on_accent_hex,
        "bg": bg_hex,
        "bgAlt": bg_alt_hex,
        "fg": fg_hex,
        "outline": outline_hex,
        "isDark": True,
        "h_pri": h_pri
    }


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
    except Exception:
        pass


def update_gtk_theme(accent_hex, on_accent_hex):
    """Update GTK 3 and GTK 4 accent color CSS if not already generated by Matugen."""
    for gtk_dir in [os.path.expanduser("~/.config/gtk-3.0"), os.path.expanduser("~/.config/gtk-4.0")]:
        os.makedirs(gtk_dir, exist_ok=True)
        css_file = os.path.join(gtk_dir, "gtk.css")
        if os.path.isfile(css_file):
            try:
                with open(css_file, "r", encoding="utf-8") as f:
                    content = f.read()
                    if "@define-color window_bg_color" in content:
                        continue
            except Exception:
                pass
        css_content = f"""/* Dynamically generated by Carbon theme-mk */
@define-color accent_color {accent_hex};
@define-color accent_bg_color {accent_hex};
@define-color accent_fg_color {on_accent_hex};
@define-color destructive_color #f38ba8;
@define-color success_color #a6e3a1;
@define-color warning_color #f9e2af;
@define-color error_color #f38ba8;
"""
        try:
            with open(css_file, "w", encoding="utf-8") as f:
                f.write(css_content)
        except Exception:
            pass


def update_waybar_theme(accent_hex, accent_lit_hex, on_accent_hex, bg_hex, bg_alt_hex, fg_hex, outline_hex, tertiary_hex):
    def hex_to_rgb(h):
        h = h.lstrip("#")
        if len(h) == 6:
            return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return 25, 20, 16

    opacity = 0.88
    try:
        bar_pos_path = os.path.expanduser("~/.config/carbon/carbon-bar-position.json")
        if os.path.isfile(bar_pos_path):
            with open(bar_pos_path, "r", encoding="utf-8") as f:
                d = json.load(f)
                if "shellOpacity" in d:
                    opacity = max(0.1, min(1.0, float(d["shellOpacity"])))
    except Exception:
        pass

    bg_r, bg_g, bg_b = hex_to_rgb(bg_hex)
    bga_r, bga_g, bga_b = hex_to_rgb(bg_alt_hex)
    out_r, out_g, out_b = hex_to_rgb(outline_hex)
    acc_r, acc_g, acc_b = hex_to_rgb(accent_hex)

    css_content = f"""@define-color background rgba({bg_r}, {bg_g}, {bg_b}, {opacity:.2f});
@define-color surface rgba({bga_r}, {bga_g}, {bga_b}, 0.75);
@define-color surface-container rgba({bga_r}, {bga_g}, {bga_b}, 0.90);
@define-color text {fg_hex};
@define-color primary {accent_hex};
@define-color secondary {accent_lit_hex};
@define-color tertiary {tertiary_hex};
@define-color primary-container rgba({acc_r}, {acc_g}, {acc_b}, 0.25);
@define-color on-primary {on_accent_hex};
@define-color border rgba({out_r}, {out_g}, {out_b}, 0.45);
@define-color shadow rgba(0, 0, 0, 0.4);
"""
    for wb_dir in [os.path.expanduser("~/.config/waybar"), os.path.expanduser("~/carbon-shell/waybar")]:
        os.makedirs(wb_dir, exist_ok=True)
        colors_file = os.path.join(wb_dir, "colors.css")
        try:
            with open(colors_file, "w", encoding="utf-8") as f:
                f.write(css_content)
        except Exception:
            pass

    subprocess.run(["pkill", "-SIGUSR2", "-f", "waybar"], capture_output=True)
    subprocess.run(["pkill", "-SIGUSR2", "-x", "waybar-bin"], capture_output=True)
    subprocess.run(["pkill", "-SIGUSR2", "-x", "waybar"], capture_output=True)


<<<<<<< HEAD
def inspect_source_colors(img_path):
    """Query matugen for available source colors."""
=======
def extract_matugen_palette(img_path, mode="dark"):
    """Run matugen to extract authentic Google Material 3 tokens non-interactively."""
>>>>>>> 4fbe11d66723936d1d3273e8aac7ab4b9a0194d6
    try:
        res = subprocess.run(
<<<<<<< HEAD
            ["matugen", "image", "--show-source-colors", img_path],
            capture_output=True, text=True, timeout=4.0
        )
        if res.returncode == 0 and res.stdout.strip():
            colors = [l.strip() for l in res.stdout.splitlines() if l.strip().startswith("#")]
            if colors:
                return colors
=======
            ["matugen", "image", "--source-color-index", "0", "-t", "scheme-tonal-spot", "--prefer", "saturation", "-j", "hex", "-m", mode, img_path],
            capture_output=True, text=True, timeout=5.0, env=env
        )
        if res.returncode == 0 and res.stdout.strip():
            data = json.loads(res.stdout)
            colors = data.get("colors", {})
            def get_c(key, fallback):
                node = colors.get(key, {})
                return node.get(mode, {}).get("color") or node.get("default", {}).get("color") or fallback

            primary = get_c("primary", None)
            if primary:
                return {
                    "primary": primary,
                    "onPrimary": get_c("on_primary", "#ffffff" if mode == "light" else "#00325a"),
                    "primaryContainer": get_c("primary_container", "#d2e4ff" if mode == "light" else "#1a4874"),
                    "onPrimaryContainer": get_c("on_primary_container", "#001d36" if mode == "light" else "#d2e4ff"),
                    "secondary": get_c("secondary", "#535f70" if mode == "light" else "#bbc7db"),
                    "onSecondary": get_c("on_secondary", "#ffffff" if mode == "light" else "#253141"),
                    "secondaryContainer": get_c("secondary_container", "#d7e3f8" if mode == "light" else "#3c4858"),
                    "onSecondaryContainer": get_c("on_secondary_container", "#101c2b" if mode == "light" else "#d7e3f8"),
                    "tertiary": get_c("tertiary", "#6b5778" if mode == "light" else "#d7bde4"),
                    "onTertiary": get_c("on_tertiary", "#ffffff" if mode == "light" else "#3b2947"),
                    "tertiaryContainer": get_c("tertiary_container", "#f3daff" if mode == "light" else "#533f5f"),
                    "onTertiaryContainer": get_c("on_tertiary_container", "#251432" if mode == "light" else "#f3daff"),
                    "surface": get_c("surface", "#f8f9ff" if mode == "light" else "#111418"),
                    "surfaceDim": get_c("surface_dim", "#d8dae0" if mode == "light" else "#111418"),
                    "surfaceBright": get_c("surface_bright", "#f8f9ff" if mode == "light" else "#37393e"),
                    "surfaceContainerLowest": get_c("surface_container_lowest", "#ffffff" if mode == "light" else "#0b0e13"),
                    "surfaceContainerLow": get_c("surface_container_low", "#f2f3fa" if mode == "light" else "#191c20"),
                    "surfaceContainer": get_c("surface_container", "#eceef4" if mode == "light" else "#1d2024"),
                    "surfaceContainerHigh": get_c("surface_container_high", "#e6e8ee" if mode == "light" else "#272a2f"),
                    "surfaceContainerHighest": get_c("surface_container_highest", "#e1e2e8" if mode == "light" else "#32353a"),
                    "onSurface": get_c("on_surface", "#191c20" if mode == "light" else "#e1e2e8"),
                    "surfaceVariant": get_c("surface_variant", "#e1e2ec" if mode == "light" else "#43474e"),
                    "onSurfaceVariant": get_c("on_surface_variant", "#43474e" if mode == "light" else "#c3c6cf"),
                    "outline": get_c("outline", "#73777f" if mode == "light" else "#8d9199"),
                    "outlineVariant": get_c("outline_variant", "#c3c6cf" if mode == "light" else "#43474e"),
                    "error": get_c("error", "#ba1a1a" if mode == "light" else "#ffb4ab"),
                    "onError": get_c("on_error", "#ffffff" if mode == "light" else "#690005"),
                    "errorContainer": get_c("error_container", "#ffdad6" if mode == "light" else "#93000a"),
                }
>>>>>>> 4fbe11d66723936d1d3273e8aac7ab4b9a0194d6
    except Exception:
        pass
    return []


def parse_matugen_json(data):
    colors = data.get("colors", {})
    def get_c(key, fallback):
        node = colors.get(key, {})
        return node.get("dark", {}).get("color") or node.get("default", {}).get("color") or fallback

    primary = get_c("primary", None)
    if primary:
        return {
            "primary": primary,
            "onPrimary": get_c("on_primary", "#29313c"),
            "primaryContainer": get_c("primary_container", "#3f4753"),
            "onPrimaryContainer": get_c("on_primary_container", "#d7e3f8"),
            "secondary": get_c("secondary", "#bbc7db"),
            "onSecondary": get_c("on_secondary", "#253141"),
            "secondaryContainer": get_c("secondary_container", "#3c4858"),
            "onSecondaryContainer": get_c("on_secondary_container", "#d7e3f8"),
            "tertiary": get_c("tertiary", "#bbc7db"),
            "onTertiary": get_c("on_tertiary", "#253141"),
            "tertiaryContainer": get_c("tertiary_container", "#3c4858"),
            "onTertiaryContainer": get_c("on_tertiary_container", "#d7e3f8"),
            "surface": get_c("surface", "#131314"),
            "surfaceDim": get_c("surface_dim", "#131314"),
            "surfaceBright": get_c("surface_bright", "#36393e"),
            "surfaceContainerLowest": get_c("surface_container_lowest", "#0e0e0f"),
            "surfaceContainerLow": get_c("surface_container_low", "#1b1b1d"),
            "surfaceContainer": get_c("surface_container", "#1f1f21"),
            "surfaceContainerHigh": get_c("surface_container_high", "#2a2a2b"),
            "surfaceContainerHighest": get_c("surface_container_highest", "#353536"),
            "onSurface": get_c("on_surface", "#e1e2e8"),
            "surfaceVariant": get_c("surface_variant", "#474648"),
            "onSurfaceVariant": get_c("on_surface_variant", "#c3c6cf"),
            "outline": get_c("outline", "#8d9199"),
            "outlineVariant": get_c("outline_variant", "#43474e"),
            "error": get_c("error", "#ffb4ab"),
            "onError": get_c("on_error", "#690005"),
            "errorContainer": get_c("error_container", "#93000a"),
        }
    return None


def extract_matugen_palette(img_path, is_mono=False, accent_override=None):
    """Run matugen with smart scheme and color index adaptation."""
    try:
        env = {**os.environ, "MATUGEN_NO_HOOK": "1"}

        # 1. Accent override (e.g. vibrant caliper/decal)
        if accent_override:
            clean_hex = accent_override.lstrip("#")
            res = subprocess.run(
                ["matugen", "color", "hex", clean_hex, "-t", "scheme-vibrant", "-j", "hex", "-m", "dark"],
                capture_output=True, text=True, timeout=5.0, env=env
            )
            if res.returncode == 0 and res.stdout.strip():
                data = json.loads(res.stdout)
                m = parse_matugen_json(data)
                if m:
                    subprocess.run(
                        ["matugen", "color", "hex", clean_hex, "-t", "scheme-vibrant", "-m", "dark"],
                        capture_output=True, timeout=4.0, env=env
                    )
                    return m

        # 2. Inspect available source colors
        src_colors = inspect_source_colors(img_path)
        chosen_idx = 0
        scheme_type = "scheme-tonal-spot"

        def get_hls(hex_str):
            h = hex_str.lstrip("#")
            r, g, b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return colorsys.rgb_to_hls(r, g, b)

        if src_colors:
            cand_info = []
            for i, c in enumerate(src_colors):
                h, l, s = get_hls(c)
                cand_info.append((i, c, h, l, s))

            # Pick secondary accent if index 0 is a dull reflection
            best_idx = 0
            best_sat = cand_info[0][4]
            for idx, col, h, l, s in cand_info[1:3]:
                if s > best_sat + 0.10:
                    best_sat = s
                    best_idx = idx

            chosen_idx = best_idx
            chosen_hls = cand_info[chosen_idx]
            chosen_sat = chosen_hls[4]
            chosen_lum = chosen_hls[3]

            if is_mono or (chosen_sat < 0.20 and chosen_lum < 0.35):
                scheme_type = "scheme-neutral"
            elif chosen_sat > 0.40:
                scheme_type = "scheme-vibrant"
            else:
                scheme_type = "scheme-tonal-spot"
        else:
            chosen_idx = 0
            scheme_type = "scheme-neutral" if is_mono else "scheme-tonal-spot"

        # Safe in-bounds command
        cmd_json = [
            "matugen", "image",
            "--source-color-index", str(chosen_idx),
            "-t", scheme_type,
            "--prefer", "saturation",
            "-j", "hex",
            "-m", "dark",
            img_path
        ]
        res = subprocess.run(cmd_json, capture_output=True, text=True, timeout=5.0, env=env)
        if res.returncode == 0 and res.stdout.strip():
            data = json.loads(res.stdout)
            m = parse_matugen_json(data)
            if m:
                cmd_apply = [
                    "matugen", "image",
                    "--source-color-index", str(chosen_idx),
                    "-t", scheme_type,
                    "--prefer", "saturation",
                    "-m", "dark",
                    img_path
                ]
                subprocess.run(cmd_apply, capture_output=True, timeout=4.0, env=env)
                return m
    except Exception as e:
        print(f"theme-mk: matugen error: {e}", file=sys.stderr)
    return None


def main():
    mode = resolve_mode()
    src_wp = resolve_source_wallpaper()
    if not src_wp or not os.path.exists(src_wp):
        print("theme-mk: no valid wallpaper source found", file=sys.stderr)
        sys.exit(0)

    analysis_img = get_image_frame_for_analysis(src_wp)
    is_mono = is_monochrome_image(analysis_img)
    wp_lower = os.path.basename(src_wp).lower()
    if any(k in wp_lower for k in ("carbon", "black", "mono", "dark", "gt3", "porsche", "grey", "gray")):
        is_mono = True

<<<<<<< HEAD
    # Check for concentrated vibrant secondary accents (brake calipers, decals, trim)
    vibrant_accent = find_vibrant_accent(analysis_img)

    m3 = extract_matugen_palette(analysis_img, is_mono=is_mono, accent_override=vibrant_accent)
    if m3:
        accent_hex = m3["primary"]
        accent_lit_hex = m3["primaryContainer"]
        tertiary_hex = m3["tertiary"]
        on_accent_hex = m3["onPrimary"]
        bg_hex = m3["surface"]
        bg_alt_hex = m3["surfaceContainerHigh"]
        fg_hex = m3["onSurface"]
        outline_hex = m3["outline"]
    else:
        pal = extract_wallpaper_palette(analysis_img)
        accent_hex = pal["accent"]
        accent_lit_hex = pal["accentLit"]
        tertiary_hex = pal["tertiary"]
        on_accent_hex = pal["onAccent"]
        bg_hex = pal["bg"]
        bg_alt_hex = pal["bgAlt"]
        fg_hex = pal["fg"]
        outline_hex = pal["outline"]
=======
    m3 = None
    if is_mono:
        if mode == "light":
            accent_hex = "#2b2b30"
            accent_lit_hex = "#484850"
            tertiary_hex = "#5c5c66"
            on_accent_hex = "#ffffff"
            bg_hex = "#f8f9fc"
            bg_alt_hex = "#eceef2"
            fg_hex = "#191c20"
            outline_hex = "#73777f"
        else:
            accent_hex = "#E2E2E8"
            accent_lit_hex = "#FFFFFF"
            tertiary_hex = "#D4D4DC"
            on_accent_hex = "#141418"
            bg_hex = "#121215"
            bg_alt_hex = "#1A1A1F"
            fg_hex = "#E4E4E8"
            outline_hex = "#484852"
        try:
            subprocess.run(
                ["matugen", "color", "hex", "111111" if mode == "light" else "ffffff", "-t", "scheme-monochrome", "-m", mode],
                capture_output=True, timeout=4.0
            )
        except Exception:
            pass
    else:
        m3 = extract_matugen_palette(analysis_img, mode=mode)
        if m3:
            accent_hex = m3["primary"]
            accent_lit_hex = m3["primaryContainer"]
            tertiary_hex = m3["tertiary"]
            on_accent_hex = m3["onPrimary"]
            bg_hex = m3["surface"]
            bg_alt_hex = m3["surfaceContainerHigh"]
            fg_hex = m3["onSurface"]
            outline_hex = m3["outline"]
            try:
                env = {**os.environ, "MATUGEN_NO_HOOK": "1"}
                subprocess.run(
                    ["matugen", "image", "--source-color-index", "0", "-t", "scheme-tonal-spot", "--prefer", "saturation", "-m", mode, src_wp],
                    capture_output=True, timeout=4.0, env=env
                )
            except Exception:
                pass
        else:
            pal = extract_wallpaper_palette(analysis_img)
            accent_hex = pal["accent"]
            accent_lit_hex = pal["accentLit"]
            tertiary_hex = pal["tertiary"]
            on_accent_hex = pal["onAccent"]
            bg_hex = pal["bg"]
            bg_alt_hex = pal["bgAlt"]
            fg_hex = pal["fg"]
            outline_hex = pal["outline"]
>>>>>>> 4fbe11d66723936d1d3273e8aac7ab4b9a0194d6

    palette_dict = {
        "bg": alpha(bg_hex, 0.92),
        "bgAlt": alpha(bg_alt_hex, 0.75),
        "bgHover": alpha(accent_hex, 0.15 if mode == "light" else 0.20),
        "bgActive": alpha(accent_hex, 0.25 if mode == "light" else 0.35),
        "fg": fg_hex,
        "fgDim": alpha(fg_hex, 0.70),
        "fgFaint": alpha(fg_hex, 0.42),
        "accent": accent_hex,
        "accentLit": accent_lit_hex,
        "tertiary": tertiary_hex,
        "onAccent": on_accent_hex,
        "outline": alpha(outline_hex, 0.30 if mode == "light" else 0.40),
        "ok": OK,
        "warn": WARN,
        "err": ERR,
        "isDark": (mode == "dark"),
        "mode": mode,
    }

    # Write theme.json atomically to both carbon and hypr configs
    for json_p in [JSON_PATH, HYPR_JSON_PATH]:
        os.makedirs(os.path.dirname(json_p), exist_ok=True)
        tmp = json_p + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(palette_dict, f, indent=2)
            os.replace(tmp, json_p)
        except Exception:
            pass

    # Write Caelestia scheme.json so M3 consumers receive full color tokens
    caelestia_scheme_path = os.path.expanduser("~/.local/state/caelestia/scheme.json")
    os.makedirs(os.path.dirname(caelestia_scheme_path), exist_ok=True)
    cael_data = {
        "name": "carbon-dynamic",
        "flavour": mode,
        "mode": mode,
        "variant": "tonalspot",
        "colours": {
            "primary": accent_hex.lstrip("#"),
            "onPrimary": on_accent_hex.lstrip("#"),
            "primaryContainer": accent_lit_hex.lstrip("#"),
            "onPrimaryContainer": (m3.get("onPrimaryContainer", on_accent_hex) if m3 else on_accent_hex).lstrip("#"),
            "accentLit": accent_lit_hex.lstrip("#"),
            "secondary": (m3.get("secondary", tertiary_hex) if m3 else tertiary_hex).lstrip("#"),
            "onSecondary": (m3.get("onSecondary", on_accent_hex) if m3 else on_accent_hex).lstrip("#"),
            "secondaryContainer": (m3.get("secondaryContainer", bg_alt_hex) if m3 else bg_alt_hex).lstrip("#"),
            "onSecondaryContainer": (m3.get("onSecondaryContainer", fg_hex) if m3 else fg_hex).lstrip("#"),
            "tertiary": tertiary_hex.lstrip("#"),
            "onTertiary": (m3.get("onTertiary", on_accent_hex) if m3 else on_accent_hex).lstrip("#"),
            "tertiaryContainer": (m3.get("tertiaryContainer", accent_lit_hex) if m3 else accent_lit_hex).lstrip("#"),
            "onTertiaryContainer": (m3.get("onTertiaryContainer", on_accent_hex) if m3 else on_accent_hex).lstrip("#"),
            "surface": bg_hex.lstrip("#"),
            "surfaceDim": (m3.get("surfaceDim", bg_hex) if m3 else bg_hex).lstrip("#"),
            "surfaceBright": (m3.get("surfaceBright", bg_alt_hex) if m3 else bg_alt_hex).lstrip("#"),
            "surfaceContainerLowest": (m3.get("surfaceContainerLowest", "ffffff" if mode == "light" else "000000") if m3 else ("ffffff" if mode == "light" else "000000")).lstrip("#"),
            "surfaceContainerLow": (m3.get("surfaceContainerLow", bg_hex) if m3 else bg_hex).lstrip("#"),
            "surfaceContainer": (m3.get("surfaceContainer", bg_hex) if m3 else bg_hex).lstrip("#"),
            "surfaceContainerHigh": bg_alt_hex.lstrip("#"),
            "surfaceContainerHighest": (m3.get("surfaceContainerHighest", bg_alt_hex) if m3 else bg_alt_hex).lstrip("#"),
            "onSurface": fg_hex.lstrip("#"),
            "surfaceVariant": (m3.get("surfaceVariant", bg_alt_hex) if m3 else bg_alt_hex).lstrip("#"),
            "onSurfaceVariant": (m3.get("onSurfaceVariant", outline_hex) if m3 else outline_hex).lstrip("#"),
            "outline": outline_hex.lstrip("#"),
            "outlineVariant": (m3.get("outlineVariant", outline_hex) if m3 else outline_hex).lstrip("#"),
            "success": OK.lstrip("#"),
            "error": (m3.get("error", ERR) if m3 else ERR).lstrip("#"),
            "onError": (m3.get("onError", "690005") if m3 else "690005").lstrip("#"),
            "errorContainer": (m3.get("errorContainer", "93000a") if m3 else "93000a").lstrip("#")
        }
    }
    try:
        with open(caelestia_scheme_path + ".tmp", "w", encoding="utf-8") as f:
            json.dump(cael_data, f, indent=2)
        os.replace(caelestia_scheme_path + ".tmp", caelestia_scheme_path)
    except Exception:
        pass

    # 1. Update GTK 3 & 4 Theme
    update_gtk_theme(accent_hex, on_accent_hex)

    # 2. Update Fastfetch Bohr atom logo
    update_fastfetch_logo(accent_hex, fg_hex)

    # 3. Ensure system color-scheme is set
    color_scheme_pref = "prefer-light" if mode == "light" else "prefer-dark"
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", color_scheme_pref],
        capture_output=True
    )

    # 4. Update Hyprland active window border dynamically
    h_acc = accent_hex.lstrip("#")
    h_lit = accent_lit_hex.lstrip("#")
    subprocess.run([
        "hyprctl", "keyword", "general:col.active_border",
        f"rgba({h_acc}ee) rgba({h_lit}aa) 45deg"
    ], capture_output=True)

    # 5. Update Waybar CSS theme
    update_waybar_theme(accent_hex, accent_lit_hex, on_accent_hex, bg_hex, bg_alt_hex, fg_hex, outline_hex, tertiary_hex)

    # 6. Notify Carbon Quickshell to reload Theme singleton immediately
    try:
        ipc_path = os.path.join(CARBON_CONFIG_DIR, "scripts", "carbon-ipc.sh")
        if not os.path.isfile(ipc_path):
            ipc_path = os.path.expanduser("~/.config/carbon/scripts/carbon-ipc.sh")
        if not os.path.isfile(ipc_path):
            ipc_path = os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh")
        if os.path.isfile(ipc_path):
            env_ipc = {**os.environ, "CARBON_IPC_NO_REBUILD": "1"}
            subprocess.run(["sh", ipc_path, "theme-reload"], capture_output=True, timeout=1.5, env=env_ipc)
    except Exception:
        pass

    print(f"theme-mk: updated theme (accent={accent_hex}, fg={fg_hex}, src={os.path.basename(src_wp)})")


if __name__ == "__main__":
    main()
