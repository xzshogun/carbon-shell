import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * LockScreen:
 * Wraps Quickshell WlSessionLock protocol.
 */
Scope {
    id: root

    property alias locked: sessionLock.locked
    property var notificationServer: null

    function lock() {
        sessionLock.locked = true
    }

    signal testNotifRequested()
    signal testNotifCenterRequested()
    signal testNotifClearRequested()

    function testNotif() {
        root.testNotifRequested()
    }

    function testNotifCenter() {
        root.testNotifCenterRequested()
    }

    function testNotifClear() {
        root.testNotifClearRequested()
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            id: surf
            notificationServer: root.notificationServer

            onRequestUnlock: {
                console.log("[LockScreen] Received onRequestUnlock -> unlocking session lock")
                sessionLock.locked = false
            }

            Connections {
                target: root
                function onTestNotifRequested() { surf.testNotif() }
                function onTestNotifCenterRequested() { surf.testNotifCenter() }
                function onTestNotifClearRequested() { surf.testNotifClear() }
            }
        }
    }
}
