pragma Singleton

import QtQuick

QtObject {
    id: root

    property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]

    signal brightnessSnapshotReady(real value, string errorString)
    signal volumeSnapshotReady(real value, bool muted, string errorString)
    signal systemStatsReady(real cpuUsage, real ramUsage, string errorString)
}
