pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Carbon palette — loaded dynamically from ~/.config/hypr/theme.json
 * regenerated from the current wallpaper by theme-mk.py (wp-apply.sh).
 * Automatically updates live across all components without restarting Quickshell.
 */
Singleton {
    id: root

    readonly property string themeJsonPath: "/home/shogun/.config/hypr/theme.json"

    FileView {
        id: themeFile
        path: root.themeJsonPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            themeFile.reload()
            root.reload()
        }
        onLoaded: root.reload()
    }

    property var palette: ({})

    function reload() {
        try {
            themeFile.reload()
            const txt = themeFile.text().trim()
            if (txt.length > 0) {
                const p = JSON.parse(txt)
                root.palette = p
                if (p.bg) root.bg = p.bg
                if (p.bgAlt) root.bgAlt = p.bgAlt
                if (p.bgHover) root.bgHover = p.bgHover
                if (p.bgActive) root.bgActive = p.bgActive
                if (p.fg) root.fg = p.fg
                if (p.fgDim) root.fgDim = p.fgDim
                if (p.fgFaint) root.fgFaint = p.fgFaint
                if (p.accent) root.accent = p.accent
                if (p.accentLit) root.accentLit = p.accentLit
                if (p.outline) root.outline = p.outline
                if (p.ok) root.ok = p.ok
                if (p.warn) root.warn = p.warn
                if (p.err) root.err = p.err
                if (p.isDark !== undefined) root.isDark = p.isDark
                console.log("[Theme] Dynamic theme reloaded! Accent:", root.accent, "Fg:", root.fg)
            }
        } catch (e) {
            console.log("Theme reload error: " + e)
        }
    }

    Component.onCompleted: reload()

    property color bg:        "#E6121214"
    property color bgAlt:     "#331E1E22"
    property color bgHover:   "#29E2E8F0"
    property color bgActive:  "#4CE2E8F0"
    property color fg:        "#F4F4F6"
    property color fgDim:     "#B0F4F4F6"
    property color fgFaint:   "#66F4F4F6"
    property color accent:    "#E2E8F0"
    property color accentLit: "#FFFFFF"
    property color outline:   "#594A4A52"
    property color ok:        "#a6e3a1"
    property color warn:      "#f9e2af"
    property color err:       "#f38ba8"
    property bool isDark:     true

    /* Bar geometry */
    readonly property real barWidth: 56
    readonly property real radius: 18
    readonly property real iconSize: 22
    readonly property real moduleMargin: 5

    /* Fonts */
    readonly property string font: "JetBrains Mono Nerd Font"
}
