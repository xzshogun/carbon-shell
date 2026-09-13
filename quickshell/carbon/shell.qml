import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "Singletons"
import "components"
import "modules"
import "modules/lock"

/**
 * Carbon — a full Quickshell shell with a single left vertical bar.
 *
 * Each monitor gets one layer-shell window pinned to the left edge that
 * reserves its own width (exclusiveZone), so tiled windows always sit beside
 * it. Modules stack vertically inside the bar; nothing else in the shell has
 * its own surface yet, so everything lives in this one window.
 */
ShellRoot {
    id: root

    property bool launcherOpen: false
    property bool wallpaperPickerOpen: false
    property string wallpaperSource: "local"

    function closeAllPopupsExcept(keep) {
        if (keep !== "mixer") { root.mixerOpen = false; root.mixerPinned = false }
        if (keep !== "brightness") { root.brightnessOpen = false; root.brightnessPinned = false }
        if (keep !== "battery") { root.batteryOpen = false; root.batteryPinned = false }
        if (keep !== "notif") { root.notifOpen = false; root.notifPinned = false }
        if (keep !== "music") { root.musicOpen = false; root.musicPinned = false; root.musicHovered = false }
        if (keep !== "smallMusic") { root.smallMusicOpen = false; root.smallMusicPinned = false; root.smallMusicHovered = false }
        if (keep !== "wifi") { root.wifiOpen = false; root.wifiPinned = false }
        if (keep !== "bt") { root.btOpen = false; root.btPinned = false }
        if (keep !== "calendar") { root.calendarOpen = false; root.calendarPinned = false }
    }

    property bool smallMusicOpen: false
    property bool smallMusicPinned: false
    property bool smallMusicHovered: false
    function openSmallMusic() {
        root.closeAllPopupsExcept("smallMusic")
        root.smallMusicOpen = true
    }
    function closeSmallMusic() { root.smallMusicOpen = false; root.smallMusicPinned = false }
    function toggleSmallMusic() {
        if (root.smallMusicOpen) {
            root.closeSmallMusic()
        } else {
            root.closeAllPopupsExcept("smallMusic")
            root.smallMusicPinned = true
            root.smallMusicOpen = true
        }
    }

    Timer {
        id: smallMusicLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.smallMusicPinned && !root.smallMusicHovered) root.closeSmallMusic()
        }
    }

    /* Calendar popup state */
    property bool calendarOpen: false
    property bool calendarPinned: false
    property bool calendarHovered: false
    property bool calendarHidden: true

    function openCalendar() {
        root.closeAllPopupsExcept("calendar")
        root.calendarOpen = true
    }
    function closeCalendar() { root.calendarOpen = false; root.calendarPinned = false }
    function toggleCalendar() {
        if (root.calendarOpen) { root.closeCalendar() }
        else { root.closeAllPopupsExcept("calendar"); root.calendarPinned = true; root.calendarOpen = true }
    }

    onCalendarOpenChanged: {
        if (root.calendarOpen) { calendarOutTimer.stop(); root.calendarHidden = false }
        else { calendarOutTimer.restart() }
    }

    Timer {
        id: calendarLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.calendarPinned && !root.calendarHovered) root.closeCalendar()
        }
    }

    Timer {
        id: calendarOutTimer
        interval: 90
        onTriggered: root.calendarHidden = true
    }

    /* Mixer popup state: open/pinned (click) or hover-release behaviour. */
    property bool mixerOpen: false
    property bool mixerPinned: false
    property bool mixerHovered: false
    property bool mixerHidden: true

    function openMixer() {
        root.closeAllPopupsExcept("mixer")
        root.mixerOpen = true
    }
    function closeMixer() { root.mixerOpen = false; root.mixerPinned = false }
    function toggleMixer() {
        if (root.mixerOpen && root.mixerPinned) { root.mixerPinned = false; root.mixerOpen = false }
        else { root.closeAllPopupsExcept("mixer"); root.mixerPinned = true; root.mixerOpen = true }
    }

    onMixerOpenChanged: {
        if (root.mixerOpen) { mixerOutTimer.stop(); root.mixerHidden = false }
        else { mixerOutTimer.restart() }
    }

    /* Hover-leave: close briefly after the pointer leaves both the bar icon
     * and the popup, unless the popup is pinned (clicked). */
    Timer {
        id: mixerLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.mixerPinned && !root.mixerHovered) root.closeMixer()
        }
    }

    /* Fade-out grace: keep the window alive a moment so the close animation
     * is visible before the layer surface unmaps. */
    Timer {
        id: mixerOutTimer
        interval: 90
        onTriggered: root.mixerHidden = true
    }

    /* Brightness popup state: open/pinned (click) or hover-release behaviour. */
    property bool brightnessOpen: false
    property bool brightnessPinned: false
    property bool brightnessHovered: false
    property bool brightnessHidden: true

    function openBrightness() {
        root.closeAllPopupsExcept("brightness")
        root.brightnessOpen = true
    }
    function closeBrightness() { root.brightnessOpen = false; root.brightnessPinned = false }
    function toggleBrightness() {
        if (root.brightnessOpen) { root.closeBrightness() }
        else { root.closeAllPopupsExcept("brightness"); root.brightnessPinned = true; root.brightnessOpen = true }
    }

    onBrightnessOpenChanged: {
        if (root.brightnessOpen) { brightnessOutTimer.stop(); root.brightnessHidden = false }
        else { brightnessOutTimer.restart() }
    }

    Timer {
        id: brightnessLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.brightnessPinned && !root.brightnessHovered) root.closeBrightness()
        }
    }

    Timer {
        id: brightnessOutTimer
        interval: 90
        onTriggered: root.brightnessHidden = true
    }

    /* Battery popup state: open/pinned (click) or hover-release behaviour. */
    property bool batteryOpen: false
    property bool batteryPinned: false
    property bool batteryHovered: false
    property bool batteryHidden: true

    function openBattery() {
        root.closeAllPopupsExcept("battery")
        root.batteryOpen = true
    }
    function closeBattery() {
        root.batteryOpen = false
        root.batteryPinned = false
    }
    function toggleBattery() {
        if (root.batteryOpen) {
            root.closeBattery()
        } else {
            root.closeAllPopupsExcept("battery")
            root.batteryPinned = true
            root.batteryOpen = true
        }
    }

    onBatteryOpenChanged: {
        if (root.batteryOpen) { batteryOutTimer.stop(); root.batteryHidden = false }
        else { batteryOutTimer.restart() }
    }

    Timer {
        id: batteryLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.batteryPinned && !root.batteryHovered) root.closeBattery()
        }
    }

    Timer {
        id: batteryOutTimer
        interval: 90
        onTriggered: root.batteryHidden = true
    }

    /* Notification popup state */
    property bool notifOpen: false
    property bool notifPinned: false
    property bool notifHovered: false
    property bool notifHidden: true

    function openNotif() {
        root.closeAllPopupsExcept("notif")
        root.notifOpen = true
    }
    function closeNotif() { root.notifOpen = false; root.notifPinned = false }
    function toggleNotif() {
        if (root.notifOpen && root.notifPinned) {
            root.closeNotif()
        } else {
            root.closeAllPopupsExcept("notif")
            root.notifPinned = true
            root.notifOpen = true
        }
    }

    onNotifOpenChanged: {
        if (root.notifOpen) { notifOutTimer.stop(); root.notifHidden = false }
        else { notifOutTimer.restart() }
    }

    Timer {
        id: notifLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.notifPinned && !root.notifHovered) root.closeNotif()
        }
    }

    Timer {
        id: notifOutTimer
        interval: 90
        onTriggered: root.notifHidden = true
    }

    /* Wifi popup state */
    property bool wifiOpen: false
    property bool wifiPinned: false
    property bool wifiHovered: false
    property bool wifiHidden: true

    function openWifi() {
        root.closeAllPopupsExcept("wifi")
        if (!wifiProbe.running) wifiProbe.running = true
        if (!wifiNameProbe.running) wifiNameProbe.running = true
        root.wifiOpen = true
    }
    function closeWifi() { root.wifiOpen = false; root.wifiPinned = false }
    function toggleWifi() {
        if (root.wifiOpen) { root.closeWifi() }
        else { root.closeAllPopupsExcept("wifi"); root.wifiPinned = true; root.wifiOpen = true }
    }

    onWifiOpenChanged: {
        if (root.wifiOpen) { wifiOutTimer.stop(); root.wifiHidden = false }
        else { wifiOutTimer.restart() }
    }

    Timer {
        id: wifiLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.wifiPinned && !root.wifiHovered) root.closeWifi()
        }
    }

    Timer {
        id: wifiOutTimer
        interval: 90
        onTriggered: root.wifiHidden = true
    }

    /* Bluetooth popup state */
    property bool btOpen: false
    property bool btPinned: false
    property bool btHovered: false
    property bool btHidden: true

    function openBt() {
        root.closeAllPopupsExcept("bt")
        if (!btProbe.running) btProbe.running = true
        if (!btNameProbe.running) btNameProbe.running = true
        root.btOpen = true
    }
    function closeBt() { root.btOpen = false; root.btPinned = false }
    function toggleBt() {
        if (root.btOpen) { root.closeBt() }
        else { root.closeAllPopupsExcept("bt"); root.btPinned = true; root.btOpen = true }
    }

    onBtOpenChanged: {
        if (root.btOpen) { btOutTimer.stop(); root.btHidden = false }
        else { btOutTimer.restart() }
    }

    Timer {
        id: btLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.btPinned && !root.btHovered) root.closeBt()
        }
    }

    Timer {
        id: btOutTimer
        interval: 90
        onTriggered: root.btHidden = true
    }

    /* Wifi & Bluetooth System Probes */
    property bool wifiOn: true
    property string wifiName: ""
    Process {
        id: wifiProbe
        command: ["sh", "-c", "nmcli radio wifi | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: wifiC; waitForEnd: true }
        onExited: root.wifiOn = String(wifiC.text).trim() === "enabled"
    }
    Process {
        id: wifiNameProbe
        command: ["sh", "-c", "wifi=$(nmcli -t -f IN-USE,SSID dev wifi 2>/dev/null | grep -E '^\\*:|^yes:' | head -1 | cut -d: -f2-); [ -n \"$wifi\" ] && echo \"$wifi\" || nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo:' | head -1 | cut -d: -f1"]
        stdout: StdioCollector { id: wifiNameC; waitForEnd: true }
        onExited: root.wifiName = String(wifiNameC.text).trim()
    }
    function toggleWifiPower() {
        root.wifiOn = !root.wifiOn
        Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (root.wifiOn ? "on" : "off")])
    }

    property bool btOn: false
    property string btName: ""
    Process {
        id: btProbe
        command: ["sh", "-c", "timeout 4 bluetoothctl show | sed -n 's/.*Powered:[ ]*//p' | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: btC; waitForEnd: true }
        onExited: root.btOn = String(btC.text).trim() === "yes"
    }
    Process {
        id: btNameProbe
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [0-9A-F:]* //'"]
        stdout: StdioCollector { id: btNameC; waitForEnd: true }
        onExited: root.btName = String(btNameC.text).trim()
    }
    function toggleBtPower() {
        root.btOn = !root.btOn
        if (!root.btOn) root.btName = ""
        Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.btOn ? "on" : "off")])
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!wifiProbe.running) wifiProbe.running = true
            if (!wifiNameProbe.running) wifiNameProbe.running = true
            if (!btProbe.running) btProbe.running = true
            if (!btNameProbe.running) btNameProbe.running = true
        }
    }

    /* Power menu state */
    property bool powerOpen: false
    function openPower() { root.powerOpen = true }
    function closePower() { root.powerOpen = false }
    function togglePower() { root.powerOpen = !root.powerOpen }

    /* Workspaces & Windows Overview state */
    property bool overviewOpen: false
    function openOverview() { root.overviewOpen = true }
    function closeOverview() { root.overviewOpen = false }
    function toggleOverview() { root.overviewOpen = !root.overviewOpen }
    onOverviewOpenChanged: {
        if (root.overviewOpen) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = true, passes = 2, size = 5 } } })"])
        } else {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = false } } })"])
        }
    }

    function openLauncher() {
        root.closeWallpaperPicker()
        root.launcherOpen = true
    }
    property real lastLauncherToggleTime: 0
    function closeLauncher() { root.launcherOpen = false }
    function toggleLauncher() {
        var now = Date.now()
        if (now - root.lastLauncherToggleTime < 280) return
        root.lastLauncherToggleTime = now
        if (root.launcherOpen) closeLauncher(); else openLauncher()
    }

    property real lastWpToggleTime: 0
    function openWallpaperPicker() {
        root.closeLauncher()
        root.wallpaperPickerOpen = true
    }
    function closeWallpaperPicker() { root.wallpaperPickerOpen = false }
    function toggleWallpaperPicker() {
        var now = Date.now()
        if (now - root.lastWpToggleTime < 280) return
        root.lastWpToggleTime = now
        if (root.wallpaperPickerOpen) closeWallpaperPicker(); else openWallpaperPicker()
    }
    onLauncherOpenChanged: {
        if (!root.launcherOpen && root.launcherItem)
            root.launcherItem.resetToApps()
    }

    /* Music popup & notch dropdown state */
    property bool musicOpen: false
    property bool musicPinned: false
    property bool musicHovered: false
    property bool musicHidden: true

    function openMusic() {
        root.closeAllPopupsExcept("music")
        root.musicOpen = true
        root.musicHovered = true
        musicLeaveTimer.stop()
    }
    function closeMusic() {
        root.musicOpen = false
        root.musicPinned = false
        root.musicHovered = false
    }
    function toggleMusic() {
        if (root.musicOpen && root.musicPinned) {
            root.musicPinned = false
            root.musicOpen = false
        } else {
            root.closeAllPopupsExcept("music")
            root.musicPinned = true
            root.musicOpen = true
        }
    }

    onMusicOpenChanged: {
        if (root.musicOpen) {
            musicOutTimer.stop()
            root.musicHidden = false
        } else {
            musicOutTimer.restart()
        }
    }

    Timer {
        id: musicLeaveTimer
        interval: 320
        onTriggered: {
            if (!root.musicPinned && !root.musicHovered) {
                root.musicOpen = false
            }
        }
    }

    Timer {
        id: musicOutTimer
        interval: 220
        onTriggered: root.musicHidden = true
    }

    /* ── Bar Mode Configuration: "pill" or "notch" ──────────────────── */
    property string barMode: "pill"

    FileView {
        id: barModeFile
        path: "/home/shogun/.config/hypr/carbon-bar-mode.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadBarMode()
        onFileChanged: reload()
    }

    property string islandStyle: "pill"
    property int islandPage: 0
    property bool islandPersistent: true
    property bool islandHovered: false
    readonly property bool islandRevealed: islandPersistent || islandHovered || mixerOpen || notifOpen || brightnessOpen || batteryOpen || wifiOpen || btOpen || calendarOpen || smallMusicOpen

    function reloadBarMode() {
        try {
            const txt = barModeFile.text().trim()
            if (txt.length > 0) {
                const d = JSON.parse(txt)
                if (d.mode) {
                    if (d.mode === "three_islands") root.barMode = "pill"
                    else root.barMode = d.mode
                }
                if (d.islandStyle) {
                    root.islandStyle = d.islandStyle
                }
                if (d.islandPersistent !== undefined) {
                    root.islandPersistent = Boolean(d.islandPersistent)
                }
                if (root.barMode === "pill" || root.barMode === "minimal") {
                    if (root.mainBarEdge !== "top" && root.mainBarEdge !== "bottom") {
                        root.mainBarEdge = "top"
                        root.barEdge = "top"
                        root.musicBarEdge = "top"
                    }
                }
            }
        } catch (e) {
            console.log("Error loading bar mode: " + e)
        }
    }

    function switchBarMode(m) {
        if (!m) return
        root.barMode = m
        Quickshell.execDetached(["python3", "-c",
            "import json, os; p=os.path.expanduser('~/.config/hypr/carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['mode']='" + m + "'; json.dump(d, open(p,'w'), indent=2)"])
    }

    function switchIslandStyle(s) {
        if (!s) return
        root.islandStyle = s
        Quickshell.execDetached(["python3", "-c",
            "import json, os; p=os.path.expanduser('~/.config/hypr/carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['islandStyle']='" + s + "'; json.dump(d, open(p,'w'), indent=2)"])
    }

    function switchIslandPersistent(p) {
        root.islandPersistent = Boolean(p)
        Quickshell.execDetached(["python3", "-c",
            "import json, os; p=os.path.expanduser('~/.config/hypr/carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['islandPersistent']=" + (p ? "True" : "False") + "; json.dump(d, open(p,'w'), indent=2)"])
    }

    property string barEdge: "top"
    property string mainBarEdge: "top"
    property string musicBarEdge: "top"
    property string musicBarContent: "both"
    property string leftAlign: "left"
    property string centerAlign: "center"
    property string rightAlign: "right"
    property string leftEdge: "top"
    property string centerEdge: "top"
    property string rightEdge: "top"

    /* Panel corner placement for Quick Settings:
     * - Pill / Minimal mode on bottom -> "top_left"
     * - Notch mode on bottom -> "top_left"
     * - Notch mode on right -> "bottom_left"
     * - Notch mode on left -> "bottom_right"
     * - Default (top) -> "bottom_right"
     */
    readonly property string controlsCorner: {
        return (root.mainBarEdge === "bottom" || root.barEdge === "bottom") ? "top_left" : "bottom_right"
    }

    FileView {
        id: barPosFile
        path: "/home/shogun/.config/hypr/carbon-bar-position.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.applyBarPos(barPosFile.text())
        onFileChanged: reload()
    }

    function applyBarPos(txt) {
        if (!txt) return
        try {
            var d = JSON.parse(txt)
            if (d.mainBarEdge) {
                root.mainBarEdge = d.mainBarEdge
                root.barEdge = d.mainBarEdge
            } else if (d.edge) {
                root.mainBarEdge = d.edge
                root.barEdge = d.edge
            }
            if (d.musicBarEdge) {
                root.musicBarEdge = d.musicBarEdge
            } else if (d.edge) {
                root.musicBarEdge = (d.edge === "bottom" ? "bottom" : "top")
            }
            if (root.barMode === "pill" || root.barMode === "notch") {
                if (root.mainBarEdge !== "top" && root.mainBarEdge !== "bottom") {
                    root.mainBarEdge = "top"
                    root.barEdge = "top"
                }
                if (root.musicBarEdge !== "top" && root.musicBarEdge !== "bottom") {
                    root.musicBarEdge = "top"
                }
            }
            if (d.musicBarContent) root.musicBarContent = d.musicBarContent

            if (d.leftAlign) root.leftAlign = d.leftAlign
            if (d.centerAlign) root.centerAlign = d.centerAlign
            if (d.rightAlign) root.rightAlign = d.rightAlign
            if (d.leftEdge) root.leftEdge = d.leftEdge
            if (d.centerEdge) root.centerEdge = d.centerEdge
            if (d.rightEdge) root.rightEdge = d.rightEdge
        } catch (e) {}
    }

    Component.onCompleted: {
        reloadBarMode()
        applyBarPos(barPosFile.text())
    }

    /* ── MPRIS Music Tracking ────────────────────────────────────────── */
    readonly property var mprisPlayers: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activeMprisPlayer: null

    function resolveActiveMprisPlayer() {
        if (!root.mprisPlayers || root.mprisPlayers.length === 0) return null
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            if (root.mprisPlayers[i].playbackState === MprisPlaybackState.Playing)
                return root.mprisPlayers[i]
        }
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            if (root.mprisPlayers[i].playbackState === MprisPlaybackState.Paused
                && (root.mprisPlayers[i].trackTitle || "").length > 0)
                return root.mprisPlayers[i]
        }
        return root.mprisPlayers[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.activeMprisPlayer = root.resolveActiveMprisPlayer()
    }

    readonly property string mprisTrackTitle: activeMprisPlayer ? (activeMprisPlayer.trackTitle || "") : ""
    readonly property string mprisTrackArtist: activeMprisPlayer ? (activeMprisPlayer.trackArtist || "") : ""
    readonly property string mprisArtUrl: activeMprisPlayer ? (activeMprisPlayer.trackArtUrl || "") : ""
    readonly property bool mprisHasTrack: root.activeMprisPlayer !== null && root.mprisTrackTitle.trim().length > 0

    /* Quick-settings panel: hover the top-right hot corner to summon it, and
     * keep it while the pointer is over the panel (or the corner). */
    property bool controlsVisible: false
    property bool controlsHovered: false
    property bool controlsPinned: false

    function openControls() {
        if (root.barMode === "minimal") return
        root.controlsVisible = true
    }
    function closeControls() { root.controlsVisible = false; root.controlsPinned = false }
    function toggleControls() {
        if (root.barMode === "minimal") return
        if (root.controlsVisible && root.controlsPinned) {
            root.closeControls()
        } else {
            root.controlsPinned = true
            root.controlsVisible = true
        }
    }

    Timer {
        id: controlsLeaveTimer
        interval: 800
        onTriggered: {
            if (!root.controlsPinned && !root.controlsHovered) root.controlsVisible = false
        }
    }

    /* Notification daemon: claims org.freedesktop.Notifications (swaync is
     * disabled in Hyprland) and feeds the top-right bar. Exactly one. */
    NotificationServer {
        id: notificationServer
        onNotification: notification => {
            notification.tracked = true
        }
    }

    /* External trigger (keybinds): Super+W brokered to the launcher in
     * wallpaper mode by carbon-ipc.sh over this unix socket. */
    SocketServer {
        path: "/tmp/carbon-shell.sock"
        active: true
        handler: Socket {
            parser: SplitParser {
                splitMarker: "\n"
                onRead: function (message) {
                    var cmd = message.trim()
                    if (cmd === "wallpaper" || cmd === "wallpaper-local") {
                        root.wallpaperSource = "local"
                        root.toggleWallpaperPicker()
                    }
                    else if (cmd === "wallpaper-live") {
                        root.wallpaperSource = "live"
                        root.openWallpaperPicker()
                    }
                    else if (cmd === "wallpaper-online") {
                        root.wallpaperSource = "wallhaven"
                        root.openWallpaperPicker()
                    }
                    else if (cmd === "close-wallpaper")
                        root.closeWallpaperPicker()
                    else if (cmd === "launcher")
                        root.openLauncher()
                    else if (cmd === "close-launcher")
                        root.closeLauncher()
                    else if (cmd === "toggle-launcher")
                        root.toggleLauncher()
                    else if (cmd === "mixer")
                        root.toggleMixer()
                    else if (cmd === "brightness")
                        root.toggleBrightness()
                    else if (cmd === "controls")
                        root.toggleControls()
                    else if (cmd === "controls-mode-todo") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 1
                    } else if (cmd === "controls-mode-timer") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 2
                    } else if (cmd === "controls-mode-quick") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 0
                    }
                    else if (cmd === "battery")
                        root.toggleBattery()
                    else if (cmd === "mixer")
                        root.toggleMixer()
                    else if (cmd === "brightness")
                        root.toggleBrightness()
                    else if (cmd === "wifi")
                        root.toggleWifi()
                    else if (cmd === "bt" || cmd === "bluetooth")
                        root.toggleBt()
                    else if (cmd === "power")
                        root.togglePower()
                    else if (cmd === "close-power")
                        root.closePower()
                    else if (cmd === "lock") {
                        root.closePower()
                        sessionLock.lock()
                    }
                    else if (cmd === "unlock") {
                        sessionLock.locked = false
                    }
                    else if (cmd === "notifications" || cmd === "notif")
                        root.toggleNotif()
                    else if (cmd === "overview" || cmd === "toggle-overview")
                        root.toggleOverview()
                    else if (cmd === "close-overview")
                        root.closeOverview()
                    else if (cmd === "calendar")
                        root.toggleCalendar()
                    else if (cmd === "music" || cmd === "music-toggle")
                        root.toggleMusic()
                    else if (cmd === "music-open") {
                        root.musicPinned = true
                        root.openMusic()
                    }
                    else if (cmd === "music-close") {
                        root.musicPinned = false
                        root.closeMusic()
                    }
                    else if (cmd === "toggle-small-music" || cmd === "music-small") {
                        root.toggleSmallMusic()
                    }
                    else if (cmd === "close-small-music") {
                        root.smallMusicOpen = false
                    }
                    else if (cmd.startsWith("bar-mode ")) {
                        var m = cmd.substring(9).trim()
                        if (m === "three_islands") m = "pill"
                        root.switchBarMode(m)
                    }
                    else if (cmd.startsWith("island-style ")) {
                        var is = cmd.substring(13).trim()
                        root.switchIslandStyle(is)
                    }
                    else if (cmd.startsWith("island-persistent ")) {
                        var ip = cmd.substring(18).trim().toLowerCase()
                        root.switchIslandPersistent(ip === "true" || ip === "1")
                    }
                    else if (cmd.startsWith("island-page ")) {
                        var pg = parseInt(cmd.substring(12).trim(), 10)
                        if (!isNaN(pg)) root.islandPage = pg
                    }
                    else if (cmd === "island-next-page") {
                        root.islandPage = (root.islandPage + 1) % 3
                    }
                    else if (cmd === "island-prev-page") {
                        root.islandPage = (root.islandPage - 1 + 3) % 3
                    }
                    else if (cmd === "reload-bar-mode")
                        root.reloadBarMode()
                    else if (cmd === "reload-bar-pos") {
                        barPosFile.reload()
                        root.applyBarPos(barPosFile.text())
                    }
                    else if (cmd === "lock") {
                        sessionLock.lock()
                    }
                    else if (cmd === "unlock") {
                        sessionLock.unlock()
                    }
                    else if (cmd === "lock-test-notif") {
                        sessionLock.testNotif()
                    }
                    else if (cmd === "lock-test-notif-center") {
                        sessionLock.testNotifCenter()
                    }
                    else if (cmd === "lock-test-notif-clear") {
                        sessionLock.testNotifClear()
                    }
                    else if (cmd === "desktop-notif-clear") {
                        if (notificationServer && notificationServer.trackedNotifications && notificationServer.trackedNotifications.values) {
                            const list = [...notificationServer.trackedNotifications.values]
                            for (let i = 0; i < list.length; i++) {
                                if (list[i] && typeof list[i].dismiss === "function") list[i].dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    /* ── Lock Screen (Carbon Lewis Dot Structure & Password Card) ───── */
    LockScreen {
        id: sessionLock
        notificationServer: notificationServer
    }

    GlobalShortcut {
        name: "lock"
        onPressed: sessionLock.lock()
    }

    /* Wallpaper: bottom-most fullscreen image, updated live by WallpaperMod */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperWindow
            required property var modelData

            screen: modelData
            color: "#000000"
            WlrLayershell.namespace: "carbon-wallpaper"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            WallpaperMod { anchors.fill: parent }
        }
    }

    /* ── Dynamic Edge Reservation Windows (Prevents App Overlap) ────────── */
    readonly property bool hasTopReserve: (root.barMode === "pill" || (root.barMode === "minimal" && root.islandPersistent))
        ? (root.mainBarEdge === "top")
        : (root.barMode === "minimal" ? false : (root.mainBarEdge === "top" || root.musicBarEdge === "top"))
    readonly property bool hasBottomReserve: (root.barMode === "pill" || (root.barMode === "minimal" && root.islandPersistent))
        ? (root.mainBarEdge === "bottom")
        : (root.barMode === "minimal" ? false : (root.mainBarEdge === "bottom" || root.musicBarEdge === "bottom"))
    readonly property bool hasLeftReserve: false
    readonly property bool hasRightReserve: false

    readonly property int topReserveHeight: root.hasTopReserve ? (root.barMode === "notch" ? 38 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 38 : 46) : 54)) : 0
    readonly property int bottomReserveHeight: root.hasBottomReserve ? (root.barMode === "notch" ? 38 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 38 : 46) : 54)) : 0
    readonly property int leftReserveWidth: root.hasLeftReserve ? 38 : 0
    readonly property int rightReserveWidth: root.hasRightReserve ? 38 : 0

    /* Top Edge Reserve */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserveTopWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-top"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.topReserveHeight
            anchors { top: true; left: true; right: true }
            implicitHeight: root.topReserveHeight
            visible: root.hasTopReserve

            mask: Region {}
        }
    }

    /* Bottom Edge Reserve */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserveBottomWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-bottom"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.bottomReserveHeight
            anchors { bottom: true; left: true; right: true }
            implicitHeight: root.bottomReserveHeight
            visible: root.hasBottomReserve

            mask: Region {}
        }
    }

    /* Left Edge Reserve */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserveLeftWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-left"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.leftReserveWidth
            anchors { left: true; top: true; bottom: true }
            implicitWidth: root.leftReserveWidth
            visible: root.hasLeftReserve

            mask: Region {}
        }
    }

    /* Right Edge Reserve */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserveRightWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-right"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.rightReserveWidth
            anchors { right: true; top: true; bottom: true }
            implicitWidth: root.rightReserveWidth
            visible: root.hasRightReserve

            mask: Region {}
        }
    }

    /* ── Pill Mode: Connected Continuous Full Floating Bar ──────────── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pillFullBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-pill-full"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
                left: true
                right: true
            }
            margins {
                top: root.mainBarEdge !== "bottom" ? 8 : 0
                bottom: root.mainBarEdge === "bottom" ? 8 : 0
                left: 12
                right: 12
            }

            implicitHeight: 38
            visible: root.barMode === "pill" && root.mainBarEdge !== "left" && root.mainBarEdge !== "right"

            Rectangle {
                id: pillFullCapsule
                anchors.fill: parent
                radius: 19
                color: Theme.bg
                border.color: Theme.outline
                border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    /* Left: Workspaces & App Launcher */
                    BarLeft {
                        id: pillLeftItem
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        showBackground: false
                        vertical: false
                        onOpenLauncher: root.openLauncher()
                    }

                    /* Center: Clock & Music Island */
                    Item {
                        id: pillCenterSec
                        anchors.centerIn: parent
                        implicitWidth: pillCenterRow.implicitWidth
                        implicitHeight: 38

                        Row {
                            id: pillCenterRow
                            anchors.centerIn: parent
                            spacing: 8

                            CenterClock {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.musicBarContent !== "music"
                            }

                            Rectangle {
                                width: 1
                                height: 14
                                color: Qt.alpha(Theme.fg, 0.22)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.musicBarContent === "both"
                            }

                            Row {
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.musicBarContent !== "clock"

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: Theme.bgAlt
                                    border.color: Theme.accent
                                    border.width: 1.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: root.mprisArtUrl
                                        fillMode: Image.PreserveAspectCrop
                                        visible: root.mprisHasTrack && root.mprisArtUrl.length > 0
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf51f"
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        color: Theme.accent
                                        visible: !root.mprisHasTrack || root.mprisArtUrl.length === 0
                                    }
                                }

                                Text {
                                    text: root.mprisHasTrack ? root.mprisTrackTitle : "Nothing Playing"
                                    font.family: "Valley Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.mprisHasTrack ? Theme.fg : Theme.fgDim
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 160)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMusic()
                            // Temporarily disabled music hover
                            // onEntered: root.openMusic()
                            // onExited: {
                            //     root.musicHovered = false
                            //     musicLeaveTimer.restart()
                            // }
                        }
                    }

                    /* Right: System Tray & Controls */
                    BarRight {
                        id: pillRightItem
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        showBackground: false
                        vertical: false
                        anchorWindow: pillFullBarWindow
                        notifCount: notifItem ? notifItem.total : 0
                        onOpenMixer: root.openMixer()
                        onCloseMixer: mixerLeaveTimer.restart()
                        onToggleMixer: root.toggleMixer()
                        onOpenBrightness: root.openBrightness()
                        onCloseBrightness: brightnessLeaveTimer.restart()
                        onToggleBrightness: root.toggleBrightness()
                        onOpenBattery: root.openBattery()
                        onCloseBattery: batteryLeaveTimer.restart()
                        onToggleBattery: root.toggleBattery()
                        onOpenNotif: root.openNotif()
                        onCloseNotif: notifLeaveTimer.restart()
                        onToggleNotif: root.toggleNotif()
                        onToggleControls: root.toggleControls()
                        onOpenPower: root.openPower()
                    }
                }
            }
        }
    }

    /* ── Pill Mode: Connected Continuous Full Vertical Floating Bar (Left / Right) ── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pillFullVerticalBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-pill-vert"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: root.mainBarEdge === "left"
                right: root.mainBarEdge === "right"
            }
            margins {
                top: 8
                bottom: 8
                left: root.mainBarEdge === "left" ? 8 : 0
                right: root.mainBarEdge === "right" ? 8 : 0
            }

            implicitWidth: 38
            visible: false

            Rectangle {
                id: pillFullVertCapsule
                anchors.fill: parent
                radius: 19
                color: Theme.bg
                border.color: Theme.outline
                border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8

                    /* Top: Workspaces & App Launcher */
                    BarLeft {
                        id: pillVertLeftItem
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        showBackground: false
                        vertical: true
                        onOpenLauncher: root.openLauncher()
                    }

                    /* Center: Mini Music & Clock Indicator */
                    Item {
                        anchors.centerIn: parent
                        width: 32
                        height: 52

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: Theme.bgAlt
                                border.color: Theme.accent
                                border.width: 1.5
                                anchors.horizontalCenter: parent.horizontalCenter
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.mprisArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.mprisHasTrack && root.mprisArtUrl.length > 0
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf51f"
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    color: Theme.accent
                                    visible: !root.mprisHasTrack || root.mprisArtUrl.length === 0
                                }
                            }

                            Text {
                                text: {
                                    let d = new Date()
                                    let h = d.getHours() % 12
                                    if (h === 0) h = 12
                                    let m = d.getMinutes()
                                    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
                                }
                                font.family: "Valley Sans"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: Theme.fg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMusic()
                        }
                    }

                    /* Bottom: System Controls */
                    BarRight {
                        id: pillVertRightItem
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        showBackground: false
                        vertical: true
                        anchorWindow: pillFullVerticalBarWindow
                        notifCount: notifItem ? notifItem.total : 0
                        onOpenMixer: root.openMixer()
                        onCloseMixer: mixerLeaveTimer.restart()
                        onToggleMixer: root.toggleMixer()
                        onOpenBrightness: root.openBrightness()
                        onCloseBrightness: brightnessLeaveTimer.restart()
                        onToggleBrightness: root.toggleBrightness()
                        onOpenBattery: root.openBattery()
                        onCloseBattery: batteryLeaveTimer.restart()
                        onToggleBattery: root.toggleBattery()
                        onOpenNotif: root.openNotif()
                        onCloseNotif: notifLeaveTimer.restart()
                        onToggleNotif: root.toggleNotif()
                        onToggleControls: root.toggleControls()
                        onOpenPower: root.openPower()
                    }
                }
            }
        }
    }

    /* ── Minimal Mode: Ultra-Lightweight Single Floating Dynamic Island ── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: minimalIslandWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-minimal"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
            }
            margins {
                top: 0
                bottom: 0
            }

            implicitHeight: 52
            implicitWidth: 600
            visible: root.barMode === "minimal"

            mask: Region {
                item: root.islandRevealed ? minimalIslandItem : edgeTrigger
            }

            Item {
                id: edgeTrigger
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                width: Math.max(minimalIslandItem.width, 360)
                height: 8
                visible: !root.islandPersistent

                HoverHandler {
                    id: edgeHov
                    onHoveredChanged: {
                        if (edgeHov.hovered) {
                            islandHoverLeaveTimer.stop()
                            root.islandHovered = true
                        }
                    }
                }
            }

            Timer {
                id: islandHoverLeaveTimer
                interval: 350
                onTriggered: {
                    if (!edgeHov.hovered && !islandHov.hovered) {
                        root.islandHovered = false
                    }
                }
            }

            MinimalIsland {
                id: minimalIslandItem
                attachedBottom: root.mainBarEdge === "bottom"
                islandStyle: root.islandStyle
                notifCount: notifItem ? notifItem.total : 0
                anchors.horizontalCenter: parent.horizontalCenter

                y: {
                    if (root.mainBarEdge === "bottom") {
                        return root.islandRevealed
                            ? (parent.height - height - ((root.islandStyle === "notch") ? 0 : 8))
                            : (parent.height + 10)
                    } else {
                        return root.islandRevealed
                            ? ((root.islandStyle === "notch") ? 0 : 8)
                            : (-height - 10)
                    }
                }
                opacity: root.islandRevealed ? 1.0 : 0.0

                Behavior on y {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                HoverHandler {
                    id: islandHov
                    onHoveredChanged: {
                        if (islandHov.hovered) {
                            islandHoverLeaveTimer.stop()
                            root.islandHovered = true
                        } else {
                            islandHoverLeaveTimer.restart()
                        }
                    }
                }

                Binding on currentPage {
                    value: root.islandPage
                }
                onCurrentPageChanged: {
                    if (root.islandPage !== currentPage) root.islandPage = currentPage
                }
                onOpenLauncher: root.openLauncher()
                onToggleControls: root.toggleControls()
                onOpenMixer: root.openMixer()
                onCloseMixer: mixerLeaveTimer.restart()
                onToggleMixer: root.toggleMixer()
                onOpenBrightness: root.openBrightness()
                onCloseBrightness: brightnessLeaveTimer.restart()
                onToggleBrightness: root.toggleBrightness()
                onOpenBattery: root.openBattery()
                onCloseBattery: batteryLeaveTimer.restart()
                onToggleBattery: root.toggleBattery()
                onOpenWifi: root.openWifi()
                onCloseWifi: wifiLeaveTimer.restart()
                onToggleWifi: root.toggleWifi()
                onOpenBt: root.openBt()
                onCloseBt: btLeaveTimer.restart()
                onToggleBt: root.toggleBt()
                onOpenNotif: root.openNotif()
                onCloseNotif: notifLeaveTimer.restart()
                onToggleNotif: root.toggleNotif()
                onOpenCalendar: root.openCalendar()
                onCloseCalendar: calendarLeaveTimer.restart()
                onToggleCalendar: root.toggleCalendar()
                onOpenSmallMusic: root.openSmallMusic()
                onCloseSmallMusic: smallMusicLeaveTimer.restart()
                onToggleSmallMusic: root.toggleSmallMusic()
                onSwitchIslandStyle: (s) => root.switchIslandStyle(s)
                onConvertToPill: root.switchBarMode("pill")
                onConvertToNotch: root.switchBarMode("notch")
            }
        }
    }

    /* ── Small Music Overlay Window (Compact Dropdown Below Island) ── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: smallMusicWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-music-small"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
            }
            margins {
                top: root.mainBarEdge !== "bottom" ? (root.barMode === "notch" ? 42 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 50)) : 0
                bottom: root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 42 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 50)) : 0
            }

            implicitWidth: 340
            implicitHeight: 140
            visible: (root.smallMusicOpen || smallMusicItem.animatingOut)

            mask: Region {
                item: root.smallMusicOpen ? smallMusicItem : null
            }

            SmallMusicOverlay {
                id: smallMusicItem
                anchors.centerIn: parent
                open: root.smallMusicOpen
                attachedBottom: root.mainBarEdge === "bottom"
                onCloseRequested: root.closeSmallMusic()
                HoverHandler {
                    id: smallMusicHov
                    onHoveredChanged: {
                        root.smallMusicHovered = smallMusicHov.hovered
                        if (root.smallMusicHovered) smallMusicLeaveTimer.stop()
                        else smallMusicLeaveTimer.restart()
                    }
                }
            }
        }
    }



    /* Music island: floats top-centre, transparent, independent of the bar.
     * Full-screen window (all four anchors, ukishima-style) so the window
     * resolves its real width; the pill self-centres inside it and the mask
     * Region confines pointer input to the pill. */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: musicWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-music"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.musicBarEdge !== "bottom"
                bottom: root.musicBarEdge === "bottom"
            }
            margins {
                top: root.musicBarEdge !== "bottom" ? (root.barMode === "notch" ? 36 : 48) : 0
                bottom: root.musicBarEdge === "bottom" ? (root.barMode === "notch" ? 36 : 48) : 0
            }

            implicitWidth: 600
            implicitHeight: 360
            visible: (!root.musicHidden || musicItem.animatingOut)

            mask: Region {
                item: root.musicOpen ? musicItem.cardItem : null
            }

            MusicMod {
                id: musicItem
                anchors.centerIn: parent
                attachedBottom: root.musicBarEdge === "bottom"
                barMode: root.barMode
                pinned: root.musicPinned
                externalOpen: root.musicOpen
                onPanelHoverChanged: (hovered) => {
                    if (hovered) {
                        root.musicHovered = true
                        musicLeaveTimer.stop()
                    } else {
                        root.musicHovered = false
                        musicLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* ── Notch Mode: Curved 3-notch bar ──────────────────────────────── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notchBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-notch"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
                left: true
                right: true
            }
            margins {
                top: 0
                bottom: 0
            }

            implicitHeight: 34
            visible: root.barMode === "notch"

            mask: notchMask
            Region {
                id: notchMask
                Region {
                    x: notchLeftItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchLeftItem.height) : 0
                    width: notchLeftItem.width
                    height: notchLeftItem.height
                }
                Region {
                    x: notchCenterItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchCenterItem.height) : 0
                    width: root.musicBarEdge === root.mainBarEdge ? notchCenterItem.width : 0
                    height: root.musicBarEdge === root.mainBarEdge ? notchCenterItem.height : 0
                }
                Region {
                    x: notchRightItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchRightItem.height) : 0
                    width: notchRightItem.width
                    height: notchRightItem.height
                }
            }

            NotchBarLeft {
                id: notchLeftItem
                attachedBottom: root.mainBarEdge === "bottom"
                anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                anchors.left: parent.left
                leftFillet: false
                rightFillet: true
                onOpenLauncher: root.openLauncher()
            }

            NotchBarCenter {
                id: notchCenterItem
                visible: root.musicBarEdge === root.mainBarEdge
                barContent: root.musicBarContent
                attachedBottom: root.mainBarEdge === "bottom"
                anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                anchors.horizontalCenter: parent.horizontalCenter
                leftFillet: true
                rightFillet: true
                onOpenMusicHover: {}
                onCloseMusicHover: {}
                onToggleMusic: root.toggleMusic()
                onOpenMusic: root.toggleMusic()
            }

            NotchBarRight {
                id: notchRightItem
                attachedBottom: root.mainBarEdge === "bottom"
                anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                anchors.right: parent.right
                leftFillet: true
                rightFillet: false
                notifCount: notifItem ? notifItem.total : 0
                onOpenMixer: root.openMixer()
                onCloseMixer: mixerLeaveTimer.restart()
                onToggleMixer: root.toggleMixer()
                onOpenBrightness: root.openBrightness()
                onCloseBrightness: brightnessLeaveTimer.restart()
                onToggleBrightness: root.toggleBrightness()
                onOpenBattery: root.openBattery()
                onCloseBattery: batteryLeaveTimer.restart()
                onToggleBattery: root.toggleBattery()
                onOpenNotif: root.openNotif()
                onCloseNotif: notifLeaveTimer.restart()
                onToggleNotif: root.toggleNotif()
                onOpenPower: root.openPower()
            }
        }
    }

    /* ── Notch Center Island Window (When musicBarEdge is on separate edge or main bar is vertical) ── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notchCenterWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-notch-center"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.musicBarEdge !== "bottom"
                bottom: root.musicBarEdge === "bottom"
            }
            implicitHeight: 34
            implicitWidth: separateNotchCenter.implicitWidth
            visible: root.barMode === "notch" && (root.musicBarEdge !== root.mainBarEdge || root.mainBarEdge === "left" || root.mainBarEdge === "right")

            NotchBarCenter {
                id: separateNotchCenter
                barContent: root.musicBarContent
                attachedBottom: root.musicBarEdge === "bottom"
                anchors.fill: parent
                onOpenMusicHover: {}
                onCloseMusicHover: {}
                onToggleMusic: root.toggleMusic()
                onOpenMusic: root.toggleMusic()
            }
        }
    }

    /* Launcher popup: centred modal over the desktop */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.launcherOpen || (launcherItem && launcherItem.animatingOut)

            MouseArea {
                anchors.fill: parent
                enabled: root.launcherOpen
                onClicked: (mouse) => {
                    var lw = launcherItem.width
                    var lh = launcherItem.height
                    var lx = launcherItem.x
                    var ly = launcherItem.y
                    if (mouse.x < lx || mouse.x > lx + lw || mouse.y < ly || mouse.y > ly + lh)
                        root.closeLauncher()
                }
            }

            LauncherMod {
                id: launcherItem
                open: root.launcherOpen
                barEdge: root.mainBarEdge
                onCloseRequested: root.closeLauncher()
            }
        }
    }

    /* Wallhaven Wallpaper Picker popup: bottom-center modal over the desktop */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperPickerWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-wallpaper-picker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.wallpaperPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.wallpaperPickerOpen || (wpItem && wpItem.animatingOut)

            /* Backdrop click dismisses wallpaper picker */
            MouseArea {
                anchors.fill: parent
                enabled: root.wallpaperPickerOpen
                onClicked: root.closeWallpaperPicker()
            }

            WallpaperPicker {
                id: wpItem
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                open: root.wallpaperPickerOpen
                activeSource: root.wallpaperSource
                onCloseRequested: root.closeWallpaperPicker()

                Connections {
                    target: root
                    function onWallpaperSourceChanged() {
                        wpItem.activeSource = root.wallpaperSource
                    }
                    function onWallpaperPickerOpenChanged() {
                        if (root.wallpaperPickerOpen) {
                            wpItem.activeSource = root.wallpaperSource
                        }
                    }
                }
            }
        }
    }

    /* Mixer popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: mixerWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-mixer"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 16)
        }

        implicitWidth: mixerItem.implicitWidth
        implicitHeight: mixerItem.implicitHeight + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.mixerOpen ? mixerItem : null
            x: 0; y: 0
            width: root.mixerOpen ? mixerItem.implicitWidth : 0
            height: root.mixerOpen ? mixerItem.implicitHeight + 20 : 0
        }

        MixerMod {
            id: mixerItem
            barEdge: root.mainBarEdge
            open: root.mixerOpen
            onCloseRequested: root.closeMixer()
            onAnyHoverChanged: {
                root.mixerHovered = mixerItem.anyHover
                if (root.mixerHovered) mixerLeaveTimer.stop()
                else mixerLeaveTimer.restart()
            }
        }
    }

    /* Brightness popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: brightnessWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-brightness"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 16)
        }

        implicitWidth: brightnessItem.implicitWidth
        implicitHeight: brightnessItem.implicitHeight + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.brightnessOpen ? brightnessItem : null
            x: 0; y: 0
            width: root.brightnessOpen ? brightnessItem.implicitWidth : 0
            height: root.brightnessOpen ? brightnessItem.implicitHeight + 20 : 0
        }

        BrightnessPopup {
            id: brightnessItem
            barEdge: root.mainBarEdge
            open: root.brightnessOpen
            onCloseRequested: root.closeBrightness()
            onAnyHoverChanged: {
                root.brightnessHovered = brightnessItem.anyHover
                if (root.brightnessHovered) brightnessLeaveTimer.stop()
                else brightnessLeaveTimer.restart()
            }
        }
    }

    /* Battery popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: batteryWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-battery"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 24)
        }

        implicitWidth: batteryItem.implicitWidth
        implicitHeight: batteryItem.implicitHeight + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.batteryOpen ? batteryItem : null
            x: 0; y: 0
            width: root.batteryOpen ? batteryItem.implicitWidth : 0
            height: root.batteryOpen ? batteryItem.implicitHeight + 20 : 0
        }

        BatteryPopup {
            id: batteryItem
            barEdge: root.mainBarEdge
            open: root.batteryOpen
            onHoveredChanged: {
                root.batteryHovered = batteryItem.hovered
                if (root.batteryHovered) batteryLeaveTimer.stop()
                else batteryLeaveTimer.restart()
            }
        }
    }

    /* Wifi popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: wifiWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-wifi"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wifiOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 16)
        }

        implicitWidth: 250
        implicitHeight: 286 + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.wifiOpen ? wifiItem : null
            x: 0; y: 0
            width: root.wifiOpen ? 250 : 0
            height: root.wifiOpen ? 286 + 20 : 0
        }

        WifiPopup {
            id: wifiItem
            open: root.wifiOpen
            powerOn: root.wifiOn
            wifiName: root.wifiName
            onPowerToggled: (on) => root.toggleWifiPower()
            onRequestedClose: root.closeWifi()
            HoverHandler {
                id: wifiHov
                onHoveredChanged: {
                    root.wifiHovered = wifiHov.hovered
                    if (root.wifiHovered) wifiLeaveTimer.stop()
                    else wifiLeaveTimer.restart()
                }
            }
        }
    }

    /* Bluetooth popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: btWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-bluetooth"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 16)
        }

        implicitWidth: 250
        implicitHeight: 286 + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.btOpen ? btItem : null
            x: 0; y: 0
            width: root.btOpen ? 250 : 0
            height: root.btOpen ? 286 + 20 : 0
        }

        BtPopup {
            id: btItem
            open: root.btOpen
            powerOn: root.btOn
            btName: root.btName
            onPowerToggled: (on) => root.toggleBtPower()
            onRequestedClose: root.closeBt()
            HoverHandler {
                id: btHov
                onHoveredChanged: {
                    root.btHovered = btHov.hovered
                    if (root.btHovered) btLeaveTimer.stop()
                    else btLeaveTimer.restart()
                }
            }
        }
    }

    /* Notification popup: (Centered below island in minimal mode, right-anchored in bar mode) */
    PanelWindow {
        id: notifWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-notif"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : (root.mainBarEdge === "right" ? (root.barMode === "notch" ? 38 : 54) : 16)
        }

        implicitWidth: notifItem.implicitWidth
        implicitHeight: notifItem.implicitHeight + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.notifOpen ? notifItem : null
            x: 0; y: 0
            width: root.notifOpen ? notifItem.implicitWidth : 0
            height: root.notifOpen ? notifItem.implicitHeight + 20 : 0
        }

        NotificationPopup {
            id: notifItem
            server: notificationServer
            barEdge: root.mainBarEdge
            open: root.notifOpen
            onHoveredChanged: {
                root.notifHovered = notifItem.hovered
                if (root.notifHovered) notifLeaveTimer.stop()
                else notifLeaveTimer.restart()
            }
            onRequestClose: root.closeNotif()
        }
    }

    /* Calendar popup: (Centered below island in minimal mode) */
    PanelWindow {
        id: calendarWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-calendar"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
            bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
            right: root.barMode !== "minimal"
        }
        margins {
            top: (root.mainBarEdge === "bottom" || root.mainBarEdge === "right") ? 0 : (root.barMode === "notch" ? 40 : (root.barMode === "minimal" ? (root.islandStyle === "notch" ? 34 : 42) : 54))
            bottom: root.mainBarEdge === "right" ? 14 : (root.mainBarEdge === "bottom" ? (root.barMode === "notch" ? 40 : 54) : 0)
            right: root.barMode === "minimal" ? 0 : 16
        }

        implicitWidth: 216
        implicitHeight: 206 + 20

        visible: root.mainBarEdge !== "left"

        mask: Region {
            item: root.calendarOpen ? calendarItem : null
            x: 0; y: 0
            width: root.calendarOpen ? 216 : 0
            height: root.calendarOpen ? 206 + 20 : 0
        }

        CalendarPopup {
            id: calendarItem
            open: root.calendarOpen
            onCloseRequested: root.closeCalendar()
            onAnyHoverChanged: {
                root.calendarHovered = calendarItem.anyHover
                if (root.calendarHovered) calendarLeaveTimer.stop()
                else calendarLeaveTimer.restart()
            }
        }
    }

    /* ── Left-anchored Popups for Left Edge Mode ── */
    PanelWindow {
        id: mixerWindowLeft
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-mixer-left"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 14
            left: root.barMode === "notch" ? 38 : 54
        }

        implicitWidth: mixerItemLeft.implicitWidth
        implicitHeight: mixerItemLeft.implicitHeight + 20

        visible: root.mainBarEdge === "left"

        mask: Region {
            item: root.mixerOpen ? mixerItemLeft : null
            x: 0; y: 0
            width: root.mixerOpen ? mixerItemLeft.implicitWidth : 0
            height: root.mixerOpen ? mixerItemLeft.implicitHeight + 20 : 0
        }

        MixerMod {
            id: mixerItemLeft
            barEdge: "left"
            open: root.mixerOpen
            onCloseRequested: root.closeMixer()
            onAnyHoverChanged: {
                root.mixerHovered = mixerItemLeft.anyHover
                if (root.mixerHovered) mixerLeaveTimer.stop()
                else mixerLeaveTimer.restart()
            }
        }
    }

    PanelWindow {
        id: brightnessWindowLeft
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-brightness-left"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 14
            left: root.barMode === "notch" ? 38 : 54
        }

        implicitWidth: brightnessItemLeft.implicitWidth
        implicitHeight: brightnessItemLeft.implicitHeight + 20

        visible: root.mainBarEdge === "left"

        mask: Region {
            x: 0; y: 0
            width: root.brightnessOpen ? brightnessItemLeft.implicitWidth : 0
            height: root.brightnessOpen ? brightnessItemLeft.implicitHeight + 20 : 0
        }

        BrightnessPopup {
            id: brightnessItemLeft
            barEdge: "left"
            open: root.brightnessOpen
            onCloseRequested: root.closeBrightness()
            onAnyHoverChanged: {
                root.brightnessHovered = brightnessItemLeft.anyHover
                if (root.brightnessHovered) brightnessLeaveTimer.stop()
                else brightnessLeaveTimer.restart()
            }
        }
    }

    PanelWindow {
        id: batteryWindowLeft
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-battery-left"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 14
            left: root.barMode === "notch" ? 38 : 54
        }

        implicitWidth: batteryItemLeft.implicitWidth
        implicitHeight: batteryItemLeft.implicitHeight + 20

        visible: root.mainBarEdge === "left"

        mask: Region {
            x: 0; y: 0
            width: root.batteryOpen ? batteryItemLeft.implicitWidth : 0
            height: root.batteryOpen ? batteryItemLeft.implicitHeight + 20 : 0
        }

        BatteryPopup {
            id: batteryItemLeft
            barEdge: "left"
            open: root.batteryOpen
            onHoveredChanged: {
                root.batteryHovered = batteryItemLeft.hovered
                if (root.batteryHovered) batteryLeaveTimer.stop()
                else batteryLeaveTimer.restart()
            }
        }
    }

    PanelWindow {
        id: notifWindowLeft
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-notif-left"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 14
            left: root.barMode === "notch" ? 38 : 54
        }

        implicitWidth: notifItemLeft.implicitWidth
        implicitHeight: notifItemLeft.implicitHeight + 20

        visible: root.mainBarEdge === "left"

        mask: Region {
            x: 0; y: 0
            width: root.notifOpen ? notifItemLeft.implicitWidth : 0
            height: root.notifOpen ? notifItemLeft.implicitHeight + 20 : 0
        }

        NotificationPopup {
            id: notifItemLeft
            server: notificationServer
            barEdge: "left"
            open: root.notifOpen
            onHoveredChanged: {
                root.notifHovered = notifItemLeft.hovered
                if (root.notifHovered) notifLeaveTimer.stop()
                else notifLeaveTimer.restart()
            }
            onRequestClose: root.closeNotif()
        }
    }

    /* Power menu: full-screen modal overlay */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: powerWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-power"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.powerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.powerOpen

            PowerMenu {
                anchors.fill: parent
                open: root.powerOpen
                onRequestClose: root.closePower()
                onRequestLock: {
                    root.closePower()
                    sessionLock.lock()
                }
            }
        }
    }

    /* Workspaces Overview: full-screen modal overlay */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overviewWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.overviewOpen

            OverviewMod {
                anchors.fill: parent
                open: root.overviewOpen
                onRequestClose: root.closeOverview()
            }
        }
    }

    /* Hot corner: full-screen transparent window whose input
     * Region summons the quick-settings panel. Dynamically placed according
     * to root.controlsCorner ("bottom_right", "top_left", or "bottom_left"). */
    PanelWindow {
        id: controlsSensor
        screen: Quickshell.screens[0]
        color: "transparent"
        visible: root.barMode !== "minimal"
        WlrLayershell.namespace: "carbon-sensor"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }

        mask: controlsSensorMask
        Region {
            id: controlsSensorMask
            readonly property real edgeThickness: 8
            readonly property real edgeSpan: 240

            // Horizontal strip:
            // - top_left: x: 0, y: 0
            // - bottom_left: x: 0, y: height - edgeThickness
            // - bottom_right: x: width - edgeSpan, y: height - edgeThickness
            Region {
                x: root.controlsCorner === "bottom_right"
                    ? (controlsSensor.width - controlsSensorMask.edgeSpan)
                    : 0
                y: root.controlsCorner === "top_left"
                    ? 0
                    : (controlsSensor.height - controlsSensorMask.edgeThickness)
                width: controlsSensorMask.edgeSpan
                height: controlsSensorMask.edgeThickness
            }

            // Vertical strip:
            // - top_left: x: 0, y: 0
            // - bottom_left: x: 0, y: height - edgeSpan
            // - bottom_right: x: width - edgeThickness, y: height - edgeSpan
            Region {
                x: root.controlsCorner === "bottom_right"
                    ? (controlsSensor.width - controlsSensorMask.edgeThickness)
                    : 0
                y: root.controlsCorner === "top_left"
                    ? 0
                    : (controlsSensor.height - controlsSensorMask.edgeSpan)
                width: controlsSensorMask.edgeThickness
                height: controlsSensorMask.edgeSpan
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.openControls()
            onExited: controlsLeaveTimer.restart()
        }
    }

    /* Quick-settings panel: now-playing strip over the quick toggles, positioned
     * dynamically according to root.controlsCorner ("bottom_right", "top_left", or "bottom_left"). */
    PanelWindow {
        id: controlsWindow
        screen: Quickshell.screens[0]
        color: "transparent"
        WlrLayershell.namespace: "carbon-controls"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.controlsVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: root.controlsCorner === "top_left"
            bottom: root.controlsCorner !== "top_left"
            left: root.controlsCorner === "top_left" || root.controlsCorner === "bottom_left"
            right: root.controlsCorner === "bottom_right"
        }
        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }

        implicitWidth: controlsItem.implicitWidth
        implicitHeight: controlsItem.implicitHeight

        mask: Region {
            item: root.controlsVisible ? controlsItem.cardItem : null
        }

        visible: (root.controlsVisible || controlsItem.animatingOut) && root.barMode !== "minimal"

        QuickSettings {
            id: controlsItem
            corner: root.controlsCorner
            width: controlsItem.implicitWidth
            height: controlsItem.implicitHeight
            open: root.controlsVisible
            onHoveredChanged: {
                root.controlsHovered = controlsItem.hovered
                if (controlsItem.hovered) root.controlsVisible = true
                controlsLeaveTimer.restart()
            }
        }
    }

    /* ── Floating Volume & Brightness Notch OSD ─────────────────────────── */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: root.mainBarEdge === "bottom" ? 16 : 42
            }

            implicitHeight: osdItem.implicitHeight
            visible: osdItem.opacity > 0.001

            NotchOsd {
                id: osdItem
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}