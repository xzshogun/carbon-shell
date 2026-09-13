import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Carbon launcher: search apps from the system desktop entries. Prefix the
 * query with ">" to run built-in actions (wallpaper, lock, suspend, logout)
 * — exactly the caelestia-style command popup. Enter launches/activates,
 * Up/Down navigate, Esc closes. Typing ">wallpaper" (or pressing Super+W, or
 * the dock's wallpaper button) morphs the card into the caelestia/ukishima
 * style filmstrip: the focused tile sits large and fully lit in the middle,
 * neighbours shrink, dim and desaturate as they slide under it. Up/Down
 * (and Left/Right, or the wheel) surf; the desktop wallpaper previews live;
 * Enter or a click on the focused tile applies wallpaper + theme.
 */
Item {
    id: root

    property bool open: false
    signal closeRequested()

    readonly property var cardItem: card
    readonly property bool animatingOut: !root.open && root.opacity > 0.001

    readonly property int maxShown: 10
    readonly property string wallpaperDir: "/home/shogun/Pictures/Wallpapers"
    readonly property string wpThumbDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/carbon/wp-thumbs"
    readonly property string thumbsScript: "/home/shogun/.config/hypr/scripts/carbon-wp-thumbs.sh"
    readonly property string stateFile: "/home/shogun/.config/hypr/current_wallpaper"

    property string mode: "apps"
    property var allApps: []
    property bool wallpaperPickerOpen: false

    onWallpaperPickerOpenChanged: {
        if (root.wallpaperPickerOpen)
            root.openWallpaperPicker()
        else
            root.resetToApps()
    }

    /* ====== Wallpaper model (thumb + newest-first listing, ukishima-style) ====== */
    property var wpEntries: []
    property bool wpLoading: false
    property int focusIndex: 0
    property real pos: 0
    property string currentPath: ""

    /* Filmstrip slot geometry — identical to the caelestia/ukishima strip */
    readonly property var slotW:      [196, 126, 104, 88, 74]
    readonly property var slotH:      [110, 71, 59, 50, 42]
    readonly property var slotCX:     [0, 143, 244, 326, 393]
    readonly property var slotBright: [1, 0.56, 0.42, 0.30, 0.22]
    readonly property var slotSat:    [1, 0.65, 0.55, 0.45, 0.40]

    function slotLerp(arr, ao) {
        if (ao >= 4)
            return arr[4]
        var i = Math.floor(ao)
        var f = ao - i
        return arr[i] + (arr[i + 1] - arr[i]) * f
    }

    function offsetX(off) {
        var ao = Math.abs(off)
        var cx = ao <= 4 ? root.slotLerp(root.slotCX, ao) : root.slotCX[4] + (ao - 4) * 60
        return (off < 0 ? -cx : cx)
    }

    function moveWallpaper(delta) {
        if (root.wpEntries.length === 0)
            return
        root.focusIndex = Math.max(0, Math.min(root.wpEntries.length - 1, root.focusIndex + delta))
    }

    FrameAnimation {
        running: root.visible && root.pos !== root.focusIndex
        onTriggered: {
            var k = 1 - Math.exp(-frameTime / 0.07)
            var next = root.pos + (root.focusIndex - root.pos) * k
            root.pos = Math.abs(next - root.focusIndex) < 0.001 ? root.focusIndex : next
        }
    }

    FileView {
        id: linkFile
        path: root.stateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.currentPath = linkFile.text().trim()
        onFileChanged: reload()
        onLoadFailed: root.currentPath = ""
    }

    function warmWallpapers() {
        if (root.wpLoading)
            return
        if (root.wpEntries.length === 0) {
            root.wpLoading = true
            thumbProc.running = true
            return
        }
        probeProc.command = ["sh", "-c", "[ -s \"$1\" ]", "_", root.wpThumbDir + "/" + String(root.wpEntries[0].name).replace(/\./g, "_") + ".png"]
        probeProc.running = true
    }

    Process {
        id: probeProc
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.wpLoading = true
                thumbProc.running = true
            }
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbsScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c",
            "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n' | sort -rn",
            "_", root.wallpaperDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var t1 = lines[i].indexOf("\t")
                    if (t1 < 1)
                        continue
                    var path = lines[i].substring(t1 + 1)
                    if (path.length === 0)
                        continue
                    var name = path.substring(path.lastIndexOf("/") + 1)
                    out.push({ path: path, name: name, mtime: parseFloat(lines[i].substring(0, t1)) })
                }
                root.wpEntries = out
                root.wpLoading = false
                if (root.focusIndex >= out.length)
                    root.focusIndex = Math.max(0, out.length - 1)
                if (root.mode === "wallpapers")
                    root.centerWallpapersOnCurrent()
            }
        }
    }

    /* ====== Actions ====== */
    readonly property var actions: [
        {
            "id": "wallpaper",
            "name": "Change wallpaper",
            "desc": "Open the wallpaper picker",
            "glyph": "\uf03e",
            "run": () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", "/home/shogun/.config/hypr/scripts/carbon-ipc.sh", "wallpaper"])
            }
        },
        {
            "id": "lock",
            "name": "Lock screen",
            "desc": "Lock the screen with Carbon lock",
            "glyph": "\uf023",
            "run": () => Quickshell.execDetached(["sh", "/home/shogun/.config/hypr/scripts/carbon-ipc.sh", "lock"])
        },
        {
            "id": "suspend",
            "name": "Suspend",
            "desc": "Suspend the system",
            "glyph": "\uf2dc",
            "run": () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            "id": "logout",
            "name": "Log out",
            "desc": "Log out of the session",
            "glyph": "\uf2f5",
            "run": () => Quickshell.execDetached(["sh", "-c", "command -v wlogout >/dev/null && wlogout"])
        }
    ]

    ListModel {
        id: appModel
    }

    ListModel {
        id: actionModel
    }

    function refresh() {
        if (root.mode === "wallpapers") return;
        const raw = searchField.text.trim();
        if (raw.startsWith(">")) {
            root.mode = "actions";
            const needle = raw.slice(1).trim().toLowerCase();
            actionModel.clear();
            for (const a of root.actions)
                if (!needle || a.name.toLowerCase().includes(needle) || a.id.includes(needle))
                    actionModel.append({ "action": a });
            resultsList.currentIndex = actionModel.count > 0 ? 0 : -1;
        } else {
            root.mode = "apps";
            const needle = raw.toLowerCase();
            const matched = [];
            for (const e of root.allApps) {
                const name = (e.name || "").toLowerCase();
                let score = -1;
                if (needle.length === 0 || name.startsWith(needle)) score = 0;
                else if (name.includes(needle)) score = 1;
                else if ((e.genericName || "").toLowerCase().includes(needle)) score = 2;
                else if ((e.comment || "").toLowerCase().includes(needle)) score = 3;
                if (score >= 0) matched.push({ "e": e, "score": score });
            }
            matched.sort((a, b) => a.score - b.score || a.e.name.localeCompare(b.e.name));
            appModel.clear();
            for (const m of matched.slice(0, root.maxShown))
                appModel.append({ "entry": m.e });
            resultsList.currentIndex = appModel.count > 0 ? 0 : -1;
        }
    }

    function launchEntry(entry) {
        if (!entry) return;
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.command.join(" ")]);
        else
            entry.execute();
        root.closeRequested();
    }

    function loadApps() {
        const values = DesktopEntries.applications.values || [];
        const list = [];
        for (let i = 0; i < values.length; i++) {
            const e = values[i];
            if (e.noDisplay || !e.name || !e.command || e.command.length === 0) continue;
            list.push(e);
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        root.allApps = list;
        root.refresh();
    }

    function centerWallpapersOnCurrent() {
        var idx = 0
        for (var i = 0; i < root.wpEntries.length; i++)
            if (root.wpEntries[i].path === root.currentPath) {
                idx = i
                break
            }
        root.focusIndex = idx
        root.pos = idx
    }

    function openWallpaperPicker() {
        root.mode = "wallpapers";
        searchField.text = "";
        root._previewPath = root.currentPath || "";
        if (root.wpEntries.length > 0)
            root.centerWallpapersOnCurrent()
        else {
            root.focusIndex = 0
            root.pos = 0
        }
        root.warmWallpapers();
        searchField.forceActiveFocus();
    }

    /* Leave the filmstrip: any plain launcher open should land on apps. */
    function resetToApps() {
        if (root.mode === "wallpapers") {
            root.mode = "apps"
            searchField.text = ""
            root.focusIndex = 0
            root.pos = 0
        }
    }

    function wallpaperAt(index) {
        if (index < 0 || index >= root.wpEntries.length) return "";
        return root.wpEntries[index].path;
    }

    function previewAt(index) {
        const p = root.wallpaperAt(index);
        if (p && p !== root._previewPath) {
            root._previewPath = p;
            Quickshell.execDetached(["sh", "/home/shogun/.config/hypr/scripts/wp-preview.sh", p]);
        }
    }

    function applyWallpaper(index) {
        const p = root.wallpaperAt(index);
        if (p)
            Quickshell.execDetached(["sh", "/home/shogun/.config/hypr/scripts/wp-apply.sh", p]);
        root.closeRequested();
    }

    property string _previewPath: ""

    onFocusIndexChanged: {
        if (root.mode === "wallpapers")
            previewTimer.restart();
    }

    Timer {
        id: previewTimer
        interval: 250
        onTriggered: root.previewAt(root.focusIndex)
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps()
        }
    }

    Component.onCompleted: {
        root.loadApps()
    }

    onOpenChanged: {
        if (root.open) {
            searchField.text = "";
            root.loadApps();
            openTimer.restart();
        }
    }

    onVisibleChanged: {
        if (root.visible && root.open) {
            searchField.text = "";
            root.loadApps();
            openTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: 120
        onTriggered: searchField.forceActiveFocus()
    }

    property string barEdge: "top"
    readonly property string attachedEdge: (root.barEdge === "bottom") ? "right" : "left"

    readonly property real filletRadius: 20
    readonly property real cornerRadius: 16

    readonly property string notchFillPath: {
        const w = root.width
        const h = root.height
        const rf = root.filletRadius
        const rc = root.cornerRadius
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h} Z`
        } else {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h} Z`
        }
    }

    readonly property string notchStrokePath: {
        const w = root.width
        const h = root.height
        const rf = root.filletRadius
        const rc = root.cornerRadius
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h}`
        } else {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h}`
        }
    }

    width: root.mode === "wallpapers" ? 420 : 340
    height: Math.min(620, parent ? Math.round(parent.height * 0.74) : 620)

    x: {
        if (!parent) return 0
        if (root.attachedEdge === "left") {
            return root.open ? 0 : (-width - 24)
        } else {
            return root.open ? (parent.width - width) : (parent.width + 24)
        }
    }
    y: parent ? Math.round((parent.height - height) / 2) : 0

    opacity: root.open ? 1.0 : 0.0

    Behavior on x {
        NumberAnimation {
            duration: root.open ? 280 : 180
            easing.type: root.open ? Easing.OutCubic : Easing.InQuad
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 220 : 140
            easing.type: root.open ? Easing.OutQuad : Easing.InQuad
        }
    }

    Shape {
        id: card
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: true
        layer.smooth: true

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.bg
            PathSvg { path: root.notchFillPath }
        }

        ShapePath {
            strokeWidth: 1.2
            strokeColor: Qt.alpha(Theme.outline, 0.45)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.notchStrokePath }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
    }

    Rectangle {
        id: searchBox
        anchors.top: parent.top
        anchors.topMargin: root.filletRadius + 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.attachedEdge === "left" ? 14 : 14
        anchors.rightMargin: root.attachedEdge === "right" ? 14 : 14
        height: 38
        radius: 12
        color: Theme.bgAlt
        border.color: searchField.activeFocus ? Theme.accent : Theme.outline
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.mode === "wallpapers" ? "Search wallpapers — Arrow keys surf, Enter to apply" : "Search apps — type \">\" for commands"
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: 13
            visible: searchField.text.length === 0
        }

        TextInput {
            id: searchField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            color: Theme.fg
            clip: true
            font.family: Theme.font
            font.pixelSize: 13
            selectByMouse: true
            onTextChanged: root.refresh()
            onAccepted: {
                if (root.mode === "wallpapers") {
                    root.applyWallpaper(root.focusIndex);
                    return;
                }
                const it = resultsList.currentItem;
                if (!it) return;
                if (root.mode === "actions")
                    it.action.run();
                else
                    root.launchEntry(it.entry);
            }
            Keys.onDownPressed: {
                if (root.mode === "wallpapers") {
                    root.moveWallpaper(1);
                } else {
                    resultsList.incrementCurrentIndex();
                }
            }
            Keys.onUpPressed: {
                if (root.mode === "wallpapers") {
                    root.moveWallpaper(-1);
                } else {
                    resultsList.decrementCurrentIndex();
                }
            }
            Keys.onRightPressed: {
                if (root.mode === "wallpapers")
                    root.moveWallpaper(1);
            }
            Keys.onLeftPressed: {
                if (root.mode === "wallpapers")
                    root.moveWallpaper(-1);
            }
            Keys.onEscapePressed: root.closeRequested()
        }
    }

    ListView {
        id: resultsList
        anchors.top: searchBox.bottom
        anchors.topMargin: 8
        anchors.bottom: quickActionsRow.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        clip: true
        visible: root.mode !== "wallpapers"
        model: root.mode === "apps" ? appModel : actionModel
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true

        delegate: Rectangle {
            id: row
            property var entry: model.entry ?? null
            property var action: model.action ?? null

            readonly property bool isAction: root.mode === "actions"

            width: resultsList.width
            height: 42
            radius: 8
            color: resultsList.currentIndex === index ? Theme.bgActive : (rowArea.containsMouse ? Theme.bgHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: 90 }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: 3
                radius: 1.5
                color: Theme.accent
                visible: resultsList.currentIndex === index
            }

            Rectangle {
                id: iconTile
                width: 28
                height: 28
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                color: Theme.bgAlt

                Image {
                    anchors.centerIn: parent
                    visible: !row.isAction
                    width: 20
                    height: 20
                    source: row.entry && row.entry.icon
                        ? Quickshell.iconPath(row.entry.icon, "image-missing")
                        : ""
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.centerIn: parent
                    visible: row.isAction
                    text: row.action ? row.action.glyph : ""
                    color: Theme.accentLit
                    font.family: Theme.font
                    font.pixelSize: 14
                }
            }

            Text {
                id: rowName
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.left: iconTile.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                text: row.isAction ? (row.action ? row.action.name : "") : (row.entry ? row.entry.name : "")
                color: row.isAction ? Theme.accentLit : (resultsList.currentIndex === index ? Theme.fg : Theme.fgDim)
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: resultsList.currentIndex === index ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                id: rowDesc
                anchors.top: rowName.bottom
                anchors.topMargin: 2
                anchors.left: iconTile.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                text: row.isAction
                    ? (row.action ? row.action.desc : "")
                    : (row.entry ? (row.entry.comment || row.entry.genericName || "") : "")
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    resultsList.currentIndex = index;
                    if (root.mode === "actions")
                        action.run();
                    else
                        root.launchEntry(entry);
                }
            }
        }
    }

    /* ── Bottom Quick Actions Row ── */
    Rectangle {
        id: quickActionsRow
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.filletRadius + 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 32
        radius: 8
        color: Theme.bgAlt
        border.color: Qt.alpha(Theme.outline, 0.3)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "\uf120"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: termHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: termHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["foot"])
                        root.closeRequested()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: cfgHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: cfgHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["/home/shogun/.config/hypr/scripts/carbon-config-editor"])
                        root.closeRequested()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "\uf023"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: lockHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: lockHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["/home/shogun/.config/hypr/scripts/hyprlock.sh"])
                        root.closeRequested()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Text {
                    anchors.centerIn: parent
                    text: "\uf03e"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: wpHov.containsMouse ? Theme.accent : Theme.fgDim
                }
                MouseArea {
                    id: wpHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.wallpaperPickerOpen = !root.wallpaperPickerOpen
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.mode === "actions" ? "Commands" : (resultsList.count + " apps")
                font.family: "Valley Sans"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.fgFaint
            }
        }
    }

    /* ====== Wallpaper filmstrip (caelestia/ukishima style) ====== */
    Item {
        id: wpStrip
        visible: root.mode === "wallpapers"
        anchors.top: searchBox.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 168
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (root.mode === "wallpapers" && root.wpEntries.length > 0)
                    root.moveWallpaper(wheel.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Repeater {
            model: root.mode === "wallpapers" ? root.wpEntries : null

            delegate: Item {
                id: tile

                required property int index
                required property var modelData

                readonly property string nameUnd: String(modelData.name).replace(/\./g, "_")
                readonly property string thumbSource: "file://" + root.wpThumbDir + "/" + tile.nameUnd + ".png?v=" + Math.round(modelData.mtime)
                readonly property string path: modelData.path
                readonly property bool isCurrent: root.currentPath === tile.path

                readonly property real off: tile.index - root.pos
                readonly property real ao: Math.abs(tile.off)
                readonly property bool focused: tile.index === root.focusIndex
                readonly property real bright: root.slotLerp(root.slotBright, tile.ao)
                readonly property real sat: root.slotLerp(root.slotSat, tile.ao)
                readonly property real corner: 8 + 2 * Math.max(0, 1 - tile.ao)

                readonly property real edgeFade: {
                    var soft = 70
                    var gap = Math.min(tile.x, parent.width - (tile.x + tile.width))
                    return Math.max(0, Math.min(1, gap / soft))
                }

                width: root.slotLerp(root.slotW, tile.ao)
                height: root.slotLerp(root.slotH, tile.ao)
                x: parent.width / 2 + root.offsetX(tile.off) - tile.width / 2
                y: (parent.height - tile.height) / 2 - 8
                z: 10 - tile.ao
                visible: tile.ao <= 5
                opacity: tile.edgeFade * (tile.ao <= 4 ? 1 : Math.max(0, 5 - tile.ao))

                Rectangle {
                    id: tcard
                    anchors.fill: parent
                    radius: tile.corner
                    color: Theme.bgAlt

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        saturation: tile.sat - 1
                        shadowEnabled: tile.focused
                        shadowColor: "#000000"
                        shadowOpacity: 0.45
                        shadowBlur: 0.7
                        shadowVerticalOffset: 4
                        maskEnabled: true
                        maskSource: tcardMask
                    }

                    Item {
                        id: tcardMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: tile.corner
                            color: "#FFFFFFFF"
                        }
                    }

                    Image {
                        id: timg
                        anchors.fill: parent
                        source: tile.ao <= 5 ? tile.thumbSource : ""
                        sourceSize: Qt.size(512, 220)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.bgAlt
                        visible: timg.status === Image.Error
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 1 - tile.bright
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: tile.corner
                    color: "transparent"
                    border.width: 1
                    border.color: tile.focused ? Theme.accentLit : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 90 } }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    width: 7
                    height: 7
                    radius: 4
                    visible: tile.isCurrent
                    color: Theme.accentLit
                    border.width: 1
                    border.color: "#000000"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (root.mode === "wallpapers" && !tile.focused) {
                            root.focusIndex = tile.index
                        }
                    }
                    onClicked: {
                        if (tile.focused)
                            root.applyWallpaper(tile.index)
                        else
                            root.focusIndex = tile.index
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.wpLoading
            text: "Scanning wallpapers…"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: 13
        }

        Text {
            anchors.centerIn: parent
            visible: !root.wpLoading && root.wpEntries.length === 0
            text: "No wallpapers found in " + root.wallpaperDir
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: 13
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            visible: !root.wpLoading && root.wpEntries.length > 0
            text: "↑↓ / ◀▶ browse   ·   Enter or click to set"
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}