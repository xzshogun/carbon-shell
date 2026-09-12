# Carbon Shell ⚛️

> **A cutting-edge, ultra-fluid, and responsive desktop shell for Hyprland built on Quickshell and GTK4/Libadwaita.**
> *Created by Kazu — Special thanks to reduct.sh*

---

## ✨ Features

- ⚛️ **Static & Animated Bohr Atomic Model**: Central "C" nucleus with dual concentric electron orbits (K-shell & L-shell) featured across the bar launcher, lock screen, config app, and Fastfetch.
- 🏝️ **3 Flexible Desktop Bar Layouts**:
  - **Notch Mode**: Elegant screen-attached curved notch bars with integrated workspaces, clock, vinyl music, and status indicators.
  - **Pill Mode**: Floating continuous capsule bar spanning the display edge.
  - **Minimal Mode (Dynamic Island)**: Compact, ultra-lightweight dynamic island capsule with lyrics-on-hover and audio waveform.
- 🪟 **macOS Mission Control / Windows Task View Overview (`Super + Tab` / 3-finger swipe)**:
  - Horizontal workspace carousel with interactive application cards.
  - Drag-and-drop windows between workspaces.
  - **Dynamic Frosted-Glass Blur**: Automatically engages 2-pass 5-strength hardware blur while open, and disables blur when dismissed for near-zero GPU overhead.
- 🎨 **Dynamic Material You Theming**:
  - Powered by Matugen & PIL color extraction from any wallpaper.
  - Instant live palette synchronization across Hyprland active borders, Quickshell, GTK4 apps, and Fastfetch terminal logo.
- 🎵 **Interactive Media Player & Draggable Waveform**:
  - Interactive seeking progress bar in the quick-settings panel.
  - Real-time synchronized lyrics support.
  - Smooth audio visualizer with Cava integration.
- ⚙️ **Native GTK4/Libadwaita Settings App (`Super + C`)**:
  - Instant layout switcher (Pill / Notch / Minimal).
  - Live Wi-Fi scanning & secure network connection dialog.
  - Live Bluetooth device scanning & pairing.
  - Clock style switcher, gestures configuration, keybinds listener, and lockscreen customizer.
  - Opens instantly in its true floating dimensions with zero resize flash.

---

## 🚀 One-Line Installation

```bash
git clone https://github.com/<YOUR_USERNAME>/carbon-shell.git
cd carbon-shell
chmod +x install.sh
./install.sh
```

---

## 📦 Dependencies

The installer will automatically prompt and install all required packages:

| Component | Packages |
|---|---|
| **Compositor & Shell** | `hyprland`, `quickshell` |
| **Theme & Color Engine** | `matugen`, `python-pillow` |
| **Config & UI** | `python-gobject`, `gtk4`, `libadwaita` |
| **Audio & Media** | `playerctl`, `pipewire`, `wireplumber`, `cava` |
| **Tools & Utilities** | `fastfetch`, `grim`, `slurp`, `socat`, `networkmanager`, `bluez` |
| **Fonts** | `Valley Sans`, `Caveat`, `JetBrainsMono Nerd Font` |

---

## ⌨️ Default Keybindings

- <kbd>Super</kbd> + <kbd>Tab</kbd> — Open Workspaces & Windows Overview
- <kbd>Super</kbd> + <kbd>C</kbd> — Open Carbon Settings
- <kbd>Super</kbd> + <kbd>Space</kbd> — App Launcher
- <kbd>Super</kbd> + <kbd>Return</kbd> — Terminal
- <kbd>Super</kbd> + <kbd>L</kbd> — Lock Screen

---

## 📜 Credits

- **Made by Kazu**
- **Special thanks to reduct.sh**
- *All rights reserved ©*
