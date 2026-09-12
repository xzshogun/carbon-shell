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
                $AUR_HELPER -S --needed --noconfirm "${MISSING_DEPS[@]}" python-pillow python-gobject gtk4 libadwaita cava ttf-jetbrains-mono-nerd || true
            else
                echo -e "      Installing official packages via sudo pacman..."
                sudo pacman -S --needed --noconfirm "${MISSING_DEPS[@]}" python-pillow python-gobject gtk4 libadwaita || true
            fi
        fi
    else
        echo -e "      ${YELLOW}Please ensure missing dependencies are installed via your package manager.${RESET}"
    fi
else
    echo -e "      ${GREEN}All primary dependencies are present!${RESET}"
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

# Restore default wallpaper symlink
if [ -f "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" ]; then
    ln -sf "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" "${HOME}/.config/hypr/current_wallpaper"
    echo "${WALLPAPER_DIR}/wallhaven-6ly7yw.png" > "${HOME}/.config/hypr/current_wallpaper_path"
fi

# Deploy Fastfetch
mkdir -p "${HOME}/.config/fastfetch"
cp -r "${REPO_DIR}/fastfetch/"* "${HOME}/.config/fastfetch/"

# Generate initial theme with theme-mk.py
echo -e "      Initializing color scheme via Matugen & theme-mk..."
if [ -f "${HOME}/.config/hypr/scripts/theme-mk.py" ]; then
    python3 "${HOME}/.config/hypr/scripts/theme-mk.py" >/dev/null 2>&1 || true
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
    echo -e "Restarting Quickshell..."
    killall quickshell 2>/dev/null || true
    sleep 0.5
    nohup quickshell --config "${HOME}/.local/share/quickshell/carbon" >/dev/null 2>&1 &
    echo -e "${GREEN}Carbon Shell is live! Enjoy your desktop!${RESET}"
fi
