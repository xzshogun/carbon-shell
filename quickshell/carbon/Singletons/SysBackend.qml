pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "."

Item {
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

    /* ── PipeWire Audio Volume Monitoring ── */
    readonly property var sink: Pipewire.defaultAudioSink
    property real lastVolume: -1
    property bool lastMuted: false

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            if (!root.sink || !root.sink.audio) return
            const vol = root.sink.audio.volume
            const isMuted = root.sink.audio.muted
            const pct = Math.round(vol * 100)
            if (root.lastVolume >= 0 && (Math.abs(vol - root.lastVolume) >= 0.005 || isMuted !== root.lastMuted)) {
                root.volumeChanged(pct, isMuted)
            }
            root.lastVolume = vol
            root.lastMuted = isMuted
        }
        function onMutedChanged() {
            if (!root.sink || !root.sink.audio) return
            const vol = root.sink.audio.volume
            const isMuted = root.sink.audio.muted
            const pct = Math.round(vol * 100)
            root.volumeChanged(pct, isMuted)
            root.lastMuted = isMuted
        }
    }

    /* ── Backlight Hardware Poller ── */
    property int lastBrightnessPct: -1

    Process {
        id: brightPoller
        command: [
            "sh", "-c",
            "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'; " +
            "exec udevadm monitor --subsystem-match=backlight --udev 2>/dev/null | while read -r line; do " +
            "  case \"$line\" in *change*) brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%';; esac; " +
            "done"
        ]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const pct = parseInt(line.trim(), 10)
                if (isNaN(pct)) return
                if (root.lastBrightnessPct >= 0 && Math.abs(pct - root.lastBrightnessPct) >= 1) {
                    root.brightnessChanged(pct / 100.0)
                }
                root.lastBrightnessPct = pct
            }
        }
    }
}
