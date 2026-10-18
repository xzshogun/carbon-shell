pragma Singleton

import QtQuick
import "."

QtObject {
    id: root

    property int batteryCapacity: 100
    property string batteryStatus: "Full"

    readonly property string lyricsCurrentLyric: LyricsService ? (LyricsService.currentLine || "") : ""
    readonly property bool lyricsIsSynced: LyricsService ? LyricsService.hasLyrics : false
    readonly property string lyricsBackendStatus: (LyricsService && LyricsService.hasLyrics) ? "synced" : "idle"

    signal volumeChanged(real volPercentage, bool isMuted)
    signal batteryChanged(int capacity, string status)
    signal brightnessChanged(real brightnessPercentage)
    signal bluetoothChanged(bool connected, string deviceName)

    function setLyricsClientActive(active) {
        // Handled via LyricsService
    }
}
