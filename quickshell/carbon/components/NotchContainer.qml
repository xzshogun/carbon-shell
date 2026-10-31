import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Top-Attached Notch Container matching SaneAspect / Tide Island exact geometry:
 * - Native Rectangle body with clipped top corners and smooth convex bottom corners
 * - Native PathArc ear fillets curving outward seamlessly into the screen edge
 * - No fuzzy SVG approximations, no stroke outlines
 */
Item {
    id: root

    property bool leftFillet: true
    property bool rightFillet: true
    property real filletRadius: Math.round(10 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real bottomRadius: Math.round(14 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real contentSpacing: Math.round(7 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real horizontalPadding: Math.round(12 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    property real earWidth: 0

    default property alias content: contentRow.data
    readonly property real contentImplicitWidth: contentRow.implicitWidth

    implicitHeight: Math.round(34 * (Theme && Theme.shellScale !== undefined ? Theme.shellScale : 1.0))
    implicitWidth: Math.max(70, contentRow.implicitWidth 
                   + (leftFillet ? filletRadius : 0) 
                   + (rightFillet ? filletRadius : 0) 
                   + (horizontalPadding * 2))
    width: implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    height: implicitHeight
    Behavior on height {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property bool attachedBottom: false
    property bool hasAttachedPopup: false
    property real notchOpacity: 0.96

    property var notchRoot: root
    readonly property color defaultBorderColor: Qt.rgba(1, 1, 1, 0.15)
    property color borderColor: defaultBorderColor
    property bool isUploading: false

    readonly property string dropEngineBin: {
        var envPath = Quickshell.env("CARBON_DROP_ENGINE")
        if (envPath && envPath.length > 0) return envPath
        var home = Quickshell.env("HOME") || ""
        if (home.length > 0) {
            return home + "/.local/bin/carbon-drop-engine"
        }
        return "carbon-drop-engine"
    }

    // SaneAspect deep dark OLED notch surface
    readonly property color notchBgColor: Theme.isDark 
        ? Qt.rgba(0.04, 0.04, 0.06, root.notchOpacity) 
        : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)

    // 1. Central Body: Clipped to hide top rounded corners, showing bottom convex corners
    Item {
        id: bodyClip
        clip: true
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (root.leftFillet && root.filletRadius > 0) ? root.filletRadius : 0
        anchors.rightMargin: (root.rightFillet && root.filletRadius > 0) ? root.filletRadius : 0

        Rectangle {
            id: notchBackground
            anchors.left: parent.left
            anchors.leftMargin: (!root.leftFillet && root.rightFillet) ? -root.bottomRadius : 0
            anchors.right: parent.right
            anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? -root.bottomRadius : 0
            y: root.attachedBottom ? 0 : -root.bottomRadius
            height: parent.height + root.bottomRadius
            radius: root.bottomRadius
            color: root.notchBgColor
            border.width: 1
            border.color: root.borderColor

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    // 2. Left Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: leftEar
        visible: root.leftFillet && root.filletRadius > 0
        x: 0
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? leftEar.height : 0
            PathLine { x: leftEar.width; y: root.attachedBottom ? leftEar.height : 0 }
            PathLine { x: leftEar.width; y: root.attachedBottom ? 0 : leftEar.height }
            PathArc {
                x: 0
                y: root.attachedBottom ? leftEar.height : 0
                radiusX: leftEar.width
                radiusY: leftEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    // 3. Right Ear Fillet (SaneAspect exact PathArc geometry)
    Shape {
        id: rightEar
        visible: root.rightFillet && root.filletRadius > 0
        x: root.width - root.filletRadius
        y: root.attachedBottom ? (root.height - root.filletRadius) : 0
        width: root.filletRadius
        height: root.filletRadius
        preferredRendererType: Shape.GeometryRenderer
        antialiasing: true
        asynchronous: false

        ShapePath {
            fillColor: root.notchBgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.attachedBottom ? 0 : rightEar.height
            PathLine { x: 0; y: root.attachedBottom ? rightEar.height : 0 }
            PathLine { x: rightEar.width; y: root.attachedBottom ? rightEar.height : 0 }
            PathArc {
                x: 0
                y: root.attachedBottom ? 0 : rightEar.height
                radiusX: rightEar.width
                radiusY: rightEar.height
                direction: root.attachedBottom ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }

    property bool isPlaying: false
    property string trackTitle: ""
    property alias mouseArea: notchMouseArea

    MouseArea {
        id: notchMouseArea
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        z: 0
    }

    Row {
        id: contentRow
        z: 1
        height: root.hasAttachedPopup ? root.implicitHeight : root.height
        anchors.verticalCenter: root.hasAttachedPopup ? undefined : parent.verticalCenter
        anchors.top: root.hasAttachedPopup && !root.attachedBottom ? parent.top : undefined
        anchors.bottom: root.hasAttachedPopup && root.attachedBottom ? parent.bottom : undefined
        anchors.left: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : parent.left)
        anchors.leftMargin: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : ((root.leftFillet ? root.filletRadius : 0) + root.horizontalPadding))
        anchors.right: (!root.rightFillet && root.leftFillet) ? parent.right : undefined
        anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? root.horizontalPadding : undefined
        anchors.horizontalCenter: (root.leftFillet && root.rightFillet) ? parent.horizontalCenter : undefined
        spacing: root.contentSpacing
    }

    DropArea {
        id: notchDropArea
        anchors.fill: parent
        z: 5
        keys: ["text/uri-list"] // Explicitly listen for file URIs

        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.accept(Qt.CopyAction); // Wayland requires this to allow the drop
                notchBackground.border.color = "#8ee8a8"
                notchBackground.border.width = 2
                notchRoot.height = 48
            }
        }

        onExited: {
            notchBackground.border.color = "rgba(255,255,255,0.15)"
            notchBackground.border.width = 1
            notchRoot.height = 28
        }

        onDropped: (drop) => {
            if (!drop.hasUrls) return;
            drop.acceptProposedAction(); // Confirm the drop

            notchBackground.border.color = "#f5b86e" // Amber processing state

            let engineCmd = [
                root.dropEngineBin || "/home/shogun/carbon-shell/apps/carbon-drop/target/release/carbon-drop-engine",
                "Buzzheavier (10GB+)",
                drop.urls[0]
            ];

            let uploadProcess = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { id: proc; property alias outputText: collector.text; readonly property var stdout: ({ trim: function() { return proc.outputText.trim(); }, toString: function() { return proc.outputText; } }); stdout: StdioCollector { id: collector; waitForEnd: true } }', root);
            uploadProcess.command = engineCmd;

            uploadProcess.exited.connect(function() {
                let url = uploadProcess.stdout.trim();
                try {
                    let lines = url.split("\n");
                    for (let i = lines.length - 1; i >= 0; i--) {
                        let l = lines[i].trim();
                        if (!l) continue;
                        try {
                            let msg = JSON.parse(l);
                            if (msg && msg.url) { url = msg.url; break; }
                        } catch(e) {}
                        if (l.startsWith("http://") || l.startsWith("https://")) {
                            url = l;
                            break;
                        }
                    }
                } catch(e) {}

                let clipProcess = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process {}', root);
                clipProcess.command = ["wl-copy", url];
                clipProcess.running = true;

                notchBackground.border.color = "rgba(255,255,255,0.15)"
                notchBackground.border.width = 1
                notchRoot.height = 28
                uploadProcess.destroy();
            });
            uploadProcess.running = true;
        }
    }
}
