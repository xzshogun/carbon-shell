pragma Singleton

import QtQuick
import "."

QtObject {
    id: root

    readonly property color transparent: "transparent"
    readonly property color white: "#ffffff"
    readonly property color error: "#f87171"
    readonly property color success: "#4ade80"
    readonly property color clearBlack: Qt.rgba(0, 0, 0, 0.4)

    readonly property color accent: Theme.accent
    readonly property color accentSoft: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)

    readonly property color textPrimary: Theme.fg
    readonly property color textMuted: Theme.outline
    readonly property color textTertiary: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.6)
    readonly property color textSoft: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.8)

    readonly property color module: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.9)
    readonly property color moduleHover: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
    readonly property color secondaryButton: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    readonly property color prompt: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
    readonly property color input: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.8)
    readonly property color inputBorder: Theme.outline

    readonly property int durationFast: 180
    readonly property int durationNormal: 300
    readonly property int durationSlow: 500

    readonly property color workspaceActiveBorder: Theme.accent
    readonly property color workspaceCellBorder: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
    readonly property color workspaceOverlay: Qt.rgba(0, 0, 0, 0.5)
    readonly property color workspaceCell: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.6)
    readonly property color overviewCard: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.8)
    readonly property color overviewBorder: Theme.outline
    readonly property color overviewInnerBorder: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
}
