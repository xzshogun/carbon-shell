#!/usr/bin/env python3
"""
Carbon Config Editor
A lightweight modern GTK4 + Libadwaita GUI for easily customizing
Hyprland variables and dotfiles without manual code editing.
"""

import os
import re
import subprocess
import sys
import threading

# Ensure instant GTK4 launch without Vulkan GPU enumeration failure stall
os.environ.setdefault("GSK_RENDERER", "cairo")

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gtk, Adw, Gio, GLib, Pango, Gdk, PangoCairo
import cairo
import math
import time

import json
import shutil

VARIABLES_PATH = os.path.expanduser("~/.config/hypr/variables.lua")
BAR_MODE_PATH = os.path.expanduser("~/.config/hypr/carbon-bar-mode.json")
BAR_POS_PATH = os.path.expanduser("~/.config/hypr/carbon-bar-position.json")
CLOCK_STYLE_PATH = os.path.expanduser("~/.config/hypr/carbon-clock-style.json")
LOCKSCREEN_CONFIG_PATH = os.path.expanduser("~/.config/hypr/carbon-lockscreen.json")
KEYBINDS_CONF_PATH = os.path.expanduser("~/.config/hypr/configs/keybinds.conf")
GESTURES_LUA_PATH = os.path.expanduser("~/.config/hypr/hyprland/gestures.lua")
INPUT_CONF_PATH = os.path.expanduser("~/.config/hypr/configs/input.conf")
CUSTOM_GESTURES_PATH = os.path.expanduser("~/.config/hypr/carbon-custom-gestures.json")

CONFIG_FILES = {
    "Bar Mode (carbon-bar-mode.json)": BAR_MODE_PATH,
    "Bar Position & Layout (carbon-bar-position.json)": BAR_POS_PATH,
    "Top Bar Clock Style (carbon-clock-style.json)": CLOCK_STYLE_PATH,
    "Lock Screen Options (carbon-lockscreen.json)": LOCKSCREEN_CONFIG_PATH,
    "Custom Gestures (carbon-custom-gestures.json)": CUSTOM_GESTURES_PATH,
    "Hyprland Variables (variables.lua)": VARIABLES_PATH,
    "Gestures Lua (gestures.lua)": GESTURES_LUA_PATH,
    "Input & Touchpad (input.conf)": INPUT_CONF_PATH,
    "Keybindings (keybinds.conf)": KEYBINDS_CONF_PATH,
    "Keybindings Lua (keybinds.lua)": os.path.expanduser("~/.config/hypr/hyprland/keybinds.lua"),
    "Main Hyprland (hyprland.conf)": os.path.expanduser("~/.config/hypr/hyprland.conf"),
    "Lock Screen (hyprlock.conf)": os.path.expanduser("~/.config/hypr/hyprlock.conf"),
    "Quick Settings Layout (carbon-qs-layout.json)": os.path.expanduser("~/.config/hypr/carbon-qs-layout.json"),
}

FLOAT_KEYS = {"windowOpacity", "touchpadScrollFactor"}

BAR_MODES = [
    {
        "id": "pill",
        "name": "Pill Mode",
        "subtitle": "Connected floating continuous pill bar spanning the top or bottom of the display",
        "icon": "view-grid-symbolic"
    },
    {
        "id": "notch",
        "name": "Notch Mode",
        "subtitle": "Screen-attached curved notch bars with integrated workspaces, clock, vinyl music, and status indicators",
        "icon": "user-desktop-symbolic"
    },
    {
        "id": "minimal",
        "name": "Minimal Mode (Dynamic Island)",
        "subtitle": "Ultra-lightweight single dynamic island capsule optimized for lowest CPU, GPU, and RAM usage",
        "icon": "open-menu-symbolic"
    }
]

CLOCK_DESIGNS = [
    {
        "id": "titan",
        "name": "Titan 3D Pop",
        "subtitle": "Titan One bold dual-tone font with raised 3D shadow",
        "markup": '<span font_family="Titan One" size="17000" weight="bold" color="#ffffff">10</span><span font_family="Titan One" size="17000" weight="bold" color="#38bdf8">:19</span>'
    },
    {
        "id": "stacked",
        "name": "Stacked Dual (Enlarged)",
        "subtitle": "Prominent dual-deck vertical hours above minutes with cyan accent bar",
        "markup": '<span font_family="Open Sans" size="11000" weight="bold" color="#ffffff">10</span>\n<span font_family="Open Sans" size="11000" weight="bold" color="#38bdf8">19</span>'
    },
    {
        "id": "mono_glow",
        "name": "Nordic Monospace",
        "subtitle": "Precision JetBrains Mono with glowing breathing separator dot",
        "markup": '<span font_family="JetBrainsMono Nerd Font" size="13000" weight="bold" color="#ffffff">10</span> <span font_family="JetBrainsMono Nerd Font" size="13000" weight="bold" color="#38bdf8">·</span> <span font_family="JetBrainsMono Nerd Font" size="13000" weight="bold" color="#38bdf8">19</span>'
    },
    {
        "id": "split_pill",
        "name": "Dual Glass Capsules",
        "subtitle": "Distinct frosted glass badge tiles for hours and minutes",
        "markup": '<span background="#232a35" font_family="Open Sans" size="11000" weight="bold" color="#ffffff"> 10 </span> <span color="#38bdf8" weight="bold">:</span> <span background="#232a35" font_family="Open Sans" size="11000" weight="bold" color="#38bdf8"> 19 </span>'
    },
    {
        "id": "orbitron",
        "name": "Cyberpunk HUD Matrix",
        "subtitle": "Futuristic telemetry HUD brackets with high-contrast digits",
        "markup": '<span font_family="JetBrainsMono Nerd Font" size="12000" weight="bold" color="#38bdf8">[ </span><span font_family="Google Sans Flex" size="12000" weight="bold" color="#ffffff">10</span><span font_family="Google Sans Flex" size="12000" weight="bold" color="#38bdf8">:</span><span font_family="Google Sans Flex" size="12000" weight="bold" color="#ffffff">19</span><span font_family="JetBrainsMono Nerd Font" size="12000" weight="bold" color="#38bdf8"> ]</span>'
    },
    {
        "id": "minimal_pill",
        "name": "Aero Pill Capsule",
        "subtitle": "Unified frosted glass capsule with illuminated accent border",
        "markup": '<span background="#1e2736" font_family="Google Sans Flex" size="11000" weight="bold" color="#ffffff">  10</span><span background="#1e2736" font_family="Google Sans Flex" size="11000" weight="bold" color="#38bdf8">:19  </span>'
    },
]


