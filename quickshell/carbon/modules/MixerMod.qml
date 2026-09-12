import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../components"
import "../Singletons"

/**
 * Carbon mixer popup: a small rounded panel that sticks to the right of the
 * left bar and slides/fades in when it opens.
 *
 * Three categories, switched from the header:
 *   · speaker -> mixer: master (system) volume + per-application streams
 *   · mic     -> input: default input volume/mute + the list of input
 *                 devices with instant default-switching
 *   · sun     -> brightness: display backlight slider, backed by brightnessctl
 *
 * Volume changes are pushed live to Pipewire, brightness via brightnessctl.
 * Everything is theme-aware.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property int view: 0
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 260
    implicitHeight: 330

    readonly property bool animatingOut: !root.open && card.opacity > 0.001

    readonly property bool pwReady: Pipewire.ready

    readonly property var allNodes: pwReady ? Pipewire.nodes.values : []
    readonly property var sinks: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Sink" || (n.isSink && !n.properties["media.class"]))
        && !/virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))
    readonly property var sources: allNodes.filter(n => n.audio && !n.isStream
        && (n.properties["media.class"] === "Audio/Source" || ((n.type & PwNodeType.Flag.Source) !== 0 && !n.properties["media.class"]))
        && !/monitor|virtual|null|stream/i.test(String(n.properties["media.class"] || n.properties["node.name"] || n.name || "")))

    readonly property var defaultSink: pwReady ? Pipewire.defaultAudioSink : null
    readonly property var defaultSource: pwReady ? Pipewire.defaultAudioSource : null

    /* Apps currently routed towards the default sink (the mixer list). */
    PwNodeLinkTracker {
        id: linkTracker
        node: root.defaultSink
    }

    readonly property var streams: linkTracker.linkGroups

    /* Keep QML bindings on the live audio state of the tracked nodes. */
    PwObjectTracker {
        objects: [ root.defaultSink, root.defaultSource ].filter(n => n !== null)
    }

    function nodeName(n) {
        if (!n) return "";
        return String(n.properties["application.name"]
            || n.properties["application.process.binary"]
            || n.nickname || n.description || n.name || "?");
    }

    /* ============ Output ports (speakers / headphones ALSA routes) ============ */
    property var outputPorts: []
    property string activeOutputPort: ""

    Process {
        id: sinkProc
        command: ["pactl", "list", "sinks"]
        stdout: StdioCollector {
            id: sinkCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseSinks(sinkCollector.text)
    }

    function refreshOutputPorts() {
        if (!root.pwReady || !root.defaultSink) return
        root.activeOutputPort = ""
        if (!sinkProc.running) sinkProc.running = true
    }

    function parseSinks(text) {
        const name = root.defaultSink ? root.defaultSink.name : ""
        if (!name) return
        for (const block of String(text).split(/\r?\nSink #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (!nm || nm[1] !== name) continue
            const port = /^\s*Active Port: (.+)$/m.exec(block)
            root.activeOutputPort = port ? port[1] : ""
            const portSection = block.split(/\r?\n\tPorts:\r?\n/)[1]
            if (portSection) {
                const portsText = portSection.split(/\r?\n\tActive Port:/)[0]
                const re = /^\t\t([a-z0-9][a-z0-9-]*)\s*:\s*(.+?)\s*\(type:\s*(Speaker|Headphones|Lineout|HDMI),?/gmi
                const out = []
                let m
                while ((m = re.exec(portsText))) out.push({ name: m[1], desc: m[2].trim() })
                root.outputPorts = out
            } else {
                root.outputPorts = []
            }
            return
        }
    }

    function selectOutputPort(portName) {
        if (!root.defaultSink) return
        Quickshell.execDetached(["pactl", "set-sink-port", root.defaultSink.name, portName])
        root.activeOutputPort = portName
        portSettleTimer.restart()
    }

    /* ============ Input ports (headset / internal mic ALSA routes) ============
     * A card can expose several mics as *routes* on one PipeWire source node
     * (e.g. Internal Mic, Headset Mic). WirePlumber hides these ports, so we
     * list them from pactl and switch with set-source-port. */
    property var inputPorts: []
    property string activeInputPort: ""
    property string sourceCardName: ""

    Process {
        id: srcProc
        command: ["pactl", "list", "sources"]
        stdout: StdioCollector {
            id: srcCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseSources(srcCollector.text)
    }

    Process {
        id: cardProc
        command: ["pactl", "list", "cards"]
        stdout: StdioCollector {
            id: cardCollector
            waitForEnd: true
        }
        onExited: (code, status) => root.parseCardPorts(cardCollector.text)
    }

    Timer {
        id: portSettleTimer
        interval: 900
        onTriggered: {
            root.refreshOutputPorts()
            root.refreshInputPorts()
        }
    }

    function refreshInputPorts() {
        if (!root.pwReady || !root.defaultSource) return
        root.activeInputPort = ""
        if (!srcProc.running) srcProc.running = true
        if (!cardProc.running) cardProc.running = true
    }

    function parseSources(text) {
        const name = root.defaultSource ? root.defaultSource.name : ""
        if (!name) { root.sourceCardName = ""; return }
        for (const block of String(text).split(/\r?\nSource #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (!nm || nm[1] !== name) continue
            const port = /^\s*Active Port: (.+)$/m.exec(block)
            root.activeInputPort = port ? port[1] : ""
            const card = /^\s*device\.name = "(.+)"$/m.exec(block)
            root.sourceCardName = card ? card[1] : ""
            return
        }
        root.sourceCardName = ""
    }

    function parseCardPorts(text) {
        if (!root.sourceCardName) return
        for (const block of String(text).split(/\r?\nCard #/)) {
            const nm = /^\tName: (.+)$/m.exec(block)
            if (!nm || nm[1] !== root.sourceCardName) continue
            const re = /^\t\t([a-z0-9][a-z0-9-]*)\s*:\s*(.+?)\s*\(type:\s*(Mic|Headset),/gm
            const out = []
            let m
            while ((m = re.exec(block))) out.push({ name: m[1], desc: m[2].trim() })
            root.inputPorts = out
            return
        }
    }

    function selectInputPort(portName) {
        if (!root.defaultSource) return
        Quickshell.execDetached(["pactl", "set-source-port", root.defaultSource.name, portName])
        root.activeInputPort = portName
        portSettleTimer.restart()
    }

    onViewChanged: {
        if (root.view === 0) root.refreshOutputPorts()
        else if (root.view === 1) root.refreshInputPorts()
    }

    onOpenChanged: {
        if (root.open) {
            root.view = 0
            root.refreshOutputPorts()
            root.refreshInputPorts()
        }
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 16
        color: Theme.bg
        border.color: root.open ? Theme.accentLit : Theme.outline
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: root.open ? 350 : 150; easing.type: Easing.OutQuad } }

        opacity: root.open ? 1 : 0
        x: root.open ? 0 : (root.barEdge === "left" ? -28 : (root.barEdge === "right" ? 28 : 0))
        y: root.open ? 0 : (root.barEdge === "top" ? -28 : (root.barEdge === "bottom" ? 28 : 0))
        scale: root.open ? 1.0 : 0.90
        transformOrigin: root.barEdge === "left" ? Item.BottomLeft :
                         (root.barEdge === "right" ? Item.BottomRight :
                         (root.barEdge === "bottom" ? Item.BottomRight : Item.TopRight))

        Behavior on opacity {
            NumberAnimation { duration: root.open ? 200 : 140; easing.type: root.open ? Easing.OutCubic : Easing.InQuad }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            /* ============ Header: speaker + mic ============ */
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    id: soundTab
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    property bool active: root.view === 0

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: parent.active ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -3
                        text: "\uf028"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: parent.active ? "#0e0e12" : Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.view = 0
                    }
                }

                Item {
                    id: micTab
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    property bool active: root.view === 1

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: parent.active ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf130"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: parent.active ? "#0e0e12" : Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.view = 1
                    }
                }

                Item { Layout.fillWidth: true }

                IconButton {
                    id: closeBtn
                    glyph: "\uf00d"
                    tip: "Close"
                    size: 14
                    color: Theme.fgDim
                    hoverColor: Theme.fg
                    pointer: true
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            /* ============ Category 1: the mixer ============ */
            ColumnLayout {
                id: mixerPane
                visible: root.view === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        id: masterMute
                        glyph: root.defaultSink && root.defaultSink.audio.muted ? "\uf026" : "\uf028"
                        tip: "Mute system sound"
                        size: 14
                        color: Theme.fg
                        pointer: true
                        onClicked: {
                            if (root.defaultSink)
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.pwReady) return "Connecting to Pipewire…"
                                if (!root.defaultSink) return "No output device"
                                return root.nodeName(root.defaultSink)
                            }
                            font.family: "Valley Sans"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        VolSlider {
                            Layout.fillWidth: true
                            interactive: root.pwReady && !!root.defaultSink
                            value: root.defaultSink ? root.defaultSink.audio.volume : 0
                            fill: Theme.accent
                            track: Theme.fgFaint
                            knob: Theme.fg
                            onChanged: (v) => {
                                if (root.defaultSink) root.defaultSink.audio.volume = v
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: mixerContentCol.height
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: parent
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const dy = event.angleDelta.y
                            parent.contentY = Math.max(0, Math.min(parent.contentHeight - parent.height, parent.contentY - dy))
                        }
                    }

                    Column {
                        id: mixerContentCol
                        width: parent.width
                        spacing: 6

                        /* Output Ports (Speakers / Headphones routes) */
                        Text {
                            visible: root.outputPorts.length > 0
                            width: parent.width
                            text: "Outputs"
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Column {
                            width: parent.width
                            visible: root.outputPorts.length > 0
                            spacing: 4

                            Repeater {
                                model: root.outputPorts
                                delegate: Rectangle {
                                    id: portCard
                                    required property var modelData
                                    readonly property bool isActive: root.activeOutputPort === modelData.name
                                    width: mixerContentCol.width
                                    height: 30
                                    radius: 8
                                    color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (portMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.accent : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 7
                                            color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                            border.width: 1.5
                                            border.color: isActive ? Theme.accent : Theme.fgFaint

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: Theme.accent
                                                visible: isActive
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: /headphone|headset/i.test(modelData.desc || modelData.name) ? "\uf025" : "\uf028"
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            color: isActive ? Theme.accent : Theme.fgDim
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            text: modelData.desc
                                            font.family: "Valley Sans"
                                            font.pixelSize: 11
                                            font.weight: isActive ? Font.DemiBold : Font.Normal
                                            color: isActive ? Theme.fg : Theme.fgDim
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: isActive
                                            text: "\uf00c"
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: portMouse
                                        anchors.fill: parent
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectOutputPort(modelData.name)
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Output Devices (Sinks: Built-in, Bluetooth, USB, HDMI) */
                        Text {
                            visible: root.sinks.length > 1
                            width: parent.width
                            text: "Devices"
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Column {
                            width: parent.width
                            visible: root.sinks.length > 1
                            spacing: 4

                            Repeater {
                                model: root.sinks
                                delegate: Rectangle {
                                    id: sinkCard
                                    required property var modelData
                                    readonly property var node: modelData
                                    readonly property bool isCurDefault: root.defaultSink && root.defaultSink.id === node.id
                                    width: mixerContentCol.width
                                    height: 30
                                    radius: 8
                                    color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (sinkMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isCurDefault ? Theme.accent : (sinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 7
                                            color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                            border.width: 1.5
                                            border.color: isCurDefault ? Theme.accent : Theme.fgFaint

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: Theme.accent
                                                visible: isCurDefault
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: {
                                                const nm = (node.name || "") + (node.description || "")
                                                if (/bluez|bluetooth/i.test(nm)) return "\uf293"
                                                if (/hdmi/i.test(nm)) return "\uf008"
                                                if (/headphone|headset/i.test(nm)) return "\uf025"
                                                return "\uf028"
                                            }
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            color: isCurDefault ? Theme.accent : Theme.fgDim
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            text: root.nodeName(node)
                                            font.family: "Valley Sans"
                                            font.pixelSize: 11
                                            font.weight: isCurDefault ? Font.DemiBold : Font.Normal
                                            color: isCurDefault ? Theme.fg : Theme.fgDim
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: isCurDefault
                                            text: "\uf00c"
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: sinkMouse
                                        anchors.fill: parent
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSink = node
                                            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                        }
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Applications Section */
                        Text {
                            width: parent.width
                            text: "Applications"
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Repeater {
                            model: root.streams
                            delegate: RowLayout {
                                required property var modelData
                                readonly property var node: modelData.source
                                width: mixerContentCol.width
                                spacing: 8

                                PwObjectTracker { objects: [node] }

                                IconButton {
                                    id: sMute
                                    glyph: node.audio.muted ? "\uf026" : "\uf027"
                                    tip: "Mute app"
                                    size: 12
                                    color: Theme.fg
                                    pointer: true
                                    onClicked: node.audio.muted = !node.audio.muted
                                    onWheel: (w) => { w.accepted = false }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    text: root.nodeName(node)
                                    font.family: "Valley Sans"
                                    font.pixelSize: 11
                                    color: node.muted ? Theme.fgFaint : Theme.fg
                                    elide: Text.ElideRight
                                }

                                VolSlider {
                                    Layout.preferredWidth: 78
                                    value: node.audio.volume
                                    fill: Theme.accent
                                    track: Theme.fgFaint
                                    knob: Theme.fg
                                    onChanged: (v) => node.audio.volume = v
                                }
                            }
                        }

                        Text {
                            visible: root.streams.length === 0
                            width: parent.width
                            text: "No applications playing right now"
                            font.family: "Valley Sans"
                            font.pixelSize: 11
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 6
                        }
                    }
                }
            }

            /* ============ Category 2: mic / input ============ */
            ColumnLayout {
                id: micPane
                visible: root.view === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        id: srcMute
                        glyph: root.defaultSource && root.defaultSource.audio.muted ? "\uf131" : "\uf130"
                        tip: "Mute microphone"
                        size: 14
                        color: Theme.fg
                        pointer: true
                        onClicked: {
                            if (root.defaultSource)
                                root.defaultSource.audio.muted = !root.defaultSource.audio.muted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.pwReady) return "Connecting to Pipewire…"
                                if (!root.defaultSource) return "No input device"
                                return root.nodeName(root.defaultSource)
                            }
                            font.family: "Valley Sans"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        VolSlider {
                            Layout.fillWidth: true
                            interactive: root.pwReady && !!root.defaultSource
                            value: root.defaultSource ? root.defaultSource.audio.volume : 0
                            fill: Theme.accent
                            track: Theme.fgFaint
                            knob: Theme.fg
                            onChanged: (v) => {
                                if (root.defaultSource) root.defaultSource.audio.volume = v
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: sourcesCol.height
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        target: parent
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const dy = event.angleDelta.y
                            parent.contentY = Math.max(0, Math.min(parent.contentHeight - parent.height, parent.contentY - dy))
                        }
                    }

                    Column {
                        id: sourcesCol
                        width: parent.width
                        spacing: 6

                        /* Inputs / Routes */
                        Text {
                            visible: root.inputPorts.length > 0
                            width: parent.width
                            text: "Inputs"
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Column {
                            width: parent.width
                            visible: root.inputPorts.length > 0
                            spacing: 4

                            Repeater {
                                model: root.inputPorts
                                delegate: Rectangle {
                                    id: inPortCard
                                    required property var modelData
                                    readonly property bool isActive: root.activeInputPort === modelData.name
                                    width: sourcesCol.width
                                    height: 30
                                    radius: 8
                                    color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (inPortMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.accent : (inPortMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 7
                                            color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                            border.width: 1.5
                                            border.color: isActive ? Theme.accent : Theme.fgFaint

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: Theme.accent
                                                visible: isActive
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: /headset|headphone/i.test(modelData.desc || modelData.name) ? "\uf025" : "\uf130"
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            color: isActive ? Theme.accent : Theme.fgDim
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            text: modelData.desc
                                            font.family: "Valley Sans"
                                            font.pixelSize: 11
                                            font.weight: isActive ? Font.DemiBold : Font.Normal
                                            color: isActive ? Theme.fg : Theme.fgDim
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: isActive
                                            text: "\uf00c"
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: inPortMouse
                                        anchors.fill: parent
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectInputPort(modelData.name)
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        /* Input Devices */
                        Text {
                            width: parent.width
                            text: "Devices"
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }

                        Column {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.sources
                                delegate: Rectangle {
                                    id: srcCard
                                    required property var modelData
                                    readonly property var node: modelData
                                    readonly property bool isCurDefault: root.defaultSource === node
                                    width: sourcesCol.width
                                    height: 30
                                    radius: 8
                                    color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (srcMouse.containsMouse ? Theme.bgHover : "transparent")
                                    border.width: 1
                                    border.color: isCurDefault ? Theme.accent : (srcMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 7
                                            color: isCurDefault ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                            border.width: 1.5
                                            border.color: isCurDefault ? Theme.accent : Theme.fgFaint

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: Theme.accent
                                                visible: isCurDefault
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: {
                                                const nm = (node.name || "") + (node.description || "")
                                                if (/bluez|bluetooth/i.test(nm)) return "\uf293"
                                                if (/headset|headphone/i.test(nm)) return "\uf025"
                                                return "\uf130"
                                            }
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            color: isCurDefault ? Theme.accent : Theme.fgDim
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            text: root.nodeName(node)
                                            font.family: "Valley Sans"
                                            font.pixelSize: 11
                                            font.weight: isCurDefault ? Font.DemiBold : Font.Normal
                                            color: isCurDefault ? Theme.fg : Theme.fgDim
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: isCurDefault
                                            text: "\uf00c"
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            color: Theme.accent
                                        }
                                    }

                                    MouseArea {
                                        id: srcMouse
                                        anchors.fill: parent
                                        z: 5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSource = node
                                            Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
                                        }
                                        onWheel: (wheel) => { wheel.accepted = false }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.sources.length === 0
                            width: parent.width
                            text: "No input devices found"
                            font.family: "Valley Sans"
                            font.pixelSize: 11
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 6
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            /* ============ Footer: open the full sound settings ============ */
            IconButton {
                Layout.alignment: Qt.AlignLeft
                glyph: "\uf013"
                tip: "Open full sound settings"
                size: 14
                color: Theme.fgDim
                hoverColor: Theme.fg
                pointer: true
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "command -v pavucontrol >/dev/null && pavucontrol || pwvucontrol"])
                    root.closeRequested()
                }
            }
        }
    }

    /* Hover tracking for the popup. HoverHandler never claims press events,
     * so every button/slider below still receives clicks and drags. */
    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.anyHover = hover.hovered
        }
    }
}