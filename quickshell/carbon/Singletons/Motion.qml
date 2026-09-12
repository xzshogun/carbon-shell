pragma Singleton

import QtQuick
import Quickshell

/**
 * Carbon motion tokens: durations and easing curves shared by the bar modules.
 */
Singleton {
    readonly property int fast: 120
    readonly property int normal: 200
    readonly property int slow: 320

    readonly property var easeStandard: Easing.OutCubic
    readonly property var easeOut: Easing.OutQuart
}