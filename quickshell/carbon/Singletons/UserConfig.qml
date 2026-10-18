pragma Singleton

import QtQuick
import Quickshell
import "."

QtObject {
    id: root

    readonly property real islandHeight: 28
    readonly property real islandWidth: 120
    readonly property real islandTopMargin: 8
    readonly property real islandPositionX: 0
    readonly property real islandBackgroundOpacity: 96
    readonly property string userConfigPath: (Quickshell.env("HOME") || "") + "/.config/tide-island/userconfig.json"
    readonly property string dynamicIslandPrimaryButton: "none"
    readonly property string dynamicIslandSecondaryButton: "none"
    readonly property string hoverExpandAction: "expand"
    readonly property bool islandAutoHideEnabled: false
    readonly property int islandAutoHideDelayMs: 2000
    readonly property string clockFormat: "24h"
    readonly property string timeFontFamily: (Theme && Theme.fontFamily) ? Theme.fontFamily : "JetBrainsMono Nerd Font"
    readonly property int bodyFontSize: 13
    readonly property int titleFontSize: 14
    readonly property int iconFontSize: 16
    readonly property string heroFontFamily: (Theme && Theme.fontFamily) ? Theme.fontFamily : "JetBrainsMono Nerd Font"
    readonly property string textFontFamily: (Theme && Theme.fontFamily) ? Theme.fontFamily : "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: (Theme && Theme.fontFamily) ? Theme.fontFamily : "JetBrainsMono Nerd Font"
    readonly property bool disableAutoExpandOnTrackChange: false
    readonly property bool wallpaperCustomCommandEnabled: false
    readonly property real islandExclusiveZone: 0
    readonly property var dynamicIslandLeftSwipeItems: ["clock", "lyrics", "custom"]
    readonly property string wallpaperPath: ""

    function mouseButtonsMask(buttons) {
        var mask = 0;
        if (!buttons || !Array.isArray(buttons)) return Qt.LeftButton;
        for (var i = 0; i < buttons.length; i++) {
            var b = buttons[i];
            if (b === 1 || b === "left") mask |= Qt.LeftButton;
            else if (b === 2 || b === "right") mask |= Qt.RightButton;
            else if (b === 4 || b === "middle") mask |= Qt.MiddleButton;
        }
        return mask > 0 ? mask : Qt.LeftButton;
    }
}
