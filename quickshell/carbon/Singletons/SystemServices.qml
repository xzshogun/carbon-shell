pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]

    signal brightnessSnapshotReady(real value, string errorString)
    signal volumeSnapshotReady(real value, bool muted, string errorString)
    signal systemStatsReady(real cpuUsage, real ramUsage, string errorString)
    signal hyprlandSnapshotReady(string requestId, string subject, string payloadJson, string errorString)
    signal wallpaperThumbnailFinished(string sourcePath, string finishedCachePath, bool cacheAvailable, bool updated, string errorString)

    function setCavaClientActive(active) {
        // Cava activity handled globally
    }

    function requestBrightness() {
        brightnessProc.running = false;
        brightnessProc.running = true;
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | head -n1 | cut -d',' -f4 | tr -d '%' || echo '100'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var val = parseFloat(text.trim()) / 100.0;
                    root.brightnessSnapshotReady(isNaN(val) ? 1.0 : val, "");
                }
            }
        }
    }

    function requestHyprlandSnapshot(requestId, subject) {
        var p = hyprSnapshotComponent.createObject(root, {
            "requestId": requestId,
            "subject": subject
        });
        if (p) p.start();
    }

    Component {
        id: hyprSnapshotComponent
        Process {
            id: proc
            property string requestId: ""
            property string subject: ""
            property string outputData: ""
            command: ["hyprctl", "-j", subject]
            stdout: SplitParser {
                onRead: (chunk) => { proc.outputData += chunk + "\n"; }
            }
            onExited: (code, status) => {
                root.hyprlandSnapshotReady(requestId, subject, code === 0 ? outputData : "[]", code === 0 ? "" : "hyprctl exited with " + code);
                proc.destroy();
            }
            function start() {
                proc.running = true;
            }
        }
    }

    function generateWallpaperThumbnail(sourcePath, cachePath, cacheDir, targetWidth, targetHeight, quality) {
        var p = thumbnailComponent.createObject(root, {
            "sourcePath": sourcePath,
            "cachePath": cachePath,
            "cacheDir": cacheDir,
            "targetWidth": targetWidth,
            "targetHeight": targetHeight,
            "quality": quality
        });
        if (p) p.start();
    }

    Component {
        id: thumbnailComponent
        Process {
            id: thumbProc
            property string sourcePath: ""
            property string cachePath: ""
            property string cacheDir: ""
            property int targetWidth: 640
            property int targetHeight: 360
            property int quality: 80

            command: [
                "bash", "-c",
                "mkdir -p \"$1\"\n" +
                "magick \"$2\" -auto-orient -resize \"${3}x${4}^\" -gravity center -extent \"${3}x${4}\" -quality \"$5\" \"$6\" 2>/dev/null || cp -f \"$2\" \"$6\" 2>/dev/null\n",
                "thumb-worker",
                cacheDir,
                sourcePath,
                String(targetWidth),
                String(targetHeight),
                String(quality),
                cachePath
            ]

            onExited: (code, status) => {
                root.wallpaperThumbnailFinished(sourcePath, cachePath, code === 0, code === 0, code === 0 ? "" : "Failed thumbnail generation");
                thumbProc.destroy();
            }

            function start() {
                thumbProc.running = true;
            }
        }
    }
}