def read_clock_style():
    if os.path.isfile(CLOCK_STYLE_PATH):
        try:
            with open(CLOCK_STYLE_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                s = d.get("style", "titan")
                if any(cd["id"] == s for cd in CLOCK_DESIGNS):
                    return s
        except Exception:
            pass
    return "titan"


def read_bar_position():
    default_pos = {
        "edge": "top",
        "leftAlign": "center",
        "centerAlign": "center",
        "rightAlign": "center",
        "leftEdge": "top",
        "centerEdge": "top",
        "rightEdge": "top",
        "mainBarEdge": "top",
        "musicBarEdge": "top",
        "musicBarContent": "both"
    }
    if os.path.isfile(BAR_POS_PATH):
        try:
            with open(BAR_POS_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                default_pos.update(d)
                if "mainBarEdge" not in d and "edge" in d:
                    default_pos["mainBarEdge"] = d["edge"]
                if "musicBarEdge" not in d and "edge" in d:
                    default_pos["musicBarEdge"] = d["edge"]
        except Exception:
            pass
    curr_m = read_bar_mode()
    if curr_m == "pill":
        if default_pos.get("mainBarEdge") not in ["top", "bottom"]:
            default_pos["mainBarEdge"] = "top"
            default_pos["edge"] = "top"
        if default_pos.get("musicBarEdge") not in ["top", "bottom"]:
            default_pos["musicBarEdge"] = "top"
    return default_pos


def save_bar_position(pos_dict):
    try:
        with open(BAR_POS_PATH, "w", encoding="utf-8") as f:
            json.dump(pos_dict, f, indent=2)
        subprocess.run(
            ["sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), "reload-bar-pos"],
            capture_output=True,
            timeout=2.0
        )
    except Exception as e:
        print("Error saving bar position:", e)


def read_bar_mode():
    if os.path.isfile(BAR_MODE_PATH):
        try:
            with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                m = d.get("mode", "pill")
                if m == "three_islands":
                    return "pill"
                if any(bm["id"] == m for bm in BAR_MODES):
                    return m
        except Exception:
            pass
    return "pill"


def save_bar_mode(mode_id):
    try:
        data = {}
        if os.path.isfile(BAR_MODE_PATH):
            try:
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                pass
        data["mode"] = mode_id
        with open(BAR_MODE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        subprocess.run(
            ["sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), f"bar-mode {mode_id}"],
            capture_output=True,
            timeout=2.0
        )
    except Exception as e:
        print("Error saving bar mode:", e)


def read_island_persistent():
    if os.path.isfile(BAR_MODE_PATH):
        try:
            with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                return d.get("islandPersistent", True)
        except Exception:
            pass
    return True


def save_island_persistent(val):
    try:
        data = {}
        if os.path.isfile(BAR_MODE_PATH):
            try:
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                pass
        data["islandPersistent"] = bool(val)
        with open(BAR_MODE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        subprocess.run(
            ["sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), f"island-persistent {'true' if val else 'false'}"],
            capture_output=True,
            timeout=2.0
        )
    except Exception as e:
        print("Error saving island persistent:", e)


def read_wallpaper_anim():
    if os.path.isfile(BAR_MODE_PATH):
        try:
            with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                return d.get("wallpaperAnimation", "cinematic")
        except Exception:
            pass
    return "cinematic"


def save_wallpaper_anim(anim_id):
    try:
        data = {}
        if os.path.isfile(BAR_MODE_PATH):
            try:
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                pass
        data["wallpaperAnimation"] = str(anim_id)
        with open(BAR_MODE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print("Error saving wallpaper anim:", e)


def read_wallpaper_duration():
    if os.path.isfile(BAR_MODE_PATH):
        try:
            with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                return int(d.get("wallpaperDuration", 800))
        except Exception:
            pass
    return 800


def save_wallpaper_duration(val):
    try:
        data = {}
        if os.path.isfile(BAR_MODE_PATH):
            try:
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                pass
        data["wallpaperDuration"] = int(val)
        with open(BAR_MODE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print("Error saving wallpaper duration:", e)


def read_lockscreen_config():
    defaults = {
        "visualizer": True,
        "mediaOverlay": True,
        "clock": True,
    }
    if os.path.isfile(LOCKSCREEN_CONFIG_PATH):
        try:
            with open(LOCKSCREEN_CONFIG_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                defaults.update(d)
        except Exception:
            pass
    return defaults


def save_lockscreen_config(cfg):
    try:
        with open(LOCKSCREEN_CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        print("Error saving lockscreen config:", e)


def read_variables():
    """Extract known keys from variables.lua."""
    data = {}
    if not os.path.isfile(VARIABLES_PATH):
        return data
    with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    patterns = {
        "terminal": r'terminal\s*=\s*"([^"]*)"',
        "browser": r'browser\s*=\s*"([^"]*)"',
        "editor": r'editor\s*=\s*"([^"]*)"',
        "fileExplorer": r'fileExplorer\s*=\s*"([^"]*)"',
        "blurEnabled": r'blurEnabled\s*=\s*(true|false)',
        "blurSize": r'blurSize\s*=\s*([0-9\.]+)',
        "blurPasses": r'blurPasses\s*=\s*([0-9\.]+)',
        "shadowEnabled": r'shadowEnabled\s*=\s*(true|false)',
        "shadowRange": r'shadowRange\s*=\s*([0-9\.]+)',
        "workspaceGaps": r'workspaceGaps\s*=\s*([0-9\.]+)',
        "windowGapsIn": r'windowGapsIn\s*=\s*([0-9\.]+)',
        "windowGapsOut": r'windowGapsOut\s*=\s*([0-9\.]+)',
        "windowOpacity": r'windowOpacity\s*=\s*([0-9\.]+)',
        "windowRounding": r'windowRounding\s*=\s*([0-9\.]+)',
        "windowBorderSize": r'windowBorderSize\s*=\s*([0-9\.]+)',
        "volumeStep": r'volumeStep\s*=\s*([0-9\.]+)',
    }

    for key, pat in patterns.items():
        m = re.search(pat, content)
        if m:
            val = m.group(1)
            if val == "true":
                data[key] = True
            elif val == "false":
                data[key] = False
            elif key in FLOAT_KEYS:
                try:
                    data[key] = float(val)
                except ValueError:
                    data[key] = val
            else:
                try:
                    data[key] = int(round(float(val)))
                except ValueError:
                    data[key] = val
    return data


def read_gesture_settings():
    settings = {
        "workspaceSwipeFingers": 4,
        "workspace_swipe_distance": 700,
        "workspace_swipe_create_new": True,
        "workspace_swipe_direction_lock": True,
        "natural_scroll": True,
        "touchpadDisableTyping": True,
        "touchpadScrollFactor": 0.3,
    }
    if os.path.isfile(VARIABLES_PATH):
        try:
            with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
                c = f.read()
            m = re.search(r'workspaceSwipeFingers\s*=\s*([0-9]+)', c)
            if m: settings["workspaceSwipeFingers"] = int(m.group(1))
            m = re.search(r'touchpadDisableTyping\s*=\s*(true|false)', c)
            if m: settings["touchpadDisableTyping"] = (m.group(1) == "true")
            m = re.search(r'touchpadScrollFactor\s*=\s*([0-9\.]+)', c)
            if m: settings["touchpadScrollFactor"] = float(m.group(1))
        except Exception:
            pass

    if os.path.isfile(GESTURES_LUA_PATH):
        try:
            with open(GESTURES_LUA_PATH, "r", encoding="utf-8") as f:
                c = f.read()
            m = re.search(r'workspace_swipe_distance\s*=\s*([0-9]+)', c)
            if m: settings["workspace_swipe_distance"] = int(m.group(1))
            m = re.search(r'workspace_swipe_create_new\s*=\s*(true|false)', c)
            if m: settings["workspace_swipe_create_new"] = (m.group(1) == "true")
            m = re.search(r'workspace_swipe_direction_lock\s*=\s*(true|false)', c)
            if m: settings["workspace_swipe_direction_lock"] = (m.group(1) == "true")
        except Exception:
            pass

    if os.path.isfile(INPUT_CONF_PATH):
        try:
            with open(INPUT_CONF_PATH, "r", encoding="utf-8") as f:
                c = f.read()
            m = re.search(r'natural_scroll\s*=\s*(true|false)', c)
            if m: settings["natural_scroll"] = (m.group(1) == "true")
        except Exception:
            pass

    return settings


def save_gesture_setting(key, value):
    try:
        if key in ["workspaceSwipeFingers", "touchpadDisableTyping", "touchpadScrollFactor"]:
            if os.path.isfile(VARIABLES_PATH):
                with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
                    content = f.read()
                if isinstance(value, bool):
                    v_str = "true" if value else "false"
                    content = re.sub(rf'({key}\s*=\s*)(true|false)', rf'\g<1>{v_str}', content)
                elif isinstance(value, float):
                    content = re.sub(rf'({key}\s*=\s*)[0-9\.]+', rf'\g<1>{value:.2f}', content)
                else:
                    content = re.sub(rf'({key}\s*=\s*)[0-9]+', rf'\g<1>{int(value)}', content)
                with open(VARIABLES_PATH, "w", encoding="utf-8") as f:
                    f.write(content)

        if key in ["workspace_swipe_distance", "workspace_swipe_create_new", "workspace_swipe_direction_lock"]:
            if os.path.isfile(GESTURES_LUA_PATH):
                with open(GESTURES_LUA_PATH, "r", encoding="utf-8") as f:
                    content = f.read()
                if isinstance(value, bool):
                    v_str = "true" if value else "false"
                    content = re.sub(rf'({key}\s*=\s*)(true|false)', rf'\g<1>{v_str}', content)
                else:
                    content = re.sub(rf'({key}\s*=\s*)[0-9]+', rf'\g<1>{int(value)}', content)
                with open(GESTURES_LUA_PATH, "w", encoding="utf-8") as f:
                    f.write(content)

        if key == "natural_scroll":
            if os.path.isfile(INPUT_CONF_PATH):
                with open(INPUT_CONF_PATH, "r", encoding="utf-8") as f:
                    content = f.read()
                v_str = "true" if value else "false"
                content = re.sub(r'(\bnatural_scroll\s*=\s*)(true|false)', rf'\g<1>{v_str}', content)
                with open(INPUT_CONF_PATH, "w", encoding="utf-8") as f:
                    f.write(content)

        subprocess.run(["hyprctl", "reload"], capture_output=True, check=False)
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "input-touchpad-symbolic",
            "Gestures Updated", f"{key} updated"
        ], check=False)
    except Exception as e:
        print(f"Failed to save gesture setting {key}:", e)


def read_custom_gestures():
    defaults = {
        "three_finger_swipe_up": "Workspaces & Windows Overview (sh ~/.config/hypr/scripts/carbon-ipc.sh toggle-overview)",
        "three_finger_swipe_down": "Take Full Screen Screenshot (/home/shogun/.local/bin/carbon-screenshot-full.sh)",
        "three_finger_swipe_left": "Switch Workspace Backward (-1)",
        "three_finger_swipe_right": "Switch Workspace Forward (+1)",
        "four_finger_swipe_horizontal": "Continuous Workspace Swipe (Trackpad Desktop Paging)",
        "four_finger_swipe_down": "Suspend and Hibernate System (systemctl suspend-then-hibernate)",
    }
    if os.path.isfile(CUSTOM_GESTURES_PATH):
        try:
            with open(CUSTOM_GESTURES_PATH, "r", encoding="utf-8") as f:
                d = json.load(f)
                defaults.update(d)
        except Exception:
            pass
    return defaults


def save_custom_gesture(key, val):
    data = read_custom_gestures()
    data[key] = str(val).strip()
    try:
        with open(CUSTOM_GESTURES_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)

        # Sync three_finger_swipe_down with gestures.lua
        if key == "three_finger_swipe_down":
            cmd_to_run = str(val).strip()
            if not cmd_to_run or "Screenshot" in cmd_to_run:
                cmd_to_run = "/home/shogun/.local/bin/carbon-screenshot-full.sh"
            if os.path.isfile(GESTURES_LUA_PATH):
                with open(GESTURES_LUA_PATH, "r", encoding="utf-8") as f:
                    lua_c = f.read()
                pattern = r'(fingers\s*=\s*vars\.gestureFingers,\s*\n?\s*direction\s*=\s*"down",\s*\n?\s*action\s*=\s*function\(\)\s*\n?\s*hl\.exec_cmd\()"[^"]*"'
                if re.search(pattern, lua_c):
                    lua_c = re.sub(pattern, rf'\g<1>"{cmd_to_run}"', lua_c)
                    with open(GESTURES_LUA_PATH, "w", encoding="utf-8") as f:
                        f.write(lua_c)
                    subprocess.run(["hyprctl", "reload"], capture_output=True, check=False)

        # Sync three_finger_swipe_up with gestures.lua
        if key == "three_finger_swipe_up":
            cmd_to_run = str(val).strip()
            if not cmd_to_run or "Overview" in cmd_to_run:
                cmd_to_run = "sh ~/.config/hypr/scripts/carbon-ipc.sh toggle-overview"
            if os.path.isfile(GESTURES_LUA_PATH):
                with open(GESTURES_LUA_PATH, "r", encoding="utf-8") as f:
                    lua_c = f.read()
                pattern = r'(fingers\s*=\s*vars\.gestureFingers,\s*\n?\s*direction\s*=\s*"up",\s*\n?\s*action\s*=\s*function\(\)\s*\n?\s*hl\.exec_cmd\()"[^"]*"'
                if re.search(pattern, lua_c):
                    lua_c = re.sub(pattern, rf'\g<1>"{cmd_to_run}"', lua_c)
                    with open(GESTURES_LUA_PATH, "w", encoding="utf-8") as f:
                        f.write(lua_c)
                    subprocess.run(["hyprctl", "reload"], capture_output=True, check=False)
    except Exception as e:
        print(f"Failed to save custom gesture {key}:", e)



def update_looknfeel_conf(updates):
    looknfeel_path = os.path.expanduser("~/.config/hypr/configs/looknfeel.conf")
    if not os.path.isfile(looknfeel_path):
        return
    with open(looknfeel_path, "r", encoding="utf-8") as f:
        content = f.read()

    if "windowGapsIn" in updates:
        content = re.sub(r'(\bgaps_in\s*=\s*)[0-9]+', rf'\g<1>{int(updates["windowGapsIn"])}', content)
    if "windowGapsOut" in updates:
        content = re.sub(r'(\bgaps_out\s*=\s*)[0-9]+', rf'\g<1>{int(updates["windowGapsOut"])}', content)
    if "windowBorderSize" in updates:
        content = re.sub(r'(\bborder_size\s*=\s*)[0-9]+', rf'\g<1>{int(updates["windowBorderSize"])}', content)
    if "windowRounding" in updates:
        content = re.sub(r'(\brounding\s*=\s*)[0-9]+', rf'\g<1>{int(updates["windowRounding"])}', content)
    if "windowOpacity" in updates:
        val = float(updates["windowOpacity"])
        content = re.sub(r'(\bactive_opacity\s*=\s*)[0-9\.]+', rf'\g<1>{val:.2f}', content)
        content = re.sub(r'(\binactive_opacity\s*=\s*)[0-9\.]+', rf'\g<1>{val:.2f}', content)

    # Shadow block
    if "shadowEnabled" in updates:
        s_val = "true" if updates["shadowEnabled"] else "false"
        content = re.sub(r'(shadow\s*\{[^}]*?\benabled\s*=\s*)(true|false)', rf'\g<1>{s_val}', content, flags=re.DOTALL)
    if "shadowRange" in updates:
        content = re.sub(r'(shadow\s*\{[^}]*?\brange\s*=\s*)[0-9]+', rf'\g<1>{int(updates["shadowRange"])}', content, flags=re.DOTALL)

    # Blur block
    if "blurEnabled" in updates:
        b_val = "true" if updates["blurEnabled"] else "false"
        content = re.sub(r'(blur\s*\{[^}]*?\benabled\s*=\s*)(true|false)', rf'\g<1>{b_val}', content, flags=re.DOTALL)
    if "blurSize" in updates:
        content = re.sub(r'(blur\s*\{[^}]*?\bsize\s*=\s*)[0-9]+', rf'\g<1>{int(updates["blurSize"])}', content, flags=re.DOTALL)
    if "blurPasses" in updates:
        content = re.sub(r'(blur\s*\{[^}]*?\bpasses\s*=\s*)[0-9]+', rf'\g<1>{int(updates["blurPasses"])}', content, flags=re.DOTALL)

    with open(looknfeel_path, "w", encoding="utf-8") as f:
        f.write(content)


def update_hyprland_gui_lua(updates):
    gui_path = os.path.expanduser("~/.config/hypr/hyprland-gui.lua")
    if not os.path.isfile(gui_path):
        return
    with open(gui_path, "r", encoding="utf-8") as f:
        content = f.read()
    if "windowRounding" in updates:
        content = re.sub(r'(\brounding\s*=\s*)[0-9]+', rf'\g<1>{int(updates["windowRounding"])}', content)
    if "blurEnabled" in updates:
        b_val = "true" if updates["blurEnabled"] else "false"
        content = re.sub(r'(blur\s*=\s*\{[^}]*?\benabled\s*=\s*)(true|false)', rf'\g<1>{b_val}', content, flags=re.DOTALL)
    if "blurSize" in updates:
        content = re.sub(r'(blur\s*=\s*\{[^}]*?\bsize\s*=\s*)[0-9]+', rf'\g<1>{int(updates["blurSize"])}', content, flags=re.DOTALL)
    if "blurPasses" in updates:
        content = re.sub(r'(blur\s*=\s*\{[^}]*?\bpasses\s*=\s*)[0-9]+', rf'\g<1>{int(updates["blurPasses"])}', content, flags=re.DOTALL)
    with open(gui_path, "w", encoding="utf-8") as f:
        f.write(content)


def apply_hyprland_live(updates):
    """Directly send hl.config to running Hyprland via hyprctl eval."""
    gen_parts = []
    dec_parts = []
    blur_parts = []
    shadow_parts = []

    if "windowGapsIn" in updates:
        gen_parts.append("gaps_in = " + str(int(updates["windowGapsIn"])))
    if "windowGapsOut" in updates:
        gen_parts.append("gaps_out = " + str(int(updates["windowGapsOut"])))
    if "windowBorderSize" in updates:
        gen_parts.append("border_size = " + str(int(updates["windowBorderSize"])))
    if "workspaceGaps" in updates:
        gen_parts.append("gaps_workspaces = " + str(int(updates["workspaceGaps"])))

    if "windowRounding" in updates:
        dec_parts.append("rounding = " + str(int(updates["windowRounding"])))
    if "windowOpacity" in updates:
        op = float(updates["windowOpacity"])
        dec_parts.append(f"active_opacity = {op:.2f}")
        dec_parts.append(f"inactive_opacity = {op:.2f}")

    if "blurEnabled" in updates:
        blur_parts.append("enabled = " + ("true" if updates["blurEnabled"] else "false"))
    if "blurSize" in updates:
        blur_parts.append("size = " + str(int(updates["blurSize"])))
    if "blurPasses" in updates:
        blur_parts.append("passes = " + str(int(updates["blurPasses"])))

    if "shadowEnabled" in updates:
        shadow_parts.append("enabled = " + ("true" if updates["shadowEnabled"] else "false"))
    if "shadowRange" in updates:
        shadow_parts.append("range = " + str(int(updates["shadowRange"])))

    if blur_parts:
        dec_parts.append("blur = { " + ", ".join(blur_parts) + " }")
    if shadow_parts:
        dec_parts.append("shadow = { " + ", ".join(shadow_parts) + " }")

    top_parts = []
    if gen_parts:
        top_parts.append("general = { " + ", ".join(gen_parts) + " }")
    if dec_parts:
        top_parts.append("decoration = { " + ", ".join(dec_parts) + " }")

    if top_parts:
        lua_cmd = "hl.config({ " + ", ".join(top_parts) + " })"
        if "windowOpacity" in updates:
            op = float(updates["windowOpacity"])
            lua_cmd += f'; hl.window_rule({{ match = {{ fullscreen = false }}, opacity = "{op:.2f} override" }})'
        subprocess.run(["hyprctl", "eval", lua_cmd], capture_output=True, check=False)


def save_variables(updates):
    """Update variables.lua and looknfeel configs, and apply live to Hyprland."""
    if os.path.isfile(VARIABLES_PATH):
        with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        for key, val in updates.items():
            if isinstance(val, bool):
                val_str = "true" if val else "false"
                content = re.sub(
                    rf'({key}\s*=\s*)(true|false)',
                    rf'\g<1>{val_str}',
                    content
                )
            elif isinstance(val, (int, float)):
                if key in FLOAT_KEYS:
                    val_str = f"{float(val):.2f}"
                else:
                    val_str = str(int(round(float(val))))
                content = re.sub(
                    rf'({key}\s*=\s*)([0-9\.]+)',
                    rf'\g<1>{val_str}',
                    content
                )
            elif isinstance(val, str):
                content = re.sub(
                    rf'({key}\s*=\s*)"[^"]*"',
                    rf'\g<1>"{val}"',
                    content
                )

        with open(VARIABLES_PATH, "w", encoding="utf-8") as f:
            f.write(content)

    update_looknfeel_conf(updates)
    update_hyprland_gui_lua(updates)
    apply_hyprland_live(updates)

    # Reload hyprland
    res = subprocess.run(["hyprctl", "reload"], capture_output=True, text=True, check=False)
    subprocess.run([
        "notify-send", "-a", "Carbon Config", "-i", "preferences-desktop-appearance-symbolic",
        "Settings Applied", "Window Appearance and Hyprland variables updated live."
    ], check=False)
    return True


KEYBIND_META_MAP = {
    # Match patterns in rest/key -> (title, description, category, icon, var_key)
    "exec, $terminal": ("Terminal", "Launch default terminal ($terminal)", "Applications", "utilities-terminal-symbolic", "kbTerminal"),
    "[float; size 800 550] $terminal": ("Floating Terminal", "Launch terminal in floating window", "Applications", "utilities-terminal-symbolic", "kbFloatingTerminal"),
    "killactive": ("Close Active Window", "Gracefully close focused window", "Window Management", "window-close-symbolic", "kbCloseWindow"),
    "hyprctl dispatch exit": ("Exit Hyprland", "Log out of current Hyprland session", "System", "system-log-out-symbolic", "kbSession"),
    "exec, $menu": ("Application Menu", "Open application launcher ($menu)", "Applications", "view-app-grid-symbolic", "kbMenu"),
    "togglefloating": ("Toggle Window Floating", "Switch between tiled and floating mode", "Window Management", "view-restore-symbolic", "kbToggleWindowFloating"),
    "pseudo": ("Pseudo Tiling", "Toggle pseudo-tiled window state", "Window Management", "view-paged-symbolic", "kbPseudo"),
    "togglesplit": ("Toggle Dwindle Split", "Toggle horizontal/vertical window split", "Window Management", "view-split-left-symbolic", "kbToggleSplit"),
    "wbrestart.sh": ("Restart Desktop Panel", "Reload and restart desktop panel", "System", "view-refresh-symbolic", None),
    "exec, firefox": ("Web Browser", "Launch Firefox web browser", "Applications", "web-browser-symbolic", "kbBrowser"),
    "hyprlock.sh": ("Lock Screen", "Lock desktop session with Hyprlock", "System", "system-lock-screen-symbolic", "kbLock"),
    "fullscreen": ("Toggle Fullscreen", "Expand active window to full screen", "Window Management", "view-fullscreen-symbolic", "kbWindowFullscreen"),
    "screenshot.sh": ("Take Screenshot", "Capture region or full screen snapshot", "Applications", "applets-screenshooter-symbolic", "kbScreenshot"),
    "carbon-ipc.sh wallpaper": ("Cycle Wallpaper", "Switch to next desktop wallpaper", "System", "preferences-desktop-wallpaper-symbolic", "kbWallpaper"),
    "KillActiveProcess.sh": ("Force Kill Process", "Terminate unresponsive active process immediately", "Window Management", "process-stop-symbolic", "kbKillProcess"),
    "hyprpicker": ("Color Picker", "Pick color from screen to clipboard", "Applications", "color-select-symbolic", "kbColorPicker"),
    "WaybarStyles.sh": ("Panel Styles", "Open panel preset styles menu", "System", "preferences-desktop-theme-symbolic", None),
    "WaybarLayout.sh": ("Panel Layout", "Open panel layout position menu", "System", "view-grid-symbolic", None),
    "pkill -SIGUSR1 waybar": ("Toggle Panel Visibility", "Show or hide the desktop panel", "System", "view-conceal-symbolic", "kbShowSidebar"),
    "exec, $fileManager": ("File Manager", "Launch Thunar file manager ($fileManager)", "Applications", "system-file-manager-symbolic", "kbFileExplorer"),
    
    # Focus
    "movefocus, l": ("Focus Window Left", "Switch focus to window on the left", "Focus and Movement", "go-previous-symbolic", None),
    "movefocus, r": ("Focus Window Right", "Switch focus to window on the right", "Focus and Movement", "go-next-symbolic", None),
    "movefocus, u": ("Focus Window Up", "Switch focus to window above", "Focus and Movement", "go-up-symbolic", None),
    "movefocus, d": ("Focus Window Down", "Switch focus to window below", "Focus and Movement", "go-down-symbolic", None),
    
    # Movement
    "movewindow, l": ("Move Window Left", "Swap active window with left neighbor", "Focus and Movement", "go-first-symbolic", None),
    "movewindow, r": ("Move Window Right", "Swap active window with right neighbor", "Focus and Movement", "go-last-symbolic", None),
    "movewindow, u": ("Move Window Up", "Swap active window with upper neighbor", "Focus and Movement", "go-top-symbolic", None),
    "movewindow, d": ("Move Window Down", "Swap active window with lower neighbor", "Focus and Movement", "go-bottom-symbolic", None),
    
    # Resize
    "resizeactive,-50 0": ("Shrink Window Width", "Decrease window width by 50px", "Focus and Movement", "zoom-out-symbolic", None),
    "resizeactive,50 0": ("Expand Window Width", "Increase window width by 50px", "Focus and Movement", "zoom-in-symbolic", None),
    "resizeactive,0 -50": ("Shrink Window Height", "Decrease window height by 50px", "Focus and Movement", "zoom-out-symbolic", None),
    "resizeactive,0 50": ("Expand Window Height", "Increase window height by 50px", "Focus and Movement", "zoom-in-symbolic", None),
    
    # Workspaces
    "workspace, e+1": ("Next Workspace", "Scroll cycle to next workspace", "Workspaces", "go-next-symbolic", "kbNextWs"),
    "workspace, e-1": ("Previous Workspace", "Scroll cycle to previous workspace", "Workspaces", "go-previous-symbolic", "kbPrevWs"),
    
    # Mouse Bindings
    "mouse:272": ("Move Window (Drag)", "Hold modifier and drag LMB to move window", "Mouse Bindings", "input-mouse-symbolic", "kbMoveWindow"),
    "mouse:273": ("Resize Window (Drag)", "Hold modifier and drag RMB to resize window", "Mouse Bindings", "input-mouse-symbolic", "kbResizeWindow"),
    
    # Media & Hardware
    "wpctl set-mute": ("Mute Microphone", "Toggle default microphone input mute", "Media and Audio", "audio-input-microphone-symbolic", None),
    "playerctl next": ("Next Media Track", "Skip to next music/video track", "Media and Audio", "media-skip-forward-symbolic", None),
    "playerctl play-pause": ("Play / Pause Media", "Play or pause current media track", "Media and Audio", "media-playback-start-symbolic", None),
    "playerctl previous": ("Previous Media Track", "Return to previous music/video track", "Media and Audio", "media-skip-backward-symbolic", None),
}


def normalize_key(name):
    special = {
        "Return": "Return",
        "ISO_Enter": "Return",
        "space": "Space",
        "BackSpace": "BackSpace",
        "Tab": "Tab",
        "ISO_Left_Tab": "Tab",
        "Escape": "Escape",
        "Delete": "Delete",
        "Insert": "Insert",
        "Home": "Home",
        "End": "End",
        "Page_Up": "Page_Up",
        "Page_Down": "Page_Down",
        "Prior": "Page_Up",
        "Next": "Page_Down",
        "Left": "left",
        "Right": "right",
        "Up": "up",
        "Down": "down",
        "period": "period",
        "comma": "comma",
        "slash": "slash",
        "backslash": "backslash",
        "minus": "minus",
        "equal": "equal",
        "semicolon": "semicolon",
        "apostrophe": "apostrophe",
        "grave": "grave",
        "bracketleft": "bracketleft",
        "bracketright": "bracketright",
    }
    if name in special:
        return special[name]
    if len(name) == 1:
        return name.upper()
    return name


def format_bind_display(mods, key):
    parts = []
    m = mods.strip()
    if "$mainMod" in m or "SUPER" in m:
        parts.append("SUPER")
    if "CTRL" in m:
        parts.append("Ctrl")
    if "ALT" in m:
        parts.append("Alt")
    if "SHIFT" in m:
        parts.append("Shift")
    k = key.strip()
    if k == "mouse:272":
        k = "Mouse Left"
    elif k == "mouse:273":
        k = "Mouse Right"
    elif k == "mouse_down":
        k = "Wheel Down"
    elif k == "mouse_up":
        k = "Wheel Up"
    parts.append(k)
    return " + ".join(parts)


def parse_keybinds_conf():
    if not os.path.isfile(KEYBINDS_CONF_PATH):
        return []
    items = []
    with open(KEYBINDS_CONF_PATH, "r", encoding="utf-8") as f:
        for idx, line in enumerate(f):
            m = re.match(r"^(\s*(?:binde|bindm|bindel|bindl|bind)\s*=\s*)([^,]*),\s*([^,]+),\s*(.*)$", line)
            if not m:
                continue
            prefix, mods, key, rest = m.groups()
            mods = mods.strip()
            key = key.strip()
            rest = rest.strip()
            bind_type = prefix.split("=")[0].strip()
            display_str = format_bind_display(mods, key)
            
            title = None
            desc = None
            cat = None
            icon = "input-keyboard-symbolic"
            var_key = None

            for k_sub, meta in KEYBIND_META_MAP.items():
                if k_sub in rest or k_sub in key:
                    title, desc, cat, icon, var_key = meta
                    break
            
            if not title:
                if "movetoworkspace," in rest:
                    ws = rest.split("movetoworkspace,")[1].strip()
                    title = f"Move Window to WS {ws}"
                    desc = f"Send active window to workspace {ws}"
                    cat = "Workspaces"
                    icon = "folder-symbolic"
                    var_key = "kbMoveWinToWs"
                elif "workspace," in rest:
                    ws = rest.split("workspace,")[1].strip()
                    title = f"Switch to Workspace {ws}"
                    desc = f"Navigate desktop view to workspace {ws}"
                    cat = "Workspaces"
                    icon = "view-paged-symbolic"
                    var_key = "kbGoToWs"
                else:
                    clean_action = rest.split("#")[0].strip()
                    title = clean_action
                    desc = rest
                    cat = "Other Keybinds"

            items.append({
                "line_idx": idx,
                "bind_type": bind_type,
                "mods": mods,
                "key": key,
                "rest": rest,
                "display_str": display_str,
                "title": title,
                "desc": desc,
                "category": cat,
                "icon": icon,
                "var_key": var_key,
            })
    return items


def update_keybind_in_conf(line_idx, new_mods, new_key, original_rest=None, var_key=None, display_str=None):
    if not os.path.isfile(KEYBINDS_CONF_PATH):
        return False
    with open(KEYBINDS_CONF_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    target_idx = -1
    if line_idx < len(lines) and original_rest and original_rest in lines[line_idx]:
        target_idx = line_idx
    elif original_rest:
        for i, l in enumerate(lines):
            if original_rest in l and re.match(r"^\s*(?:binde|bindm|bindel|bindl|bind)\s*=", l):
                target_idx = i
                break
    elif line_idx < len(lines):
        target_idx = line_idx
        
    if target_idx == -1 or target_idx >= len(lines):
        return False
        
    old_line = lines[target_idx]
    m = re.match(r"^(\s*(?:binde|bindm|bindel|bindl|bind)\s*=\s*)([^,]*),\s*([^,]+),\s*(.*)$", old_line)
    if not m:
        return False
        
    prefix = m.group(1)
    old_mods = m.group(2).strip()
    old_key = m.group(3).strip()
    rest = m.group(4)
    if new_mods:
        lines[target_idx] = f"{prefix}{new_mods}, {new_key}, {rest}\n"
    else:
        lines[target_idx] = f"{prefix}, {new_key}, {rest}\n"
        
    with open(KEYBINDS_CONF_PATH, "w", encoding="utf-8") as f:
        f.writelines(lines)
        
    # Sync variables.lua if mapped
    if var_key and display_str and os.path.isfile(VARIABLES_PATH):
        try:
            with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
                v_content = f.read()
            if re.search(rf'{var_key}\s*=', v_content):
                v_content = re.sub(
                    rf'({var_key}\s*=\s*)"[^"]*"',
                    rf'\g<1>"{display_str}"',
                    v_content
                )
            else:
                # Append before closing brace of return table
                v_content = re.sub(
                    r'(return\s*\{.*?)(\n\s*\})',
                    rf'\1    {var_key} = "{display_str}",\2',
                    v_content,
                    flags=re.DOTALL
                )
            with open(VARIABLES_PATH, "w", encoding="utf-8") as f:
                f.write(v_content)
        except Exception:
            pass

    # If running under Hyprland Lua, unbind old combination so it doesn't conflict
    try:
        old_lua_combo = f"{old_mods} + {old_key}" if old_mods else old_key
        subprocess.run(["hyprctl", "eval", f'hl.unbind("{old_lua_combo}")'], capture_output=True, timeout=1, check=False)
    except Exception:
        pass

    # Immediate live reload so Hyprland re-reads configs immediately
    try:
        subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=2, check=False)
    except Exception:
        pass

class CarbonSplashWidget(Gtk.DrawingArea):
    """
    Ultra-smooth, 60/120fps vsync-synchronized Cairo splash widget displaying the Carbon Lewis dot logo:
    1. Central 'C' with 4 valence dots smoothly fade in.
    2. The 4 dots glide outward toward the 4 corners of the window with fluid cubic ease-out.
    3. The central 'C' dissolves gracefully.
    4. The dark splash backdrop dissolves smoothly, unveiling the settings app.
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF", bg_hex="#121214", on_finish=None):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.on_finish = on_finish
        self.start_time = None
        self.current_elapsed = 0.0
        self.tick_id = None
        self.is_finished = False

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) == 8:
                return int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, int(h[6:8], 16) / 255.0
            elif len(h) == 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.07, 0.07, 0.08

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)
        self.bg_rgb = hex_to_rgb(bg_hex)

        # Pre-create Pango font description to avoid allocations in draw loop
        self.font_desc = Pango.FontDescription("Valley Sans Bold 44")
        self.pango_layout = None
        self.c_w = 0
        self.c_h = 0

        self.set_draw_func(self.on_draw)
        self.connect("map", self.on_map)

    def on_map(self, widget):
        self.start()

    def start(self):
        self.start_time = None
        self.current_elapsed = 0.0
        self.is_finished = False
        self.set_visible(True)
        if not self.tick_id:
            self.tick_id = self.add_tick_callback(self.on_tick)

    def on_tick(self, widget, frame_clock):
        t = frame_clock.get_frame_time() / 1_000_000.0
        if self.start_time is None:
            self.start_time = t

        elapsed = t - self.start_time
        self.current_elapsed = elapsed
        self.queue_draw()

        if elapsed >= 0.70:
            self.is_finished = True
            self.set_visible(False)
            if self.on_finish:
                self.on_finish()
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def on_draw(self, area, cr, width, height):
        if self.is_finished:
            return

        elapsed = max(0.0, self.current_elapsed)

        cx = width / 2.0
        cy = height / 2.0

        # Background overlay fade (0.46 to 0.70s)
        bg_alpha = 1.0
        if elapsed > 0.46:
            bg_alpha = max(0.0, 1.0 - (elapsed - 0.46) / 0.24)

        br, bg, bb = self.bg_rgb
        cr.set_source_rgba(br, bg, bb, bg_alpha)
        cr.paint()

        if bg_alpha <= 0.001:
            return

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        # "C" dissolve (0.18 to 0.38s)
        c_alpha = 1.0
        if elapsed < 0.12:
            c_alpha = elapsed / 0.12
        elif elapsed > 0.18:
            c_alpha = max(0.0, 1.0 - (elapsed - 0.18) / 0.20)

        if c_alpha > 0.005:
            if self.pango_layout is None:
                self.pango_layout = PangoCairo.create_layout(cr)
                self.pango_layout.set_font_description(self.font_desc)
                self.pango_layout.set_text("C", -1)
                ink, log = self.pango_layout.get_pixel_extents()
                self.c_w = log.width
                self.c_h = log.height
            else:
                PangoCairo.update_layout(cr, self.pango_layout)

            c_scale = 1.0
            if elapsed > 0.18:
                c_scale = 1.0 - 0.10 * min(1.0, (elapsed - 0.18) / 0.20)

            cr.save()
            cr.translate(cx, cy)
            cr.scale(c_scale, c_scale)
            cr.set_source_rgba(alr, alg, alb, c_alpha * bg_alpha)
            cr.move_to(-self.c_w / 2.0, -self.c_h / 2.0)
            PangoCairo.show_layout(cr, self.pango_layout)
            cr.restore()

        # 4 Dots Travel (0.12 to 0.48s)
        r0 = 42.0
        pad = 32.0
        start_dots = [
            (cx, cy - r0),
            (cx + r0, cy),
            (cx, cy + r0),
            (cx - r0, cy)
        ]
        target_dots = [
            (pad, pad),
            (width - pad, pad),
            (width - pad, height - pad),
            (pad, height - pad)
        ]

        t_travel = max(0.0, min(1.0, (elapsed - 0.12) / 0.36))
        ease = 1.0 - math.pow(1.0 - t_travel, 3)

        dot_alpha = 1.0
        if elapsed < 0.12:
            dot_alpha = elapsed / 0.12
        elif t_travel > 0.70:
            dot_alpha = max(0.0, 1.0 - (t_travel - 0.70) / 0.30)

        dot_alpha *= bg_alpha

        if dot_alpha > 0.005:
            for i in range(4):
                sx, sy = start_dots[i]
                tx, ty = target_dots[i]
                cur_x = sx + (tx - sx) * ease
                cur_y = sy + (ty - sy) * ease

                # Outer glowing halo
                cr.set_source_rgba(ar, ag, ab, 0.35 * dot_alpha)
                cr.arc(cur_x, cur_y, 8.5, 0, 2 * math.pi)
                cr.fill()

                # Core dot
                cr.set_source_rgba(alr, alg, alb, dot_alpha)
                cr.arc(cur_x, cur_y, 5.5, 0, 2 * math.pi)
                cr.fill()


class CarbonBohrLogoWidget(Gtk.DrawingArea):
    """
    Ultra-smooth 60/120fps Cairo animation displaying the Carbon Bohr Atom Logo identical to the lockscreen:
    - Optically centered bold 'C' glyph with glow and specular highlight
    - Dual concentric orbital circumcircles (K-shell & L-shell) with ambient breathing
    - Layer 1 (Inner 2 dots): Clockwise rotation at 5.8s period
    - Layer 2 (Outer 4 dots): Counter-clockwise rotation at 9.4s period
    - Periodic shockwave ripple and dot bounce pulse at 1.85s period
    - Multi-layer electron dots: glowing halo, crisp white core, accent border, and neon nucleus
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF"):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(False)
        self.set_content_height(290)
        self.set_content_width(360)

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) == 8:
                return int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, int(h[6:8], 16) / 255.0
            elif len(h) == 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.0, 0.94, 1.0

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)

        self.r_inner = 48.0
        self.r_outer = 86.0

        self.font_desc = Pango.FontDescription("Valley Sans Bold 54")
        self.pango_layout = None

        self.start_time = None
        self.current_t = 0.0
        self.tick_id = None

        self.set_draw_func(self.on_draw)
        self.connect("map", self.on_map)
        self.connect("unmap", self.on_unmap)

    def on_map(self, widget):
        if not self.tick_id:
            self.start_time = None
            self.tick_id = self.add_tick_callback(self.on_tick)

    def on_unmap(self, widget):
        if self.tick_id:
            self.remove_tick_callback(self.tick_id)
            self.tick_id = None

    def on_tick(self, widget, frame_clock):
        t = frame_clock.get_frame_time() / 1_000_000.0
        if self.start_time is None:
            self.start_time = t
        self.current_t = t - self.start_time
        self.queue_draw()
        return GLib.SOURCE_CONTINUE

    def on_draw(self, area, cr, width, height):
        cx = width / 2.0
        cy = height / 2.0
        t = max(0.0, self.current_t)

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        # Ambient Breathing Cycle (period ~3.8s)
        breathe = math.sin(t * (2.0 * math.pi / 3.8))
        b_norm = (breathe + 1.0) / 2.0
        b_scale = 0.98 + 0.04 * b_norm
        ring_base_alpha = 0.22 + 0.16 * b_norm
        center_glow_alpha = 0.18 + 0.14 * b_norm

        # Periodic Heartbeat Pulse (period ~1.85s matches lockscreen interval 1850ms)
        hb_cycle = t % 1.85

        # 1. Shockwave Ripple Expanding Ring
        if hb_cycle < 0.75:
            st = hb_cycle / 0.75
            ease_st = 1.0 - math.pow(1.0 - st, 3)  # OutCubic
            shock_scale = 1.0 + 1.25 * ease_st
            shock_r = (self.r_outer * b_scale) * shock_scale
            shock_alpha = 0.82 * (1.0 - ease_st)

            cr.save()
            cr.set_source_rgba(ar, ag, ab, shock_alpha)
            cr.set_line_width(2.2 * (1.0 - ease_st * 0.4))
            cr.arc(cx, cy, shock_r, 0, 2.0 * math.pi)
            cr.stroke()
            cr.restore()

        # 2. Valence Dot Bounce Pulse & Ring Brightness Flash
        if hb_cycle < 0.18:
            dot_scale = 1.0 + 0.32 * (hb_cycle / 0.18)
            pulse_flash = (hb_cycle / 0.18) * 0.38
        elif hb_cycle < 0.53:
            t_back = (hb_cycle - 0.18) / 0.35
            dot_scale = 1.0 + 0.32 * (1.0 - t_back) * math.cos(t_back * math.pi * 0.5)
            pulse_flash = (1.0 - (hb_cycle - 0.18) / 0.55) * 0.38
        else:
            dot_scale = 1.0
            pulse_flash = 0.0

        r1 = self.r_inner * b_scale
        r2 = self.r_outer * b_scale
        ring_alpha = min(0.95, ring_base_alpha + pulse_flash)

        # 3. Dual Concentric Orbital Circumcircles
        cr.save()
        cr.set_source_rgba(ar, ag, ab, ring_alpha * 0.65)
        cr.set_line_width(1.4)
        cr.arc(cx, cy, r1, 0, 2.0 * math.pi)
        cr.stroke()

        cr.set_source_rgba(ar, ag, ab, ring_alpha)
        cr.set_line_width(1.5)
        cr.arc(cx, cy, r2, 0, 2.0 * math.pi)
        cr.stroke()
        cr.restore()

        # 4. Central Ambient Glow
        glow_rad = 44.0 * b_scale
        pat_center = cairo.RadialGradient(cx, cy, 0, cx, cy, glow_rad)
        cg_alpha = min(0.60, center_glow_alpha + pulse_flash * 0.35)
        pat_center.add_color_stop_rgba(0.0, ar, ag, ab, cg_alpha)
        pat_center.add_color_stop_rgba(0.65, ar, ag, ab, cg_alpha * 0.35)
        pat_center.add_color_stop_rgba(1.0, ar, ag, ab, 0.0)
        cr.save()
        cr.set_source(pat_center)
        cr.arc(cx, cy, glow_rad, 0, 2.0 * math.pi)
        cr.fill()
        cr.restore()

        # 5. Optical Centering of Central 'C' Glyph
        if self.pango_layout is None:
            self.pango_layout = PangoCairo.create_layout(cr)
            self.pango_layout.set_font_description(self.font_desc)
            self.pango_layout.set_text("C", -1)
        else:
            PangoCairo.update_layout(cr, self.pango_layout)

        ink, log = self.pango_layout.get_pixel_extents()
        # True optical center offset from glyph ink boundary
        opt_x = cx - (ink.x + ink.width / 2.0)
        opt_y = cy - (ink.y + ink.height / 2.0)

        cr.save()
        cr.translate(opt_x, opt_y)
        # Main accent glyph
        cr.set_source_rgba(ar, ag, ab, 0.95)
        PangoCairo.show_layout(cr, self.pango_layout)
        # Specular white overlay
        cr.set_source_rgba(alr, alg, alb, 0.45)
        PangoCairo.show_layout(cr, self.pango_layout)
        cr.restore()

        # 6. Valence Electron Dot Drawer (Halo + Core + Nucleus)
        def draw_dot(dx, dy, base_halo=14.0, base_core=8.0, base_inner=3.0):
            sh = base_halo * dot_scale
            sc = base_core * dot_scale
            si = base_inner * dot_scale

            # Glowing outer halo
            pat_h = cairo.RadialGradient(dx, dy, 0, dx, dy, sh)
            pat_h.add_color_stop_rgba(0.0, ar, ag, ab, 0.42)
            pat_h.add_color_stop_rgba(0.60, ar, ag, ab, 0.18)
            pat_h.add_color_stop_rgba(1.0, ar, ag, ab, 0.0)
            cr.save()
            cr.set_source(pat_h)
            cr.arc(dx, dy, sh, 0, 2.0 * math.pi)
            cr.fill()

            # Crisp white core with accent border
            cr.arc(dx, dy, sc, 0, 2.0 * math.pi)
            cr.set_source_rgba(alr, alg, alb, 0.98)
            cr.fill_preserve()
            cr.set_source_rgba(ar, ag, ab, 1.0)
            cr.set_line_width(2.0)
            cr.stroke()

            # Inner neon nucleus
            cr.arc(dx, dy, si, 0, 2.0 * math.pi)
            cr.set_source_rgba(ar, ag, ab, 1.0)
            cr.fill()
            cr.restore()

        # 7. Layer 1: Inner 2 Dots (Clockwise rotation at 5.8s period)
        theta = (t / 5.8) * 2.0 * math.pi
        draw_dot(cx + r1 * math.sin(theta), cy - r1 * math.cos(theta), 13.0, 7.5, 2.6)
        draw_dot(cx + r1 * math.sin(theta + math.pi), cy - r1 * math.cos(theta + math.pi), 13.0, 7.5, 2.6)

        # 8. Layer 2: Outer 4 Dots (Counter-clockwise rotation at 9.4s period)
        phi = -(t / 9.4) * 2.0 * math.pi
        for idx in range(4):
            ang = phi + idx * (math.pi / 2.0)
            draw_dot(cx + r2 * math.cos(ang), cy + r2 * math.sin(ang), 16.0, 8.6, 3.0)


class ConfigEditorWindow(Adw.ApplicationWindow):
    def __init__(self, app, initial_page=None):
        super().__init__(application=app, title="Carbon Settings")

        # Open directly at exact 60%x70% floating geometry to prevent opening expansion/snap
        target_w, target_h = 820, 538
        try:
            display = Gdk.Display.get_default()
            if display:
                monitors = display.get_monitors()
                if monitors and monitors.get_n_items() > 0:
                    mon = monitors.get_item(0)
                    geom = mon.get_geometry()
                    target_w = int(geom.width * 0.6)
                    target_h = int(geom.height * 0.7)
        except Exception:
            pass
        self.set_default_size(target_w, target_h)
        self.set_size_request(target_w, target_h)
        # Release fixed minimum constraint shortly after initial map so window is user-resizable
        GLib.timeout_add(700, lambda: (self.set_size_request(-1, -1), False)[1])
        self.initial_page = initial_page

        self.var_data = read_variables()
        self.inputs = {}
        self.current_bar_mode = read_bar_mode()
        self.bar_mode_rows = {}
        self.current_clock_style = read_clock_style()
        self.clock_rows = {}
        self.bar_pos = read_bar_position()
        self.pill_edge_buttons = {}
        self.pill_content_buttons = {}
        self.notch_edge_buttons = {}
        self.notch_music_edge_buttons = {}
        self.notch_content_buttons = {}
        self.main_edge_buttons = self.pill_edge_buttons
        self.music_edge_buttons = self.notch_music_edge_buttons
        self.grp_pill = None
        self.grp_notch = None
        self.edge_buttons = {}
        self.align_buttons = {
            "left": {},
            "center": {},
            "right": {}
        }

        # Keybind recording state
        self.recording_btn = None
        self.recording_bind_info = None
        self.key_controller = None
        self.held_modifiers = set()

        # Read theme.json dynamically
        theme_json_path = os.path.expanduser("~/.config/hypr/theme.json")
        theme = {}
        if os.path.exists(theme_json_path):
            try:
                with open(theme_json_path, "r", encoding="utf-8") as f:
                    theme = json.load(f)
            except Exception:
                pass

        accent = theme.get("accent", "#E2E8F0")
        accent_lit = theme.get("accentLit", "#FFFFFF")
        is_dark = theme.get("isDark", True)
        self.theme_accent = accent
        self.theme_accent_lit = accent_lit

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) == 6:
                return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            return 226, 232, 240

        ar, ag, ab = hex_to_rgb(accent)
        alum = 0.2126 * ar + 0.7152 * ag + 0.0722 * ab
        accent_fg = "#121214" if alum > 140 else "#FFFFFF"

        # Configure Libadwaita style manager directly
        try:
            sm = Adw.StyleManager.get_default()
            sm.set_color_scheme(Adw.ColorScheme.PREFER_DARK if is_dark else Adw.ColorScheme.PREFER_LIGHT)
        except Exception:
            pass

        # CSS for Visual Clock Cards, Small Keybind Pills, and Theme Accents
        css = f"""
        @define-color accent_color {accent};
        @define-color accent_bg_color {accent};
        @define-color accent_fg_color {accent_fg};

        .suggested-action {{
            background-color: {accent};
            color: {accent_fg};
            font-weight: 700;
        }}
        .suggested-action:hover {{
            background-color: {accent_lit};
            color: {accent_fg};
        }}
        .navigation-sidebar row {{
            padding: 2px 4px;
            margin: 1px 4px;
            border-radius: 6px;
        }}
        .navigation-sidebar row:selected {{
            background-color: rgba({ar}, {ag}, {ab}, 0.20);
            color: {accent_lit};
        }}
        .navigation-sidebar row:selected label {{
            color: {accent_lit};
            font-weight: 700;
        }}
        switch:checked {{
            background-color: {accent};
            color: {accent_fg};
        }}
        .accent {{
            color: {accent};
        }}
        .clock-preview-card {{
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 10px;
            padding: 4px 12px;
            min-width: 100px;
        }}
        .clock-preview-card:hover {{
            background-color: rgba(255, 255, 255, 0.08);
            border-color: {accent};
        }}
        .keybind-pill {{
            background-color: rgba({ar}, {ag}, {ab}, 0.14);
            color: {accent};
            border: 1px solid rgba({ar}, {ag}, {ab}, 0.35);
            border-radius: 6px;
            padding: 2px 8px;
            font-size: 11px;
            font-weight: 700;
            font-family: 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace;
            min-height: 20px;
            min-width: 28px;
            transition: all 120ms ease;
        }}
        .keybind-pill:hover {{
            background-color: rgba({ar}, {ag}, {ab}, 0.28);
            border-color: {accent};
            color: {accent_lit};
        }}
        .keybind-pill-listening {{
            background-color: rgba(245, 158, 11, 0.25);
            color: #fbbf24;
            border: 1px dashed #f59e0b;
            border-radius: 6px;
            padding: 2px 8px;
            font-size: 11px;
            font-weight: 700;
            font-family: 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace;
            min-height: 20px;
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER + 50
        )

        # Root Overlay holding Main Content + Splash Animation
        self.root_overlay = Gtk.Overlay()
        outer_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toast_overlay = Adw.ToastOverlay.new()
        self.toast_overlay.set_child(outer_box)
        self.root_overlay.set_child(self.toast_overlay)

        # Splash Widget covering window with Carbon Lewis Dot sequence
        self.splash_widget = CarbonSplashWidget(
            accent_hex=accent,
            accent_lit_hex=accent_lit,
            bg_hex=theme.get("bg", "#121214"),
            on_finish=self.on_splash_finished
        )
        self.root_overlay.add_overlay(self.splash_widget)
        self.set_content(self.root_overlay)

        # HeaderBar
        header = Adw.HeaderBar()
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        title_lbl = Gtk.Label(label="Carbon Settings")
        title_lbl.add_css_class("title")
        subtitle_lbl = Gtk.Label(label="Desktop and Bar Configuration")
        subtitle_lbl.add_css_class("subtitle")
        title_box.append(title_lbl)
        title_box.append(subtitle_lbl)
        header.set_title_widget(title_box)
        outer_box.append(header)

        # Apply Button in Header
        apply_btn = Gtk.Button(label="Apply Configuration")
        apply_btn.set_tooltip_text("Save all changes and reload Hyprland & Carbon Shell")
        apply_btn.add_css_class("suggested-action")
        apply_btn.connect("clicked", self.on_apply_quick_tweaks)
        header.pack_end(apply_btn)

        # Open in Codium Button
        codium_btn = Gtk.Button(icon_name="text-editor-symbolic")
        codium_btn.set_tooltip_text("Open configs in VSCodium")
        codium_btn.connect("clicked", self.on_open_codium)
        header.pack_start(codium_btn)

        # Main Body: Split Horizontal Box (Left Sidebar Menu + Content ViewStack)
        body_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        body_box.set_vexpand(True)
        outer_box.append(body_box)

        # ── Left Sidebar Menu ──────────────────────────────────────────
        sidebar_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        sidebar_frame.set_size_request(210, -1)
        sidebar_frame.add_css_class("navigation-sidebar")
        body_box.append(sidebar_frame)

        # Scrolled Sidebar
        scrolled_sidebar = Gtk.ScrolledWindow()
        scrolled_sidebar.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled_sidebar.set_vexpand(True)
        sidebar_frame.append(scrolled_sidebar)

        self.sidebar_list = Gtk.ListBox()
        self.sidebar_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.sidebar_list.add_css_class("navigation-sidebar")
        scrolled_sidebar.set_child(self.sidebar_list)

        # Vertical Divider Separating Sidebar and Content
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        body_box.append(sep)

        # Right Content ViewStack
        self.view_stack = Adw.ViewStack()
        self.view_stack.set_hexpand(True)
        self.view_stack.set_vexpand(True)
        body_box.append(self.view_stack)

        # Sidebar navigation items (Bar is FIRST as requested)
        nav_items = [
            ("bar", "Bar & Layout", "view-grid-symbolic"),
            ("minimal", "Minimal Mode", "open-menu-symbolic"),
            ("clock", "Clock Styles", "preferences-system-time-symbolic"),
            ("wifi", "Wi-Fi Networks", "network-wireless-symbolic"),
            ("bluetooth", "Bluetooth", "bluetooth-symbolic"),
            ("lockscreen", "Lock Screen", "system-lock-screen-symbolic"),
            ("appearance", "Window Appearance", "preferences-desktop-appearance-symbolic"),
            ("apps", "Default Apps", "applications-system-symbolic"),
            ("keybinds", "Keybinds", "input-keyboard-symbolic"),
            ("gestures", "Gestures", "input-touchpad-symbolic"),
            ("files", "Config Files", "text-editor-symbolic"),
            ("about", "About", "help-about-symbolic"),
        ]

        self.sidebar_rows = []
        for tag, label, icon in nav_items:
            row = Gtk.ListBoxRow()
            row.page_name = tag
            h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            h.set_margin_top(4)
            h.set_margin_bottom(4)
            h.set_margin_start(10)
            h.set_margin_end(10)

            img = Gtk.Image.new_from_icon_name(icon)
            img.set_pixel_size(16)
            lbl = Gtk.Label(label=label, xalign=0)
            lbl.set_hexpand(True)

            h.append(img)
            h.append(lbl)
            row.set_child(h)
            self.sidebar_list.append(row)
            self.sidebar_rows.append(row)

        self.sidebar_list.connect("row-selected", self.on_sidebar_row_selected)

        # Lazy Page Builders setup for instantaneous launch
        self._page_builders = {
            "bar": self.build_bar_page,
            "minimal": self.build_minimal_page,
            "clock": self.build_clock_page,
            "wifi": self.build_wifi_page,
            "bluetooth": self.build_bluetooth_page,
            "lockscreen": self.build_lockscreen_page,
            "appearance": self.build_appearance_page,
            "apps": self.build_apps_page,
            "keybinds": self.build_keybinds_page,
            "gestures": self.build_gestures_page,
            "files": self.build_files_page,
            "about": self.build_about_page,
        }
        self._built_pages = set()
        self._idle_pages_queue = ["minimal", "clock", "wifi", "bluetooth", "lockscreen", "appearance", "apps", "keybinds", "gestures", "files", "about"]

        # Select initial page (default "bar" or from self.initial_page or --page arg)
        initial_page = getattr(self, "initial_page", None) or "bar"
        for i, arg in enumerate(sys.argv):
            if arg.startswith("--page="):
                initial_page = arg.split("=")[1]
            elif arg == "--page" and i + 1 < len(sys.argv):
                initial_page = sys.argv[i + 1]

        # Build initial page immediately
        self.ensure_page_built(initial_page)
        if initial_page in self._idle_pages_queue:
            self._idle_pages_queue.remove(initial_page)

        target_row = next((r for r in self.sidebar_rows if getattr(r, "page_name", None) == initial_page), self.sidebar_rows[0])
        self.sidebar_list.select_row(target_row)
        self.view_stack.set_visible_child_name(target_row.page_name)

        # Start splash animation immediately (remaining pages build in idle after splash finishes)
        self.splash_widget.start()

    def ensure_page_built(self, name):
        if name in self._built_pages:
            return
        self._built_pages.add(name)
        builder = self._page_builders.get(name)
        if builder:
            builder()
            if name in ("bar", "minimal"):
                self.update_pos_buttons_ui()

    def _build_next_idle_page(self):
        if not self._idle_pages_queue:
            return GLib.SOURCE_REMOVE
        next_page = self._idle_pages_queue.pop(0)
        self.ensure_page_built(next_page)
        return GLib.SOURCE_CONTINUE if self._idle_pages_queue else GLib.SOURCE_REMOVE

    def on_splash_finished(self):
        try:
            self.root_overlay.remove_overlay(self.splash_widget)
        except Exception:
            pass
        if getattr(self, "initial_page", None):
            self.navigate_to_page(self.initial_page)
        # Incrementally build remaining pages during idle time AFTER splash finishes
        GLib.idle_add(self._build_next_idle_page)

    def on_sidebar_row_selected(self, listbox, row):
        if row and hasattr(row, "page_name"):
            self.ensure_page_built(row.page_name)
            self.view_stack.set_visible_child_name(row.page_name)

    def show_toast(self, title, subtitle=""):
        msg = f"{title}: {subtitle}" if subtitle else title
        toast = Adw.Toast.new(msg)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

    def cancel_recording(self):
        if self.recording_btn and self.recording_bind_info:
            self.recording_btn.set_label(self.recording_bind_info["display_str"])
            self.recording_btn.remove_css_class("keybind-pill-listening")
            self.recording_btn.add_css_class("keybind-pill")
        if self.key_controller:
            self.remove_controller(self.key_controller)
            self.key_controller = None
        self.recording_btn = None
        self.recording_bind_info = None
        self.held_modifiers.clear()

    def on_keybind_btn_clicked(self, btn, bind_info):
        if self.recording_btn == btn:
            self.cancel_recording()
            return
        
        self.cancel_recording()

        self.recording_btn = btn
        self.recording_bind_info = bind_info
        btn.remove_css_class("keybind-pill")
        btn.add_css_class("keybind-pill-listening")
        btn.set_label("Press shortcut...")

        self.key_controller = Gtk.EventControllerKey.new()
        self.key_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        self.key_controller.connect("key-pressed", self.on_keybind_key_pressed)
        self.key_controller.connect("key-released", self.on_keybind_key_released)
        self.add_controller(self.key_controller)

    def on_keybind_key_released(self, controller, keyval, keycode, state):
        key_name = Gdk.keyval_name(keyval) or ""
        if key_name in ("Super_L", "Super_R"):
            self.held_modifiers.discard("SUPER")
        elif key_name in ("Control_L", "Control_R"):
            self.held_modifiers.discard("CTRL")
        elif key_name in ("Alt_L", "Alt_R"):
            self.held_modifiers.discard("ALT")
        elif key_name in ("Shift_L", "Shift_R"):
            self.held_modifiers.discard("SHIFT")

    def on_keybind_key_pressed(self, controller, keyval, keycode, state):
        if not self.recording_btn or not self.recording_bind_info:
            return Gdk.EVENT_PROPAGATE

        key_name = Gdk.keyval_name(keyval) or ""
        mod_keys = {
            "Super_L": "SUPER", "Super_R": "SUPER",
            "Control_L": "CTRL", "Control_R": "CTRL",
            "Alt_L": "ALT", "Alt_R": "ALT",
            "Shift_L": "SHIFT", "Shift_R": "SHIFT",
            "Meta_L": "ALT", "Meta_R": "ALT",
        }

        # If a modifier key was pressed:
        if key_name in mod_keys:
            self.held_modifiers.add(mod_keys[key_name])
            current_mods = " + ".join(sorted(self.held_modifiers))
            self.recording_btn.set_label(f"{current_mods} + ...")
            return Gdk.EVENT_STOP

        # If Escape is pressed with no modifiers: cancel
        if key_name == "Escape" and not self.held_modifiers and not (state & (Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK)):
            self.cancel_recording()
            return Gdk.EVENT_STOP

        # Check modifier presence
        has_super = bool(state & Gdk.ModifierType.SUPER_MASK) or ("SUPER" in self.held_modifiers)
        has_ctrl = bool(state & Gdk.ModifierType.CONTROL_MASK) or ("CTRL" in self.held_modifiers)
        has_alt = bool(state & Gdk.ModifierType.ALT_MASK) or ("ALT" in self.held_modifiers)
        has_shift = bool(state & Gdk.ModifierType.SHIFT_MASK) or ("SHIFT" in self.held_modifiers)

        # Normalize key name
        hypr_key = normalize_key(key_name)

        # Build Hyprland mods
        mods_list = []
        if has_super:
            mods_list.append("$mainMod")
        if has_ctrl:
            mods_list.append("CTRL")
        if has_alt:
            mods_list.append("ALT")
        if has_shift:
            mods_list.append("SHIFT")
        hypr_mods = " ".join(mods_list)

        # Build display string
        disp_list = []
        if has_super:
            disp_list.append("SUPER")
        if has_ctrl:
            disp_list.append("Ctrl")
        if has_alt:
            disp_list.append("Alt")
        if has_shift:
            disp_list.append("Shift")
        disp_list.append(hypr_key)
        new_display_str = " + ".join(disp_list)

        # Apply immediately to keybinds.conf
        success = update_keybind_in_conf(
            line_idx=self.recording_bind_info["line_idx"],
            new_mods=hypr_mods,
            new_key=hypr_key,
            original_rest=self.recording_bind_info["rest"],
            var_key=self.recording_bind_info.get("var_key"),
            display_str=new_display_str
        )

        btn = self.recording_btn
        bind_info = self.recording_bind_info

        btn.set_label(new_display_str)
        btn.remove_css_class("keybind-pill-listening")
        btn.add_css_class("keybind-pill")
        bind_info["mods"] = hypr_mods
        bind_info["key"] = hypr_key
        bind_info["display_str"] = new_display_str

        self.remove_controller(self.key_controller)
        self.key_controller = None
        self.recording_btn = None
        self.recording_bind_info = None
        self.held_modifiers.clear()

        if success:
            self.show_toast("Keybind Applied", f"{bind_info['title']} -> {new_display_str}")
        else:
            self.show_toast("Update Failed", "Could not write to keybinds.conf")

        return Gdk.EVENT_STOP

    # ── Page 1: Bar & Bar Modes ─────────────────────────────────────
    def build_bar_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Bar")
        page.set_icon_name("view-grid-symbolic")

        # Group 1: Bar Modes Selection
        grp_modes = Adw.PreferencesGroup(
            title="Bar Modes",
            description="Choose from 3 desktop bar layout modes"
        )
        page.add(grp_modes)

        for mode_info in BAR_MODES:
            mid = mode_info["id"]
            mname = mode_info["name"]
            msub = mode_info["subtitle"]
            micon = mode_info["icon"]

            row = Adw.ActionRow()
            row.set_title(mname)
            row.set_subtitle(msub)
            row.set_activatable(True)

            prefix_icon = Gtk.Image.new_from_icon_name(micon)
            prefix_icon.set_pixel_size(20)
            row.add_prefix(prefix_icon)

            check_img = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
            check_img.set_pixel_size(18)
            check_img.add_css_class("accent")
            check_img.set_visible(self.current_bar_mode == mid)
            row.add_suffix(check_img)

            def make_click_handler(mode_key):
                return lambda r: self.select_bar_mode(mode_key)

            row.connect("activated", make_click_handler(mid))
            grp_modes.add(row)
            self.bar_mode_rows[mid] = (row, check_img)

        # ── Section 1: Pill Mode Configuration ──────────────────────────────
        grp_pill = Adw.PreferencesGroup(
            title="Pill Mode",
            description="Configuration for the unified continuous floating pill bar"
        )
        page.add(grp_pill)
        self.grp_pill = grp_pill

        # Shift Whole Pill Bar Edge (Top / Bottom)
        row_pill_edge = Adw.ActionRow()
        row_pill_edge.set_title("Shift Whole Pill Bar Edge")
        row_pill_edge.set_subtitle("Shift the continuous connected pill bar between the Top or Bottom screen edge")
        picon_pill = Gtk.Image.new_from_icon_name("view-grid-symbolic")
        picon_pill.set_pixel_size(20)
        row_pill_edge.add_prefix(picon_pill)

        box_pill_edge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box_pill_edge.add_css_class("linked")
        box_pill_edge.set_valign(Gtk.Align.CENTER)

        pill_edges = [("top", "Top"), ("bottom", "Bottom")]
        for evalue, elabel in pill_edges:
            btn = Gtk.Button(label=elabel)
            def make_pill_edge_handler(ev):
                return lambda b: self.set_pill_bar_edge(ev)
            btn.connect("clicked", make_pill_edge_handler(evalue))
            box_pill_edge.append(btn)
            self.pill_edge_buttons[evalue] = btn

        row_pill_edge.add_suffix(box_pill_edge)
        grp_pill.add(row_pill_edge)

        # Pill Center Module Content (Clock + Music / Clock Only / Music Only)
        row_pill_content = Adw.ActionRow()
        row_pill_content.set_title("Center Module Content")
        row_pill_content.set_subtitle("Choose what displays inside the centered module of the pill bar")
        picon_pill_content = Gtk.Image.new_from_icon_name("preferences-system-time-symbolic")
        picon_pill_content.set_pixel_size(20)
        row_pill_content.add_prefix(picon_pill_content)

        box_pill_content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box_pill_content.add_css_class("linked")
        box_pill_content.set_valign(Gtk.Align.CENTER)

        content_options = [
            ("both", "Clock + Music"),
            ("clock", "Clock Only"),
            ("music", "Music Only")
        ]
        for cvalue, clabel in content_options:
            btn = Gtk.Button(label=clabel)
            def make_pill_content_handler(cv):
                return lambda b: self.set_music_bar_content(cv)
            btn.connect("clicked", make_pill_content_handler(cvalue))
            box_pill_content.append(btn)
            self.pill_content_buttons[cvalue] = btn

        row_pill_content.add_suffix(box_pill_content)
        grp_pill.add(row_pill_content)

        # Clock Style shortcut row
        row_pill_clock = Adw.ActionRow()
        row_pill_clock.set_title("Pill Bar Clock Style")
        row_pill_clock.set_subtitle("Customize the font and visual design of the centered clock")
        row_pill_clock.set_activatable(True)
        row_pill_clock.add_prefix(Gtk.Image.new_from_icon_name("preferences-system-time-symbolic"))
        row_pill_clock.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
        row_pill_clock.connect("activated", lambda r: self.navigate_to_page("clock"))
        grp_pill.add(row_pill_clock)

        # ── Section 2: Notch Mode Configuration ─────────────────────────────
        grp_notch = Adw.PreferencesGroup(
            title="Notch Mode",
            description="Configuration for screen-attached curved notch bars with separate islands"
        )
        page.add(grp_notch)
        self.grp_notch = grp_notch

        # Notch Main Bar Edge (Top / Bottom / Left / Right)
        row_notch_edge = Adw.ActionRow()
        row_notch_edge.set_title("Notch Workspaces and Controls Placement")
        row_notch_edge.set_subtitle("Select screen edge for the outer workspaces notch and system controls notch")
        picon_notch_edge = Gtk.Image.new_from_icon_name("user-desktop-symbolic")
        picon_notch_edge.set_pixel_size(20)
        row_notch_edge.add_prefix(picon_notch_edge)

        box_notch_edge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box_notch_edge.add_css_class("linked")
        box_notch_edge.set_valign(Gtk.Align.CENTER)

        notch_edges = [("top", "Top"), ("bottom", "Bottom"), ("left", "Left"), ("right", "Right")]
        for evalue, elabel in notch_edges:
            btn = Gtk.Button(label=elabel)
            def make_notch_edge_handler(ev):
                return lambda b: self.set_notch_bar_edge(ev)
            btn.connect("clicked", make_notch_edge_handler(evalue))
            box_notch_edge.append(btn)
            self.notch_edge_buttons[evalue] = btn

        row_notch_edge.add_suffix(box_notch_edge)
        grp_notch.add(row_notch_edge)

        # Separate Center Music Island Placement (Top / Bottom)
        row_notch_music_edge = Adw.ActionRow()
        row_notch_music_edge.set_title("Separate Center Music Island Placement")
        row_notch_music_edge.set_subtitle("Place the independent curved center music notch on Top or Bottom edge")
        picon_notch_music = Gtk.Image.new_from_icon_name("preferences-desktop-display-symbolic")
        picon_notch_music.set_pixel_size(20)
        row_notch_music_edge.add_prefix(picon_notch_music)

        box_notch_music = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box_notch_music.add_css_class("linked")
        box_notch_music.set_valign(Gtk.Align.CENTER)

        for evalue, elabel in [("top", "Top"), ("bottom", "Bottom")]:
            btn = Gtk.Button(label=elabel)
            def make_notch_music_handler(ev):
                return lambda b: self.set_notch_music_edge(ev)
            btn.connect("clicked", make_notch_music_handler(evalue))
            box_notch_music.append(btn)
            self.notch_music_edge_buttons[evalue] = btn

        row_notch_music_edge.add_suffix(box_notch_music)
        grp_notch.add(row_notch_music_edge)

        # Notch Island Displayed Content
        row_notch_content = Adw.ActionRow()
        row_notch_content.set_title("Island Displayed Content")
        row_notch_content.set_subtitle("Choose to display clock, vinyl music info, or both on the center notch")
        picon_notch_c = Gtk.Image.new_from_icon_name("preferences-system-time-symbolic")
        picon_notch_c.set_pixel_size(20)
        row_notch_content.add_prefix(picon_notch_c)

        box_notch_content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        box_notch_content.add_css_class("linked")
        box_notch_content.set_valign(Gtk.Align.CENTER)

        for cvalue, clabel in content_options:
            btn = Gtk.Button(label=clabel)
            def make_notch_content_handler(cv):
                return lambda b: self.set_music_bar_content(cv)
            btn.connect("clicked", make_notch_content_handler(cvalue))
            box_notch_content.append(btn)
            self.notch_content_buttons[cvalue] = btn

        row_notch_content.add_suffix(box_notch_content)
        grp_notch.add(row_notch_content)

        # Notch Clock Style shortcut row
        row_notch_clock = Adw.ActionRow()
        row_notch_clock.set_title("Center Notch Clock Visual Styles")
        row_notch_clock.set_subtitle("Choose font and styling for the center notch clock: Titan, Digital, Minimal, Pixel")
        row_notch_clock.set_activatable(True)
        row_notch_clock.add_prefix(Gtk.Image.new_from_icon_name("preferences-system-time-symbolic"))
        row_notch_clock.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
        row_notch_clock.connect("activated", lambda r: self.navigate_to_page("clock"))
        grp_notch.add(row_notch_clock)

        self.update_mode_sensitivity()

        self.view_stack.add_named(page, "bar")

    def build_minimal_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Minimal Mode")
        page.set_icon_name("open-menu-symbolic")

        # Group 1: Dynamic Island Status & Conversion
        grp_status = Adw.PreferencesGroup(
            title="Dynamic Island Status",
            description="Ultra-lightweight single bar mode engineered for minimum CPU, GPU, and RAM consumption"
        )
        page.add(grp_status)

        # Status row
        row_status = Adw.ActionRow()
        row_status.set_title("Minimal Mode Active")
        row_status.set_subtitle("Dynamic Island is currently active on screen" if self.current_bar_mode == "minimal" else "Currently inactive - click switch below to activate")
        row_status.add_prefix(Gtk.Image.new_from_icon_name("open-menu-symbolic"))

        box_status_action = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        box_status_action.set_valign(Gtk.Align.CENTER)

        btn_activate = Gtk.Button(label="Activate Minimal Mode")
        btn_activate.add_css_class("suggested-action")
        btn_activate.connect("clicked", lambda b: self.select_bar_mode("minimal"))
        box_status_action.append(btn_activate)
        self.minimal_activate_btn = btn_activate

        badge_active = Gtk.Label(label="ACTIVE")
        badge_active.add_css_class("accent")
        box_status_action.append(badge_active)
        self.minimal_status_badge = badge_active

        is_min = (self.current_bar_mode == "minimal")
        btn_activate.set_visible(not is_min)
        badge_active.set_visible(is_min)

        row_status.add_suffix(box_status_action)
        grp_status.add(row_status)
        self.minimal_status_row = row_status

        # Convert to Desktop Bar row
        row_convert = Adw.ActionRow()
        row_convert.set_title("Convert to Desktop Bar")
        row_convert.set_subtitle("Switch from Minimal Island to a full multi-module desktop bar")
        row_convert.add_prefix(Gtk.Image.new_from_icon_name("view-grid-symbolic"))

        box_convert = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        box_convert.set_valign(Gtk.Align.CENTER)

        btn_to_pill = Gtk.Button(label="Switch to Pill Bar")
        btn_to_pill.connect("clicked", lambda b: self.select_bar_mode("pill"))
        box_convert.append(btn_to_pill)

        btn_to_notch = Gtk.Button(label="Switch to Notch Bar")
        btn_to_notch.connect("clicked", lambda b: self.select_bar_mode("notch"))
        box_convert.append(btn_to_notch)

        row_convert.add_suffix(box_convert)
        grp_status.add(row_convert)
        self.minimal_convert_row = row_convert

        # Persistent Island Bar Option
        row_persist = Adw.SwitchRow()
        row_persist.set_title("Persistent Island Bar")
        row_persist.set_subtitle("Always visible on screen (persistent) or reveal only on hover (hover mode)")
        row_persist.add_prefix(Gtk.Image.new_from_icon_name("view-reveal-symbolic"))
        row_persist.set_active(read_island_persistent())
        row_persist.connect("notify::active", lambda s, p: save_island_persistent(s.get_active()))
        grp_status.add(row_persist)
        self.minimal_persist_row = row_persist

        # Group 2: Minimal Island Shape
        grp_island_mode = Adw.PreferencesGroup(
            title="Minimal Island Shape",
            description="Choose whether the dynamic island renders as a floating capsule or screen-attached curved notch"
        )
        page.add(grp_island_mode)
        self.grp_island_mode = grp_island_mode

        row_island_mode = Adw.ActionRow()
        row_island_mode.set_title("Island Shape")
        row_island_mode.set_subtitle("Floating Capsule (rounded floating island) or Screen Notch (attached curved notch)")
        row_island_mode.add_prefix(Gtk.Image.new_from_icon_name("view-paged-symbolic"))

        box_island_mode = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        box_island_mode.set_valign(Gtk.Align.CENTER)
        self.island_style_buttons = {}

        curr_island_style = self.read_island_style()
        for svalue, slabel, sicon in [("pill", "Floating Capsule", "view-grid-symbolic"), ("notch", "Screen Notch", "user-desktop-symbolic")]:
            btn = Gtk.Button()
            h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
            h.append(Gtk.Image.new_from_icon_name(sicon))
            h.append(Gtk.Label(label=slabel))
            btn.set_child(h)
            if svalue == curr_island_style:
                btn.add_css_class("suggested-action")

            def make_island_style_handler(sv):
                return lambda b: self.set_island_style(sv)
            btn.connect("clicked", make_island_style_handler(svalue))
            box_island_mode.append(btn)
            self.island_style_buttons[svalue] = btn

        row_island_mode.add_suffix(box_island_mode)
        grp_island_mode.add(row_island_mode)

        # Group 3: Screen Edge Placement
        grp_edge = Adw.PreferencesGroup(
            title="Screen Placement",
            description="Position the floating dynamic island at the top or bottom of the screen"
        )
        page.add(grp_edge)
        self.grp_minimal_settings = grp_edge

        row_edge = Adw.ActionRow()
        row_edge.set_title("Dynamic Island Edge")
        row_edge.set_subtitle("Shift island between Top and Bottom edge")
        row_edge.add_prefix(Gtk.Image.new_from_icon_name("preferences-desktop-display-symbolic"))

        box_edge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        box_edge.set_valign(Gtk.Align.CENTER)
        self.minimal_edge_buttons = {}

        curr_main_edge = self.bar_pos.get("mainBarEdge", "top")
        for evalue, elabel in [("top", "Top (Default)"), ("bottom", "Bottom")]:
            btn = Gtk.Button(label=elabel)
            if evalue == curr_main_edge:
                btn.add_css_class("suggested-action")

            def make_edge_handler(ev):
                return lambda b: self.set_pill_bar_edge(ev)
            btn.connect("clicked", make_edge_handler(evalue))
            box_edge.append(btn)
            self.minimal_edge_buttons[evalue] = btn

        row_edge.add_suffix(box_edge)
        grp_edge.add(row_edge)

        # Group 3: Low Resource Optimization Metrics
        grp_metrics = Adw.PreferencesGroup(
            title="Resource Consumption Profile",
            description="Architectural optimizations ensuring absolute lowest hardware overhead"
        )
        page.add(grp_metrics)

        row_surf = Adw.ActionRow()
        row_surf.set_title("Single Wayland Surface")
        row_surf.set_subtitle("Allocates only 1 compact layer-shell window (saves 65% VRAM vs multi-window modes)")
        row_surf.add_prefix(Gtk.Image.new_from_icon_name("emblem-ok-symbolic"))
        grp_metrics.add(row_surf)

        row_blur = Adw.ActionRow()
        row_blur.set_title("Zero Multi-Pass Shaders")
        row_blur.set_subtitle("Bypasses GPU-intensive fast blur shader pipelines for near-zero GPU utilization")
        row_blur.add_prefix(Gtk.Image.new_from_icon_name("emblem-ok-symbolic"))
        grp_metrics.add(row_blur)

        row_event = Adw.ActionRow()
        row_event.set_title("Pure Event-Driven Telemetry")
        row_event.set_subtitle("Replaces polling timers with native Hyprland, PipeWire, and UPower event signals")
        row_event.add_prefix(Gtk.Image.new_from_icon_name("emblem-ok-symbolic"))
        grp_metrics.add(row_event)

        self.view_stack.add_named(page, "minimal")

    def build_clock_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Clock Styles")
        page.set_icon_name("preferences-system-time-symbolic")

        grp_clock = Adw.PreferencesGroup(
            title="Center Bar Clock Designs",
            description="Click any visual design below to immediately activate it on the center bar clock"
        )
        page.add(grp_clock)

        for cinfo in CLOCK_DESIGNS:
            cid = cinfo["id"]
            cname = cinfo["name"]
            csub = cinfo["subtitle"]
            cmarkup = cinfo["markup"]

            row = Adw.ActionRow()
            row.set_title(cname)
            row.set_subtitle(csub)
            row.set_activatable(True)

            # Visual Clock Display Preview Box (PREFIX)
            preview_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            preview_box.set_valign(Gtk.Align.CENTER)
            preview_box.set_size_request(130, 48)
            preview_box.add_css_class("clock-preview-card")

            lbl = Gtk.Label()
            lbl.set_use_markup(True)
            lbl.set_markup(cmarkup)
            lbl.set_halign(Gtk.Align.CENTER)
            lbl.set_valign(Gtk.Align.CENTER)
            lbl.set_hexpand(True)
            preview_box.append(lbl)
            row.add_prefix(preview_box)

            # Active selection checkmark (SUFFIX)
            check_img = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
            check_img.set_pixel_size(18)
            check_img.add_css_class("accent")
            check_img.set_visible(self.current_clock_style == cid)
            row.add_suffix(check_img)

            def make_clock_click_handler(clock_key):
                return lambda r: self.select_clock_style(clock_key)

            row.connect("activated", make_clock_click_handler(cid))
            grp_clock.add(row)
            self.clock_rows[cid] = (row, check_img)

        self.view_stack.add_named(page, "clock")

    def build_wifi_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Wi-Fi Networks")
        page.set_icon_name("network-wireless-symbolic")

        # Group 1: Hardware Toggle
        grp_hw = Adw.PreferencesGroup(
            title="Wi-Fi Hardware",
            description="Manage wireless adapter and connection status"
        )
        page.add(grp_hw)

        wifi_switch = Adw.SwitchRow()
        wifi_switch.set_title("Wi-Fi Radio")
        wifi_switch.set_subtitle("Enable or disable wireless antenna")

        def check_wifi_enabled():
            try:
                res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True, timeout=1.5)
                return "enabled" in res.stdout.lower()
            except Exception:
                return True

        self._wifi_updating = True
        wifi_switch.set_active(check_wifi_enabled())
        self._wifi_updating = False

        grp_networks = Adw.PreferencesGroup(
            title="Available Networks",
            description="Scanned wireless access points in range"
        )

        # Header suffix: Spinner + Scan Button
        scan_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        scan_box.set_valign(Gtk.Align.CENTER)

        wifi_spinner = Gtk.Spinner()
        wifi_spinner.set_visible(False)
        scan_box.append(wifi_spinner)

        btn_scan = Gtk.Button()
        btn_scan_content = Adw.ButtonContent()
        btn_scan_content.set_icon_name("view-refresh-symbolic")
        btn_scan_content.set_label("Scan Networks")
        btn_scan.set_child(btn_scan_content)
        btn_scan.set_valign(Gtk.Align.CENTER)
        btn_scan.add_css_class("flat")
        btn_scan.set_tooltip_text("Scan for nearby Wi-Fi Networks")
        scan_box.append(btn_scan)

        grp_networks.set_header_suffix(scan_box)

        def on_wifi_toggled(row, param):
            if getattr(self, "_wifi_updating", False):
                return
            state = "on" if row.get_active() else "off"
            subprocess.run(["nmcli", "radio", "wifi", state])
            self.show_toast("Wi-Fi", f"Wireless radio turned {state}")
            refresh_networks(rescan=True)

        wifi_switch.connect("notify::active", on_wifi_toggled)
        grp_hw.add(wifi_switch)

        self.wifi_rows = []

        def get_signal_icon(sig):
            if sig >= 75: return "network-wireless-signal-excellent-symbolic"
            if sig >= 50: return "network-wireless-signal-good-symbolic"
            if sig >= 25: return "network-wireless-signal-ok-symbolic"
            return "network-wireless-signal-weak-symbolic"

        def get_saved_connections():
            saved = {}
            try:
                res = subprocess.run(["nmcli", "-t", "-f", "NAME,UUID,TYPE", "con", "show"], capture_output=True, text=True, timeout=2)
                for l in res.stdout.strip().split("\n"):
                    parts = l.split(":")
                    if len(parts) >= 3 and parts[2] in ("802-11-wireless", "wifi"):
                        saved[parts[0]] = parts[1]
            except Exception:
                pass
            return saved

        def prompt_password_dialog(ssid, security):
            dialog = Adw.MessageDialog(
                transient_for=self,
                heading=f"Connect to “{ssid}”",
                body=f"Security: {security or 'WPA/WPA2/WPA3'}\nEnter the wireless network password to connect."
            )
            dialog.add_response("cancel", "Cancel")
            dialog.add_response("connect", "Connect")
            dialog.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_default_response("connect")
            dialog.set_close_response("cancel")

            pwd_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            pwd_box.set_margin_top(12)
            pwd_box.set_margin_bottom(12)
            pwd_box.set_margin_start(16)
            pwd_box.set_margin_end(16)

            pwd_entry = Gtk.PasswordEntry()
            pwd_entry.set_show_peek_icon(True)
            pwd_entry.set_placeholder_text("Network Password")
            pwd_entry.set_hexpand(True)
            pwd_entry.connect("activate", lambda e: dialog.response("connect"))
            pwd_box.append(pwd_entry)
            dialog.set_extra_child(pwd_box)

            def on_dialog_response(dlg, response):
                if response == "connect":
                    pwd = pwd_entry.get_text()
                    self.show_toast("Wi-Fi", f"Connecting to {ssid}…")
                    def run_pwd_connect():
                        subprocess.run(["nmcli", "con", "delete", "id", ssid], capture_output=True, text=True, timeout=3)
                        cmd = ["nmcli", "dev", "wifi", "connect", ssid]
                        if pwd:
                            cmd += ["password", pwd]
                        res = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
                        if res.returncode == 0:
                            GLib.idle_add(lambda: self.show_toast("Wi-Fi Connected", f"Connected to {ssid}"))
                        else:
                            err = res.stderr.strip() or res.stdout.strip() or "Failed to connect"
                            err = re.sub(r"^Error:\s*", "", err)
                            GLib.idle_add(lambda: self.show_toast("Connection Failed", err))
                        GLib.idle_add(lambda: refresh_networks(rescan=False))
                    threading.Thread(target=run_pwd_connect, daemon=True).start()

            dialog.connect("response", on_dialog_response)
            dialog.present()
            GLib.idle_add(pwd_entry.grab_focus)

        def connect_to_network(ssid, security, is_saved=False):
            if is_saved:
                self.show_toast("Wi-Fi", f"Connecting to {ssid}…")
                def run_saved_connect():
                    res = subprocess.run(["nmcli", "con", "up", "id", ssid], capture_output=True, text=True, timeout=15)
                    if res.returncode == 0:
                        GLib.idle_add(lambda: self.show_toast("Wi-Fi Connected", f"Connected to {ssid}"))
                    else:
                        GLib.idle_add(lambda: prompt_password_dialog(ssid, security))
                    GLib.idle_add(lambda: refresh_networks(rescan=False))
                threading.Thread(target=run_saved_connect, daemon=True).start()
            elif security == "Open" or not security or "none" in security.lower():
                self.show_toast("Wi-Fi", f"Connecting to {ssid}…")
                def run_open_connect():
                    res = subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], capture_output=True, text=True, timeout=15)
                    if res.returncode == 0:
                        GLib.idle_add(lambda: self.show_toast("Wi-Fi Connected", f"Connected to {ssid}"))
                    else:
                        err = res.stderr.strip() or res.stdout.strip() or "Connection failed"
                        GLib.idle_add(lambda: self.show_toast("Connection Failed", err))
                    GLib.idle_add(lambda: refresh_networks(rescan=False))
                threading.Thread(target=run_open_connect, daemon=True).start()
            else:
                prompt_password_dialog(ssid, security)

        def disconnect_network(ssid):
            def run_dc():
                subprocess.run(["nmcli", "con", "down", "id", ssid], capture_output=True, text=True, timeout=5)
                GLib.idle_add(lambda: self.show_toast("Wi-Fi", f"Disconnected from {ssid}"))
                GLib.idle_add(lambda: refresh_networks(rescan=False))
            threading.Thread(target=run_dc, daemon=True).start()

        def forget_network(ssid):
            def run_forget():
                subprocess.run(["nmcli", "con", "delete", "id", ssid], capture_output=True, text=True, timeout=5)
                GLib.idle_add(lambda: self.show_toast("Wi-Fi", f"Removed profile for {ssid}"))
                GLib.idle_add(lambda: refresh_networks(rescan=False))
            threading.Thread(target=run_forget, daemon=True).start()

        def connect_hidden_network():
            dialog = Adw.MessageDialog(
                transient_for=self,
                heading="Connect to Hidden Network",
                body="Enter the exact SSID name and security credentials of the hidden network."
            )
            dialog.add_response("cancel", "Cancel")
            dialog.add_response("connect", "Connect")
            dialog.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_default_response("connect")
            dialog.set_close_response("cancel")

            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            box.set_margin_top(12)
            box.set_margin_bottom(12)
            box.set_margin_start(16)
            box.set_margin_end(16)

            ssid_entry = Gtk.Entry()
            ssid_entry.set_placeholder_text("Network Name (SSID)")
            box.append(ssid_entry)

            pwd_entry = Gtk.PasswordEntry()
            pwd_entry.set_show_peek_icon(True)
            pwd_entry.set_placeholder_text("Password (leave empty if open)")
            pwd_entry.connect("activate", lambda e: dialog.response("connect"))
            box.append(pwd_entry)

            dialog.set_extra_child(box)

            def on_hidden_resp(dlg, resp):
                if resp == "connect":
                    s = ssid_entry.get_text().strip()
                    p = pwd_entry.get_text().strip()
                    if not s:
                        self.show_toast("Error", "Network name cannot be empty")
                        return
                    self.show_toast("Wi-Fi", f"Connecting to {s}…")
                    def run_hidden_connect():
                        cmd = ["nmcli", "dev", "wifi", "connect", s, "hidden", "yes"]
                        if p:
                            cmd += ["password", p]
                        res = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
                        if res.returncode == 0:
                            GLib.idle_add(lambda: self.show_toast("Wi-Fi Connected", f"Connected to {s}"))
                        else:
                            err = res.stderr.strip() or res.stdout.strip() or "Connection failed"
                            GLib.idle_add(lambda: self.show_toast("Connection Failed", err))
                        GLib.idle_add(lambda: refresh_networks(rescan=False))
                    threading.Thread(target=run_hidden_connect, daemon=True).start()

            dialog.connect("response", on_hidden_resp)
            dialog.present()
            GLib.idle_add(ssid_entry.grab_focus)

        def populate_wifi_ui(networks, saved_conns):
            for r in self.wifi_rows:
                grp_networks.remove(r)
            self.wifi_rows.clear()

            if not networks:
                empty_row = Adw.ActionRow()
                empty_row.set_title("No Wi-Fi Networks Found")
                empty_row.set_subtitle("Ensure Wi-Fi is enabled or click 'Scan Networks' to search again")
                grp_networks.add(empty_row)
                self.wifi_rows.append(empty_row)
            else:
                for net in networks:
                    row = Adw.ActionRow()
                    row.set_title(net["ssid"])
                    sec_str = net["security"] or "Open"
                    is_saved = net["ssid"] in saved_conns
                    sub_parts = [sec_str, f"Signal: {net['signal']}%"]
                    if is_saved:
                        sub_parts.append("Saved")
                    row.set_subtitle(" · ".join(sub_parts))

                    sig_img = Gtk.Image.new_from_icon_name(get_signal_icon(net["signal"]))
                    sig_img.set_pixel_size(18)
                    if net["in_use"]:
                        sig_img.add_css_class("accent")
                    row.add_prefix(sig_img)

                    if net["in_use"]:
                        badge = Gtk.Label(label="Connected")
                        badge.add_css_class("success")
                        badge.set_valign(Gtk.Align.CENTER)
                        row.add_suffix(badge)

                        btn_dc = Gtk.Button(label="Disconnect")
                        btn_dc.set_valign(Gtk.Align.CENTER)
                        btn_dc.add_css_class("destructive-action")
                        btn_dc.connect("clicked", lambda b, s=net["ssid"]: disconnect_network(s))
                        row.add_suffix(btn_dc)
                    else:
                        btn_c = Gtk.Button(label="Connect")
                        btn_c.set_valign(Gtk.Align.CENTER)
                        btn_c.add_css_class("suggested-action")
                        btn_c.connect("clicked", lambda b, s=net["ssid"], sec=net["security"], sav=is_saved: connect_to_network(s, sec, sav))
                        row.add_suffix(btn_c)

                        if is_saved:
                            btn_forget = Gtk.Button(icon_name="user-trash-symbolic")
                            btn_forget.set_valign(Gtk.Align.CENTER)
                            btn_forget.set_tooltip_text(f"Forget {net['ssid']}")
                            btn_forget.add_css_class("flat")
                            btn_forget.connect("clicked", lambda b, s=net["ssid"]: forget_network(s))
                            row.add_suffix(btn_forget)

                    row.set_activatable(not net["in_use"])
                    if not net["in_use"]:
                        row.connect("activated", lambda r, s=net["ssid"], sec=net["security"], sav=is_saved: connect_to_network(s, sec, sav))

                    grp_networks.add(row)
                    self.wifi_rows.append(row)

            # Hidden network entry row
            hidden_row = Adw.ActionRow()
            hidden_row.set_title("Connect to Hidden Network…")
            hidden_row.set_subtitle("Join a network that is not broadcasting its SSID")
            hidden_img = Gtk.Image.new_from_icon_name("list-add-symbolic")
            hidden_img.set_pixel_size(18)
            hidden_row.add_prefix(hidden_img)
            hidden_row.set_activatable(True)
            hidden_row.connect("activated", lambda r: connect_hidden_network())

            btn_add = Gtk.Button(label="Add")
            btn_add.set_valign(Gtk.Align.CENTER)
            btn_add.add_css_class("flat")
            btn_add.connect("clicked", lambda b: connect_hidden_network())
            hidden_row.add_suffix(btn_add)

            grp_networks.add(hidden_row)
            self.wifi_rows.append(hidden_row)

        def refresh_networks(rescan=True):
            btn_scan.set_sensitive(False)
            btn_scan_content.set_label("Scanning…")
            wifi_spinner.set_visible(True)
            wifi_spinner.start()

            def scan_worker():
                networks = []
                saved_conns = get_saved_connections()
                try:
                    if rescan:
                        subprocess.run(["nmcli", "dev", "wifi", "rescan"], capture_output=True, text=True, timeout=6)
                    cmd = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
                    res = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
                    seen = {}
                    for line in res.stdout.strip().split("\n"):
                        if not line: continue
                        parts = line.replace(r"\:", "__COLON__").split(":")
                        if len(parts) >= 4:
                            in_use = parts[0].strip() == "*"
                            ssid = parts[1].replace("__COLON__", ":").strip()
                            if not ssid: continue
                            sig = int(parts[2].strip()) if parts[2].strip().isdigit() else 0
                            sec = parts[3].strip() or "Open"
                            if ssid not in seen or in_use or sig > seen[ssid]["signal"]:
                                seen[ssid] = {"in_use": in_use, "ssid": ssid, "signal": sig, "security": sec}
                    networks = sorted(
                        seen.values(),
                        key=lambda x: (-int(x["in_use"]), -int(x["ssid"] in saved_conns), -x["signal"])
                    )
                except Exception as e:
                    print("Wi-Fi scan error:", e)
                GLib.idle_add(lambda: populate_wifi_ui(networks, saved_conns))
                GLib.idle_add(lambda: wifi_spinner.stop())
                GLib.idle_add(lambda: wifi_spinner.set_visible(False))
                GLib.idle_add(lambda: btn_scan_content.set_label("Scan Networks"))
                GLib.idle_add(lambda: btn_scan.set_sensitive(True))

            threading.Thread(target=scan_worker, daemon=True).start()

        btn_scan.connect("clicked", lambda b: refresh_networks(rescan=True))
        page.add(grp_networks)

        refresh_networks(rescan=False)
        self.view_stack.add_named(page, "wifi")

    def build_bluetooth_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Bluetooth")
        page.set_icon_name("bluetooth-symbolic")

        # Group 1: Adapter Status & Power
        grp_adapter = Adw.PreferencesGroup(
            title="Bluetooth Adapter",
            description="Manage Bluetooth radio and device connections"
        )
        page.add(grp_adapter)

        bt_switch = Adw.SwitchRow()
        bt_switch.set_title("Bluetooth Radio")
        bt_switch.set_subtitle("Enable or disable controller communication")

        def check_bt_powered():
            try:
                res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True, timeout=1.5)
                return "Powered: yes" in res.stdout
            except Exception:
                return False

        self._bt_updating = True
        bt_switch.set_active(check_bt_powered())
        self._bt_updating = False

        # Group 2: Paired Devices
        grp_paired = Adw.PreferencesGroup(
            title="Paired Devices",
            description="Connected or saved peripherals and accessories"
        )

        # Header suffix on Paired group: Spinner + Scan Button
        scan_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        scan_box.set_valign(Gtk.Align.CENTER)

        bt_spinner = Gtk.Spinner()
        bt_spinner.set_visible(False)
        scan_box.append(bt_spinner)

        btn_scan = Gtk.Button()
        btn_scan_content = Adw.ButtonContent()
        btn_scan_content.set_icon_name("view-refresh-symbolic")
        btn_scan_content.set_label("Scan for Devices")
        btn_scan.set_child(btn_scan_content)
        btn_scan.set_valign(Gtk.Align.CENTER)
        btn_scan.add_css_class("flat")
        btn_scan.set_tooltip_text("Scan for nearby Bluetooth devices in pairing mode")
        scan_box.append(btn_scan)

        grp_paired.set_header_suffix(scan_box)

        # Group 3: Available / Nearby Devices
        grp_nearby = Adw.PreferencesGroup(
            title="Nearby Devices",
            description="Discovered Bluetooth devices in range ready to pair"
        )

        def on_bt_toggled(row, param):
            if getattr(self, "_bt_updating", False):
                return
            state = "on" if row.get_active() else "off"
            subprocess.run(["rfkill", "unblock", "bluetooth"], capture_output=True)
            subprocess.run(["bluetoothctl", "power", state], capture_output=True)
            self.show_toast("Bluetooth", f"Bluetooth radio turned {state}")
            refresh_bt_devices(scan=(state == "on"))

        bt_switch.connect("notify::active", on_bt_toggled)
        grp_adapter.add(bt_switch)

        self.bt_paired_rows = []
        self.bt_nearby_rows = []

        def get_bt_icon(name, info_str=""):
            n = (name or "").lower()
            comb = (n + " " + (info_str or "").lower())
            if any(k in comb for k in ("audio", "headset", "earphones", "headphone", "airpods", "airdopes", "rockerz", "buds", "sound")):
                return "audio-headphones-symbolic"
            if any(k in comb for k in ("mouse", "trackpad")):
                return "input-mouse-symbolic"
            if any(k in comb for k in ("keyboard", "keypad")):
                return "input-keyboard-symbolic"
            if any(k in comb for k in ("tv", "oled", "display", "screen", "stb")):
                return "video-display-symbolic"
            if any(k in comb for k in ("phone", "iphone", "android", "pixel", "galaxy")):
                return "phone-symbolic"
            return "bluetooth-symbolic"

        def toggle_bt_connect(mac, currently_connected):
            action = "disconnect" if currently_connected else "connect"
            def run_bt_action():
                res = subprocess.run(["bluetoothctl", action, mac], capture_output=True, text=True, timeout=12)
                if res.returncode == 0:
                    GLib.idle_add(lambda: self.show_toast("Bluetooth", f"{action.capitalize()}ed {mac}"))
                else:
                    err = res.stderr.strip() or res.stdout.strip() or f"Failed to {action}"
                    GLib.idle_add(lambda: self.show_toast("Bluetooth Error", err))
                GLib.idle_add(lambda: refresh_bt_devices(scan=False))
            threading.Thread(target=run_bt_action, daemon=True).start()

        def remove_bt_device(mac, name):
            def run_rm():
                subprocess.run(["bluetoothctl", "remove", mac], capture_output=True, text=True, timeout=5)
                GLib.idle_add(lambda: self.show_toast("Bluetooth", f"Forgot {name}"))
                GLib.idle_add(lambda: refresh_bt_devices(scan=False))
            threading.Thread(target=run_rm, daemon=True).start()

        def pair_bt_device(mac, name, btn):
            btn.set_sensitive(False)
            btn.set_label("Pairing…")
            self.show_toast("Bluetooth", f"Pairing with {name}…")
            def run_pair():
                p1 = subprocess.run(["bluetoothctl", "pair", mac], capture_output=True, text=True, timeout=25)
                subprocess.run(["bluetoothctl", "trust", mac], capture_output=True, text=True, timeout=5)
                p2 = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True, timeout=15)
                if p1.returncode == 0 or p2.returncode == 0:
                    GLib.idle_add(lambda: self.show_toast("Bluetooth", f"Paired & Connected to {name}"))
                else:
                    err = p1.stderr.strip() or p2.stderr.strip() or p1.stdout.strip() or "Pairing timed out"
                    err = re.sub(r"^Failed to pair:\s*", "", err)
                    GLib.idle_add(lambda: self.show_toast("Pairing Failed", err))
                GLib.idle_add(lambda: refresh_bt_devices(scan=False))
            threading.Thread(target=run_pair, daemon=True).start()

        def populate_bt_ui(paired, nearby):
            for r in self.bt_paired_rows:
                grp_paired.remove(r)
            self.bt_paired_rows.clear()

            for r in self.bt_nearby_rows:
                grp_nearby.remove(r)
            self.bt_nearby_rows.clear()

            # 1. Populate Paired Devices
            if not paired:
                empty_row = Adw.ActionRow()
                empty_row.set_title("No Paired Devices")
                empty_row.set_subtitle("Put your Bluetooth device in pairing mode and click 'Scan for Devices'")
                grp_paired.add(empty_row)
                self.bt_paired_rows.append(empty_row)
            else:
                for dev in paired:
                    row = Adw.ActionRow()
                    row.set_title(dev["name"])
                    status_str = "Connected" if dev["connected"] else "Not Connected"
                    row.set_subtitle(f"{dev['mac']} · {status_str}")

                    dev_img = Gtk.Image.new_from_icon_name(dev["icon"])
                    dev_img.set_pixel_size(18)
                    if dev["connected"]:
                        dev_img.add_css_class("accent")
                    row.add_prefix(dev_img)

                    if dev["connected"]:
                        badge = Gtk.Label(label="Connected")
                        badge.add_css_class("success")
                        badge.set_valign(Gtk.Align.CENTER)
                        row.add_suffix(badge)

                        btn_dc = Gtk.Button(label="Disconnect")
                        btn_dc.set_valign(Gtk.Align.CENTER)
                        btn_dc.add_css_class("destructive-action")
                        btn_dc.connect("clicked", lambda b, m=dev["mac"]: toggle_bt_connect(m, True))
                        row.add_suffix(btn_dc)
                    else:
                        btn_c = Gtk.Button(label="Connect")
                        btn_c.set_valign(Gtk.Align.CENTER)
                        btn_c.add_css_class("suggested-action")
                        btn_c.connect("clicked", lambda b, m=dev["mac"]: toggle_bt_connect(m, False))
                        row.add_suffix(btn_c)

                    btn_forget = Gtk.Button(icon_name="user-trash-symbolic")
                    btn_forget.set_valign(Gtk.Align.CENTER)
                    btn_forget.set_tooltip_text(f"Forget {dev['name']}")
                    btn_forget.add_css_class("flat")
                    btn_forget.connect("clicked", lambda b, m=dev["mac"], n=dev["name"]: remove_bt_device(m, n))
                    row.add_suffix(btn_forget)

                    row.set_activatable(True)
                    row.connect("activated", lambda r, m=dev["mac"], c=dev["connected"]: toggle_bt_connect(m, c))

                    grp_paired.add(row)
                    self.bt_paired_rows.append(row)

            # 2. Populate Nearby Devices
            if not nearby:
                empty_row = Adw.ActionRow()
                empty_row.set_title("No Nearby Devices")
                empty_row.set_subtitle("Make sure your device is in pairing mode and click 'Scan for Devices'")
                grp_nearby.add(empty_row)
                self.bt_nearby_rows.append(empty_row)
            else:
                for dev in nearby:
                    row = Adw.ActionRow()
                    row.set_title(dev["name"])
                    row.set_subtitle(dev["mac"])

                    dev_img = Gtk.Image.new_from_icon_name(dev["icon"])
                    dev_img.set_pixel_size(18)
                    row.add_prefix(dev_img)

                    btn_pair = Gtk.Button(label="Pair")
                    btn_pair.set_valign(Gtk.Align.CENTER)
                    btn_pair.add_css_class("suggested-action")
                    btn_pair.connect("clicked", lambda b, m=dev["mac"], n=dev["name"]: pair_bt_device(m, n, b))
                    row.add_suffix(btn_pair)

                    row.set_activatable(True)
                    row.connect("activated", lambda r, m=dev["mac"], n=dev["name"], b=btn_pair: pair_bt_device(m, n, b))

                    grp_nearby.add(row)
                    self.bt_nearby_rows.append(row)

        def refresh_bt_devices(scan=False):
            btn_scan.set_sensitive(False)
            if scan:
                btn_scan_content.set_label("Scanning…")
                bt_spinner.set_visible(True)
                bt_spinner.start()

            def bt_worker():
                paired = []
                nearby = []
                try:
                    if scan:
                        subprocess.run(["bluetoothctl", "--timeout", "6", "scan", "on"], capture_output=True, text=True, timeout=8)

                    paired_out = subprocess.run(["bluetoothctl", "devices", "Paired"], capture_output=True, text=True, timeout=3).stdout
                    paired_macs = set()
                    for line in paired_out.strip().split("\n"):
                        if not line: continue
                        parts = line.split(" ", 2)
                        if len(parts) >= 3 and parts[0] == "Device":
                            mac = parts[1]
                            name = parts[2].strip()
                            paired_macs.add(mac)
                            info_res = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True, timeout=2).stdout
                            conn = "Connected: yes" in info_res
                            icon = get_bt_icon(name, info_res)
                            paired.append({"mac": mac, "name": name, "connected": conn, "icon": icon})

                    all_out = subprocess.run(["bluetoothctl", "devices"], capture_output=True, text=True, timeout=3).stdout
                    for line in all_out.strip().split("\n"):
                        if not line: continue
                        parts = line.split(" ", 2)
                        if len(parts) >= 3 and parts[0] == "Device":
                            mac = parts[1]
                            name = parts[2].strip()
                            if mac not in paired_macs:
                                if not name or name.replace("-", ":").upper() == mac.upper():
                                    continue
                                icon = get_bt_icon(name)
                                nearby.append({"mac": mac, "name": name, "icon": icon})

                    nearby.sort(key=lambda x: x["name"].lower())

                except Exception as e:
                    print("Bluetooth query error:", e)

                GLib.idle_add(lambda: populate_bt_ui(paired, nearby))
                GLib.idle_add(lambda: bt_spinner.stop())
                GLib.idle_add(lambda: bt_spinner.set_visible(False))
                GLib.idle_add(lambda: btn_scan_content.set_label("Scan for Devices"))
                GLib.idle_add(lambda: btn_scan.set_sensitive(True))

            threading.Thread(target=bt_worker, daemon=True).start()

        btn_scan.connect("clicked", lambda b: refresh_bt_devices(scan=True))
        page.add(grp_paired)
        page.add(grp_nearby)

        refresh_bt_devices(scan=False)
        self.view_stack.add_named(page, "bluetooth")

    def build_lockscreen_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Lock Screen")

        self.lockscreen_cfg = read_lockscreen_config()

        # Group 1: Audio Visualizer
        grp_vis = Adw.PreferencesGroup(
            title="Audio Visualizer",
            description="Continuous fluid audio wave attached to the top edge of the lock screen"
        )
        page.add(grp_vis)

        # Cava Visualizer toggle switch
        row_cava = Adw.SwitchRow()
        row_cava.set_title("Top Edge Wavy Audio Visualizer")
        row_cava.set_subtitle("Continuous fluid frequency wave spanning from left to right edge when media plays")
        row_cava.set_active(self.lockscreen_cfg.get("visualizer", True))
        row_cava.add_prefix(Gtk.Image.new_from_icon_name("audio-volume-high-symbolic"))

        def on_cava_toggled(switch_row, param):
            val = switch_row.get_active()
            self.lockscreen_cfg["visualizer"] = val
            save_lockscreen_config(self.lockscreen_cfg)
            self.show_toast("Lock Visualizer " + ("Enabled" if val else "Disabled"), f"Top wavy visualizer is now {'active' if val else 'hidden'}")

        row_cava.connect("notify::active", on_cava_toggled)
        grp_vis.add(row_cava)

        # Group 2: Atomic Logo Animations
        grp_atom = Adw.PreferencesGroup(
            title="Atom Core Effects",
            description="Visual animations of the central Carbon Bohr atom structure"
        )
        page.add(grp_atom)

        # Heartbeat Pulse switch
        row_heartbeat = Adw.SwitchRow()
        row_heartbeat.set_title("Atom Heartbeat Pulse Effect")
        row_heartbeat.set_subtitle("Periodic shockwave ripple and valence electron bounce expanding from the atomic core")
        row_heartbeat.set_active(self.lockscreen_cfg.get("heartbeat", True))
        row_heartbeat.add_prefix(Gtk.Image.new_from_icon_name("media-record-symbolic"))

        def on_heartbeat_toggled(switch_row, param):
            val = switch_row.get_active()
            self.lockscreen_cfg["heartbeat"] = val
            save_lockscreen_config(self.lockscreen_cfg)
            self.show_toast("Atom Heartbeat " + ("Enabled" if val else "Disabled"), f"Heartbeat shockwave ripple is now {'active' if val else 'disabled'}")

        row_heartbeat.connect("notify::active", on_heartbeat_toggled)
        grp_atom.add(row_heartbeat)

        # Group 4: Widgets & Overlays
        grp_widgets = Adw.PreferencesGroup(
            title="Lock Screen Widgets",
            description="Corner widgets and overlays displayed on the lock surface"
        )
        page.add(grp_widgets)

        # Media Player Overlay
        row_media = Adw.SwitchRow()
        row_media.set_title("Bottom-Left Media Player Overlay")
        row_media.set_subtitle("Minimalist player with album artwork, title, artist, and live progress bar")
        row_media.set_active(self.lockscreen_cfg.get("mediaOverlay", True))
        row_media.add_prefix(Gtk.Image.new_from_icon_name("multimedia-player-symbolic"))

        def on_media_toggled(switch_row, param):
            val = switch_row.get_active()
            self.lockscreen_cfg["mediaOverlay"] = val
            save_lockscreen_config(self.lockscreen_cfg)
            self.show_toast("Media Overlay " + ("Enabled" if val else "Disabled"), f"Bottom-left player card is now {'active' if val else 'hidden'}")

        row_media.connect("notify::active", on_media_toggled)
        grp_widgets.add(row_media)

        # Bottom-Right Clock
        row_clock = Adw.SwitchRow()
        row_clock.set_title("Bottom-Right Clock and Date")
        row_clock.set_subtitle("Crisp time readout with cursive day in Caveat font and formatted date")
        row_clock.set_active(self.lockscreen_cfg.get("clock", True))
        row_clock.add_prefix(Gtk.Image.new_from_icon_name("preferences-system-time-symbolic"))

        def on_clock_toggled(switch_row, param):
            val = switch_row.get_active()
            self.lockscreen_cfg["clock"] = val
            save_lockscreen_config(self.lockscreen_cfg)
            self.show_toast("Lock Clock " + ("Enabled" if val else "Disabled"), f"Bottom-right clock is now {'active' if val else 'hidden'}")

        row_clock.connect("notify::active", on_clock_toggled)
        grp_widgets.add(row_clock)

        # Group 4: Preview & Actions
        grp_actions = Adw.PreferencesGroup(
            title="Preview and Actions",
            description="Immediately preview your lock screen customizations"
        )
        page.add(grp_actions)

        row_test = Adw.ActionRow()
        row_test.set_title("Lock Screen Now")
        row_test.set_subtitle("Test the Carbon Lewis Dot lock screen, visualizer, and widgets immediately")
        row_test.set_activatable(True)
        row_test.add_prefix(Gtk.Image.new_from_icon_name("system-lock-screen-symbolic"))
        row_test.add_suffix(Gtk.Image.new_from_icon_name("media-playback-start-symbolic"))

        def on_test_clicked(row):
            subprocess.Popen(["sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), "lock"])

        row_test.connect("activated", on_test_clicked)
        grp_actions.add(row_test)

        self.view_stack.add_named(page, "lockscreen")

    def navigate_to_page(self, page_name):
        self.ensure_page_built(page_name)
        self.view_stack.set_visible_child_name(page_name)
        for row in self.sidebar_rows:
            if getattr(row, "page_name", None) == page_name:
                self.sidebar_list.select_row(row)
                row.grab_focus()
                break

    def select_bar_mode(self, mode_id):
        self.current_bar_mode = mode_id
        if mode_id in ["pill", "minimal"]:
            if self.bar_pos.get("mainBarEdge") not in ["top", "bottom"]:
                self.bar_pos["mainBarEdge"] = "top"
                self.bar_pos["edge"] = "top"
                self.bar_pos["musicBarEdge"] = "top"
                save_bar_position(self.bar_pos)

        save_bar_mode(mode_id)

        for mid, (row, check_img) in self.bar_mode_rows.items():
            check_img.set_visible(mid == mode_id)

        self.update_mode_sensitivity()
        self.update_pos_buttons_ui()

        active_name = next((m["name"] for m in BAR_MODES if m["id"] == mode_id), mode_id)
        if hasattr(self, "bar_banner") and self.bar_banner:
            self.bar_banner.set_title(f"Active Mode: {active_name}")

        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            "Bar Mode Selected", f"Active mode set to: {active_name}"
        ], check=False)

    # ── Page 2: Window Appearance & Effects ─────────────────────────
    def build_appearance_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Window Appearance")
        page.set_icon_name("preferences-desktop-appearance-symbolic")

        # Group 1: Window Geometry & Opacity
        grp_win = Adw.PreferencesGroup(title="Window Appearance", description="Visual styling of client windows")
        page.add(grp_win)

        # Opacity
        opacity_val = self.var_data.get("windowOpacity", 0.95)
        row_opacity = Adw.SpinRow.new_with_range(0.50, 1.00, 0.05)
        row_opacity.set_title("Window Opacity")
        row_opacity.set_subtitle("Inactive/Active window background opacity")
        row_opacity.set_value(opacity_val)
        grp_win.add(row_opacity)
        self.inputs["windowOpacity"] = row_opacity

        # Rounding
        rounding_val = self.var_data.get("windowRounding", 15)
        row_round = Adw.SpinRow.new_with_range(0, 35, 1)
        row_round.set_title("Window Corner Rounding")
        row_round.set_subtitle("Corner radius in pixels")
        row_round.set_value(rounding_val)
        grp_win.add(row_round)
        self.inputs["windowRounding"] = row_round

        # Border size
        border_val = self.var_data.get("windowBorderSize", 1)
        row_border = Adw.SpinRow.new_with_range(0, 6, 1)
        row_border.set_title("Window Border Size")
        row_border.set_subtitle("Window frame border thickness in pixels")
        row_border.set_value(border_val)
        grp_win.add(row_border)
        self.inputs["windowBorderSize"] = row_border

        # Group 2: Gaps & Spacing
        grp_gaps = Adw.PreferencesGroup(title="Gaps and Spacing", description="Margins between tiled windows and screen edges")
        page.add(grp_gaps)

        # Gaps In
        gaps_in_val = self.var_data.get("windowGapsIn", 5)
        row_gaps_in = Adw.SpinRow.new_with_range(0, 30, 1)
        row_gaps_in.set_title("Inner Gaps (gaps_in)")
        row_gaps_in.set_subtitle("Spacing between adjacent windows")
        row_gaps_in.set_value(gaps_in_val)
        grp_gaps.add(row_gaps_in)
        self.inputs["windowGapsIn"] = row_gaps_in

        # Gaps Out
        gaps_out_val = self.var_data.get("windowGapsOut", 10)
        row_gaps_out = Adw.SpinRow.new_with_range(0, 40, 1)
        row_gaps_out.set_title("Outer Gaps (gaps_out)")
        row_gaps_out.set_subtitle("Spacing between windows and monitor screen edges")
        row_gaps_out.set_value(gaps_out_val)
        grp_gaps.add(row_gaps_out)
        self.inputs["windowGapsOut"] = row_gaps_out

        # Workspace gaps
        ws_gaps_val = self.var_data.get("workspaceGaps", 20)
        row_ws_gaps = Adw.SpinRow.new_with_range(0, 50, 1)
        row_ws_gaps.set_title("Workspace Gaps")
        row_ws_gaps.set_subtitle("Default outer margins for workspace clusters")
        row_ws_gaps.set_value(ws_gaps_val)
        grp_gaps.add(row_ws_gaps)
        self.inputs["workspaceGaps"] = row_ws_gaps

        # Group 3: Blur & Shadow
        grp_effects = Adw.PreferencesGroup(title="Effects", description="Hardware-accelerated blur and drop shadows")
        page.add(grp_effects)

        # Blur
        blur_enabled = self.var_data.get("blurEnabled", True)
        row_blur = Adw.SwitchRow()
        row_blur.set_title("Window Blur")
        row_blur.set_subtitle("Enable background blur behind semi-transparent windows")
        row_blur.set_active(blur_enabled)
        grp_effects.add(row_blur)
        self.inputs["blurEnabled"] = row_blur

        blur_size = self.var_data.get("blurSize", 5)
        row_blur_size = Adw.SpinRow.new_with_range(1, 20, 1)
        row_blur_size.set_title("Blur Radius (blurSize)")
        row_blur_size.set_value(blur_size)
        grp_effects.add(row_blur_size)
        self.inputs["blurSize"] = row_blur_size

        blur_passes = self.var_data.get("blurPasses", 2)
        row_blur_passes = Adw.SpinRow.new_with_range(1, 5, 1)
        row_blur_passes.set_title("Blur Passes")
        row_blur_passes.set_value(blur_passes)
        grp_effects.add(row_blur_passes)
        self.inputs["blurPasses"] = row_blur_passes

        # Shadows
        shadow_enabled = self.var_data.get("shadowEnabled", True)
        row_shadow = Adw.SwitchRow()
        row_shadow.set_title("Window Drop Shadows")
        row_shadow.set_active(shadow_enabled)
        grp_effects.add(row_shadow)
        self.inputs["shadowEnabled"] = row_shadow

        shadow_range = self.var_data.get("shadowRange", 15)
        row_shadow_range = Adw.SpinRow.new_with_range(5, 50, 1)
        row_shadow_range.set_title("Shadow Range")
        row_shadow_range.set_value(shadow_range)
        grp_effects.add(row_shadow_range)
        self.inputs["shadowRange"] = row_shadow_range

        # Group 4: Wallpaper Transitions
        grp_wp = Adw.PreferencesGroup(title="Wallpaper Transition Animations", description="Hardware-accelerated visual animation when switching wallpapers")
        page.add(grp_wp)

        anim_styles = [
            ("cinematic", "Cinematic Zoom (Depth Zoom & Crossfade)"),
            ("crossfade", "Smooth Dissolve (Pure Crossfade)"),
            ("slide-left", "Slide Left (Horizontal Carousel Push)"),
            ("slide-right", "Slide Right (Horizontal Carousel Push)"),
            ("zoom-out", "Expansive Reveal (Zoom Out)"),
        ]
        curr_anim = read_wallpaper_anim()
        curr_idx = 0
        for i, (cid, _) in enumerate(anim_styles):
            if cid == curr_anim:
                curr_idx = i
                break

        str_list = Gtk.StringList.new([s[1] for s in anim_styles])
        row_anim = Adw.ComboRow(title="Transition Style", subtitle="Select the visual animation effect for wallpaper changes")
        row_anim.set_model(str_list)
        row_anim.set_selected(curr_idx)

        def on_anim_changed(widget, _pspec):
            sel = widget.get_selected()
            if 0 <= sel < len(anim_styles):
                save_wallpaper_anim(anim_styles[sel][0])

        row_anim.connect("notify::selected", on_anim_changed)
        grp_wp.add(row_anim)

        # Transition Duration
        curr_dur = read_wallpaper_duration()
        row_dur = Adw.SpinRow.new_with_range(200, 2500, 50)
        row_dur.set_title("Transition Duration")
        row_dur.set_subtitle("Animation duration in milliseconds (default: 800ms)")
        row_dur.set_value(curr_dur)

        def on_dur_changed(widget):
            save_wallpaper_duration(int(widget.get_value()))

        row_dur.connect("changed", on_dur_changed)
        grp_wp.add(row_dur)

        self.view_stack.add_named(page, "appearance")

    # ── Page 3: Default Applications ────────────────────────────────
    def build_apps_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Default Apps")
        page.set_icon_name("applications-system-symbolic")

        grp_apps = Adw.PreferencesGroup(title="Default Applications", description="Primary apps executed by keybindings")
        page.add(grp_apps)

        row_term = Adw.EntryRow()
        row_term.set_title("Terminal (SUPER + Enter)")
        row_term.set_text(str(self.var_data.get("terminal", "foot")))
        grp_apps.add(row_term)
        self.inputs["terminal"] = row_term

        row_browser = Adw.EntryRow()
        row_browser.set_title("Browser (SUPER + B)")
        row_browser.set_text(str(self.var_data.get("browser", "firefox")))
        grp_apps.add(row_browser)
        self.inputs["browser"] = row_browser

        row_files = Adw.EntryRow()
        row_files.set_title("File Manager (SUPER + Shift + E)")
        row_files.set_text(str(self.var_data.get("fileExplorer", "thunar")))
        grp_apps.add(row_files)
        self.inputs["fileExplorer"] = row_files

        self.view_stack.add_named(page, "apps")

    # ── Page: Keybinds ──────────────────────────────────────────────
    def build_keybinds_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Keybinds")
        page.set_icon_name("input-keyboard-symbolic")

        # Top Group with description and search
        top_grp = Adw.PreferencesGroup(
            title="Keyboard Shortcuts",
            description="Click on any keybind to reassign it. Press the shortcut combination you want, and it will be applied automatically."
        )
        page.add(top_grp)

        search_entry = Gtk.SearchEntry()
        search_entry.set_placeholder_text("Search keybindings, actions, or shortcuts...")
        search_entry.set_margin_bottom(4)
        top_grp.add(search_entry)

        bind_items = parse_keybinds_conf()

        categories = [
            ("Applications", "Launch terminal, browser, menu, and utilities", "applications-system-symbolic"),
            ("Window Management", "Close, kill, float, fullscreen, and split windows", "window-close-symbolic"),
            ("Focus and Movement", "Focus, move, and resize tiled windows", "view-grid-symbolic"),
            ("Workspaces", "Switch and send windows across workspaces", "view-paged-symbolic"),
            ("Media and Audio", "Volume, playback, and microphone shortcuts", "audio-volume-high-symbolic"),
            ("System", "Bar toggles, lock screen, and session controls", "system-run-symbolic"),
            ("Mouse Bindings", "Mouse drag actions for moving and resizing", "input-mouse-symbolic"),
            ("Other Keybinds", "Additional custom Hyprland bindings", "input-keyboard-symbolic"),
        ]

        row_widgets = []

        for cat_name, cat_desc, cat_icon in categories:
            items_in_cat = [b for b in bind_items if b["category"] == cat_name]
            if not items_in_cat:
                continue

            grp = Adw.PreferencesGroup(title=cat_name, description=cat_desc)
            page.add(grp)

            for item in items_in_cat:
                row = Adw.ActionRow()
                row.set_title(item["title"])
                row.set_subtitle(item["desc"])
                row.set_title_lines(1)
                row.set_subtitle_lines(1)
                img = Gtk.Image.new_from_icon_name(item["icon"])
                img.set_pixel_size(16)
                row.add_prefix(img)

                btn = Gtk.Button(label=item["display_str"])
                btn.set_valign(Gtk.Align.CENTER)
                btn.set_halign(Gtk.Align.END)
                btn.add_css_class("keybind-pill")
                btn.set_tooltip_text("Click to reassign keybind")
                btn.connect("clicked", self.on_keybind_btn_clicked, item)

                row.add_suffix(btn)
                grp.add(row)
                row_widgets.append((row, grp, item))

        def on_search_changed(entry):
            query = entry.get_text().strip().lower()
            grp_counts = {}
            for row, grp, item in row_widgets:
                if not query:
                    row.set_visible(True)
                    grp_counts[grp] = grp_counts.get(grp, 0) + 1
                else:
                    match = (
                        query in item["title"].lower() or
                        query in item["desc"].lower() or
                        query in item["display_str"].lower() or
                        query in item["category"].lower()
                    )
                    row.set_visible(match)
                    if match:
                        grp_counts[grp] = grp_counts.get(grp, 0) + 1

            for row, grp, item in row_widgets:
                grp.set_visible(grp_counts.get(grp, 0) > 0)

        search_entry.connect("search-changed", on_search_changed)

        self.view_stack.add_named(page, "keybinds")

    # ── Page: Gestures ──────────────────────────────────────────────
    def build_gestures_page(self):
        page = Adw.PreferencesPage()
        page.set_title("Gestures")
        page.set_icon_name("input-touchpad-symbolic")

        g_data = read_gesture_settings()

        # Group 1: Workspace Touchpad Gestures
        grp_ws = Adw.PreferencesGroup(
            title="Workspace Touchpad Gestures",
            description="Configure multi-finger horizontal swipes to switch workspaces smoothly"
        )
        page.add(grp_ws)

        # Finger count
        row_fingers = Adw.SpinRow.new_with_range(3, 4, 1)
        row_fingers.set_title("Workspace Swipe Fingers")
        row_fingers.set_subtitle("Number of fingers required to trigger continuous workspace switching (3 or 4)")
        row_fingers.set_value(float(g_data.get("workspaceSwipeFingers", 4)))
        row_fingers.connect("notify::value", lambda w, p: save_gesture_setting("workspaceSwipeFingers", int(w.get_value())))
        grp_ws.add(row_fingers)

        # Swipe distance
        row_dist = Adw.SpinRow.new_with_range(200, 1200, 50)
        row_dist.set_title("Swipe Distance")
        row_dist.set_subtitle("Touchpad travel distance in pixels required to complete a workspace switch")
        row_dist.set_value(float(g_data.get("workspace_swipe_distance", 700)))
        row_dist.connect("notify::value", lambda w, p: save_gesture_setting("workspace_swipe_distance", int(w.get_value())))
        grp_ws.add(row_dist)

        # Create new
        row_create = Adw.SwitchRow()
        row_create.set_title("Create New Workspace on Swipe")
        row_create.set_subtitle("Swiping past the last active workspace creates a new workspace")
        row_create.set_active(bool(g_data.get("workspace_swipe_create_new", True)))
        row_create.connect("notify::active", lambda w, p: save_gesture_setting("workspace_swipe_create_new", w.get_active()))
        grp_ws.add(row_create)

        # Direction lock
        row_lock = Adw.SwitchRow()
        row_lock.set_title("Swipe Direction Lock")
        row_lock.set_subtitle("Lock horizontal gesture direction once swipe motion begins")
        row_lock.set_active(bool(g_data.get("workspace_swipe_direction_lock", True)))
        row_lock.connect("notify::active", lambda w, p: save_gesture_setting("workspace_swipe_direction_lock", w.get_active()))
        grp_ws.add(row_lock)

        # Group 2: Multi-Finger Touchpad Actions
        grp_actions = Adw.PreferencesGroup(
            title="Configured Gesture Actions",
            description="Active touch gestures handled by Hyprland and Caelestia"
        )
        page.add(grp_actions)

        # 3-finger swipe up (Workspaces & Windows Overview)
        row_up = Adw.ActionRow()
        row_up.set_title("3-Finger Swipe Up")
        row_up.set_subtitle("Workspaces and Windows Overview (animated list of workspaces and open apps)")
        row_up.add_prefix(Gtk.Image.new_from_icon_name("view-grid-symbolic"))

        btn_test_overview = Gtk.Button(label="Open Overview")
        btn_test_overview.set_valign(Gtk.Align.CENTER)
        btn_test_overview.add_css_class("pill")
        btn_test_overview.connect("clicked", lambda b: subprocess.Popen(["sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), "toggle-overview"]))
        row_up.add_suffix(btn_test_overview)
        grp_actions.add(row_up)

        # 3-finger slide down (Screenshot)
        row_down = Adw.ActionRow()
        row_down.set_title("3-Finger Slide Down")
        row_down.set_subtitle("Take Full Screen Screenshot (copies to clipboard and saves to ~/Pictures/Screenshots)")
        row_down.add_prefix(Gtk.Image.new_from_icon_name("camera-photo-symbolic"))

        btn_test_shot = Gtk.Button(label="Test Screenshot")
        btn_test_shot.set_valign(Gtk.Align.CENTER)
        btn_test_shot.add_css_class("pill")
        btn_test_shot.connect("clicked", lambda b: subprocess.Popen(["/home/shogun/.local/bin/carbon-screenshot-full.sh"]))
        row_down.add_suffix(btn_test_shot)
        grp_actions.add(row_down)

        # 4-finger swipe down
        row_sleep = Adw.ActionRow()
        row_sleep.set_title("4-Finger Swipe Down")
        row_sleep.set_subtitle("Suspend and Hibernate system (systemctl suspend-then-hibernate)")
        row_sleep.add_prefix(Gtk.Image.new_from_icon_name("system-shutdown-symbolic"))
        grp_actions.add(row_sleep)

        # 3-finger swipe right (Workspace Forward)
        row_3_right = Adw.ActionRow()
        row_3_right.set_title("3-Finger Swipe Right")
        row_3_right.set_subtitle("Switch to Next Workspace (+1 forward)")
        row_3_right.add_prefix(Gtk.Image.new_from_icon_name("go-next-symbolic"))

        btn_test_ws_fwd = Gtk.Button(label="Next Workspace")
        btn_test_ws_fwd.set_valign(Gtk.Align.CENTER)
        btn_test_ws_fwd.add_css_class("pill")
        btn_test_ws_fwd.connect("clicked", lambda b: subprocess.Popen(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"+1\" })"]))
        row_3_right.add_suffix(btn_test_ws_fwd)
        grp_actions.add(row_3_right)

        # 3-finger swipe left (Workspace Backward)
        row_3_left = Adw.ActionRow()
        row_3_left.set_title("3-Finger Swipe Left")
        row_3_left.set_subtitle("Switch to Previous Workspace (-1 backward)")
        row_3_left.add_prefix(Gtk.Image.new_from_icon_name("go-previous-symbolic"))

        btn_test_ws_back = Gtk.Button(label="Previous Workspace")
        btn_test_ws_back.set_valign(Gtk.Align.CENTER)
        btn_test_ws_back.add_css_class("pill")
        btn_test_ws_back.connect("clicked", lambda b: subprocess.Popen(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"-1\" })"]))
        row_3_left.add_suffix(btn_test_ws_back)
        grp_actions.add(row_3_left)

        # 4-finger swipe horizontal (Continuous Workspace Paging)
        row_4_ws = Adw.ActionRow()
        row_4_ws.set_title("4-Finger Swipe Horizontal")
        row_4_ws.set_subtitle("Continuous smooth workspace desktop sliding and swiping")
        row_4_ws.add_prefix(Gtk.Image.new_from_icon_name("view-grid-symbolic"))
        grp_actions.add(row_4_ws)

        # Group 3: Directional Multi-Finger Custom Gestures (Ready for binding)
        g_custom = read_custom_gestures()
        grp_custom = Adw.PreferencesGroup(
            title="Directional Multi-Finger Gestures",
            description="Custom touchpad gestures ready for bindings"
        )
        page.add(grp_custom)

        custom_defs = [
            ("three_finger_swipe_up", "Three Fingers Swipe Up", "view-grid-symbolic"),
            ("three_finger_swipe_down", "Three Fingers Slide Down", "camera-photo-symbolic"),
            ("three_finger_swipe_left", "Three Fingers Swipe Left", "go-previous-symbolic"),
            ("three_finger_swipe_right", "Three Fingers Swipe Right", "go-next-symbolic"),
            ("four_finger_swipe_horizontal", "Four Fingers Horizontal Swipe", "view-grid-symbolic"),
            ("four_finger_swipe_down", "Four Fingers Swipe Down", "system-shutdown-symbolic"),
        ]

        for g_key, g_title, g_icon in custom_defs:
            row_g = Adw.EntryRow()
            row_g.set_title(g_title)
            row_g.set_text(g_custom.get(g_key, "Unbound (Awaiting binding)"))
            row_g.add_prefix(Gtk.Image.new_from_icon_name(g_icon))
            row_g.connect("notify::text", lambda w, p, k=g_key: save_custom_gesture(k, w.get_text()))
            grp_custom.add(row_g)

        # Group 4: Touchpad Hardware Behavior
        grp_hardware = Adw.PreferencesGroup(
            title="Touchpad Hardware Behavior",
            description="Pointer feel, natural scrolling, and palm rejection"
        )
        page.add(grp_hardware)

        # Natural scroll
        row_natural = Adw.SwitchRow()
        row_natural.set_title("Natural Scrolling")
        row_natural.set_subtitle("Invert vertical scroll direction so content tracks fingers naturally")
        row_natural.set_active(bool(g_data.get("natural_scroll", True)))
        row_natural.connect("notify::active", lambda w, p: save_gesture_setting("natural_scroll", w.get_active()))
        grp_hardware.add(row_natural)

        # Disable typing
        row_typing = Adw.SwitchRow()
        row_typing.set_title("Disable Touchpad While Typing")
        row_typing.set_subtitle("Ignore accidental touchpad taps or gestures while typing on the keyboard")
        row_typing.set_active(bool(g_data.get("touchpadDisableTyping", True)))
        row_typing.connect("notify::active", lambda w, p: save_gesture_setting("touchpadDisableTyping", w.get_active()))
        grp_hardware.add(row_typing)

        # Scroll factor
        row_factor = Adw.SpinRow.new_with_range(0.10, 2.00, 0.05)
        row_factor.set_title("Scroll Sensitivity Factor")
        row_factor.set_subtitle("Multiplier for touchpad two-finger scroll speed (default: 0.30)")
        row_factor.set_value(float(g_data.get("touchpadScrollFactor", 0.30)))
        row_factor.connect("notify::value", lambda w, p: save_gesture_setting("touchpadScrollFactor", round(float(w.get_value()), 2)))
        grp_hardware.add(row_factor)

        self.view_stack.add_named(page, "gestures")

    # ── Page 4: Config Files Direct Editor ──────────────────────────
    def build_files_page(self):
        box_files = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box_files.set_margin_top(12)
        box_files.set_margin_bottom(12)
        box_files.set_margin_start(16)
        box_files.set_margin_end(16)

        toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box_files.append(toolbar)

        lbl_select = Gtk.Label(label="Config File:")
        toolbar.append(lbl_select)

        self.file_keys = list(CONFIG_FILES.keys())
        str_list = Gtk.StringList.new(self.file_keys)
        self.combo_file = Gtk.DropDown.new(str_list, None)
        self.combo_file.set_hexpand(True)
        self.combo_file.connect("notify::selected", self.on_file_selected)
        toolbar.append(self.combo_file)

        btn_save_file = Gtk.Button(label="Save File")
        btn_save_file.add_css_class("suggested-action")
        btn_save_file.connect("clicked", self.on_save_file)
        toolbar.append(btn_save_file)

        btn_reload_hypr = Gtk.Button(label="Reload Hyprland")
        btn_reload_hypr.connect("clicked", lambda b: subprocess.run(["hyprctl", "reload"]))
        toolbar.append(btn_reload_hypr)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        scrolled.add_css_class("card")
        box_files.append(scrolled)

        self.text_view = Gtk.TextView()
        self.text_view.set_monospace(True)
        self.text_view.set_wrap_mode(Gtk.WrapMode.NONE)
        self.text_view.set_left_margin(12)
        self.text_view.set_right_margin(12)
        self.text_view.set_top_margin(12)
        self.text_view.set_bottom_margin(12)
        scrolled.set_child(self.text_view)
        self.text_buffer = self.text_view.get_buffer()

        self.current_loaded_file = None
        self.load_selected_file(0)

        self.view_stack.add_named(box_files, "files")

    def build_about_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        page.set_hexpand(True)
        page.set_vexpand(True)
        page.set_margin_top(20)
        page.set_margin_bottom(12)
        page.set_margin_start(20)
        page.set_margin_end(20)

        # Center content container
        center_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        center_box.set_hexpand(True)
        center_box.set_vexpand(True)
        center_box.set_valign(Gtk.Align.CENTER)
        center_box.set_halign(Gtk.Align.CENTER)

        # Smooth lockscreen Bohr atom logo widget
        logo_widget = CarbonBohrLogoWidget(
            accent_hex=getattr(self, "theme_accent", "#00F0FF"),
            accent_lit_hex=getattr(self, "theme_accent_lit", "#FFFFFF")
        )
        logo_widget.set_halign(Gtk.Align.CENTER)
        center_box.append(logo_widget)

        # Cursive subtitle in Caveat:
        # "Made by Kazu
        # Special thanks to reduct.sh"
        lbl_credits = Gtk.Label()
        lbl_credits.set_use_markup(True)
        lbl_credits.set_markup(
            '<span font_family="Caveat" font_size="22pt" font_weight="bold">Made by Kazu</span>\n'
            '<span font_family="Caveat" font_size="16.5pt" alpha="75%">Special thanks to reduct.sh</span>'
        )
        lbl_credits.set_justify(Gtk.Justification.CENTER)
        lbl_credits.set_halign(Gtk.Align.CENTER)
        lbl_credits.set_margin_top(4)
        center_box.append(lbl_credits)

        page.append(center_box)

        # Bottom-right footer: "all rights reserved ©"
        footer_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        footer_box.set_hexpand(True)
        footer_box.set_valign(Gtk.Align.END)

        lbl_footer = Gtk.Label()
        lbl_footer.set_use_markup(True)
        lbl_footer.set_markup('<span font_size="9pt" alpha="50%">all rights reserved ©</span>')
        lbl_footer.set_hexpand(True)
        lbl_footer.set_halign(Gtk.Align.END)
        lbl_footer.set_margin_end(6)
        lbl_footer.set_margin_bottom(6)
        footer_box.append(lbl_footer)

        page.append(footer_box)

        self.view_stack.add_named(page, "about")

    def select_clock_style(self, style_id):
        self.current_clock_style = style_id
        self.save_clock_style(style_id)
        for cid, (row, check_img) in self.clock_rows.items():
            check_img.set_visible(cid == style_id)

    def save_clock_style(self, chosen):
        try:
            with open(CLOCK_STYLE_PATH, "w", encoding="utf-8") as f:
                json.dump({"style": chosen}, f, indent=2)
            cname = next((cd["name"] for cd in CLOCK_DESIGNS if cd["id"] == chosen), chosen.capitalize())
            subprocess.run([
                "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
                "Clock Design Selected", f"Center island clock set to: {cname}"
            ], check=False)
        except Exception as e:
            print("Failed to save clock style:", e)

    def read_island_style(self):
        if os.path.isfile(BAR_MODE_PATH):
            try:
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    d = json.load(f)
                    return d.get("islandStyle", "pill")
            except Exception:
                pass
        return "pill"

    def set_island_style(self, style):
        try:
            data = {}
            if os.path.isfile(BAR_MODE_PATH):
                with open(BAR_MODE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            data["islandStyle"] = style
            with open(BAR_MODE_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            subprocess.run([
                "sh", os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh"), f"island-style {style}"
            ], check=False)
            if hasattr(self, "island_style_buttons"):
                for sval, btn in self.island_style_buttons.items():
                    if sval == style:
                        btn.add_css_class("suggested-action")
                    else:
                        btn.remove_css_class("suggested-action")
            mode_name = "Pill Mode (Floating)" if style == "pill" else "Notch Mode (Attached Curved)"
            subprocess.run([
                "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
                "Dynamic Island Mode", f"Island mode set to: {mode_name}"
            ], check=False)
        except Exception as e:
            print("Failed to save island style:", e)

    def update_mode_sensitivity(self):
        is_pill = (self.current_bar_mode == "pill")
        is_notch = (self.current_bar_mode == "notch")
        is_minimal = (self.current_bar_mode == "minimal")
        if getattr(self, "grp_pill", None):
            self.grp_pill.set_sensitive(is_pill)
        if getattr(self, "grp_notch", None):
            self.grp_notch.set_sensitive(is_notch)
        if getattr(self, "grp_island_mode", None):
            self.grp_island_mode.set_sensitive(is_minimal)
        if getattr(self, "grp_minimal_settings", None):
            self.grp_minimal_settings.set_sensitive(is_minimal)
        if getattr(self, "minimal_convert_row", None):
            self.minimal_convert_row.set_sensitive(is_minimal)
        if getattr(self, "minimal_persist_row", None):
            self.minimal_persist_row.set_sensitive(is_minimal)
        if getattr(self, "minimal_status_badge", None):
            self.minimal_status_badge.set_visible(is_minimal)
        if getattr(self, "minimal_activate_btn", None):
            self.minimal_activate_btn.set_visible(not is_minimal)
        if getattr(self, "minimal_status_row", None):
            self.minimal_status_row.set_subtitle(
                "Dynamic Island is currently active on screen" if is_minimal else f"Currently inactive ({self.current_bar_mode.capitalize()} Mode active) - click below to activate"
            )

    def update_pos_buttons_ui(self):
        curr_main_edge = self.bar_pos.get("mainBarEdge", self.bar_pos.get("edge", "top"))
        for edge_val, btn in self.pill_edge_buttons.items():
            if edge_val == curr_main_edge:
                btn.add_css_class("suggested-action")
            else:
                btn.remove_css_class("suggested-action")

        if hasattr(self, "minimal_edge_buttons"):
            for edge_val, btn in self.minimal_edge_buttons.items():
                if edge_val == curr_main_edge:
                    btn.add_css_class("suggested-action")
                else:
                    btn.remove_css_class("suggested-action")

        for edge_val, btn in self.notch_edge_buttons.items():
            if edge_val == curr_main_edge:
                btn.add_css_class("suggested-action")
            else:
                btn.remove_css_class("suggested-action")

        curr_music_edge = self.bar_pos.get("musicBarEdge", "top")
        for edge_val, btn in self.notch_music_edge_buttons.items():
            if edge_val == curr_music_edge:
                btn.add_css_class("suggested-action")
            else:
                btn.remove_css_class("suggested-action")

        curr_content = self.bar_pos.get("musicBarContent", "both")
        for content_val, btn in self.pill_content_buttons.items():
            if content_val == curr_content:
                btn.add_css_class("suggested-action")
            else:
                btn.remove_css_class("suggested-action")

        for content_val, btn in self.notch_content_buttons.items():
            if content_val == curr_content:
                btn.add_css_class("suggested-action")
            else:
                btn.remove_css_class("suggested-action")

    def set_pill_bar_edge(self, edge):
        if self.current_bar_mode not in ["pill", "minimal"] or edge not in ["top", "bottom"]:
            return
        self.bar_pos["mainBarEdge"] = edge
        self.bar_pos["musicBarEdge"] = edge
        self.bar_pos["edge"] = edge
        self.bar_pos["leftEdge"] = edge
        self.bar_pos["rightEdge"] = edge
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()
        mode_label = "Dynamic Island" if self.current_bar_mode == "minimal" else "Connected Pill Bar"
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            f"{mode_label} Edge", f"Shifted bar to: {edge.capitalize()} Edge"
        ], check=False)

    def set_notch_bar_edge(self, edge):
        if self.current_bar_mode != "notch":
            return
        self.bar_pos["mainBarEdge"] = edge
        if edge in ["top", "bottom"]:
            self.bar_pos["edge"] = edge
            self.bar_pos["leftEdge"] = edge
            self.bar_pos["rightEdge"] = edge
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            "Notch Bar Edge", f"Placed notch workspaces & controls at: {edge.capitalize()} Edge"
        ], check=False)

    def set_notch_music_edge(self, edge):
        if self.current_bar_mode != "notch":
            return
        self.bar_pos["musicBarEdge"] = edge
        self.bar_pos["centerEdge"] = edge
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            "Notch Music Island", f"Placed center notch island at: {edge.capitalize()} Edge"
        ], check=False)

    def set_main_bar_edge(self, edge):
        self.set_notch_bar_edge(edge)

    def set_music_bar_edge(self, edge):
        self.set_notch_music_edge(edge)

    def set_music_bar_content(self, content):
        self.bar_pos["musicBarContent"] = content
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()
        names = {"both": "Clock & Music (Both)", "clock": "Clock Only", "music": "Music Only"}
        cname = names.get(content, content)
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            "Music Bar Content", f"Center bar display set to: {cname}"
        ], check=False)

    def set_bar_edge(self, edge):
        self.set_main_bar_edge(edge)
        self.set_music_bar_edge(edge)

    def set_bar_align(self, bar_key, align_key, align_val):
        self.bar_pos[align_key] = align_val
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()

    def apply_preset(self, preset):
        if preset == "standard":
            self.bar_pos.update({
                "edge": "top", "mainBarEdge": "top", "musicBarEdge": "top",
                "leftAlign": "left", "centerAlign": "center", "rightAlign": "right"
            })
            desc = "Standard (Top Bar)"
        elif preset == "all_bottom":
            self.bar_pos.update({
                "edge": "bottom", "mainBarEdge": "bottom", "musicBarEdge": "bottom"
            })
            desc = "Shifted all bars to screen Bottom"
        elif preset == "all_top":
            self.bar_pos.update({
                "edge": "top", "mainBarEdge": "top", "musicBarEdge": "top"
            })
            desc = "Shifted all bars to screen Top"
        save_bar_position(self.bar_pos)
        self.update_pos_buttons_ui()
        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "preferences-system",
            "Preset Applied", desc
        ], check=False)

    def on_apply_quick_tweaks(self, btn):
        updates = {}
        for key, widget in self.inputs.items():
            if isinstance(widget, Adw.SpinRow):
                val = widget.get_value()
                if key in FLOAT_KEYS:
                    updates[key] = round(float(val), 2)
                else:
                    updates[key] = int(round(float(val)))
            elif isinstance(widget, Adw.SwitchRow):
                updates[key] = widget.get_active()
            elif isinstance(widget, Adw.EntryRow):
                updates[key] = widget.get_text().strip()

        self.save_clock_style(self.current_clock_style)
        save_variables(updates)

        # If a file in direct editor was edited, save it
        if hasattr(self, "current_loaded_file") and self.current_loaded_file and hasattr(self, "text_buffer"):
            try:
                start_iter = self.text_buffer.get_start_iter()
                end_iter = self.text_buffer.get_end_iter()
                content = self.text_buffer.get_text(start_iter, end_iter, False)
                if content and not content.startswith("-- File does not exist:"):
                    with open(self.current_loaded_file, "w", encoding="utf-8") as f:
                        f.write(content)
            except Exception as e:
                print("Failed to save direct editor buffer:", e)

        # Reload Hyprland
        subprocess.run(["hyprctl", "reload"], check=False)

        # Reload Quickshell via unix socket
        try:
            import socket
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(1.0)
            sock.connect("/tmp/carbon-shell.sock")
            sock.sendall(b"reload\n")
            sock.close()
        except Exception:
            pass

        # Visual feedback: update button label & styling temporarily
        orig_label = btn.get_label()
        btn.set_label("✓ Applied!")
        btn.remove_css_class("suggested-action")
        btn.add_css_class("success")

        def reset_btn():
            btn.set_label(orig_label)
            btn.remove_css_class("success")
            btn.add_css_class("suggested-action")
            return False

        GLib.timeout_add(1500, reset_btn)

        # In-app toast notification
        if hasattr(self, "toast_overlay") and self.toast_overlay:
            toast = Adw.Toast.new("Configuration Applied & Shell Reloaded")
            toast.set_timeout(2)
            self.toast_overlay.add_toast(toast)

        subprocess.run([
            "notify-send", "-a", "Carbon Config", "-i", "emblem-default-symbolic",
            "Configuration Applied", "Hyprland and Carbon Shell reloaded successfully"
        ], check=False)

        # Refresh direct editor if variables.lua is loaded
        if self.current_loaded_file == VARIABLES_PATH:
            self.load_selected_file(self.combo_file.get_selected())

    def on_open_codium(self, btn):
        editor = "code" if shutil.which("code") else ("codium" if shutil.which("codium") else "xdg-open")
        try:
            subprocess.Popen([editor, os.path.expanduser("~/.config/hypr")])
        except Exception as e:
            print("Failed to launch editor:", e)

    def on_file_selected(self, dropdown, param):
        idx = dropdown.get_selected()
        self.load_selected_file(idx)

    def load_selected_file(self, idx):
        if idx < 0 or idx >= len(self.file_keys):
            return
        key = self.file_keys[idx]
        fpath = CONFIG_FILES[key]
        self.current_loaded_file = fpath
        if os.path.isfile(fpath):
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
            self.text_buffer.set_text(content)
        else:
            self.text_buffer.set_text(f"-- File does not exist: {fpath}")

    def on_save_file(self, btn):
        if not self.current_loaded_file:
            return
        start_iter = self.text_buffer.get_start_iter()
        end_iter = self.text_buffer.get_end_iter()
        content = self.text_buffer.get_text(start_iter, end_iter, False)

        try:
            with open(self.current_loaded_file, "w", encoding="utf-8") as f:
                f.write(content)
            if self.current_loaded_file.endswith(".lua") or self.current_loaded_file.endswith(".conf"):
                subprocess.run(["hyprctl", "reload"], check=False)
            subprocess.run([
                "notify-send", "-a", "Carbon Config", "-i", "document-save",
                "Saved", f"File saved: {os.path.basename(self.current_loaded_file)}"
            ], check=False)
        except Exception as e:
            subprocess.run([
                "notify-send", "-u", "critical", "-a", "Carbon Config",
                "Save Failed", str(e)
            ], check=False)


class CarbonConfigApp(Adw.Application):
    def __init__(self, initial_page=None):
        super().__init__(
            application_id="org.carbon.configeditor",
            flags=Gio.ApplicationFlags.NON_UNIQUE
        )
        self.initial_page = initial_page
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        win = app.props.active_window
        if not win:
            self.win = ConfigEditorWindow(app, initial_page=self.initial_page)
            win = self.win
        win.present()


def main():
    initial_page = None
    if len(sys.argv) > 1:
        if sys.argv[1].startswith("--page="):
            initial_page = sys.argv[1].split("=")[1]
        elif sys.argv[1] == "--page" and len(sys.argv) > 2:
            initial_page = sys.argv[2]
        elif not sys.argv[1].startswith("-"):
            initial_page = sys.argv[1]
    app = CarbonConfigApp(initial_page=initial_page)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
