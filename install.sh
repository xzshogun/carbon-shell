#!/usr/bin/env bash
# ==============================================================================
#  Carbon Shell Installer
#  Created by Kazu — Special thanks to reduct.sh
# ==============================================================================

set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.config/carbon_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${CYAN}"
cat << "BANNER"
   ______           __                   _____ __          ____
  / ____/___ ______/ /_  ____  ____     / ___// /_  ___   / / /
 / /   / __ `/ ___/ __ \/ __ \/ __ \    \__ \/ __ \/ _ \ / / / 
/ /___/ /_/ / /  / /_/ / /_/ / / / /   ___/ / / / /  __// / /  
\____/\__,_/_/  /_.___/\____/_/ /_/   /____/_/ /_/\___//_/_/   
                                                               
      Atom-Fluid Hyprland Desktop Environment & Config
BANNER
echo -e "${RESET}"
echo -e "${WHITE}Created by ${CYAN}Kazu${WHITE} — Special thanks to ${MAGENTA}reduct.sh${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Distro Detection
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/5]${RESET} Checking system environment..."
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi
echo -e "      Detected distribution: ${GREEN}${DISTRO}${RESET}"

# ------------------------------------------------------------------------------
# 2. Dependency Checking
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[2/5]${RESET} Checking dependencies..."

DEPENDENCIES=(
    "hyprland"
    "quickshell"
    "matugen"
    "python3"
    "playerctl"
    "fastfetch"
    "grim"
    "slurp"
    "socat"
    "jq"
    "brightnessctl"
    "pipewire"
    "wireplumber"
    "wpctl"
)

MISSING_DEPS=()
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "      ${YELLOW}Notice: The following optional/required utilities are missing:${RESET}"
    for m in "${MISSING_DEPS[@]}"; do
        echo -e "        - ${RED}${m}${RESET}"
    done
    
    if [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "cachyos" ] || [ "$DISTRO" = "endeavouros" ] || [ "$DISTRO" = "manjaro" ]; then
        echo -e "\n      ${CYAN}Would you like to attempt installing missing dependencies now? [y/N]${RESET} "
        read -r -p "      > " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            AUR_HELPER=""
            if command -v yay >/dev/null 2>&1; then
                AUR_HELPER="yay"
            elif command -v paru >/dev/null 2>&1; then
                AUR_HELPER="paru"
            fi
            
            if [ -n "$AUR_HELPER" ]; then
                echo -e "      Installing via ${AUR_HELPER}..."
                $AUR_HELPER -S --needed --noconfirm "${MISSING_DEPS[@]}" python-pillow python-gobject gtk4 libadwaita cava ttf-jetbrains-mono-nerd ttf-material-symbols-variable alsa-utils brightnessctl || true
            else
                echo -e "      Installing official packages via sudo pacman..."
                sudo pacman -S --needed --noconfirm "${MISSING_DEPS[@]}" python-pillow python-gobject gtk4 libadwaita alsa-utils brightnessctl || true
            fi
        fi
    else
        echo -e "      ${YELLOW}Please ensure missing dependencies are installed via your package manager.${RESET}"
    fi
else
    echo -e "      ${GREEN}All primary dependencies are present!${RESET}"
fi

# ------------------------------------------------------------------------------
# 2.1 Hardware, Permissions & Security Diagnostics
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[2.1]${RESET} Running pre-flight system & hardware diagnostics..."
DIAG_ERRORS=()
DIAG_WARNINGS=()

# Audio & PipeWire Service Check
if systemctl --user is-active pipewire >/dev/null 2>&1 && systemctl --user is-active wireplumber >/dev/null 2>&1; then
    echo -e "      ${GREEN}✓${RESET} Audio Engine: PipeWire and WirePlumber active"
else
    DIAG_WARNINGS+=("PipeWire / WirePlumber user services are not currently active. Audio slider / mute toggles may be non-responsive.")
    echo -e "      ${YELLOW}⚠${RESET} Audio Engine: PipeWire or WirePlumber service is inactive"
fi

# Audio Hardware Controls (amixer / wpctl)
if command -v amixer >/dev/null 2>&1 || command -v wpctl >/dev/null 2>&1; then
    echo -e "      ${GREEN}✓${RESET} Audio Hardware Link: ALSA / WirePlumber controller found"
else
    DIAG_WARNINGS+=("Neither amixer (alsa-utils) nor wpctl (wireplumber) was found. Install alsa-utils or wireplumber.")
    echo -e "      ${YELLOW}⚠${RESET} Audio Hardware Link: Missing mixer controller"
fi

# Display Backlight & brightnessctl Permissions
BACKLIGHT_FOUND=false
if [ -d "/sys/class/backlight" ] && [ "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
    BACKLIGHT_FOUND=true
    if command -v brightnessctl >/dev/null 2>&1; then
        if brightnessctl g >/dev/null 2>&1; then
            echo -e "      ${GREEN}✓${RESET} Brightness Control: Hardware backlight detected and accessible"
        else
            DIAG_WARNINGS+=("Backlight detected but non-root write access denied. Add user to video group: sudo usermod -aG video \$USER")
            echo -e "      ${YELLOW}⚠${RESET} Brightness Control: Permission denied for backlight write"
        fi
    fi
else
    echo -e "      ${BLUE}ℹ${RESET} Brightness Control: Desktop / external monitor detected (no internal laptop backlight)"
fi

# Font Verification (Material Symbols Rounded & JetBrainsMono Nerd Font)
if fc-list : family 2>/dev/null | grep -iq "Material Symbols Rounded"; then
    echo -e "      ${GREEN}✓${RESET} Fonts: Material Symbols Rounded available"
elif fc-list : family 2>/dev/null | grep -iq "Material Symbols"; then
    echo -e "      ${GREEN}✓${RESET} Fonts: Material Symbols (generic) available"
else
    DIAG_WARNINGS+=("Material Symbols Rounded font is missing. Shell icons may render as raw text. Install ttf-material-symbols-variable or similar.")
    echo -e "      ${YELLOW}⚠${RESET} Fonts: Material Symbols Rounded NOT detected"
fi

if fc-list : family 2>/dev/null | grep -iq "JetBrainsMono Nerd Font"; then
    echo -e "      ${GREEN}✓${RESET} Fonts: JetBrainsMono Nerd Font available"
else
    DIAG_WARNINGS+=("JetBrainsMono Nerd Font is missing. Install ttf-jetbrains-mono-nerd for terminal & widget glyphs.")
    echo -e "      ${YELLOW}⚠${RESET} Fonts: JetBrainsMono Nerd Font NOT detected"
fi

# PAM Authentication Check for hyprlock / lock screen
if command -v hyprlock >/dev/null 2>&1; then
    if [ -f "/etc/pam.d/hyprlock" ]; then
        echo -e "      ${GREEN}✓${RESET} PAM Authentication: /etc/pam.d/hyprlock is configured"
    elif [ -f "/etc/pam.d/system-auth" ] || [ -f "/etc/pam.d/login" ]; then
        echo -e "      ${YELLOW}⚠${RESET} PAM Authentication: /etc/pam.d/hyprlock missing (fallback to system-auth/login)"
        DIAG_WARNINGS+=("/etc/pam.d/hyprlock missing. Recommended fix: sudo cp /etc/pam.d/system-auth /etc/pam.d/hyprlock")
    else
        DIAG_ERRORS+=("No valid PAM configuration found for screen locker! Locking screen could result in lockout.")
        echo -e "      ${RED}✗${RESET} PAM Authentication: Critical PAM configuration missing!"
    fi
fi

# Summary Diagnostic Alert
if [ ${#DIAG_ERRORS[@]} -gt 0 ] || [ ${#DIAG_WARNINGS[@]} -gt 0 ]; then
    echo -e "\n  ${YELLOW}┌────────────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "  ${YELLOW}│${RESET}  ${YELLOW}PRE-FLIGHT DIAGNOSTIC NOTICES${RESET}                                         ${YELLOW}│${RESET}"
    echo -e "  ${YELLOW}├────────────────────────────────────────────────────────────────────────┤${RESET}"
    for w in "${DIAG_WARNINGS[@]}"; do
        echo -e "  ${YELLOW}│${RESET}  ${YELLOW}[WARN]${RESET} $w"
    done
    for e in "${DIAG_ERRORS[@]}"; do
        echo -e "  ${YELLOW}│${RESET}  ${RED}[FAIL]${RESET} $e"
    done
    echo -e "  ${YELLOW}└────────────────────────────────────────────────────────────────────────┘${RESET}\n"
    if [ ${#DIAG_ERRORS[@]} -gt 0 ]; then
        echo -e "      ${RED}Critical pre-flight checks failed. Do you still wish to proceed? [y/N]${RESET} "
        read -r -p "      > " proceed_choice
        if [[ ! "$proceed_choice" =~ ^[Yy]$ ]]; then
            echo -e "      ${RED}Installation aborted by user.${RESET}"
            exit 1
        fi
    fi
else
    echo -e "      ${GREEN}Pre-flight diagnostics passed with zero warnings!${RESET}"
fi

# ------------------------------------------------------------------------------
# 3. Safe Backups
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[3/5]${RESET} Creating safety backup of existing configurations..."
mkdir -p "$BACKUP_DIR"

if [ -d "${HOME}/.local/share/quickshell/carbon" ]; then
    cp -r "${HOME}/.local/share/quickshell/carbon" "${BACKUP_DIR}/quickshell_carbon"
    echo -e "      Backed up Quickshell carbon to: ${CYAN}${BACKUP_DIR}/quickshell_carbon${RESET}"
fi

if [ -d "${HOME}/.config/hypr" ]; then
    cp -r "${HOME}/.config/hypr" "${BACKUP_DIR}/hypr"
    echo -e "      Backed up Hyprland configs to: ${CYAN}${BACKUP_DIR}/hypr${RESET}"
fi

if [ -d "${HOME}/.config/fastfetch" ]; then
    cp -r "${HOME}/.config/fastfetch" "${BACKUP_DIR}/fastfetch"
    echo -e "      Backed up Fastfetch configs to: ${CYAN}${BACKUP_DIR}/fastfetch${RESET}"
fi

# ------------------------------------------------------------------------------
# 4. Installing Fonts & Assets
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[4/5]${RESET} Installing custom fonts & assets..."
FONT_DIR="${HOME}/.local/share/fonts"
mkdir -p "$FONT_DIR"
if [ -d "${REPO_DIR}/fonts" ]; then
    cp -r "${REPO_DIR}/fonts/"*.ttf "$FONT_DIR/" 2>/dev/null || true
    echo -e "      Updating font cache..."
    fc-cache -f >/dev/null 2>&1 || true
    echo -e "      ${GREEN}Fonts (Valley Sans & Caveat) installed successfully.${RESET}"
fi

# Wallpapers
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [ -f "${REPO_DIR}/assets/wallpapers/default.png" ]; then
    if [ ! -f "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" ]; then
        cp "${REPO_DIR}/assets/wallpapers/default.png" "${WALLPAPER_DIR}/wallhaven-6ly7yw.png"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Installing Shell Configurations
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[5/5]${RESET} Deploying Carbon Shell, Hyprland configs, and Fastfetch..."

# Deploy Quickshell Carbon
mkdir -p "${HOME}/.local/share/quickshell"
rm -rf "${HOME}/.local/share/quickshell/carbon"
cp -r "${REPO_DIR}/quickshell/carbon" "${HOME}/.local/share/quickshell/carbon"

# Deploy Hyprland configs & scripts
mkdir -p "${HOME}/.config/hypr"
cp -r "${REPO_DIR}/hypr/"* "${HOME}/.config/hypr/"
chmod +x "${HOME}/.config/hypr/scripts/"*.sh 2>/dev/null || true
chmod +x "${HOME}/.config/hypr/scripts/"*.py 2>/dev/null || true
chmod +x "${HOME}/.config/hypr/scripts/carbon-config-editor" 2>/dev/null || true
chmod +x "${HOME}/.config/hypr/scripts/carbon-pomodoro" 2>/dev/null || true

# Deploy user binaries (~/.local/bin)
mkdir -p "${HOME}/.local/bin"
cp "${HOME}/.config/hypr/scripts/carbon-screenshot-"*.sh "${HOME}/.local/bin/" 2>/dev/null || true
chmod +x "${HOME}/.local/bin/carbon-screenshot-"*.sh 2>/dev/null || true

# Restore default wallpaper symlink
if [ -f "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" ]; then
    ln -sf "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" "${HOME}/.config/hypr/current_wallpaper"
    echo "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" > "${HOME}/.config/hypr/current_wallpaper_path"
fi

# Deploy Fastfetch
mkdir -p "${HOME}/.config/fastfetch"
cp -r "${REPO_DIR}/fastfetch/"* "${HOME}/.config/fastfetch/"

# Deploy xdg-desktop-portal configs for Wayland Screen Casting
mkdir -p "${HOME}/.config/xdg-desktop-portal"
cp -r "${REPO_DIR}/xdg-desktop-portal/"* "${HOME}/.config/xdg-desktop-portal/"

# Generate initial theme with theme-mk.py
echo -e "      Initializing color scheme via Matugen & theme-mk..."
if [ -f "${HOME}/.config/hypr/scripts/theme-mk.py" ]; then
    python3 "${HOME}/.config/hypr/scripts/theme-mk.py" >/dev/null 2>&1 || true
fi

# Configure & unmute ALSA / Realtek ALC audio hardware
echo -e "      Configuring ALSA / Realtek ALC audio hardware..."
if [ -f "${HOME}/.config/hypr/scripts/carbon-audio-init.sh" ]; then
    bash "${HOME}/.config/hypr/scripts/carbon-audio-init.sh" >/dev/null 2>&1 || true
fi

# Clean up any deprecated config keys (e.g. dwindle.pseudotile, misc.vfr)
sed -i '/dwindle\.pseudotile/d; /misc\.vfr/d' "${HOME}/.config/hypr/"*.lua "${HOME}/.config/hypr/hyprland/"*.lua 2>/dev/null || true

# Dynamic portability sanitization: ensure any residual developer paths are mapped to current user
echo -e "      Ensuring 100% path portability for user: ${USER} (${HOME})..."
find "${HOME}/.local/share/quickshell/carbon" "${HOME}/.config/hypr" "${HOME}/.config/fastfetch" "${HOME}/.config/systemd/user" -type f \( -name "*.qml" -o -name "*.conf" -o -name "*.lua" -o -name "*.json" -o -name "*.jsonc" -o -name "*.sh" -o -name "*.py" -o -name "*.service" \) -exec sed -i "s|/home/shogun|${HOME}|g" {} + 2>/dev/null || true

# Install & enable carbon-quickshell systemd user service
mkdir -p "${HOME}/.config/systemd/user"
if [ -f "${REPO_DIR}/systemd/carbon-quickshell.service" ]; then
    cp "${REPO_DIR}/systemd/carbon-quickshell.service" "${HOME}/.config/systemd/user/"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable carbon-quickshell.service >/dev/null 2>&1 || true
fi

echo -e "\n${GREEN}==============================================================================${RESET}"
echo -e "${GREEN}  ✓ Carbon Shell installation completed successfully!${RESET}"
echo -e "${GREEN}==============================================================================${RESET}\n"

echo -e "Useful Shortcuts:"
echo -e "  - ${CYAN}Super + Tab${RESET}    : Workspaces & Windows Overview (Task View)"
echo -e "  - ${CYAN}Super + C${RESET}      : Open Carbon Settings Editor"
echo -e "  - ${CYAN}Super + Space${RESET}  : Open Application Launcher"
echo -e "  - ${CYAN}Super + L${RESET}      : Lock Screen (Bohr Atomic Model)\n"

echo -e "${YELLOW}Would you like to restart Quickshell and reload Hyprland now? [Y/n]${RESET} "
read -r -p "> " reload_choice
if [[ -z "$reload_choice" || "$reload_choice" =~ ^[Yy]$ ]]; then
    echo -e "Reloading Hyprland..."
    hyprctl reload >/dev/null 2>&1 || true
    echo -e "Restarting Quickshell service..."
    systemctl --user restart carbon-quickshell.service >/dev/null 2>&1 || (killall quickshell 2>/dev/null; nohup quickshell --config "${HOME}/.local/share/quickshell/carbon" >/dev/null 2>&1 &)
    echo -e "${GREEN}Carbon Shell is live! Enjoy your desktop!${RESET}"
fi
