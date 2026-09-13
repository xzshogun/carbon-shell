import QtQuick
import QtQuick.Shapes
import "../Singletons"

/**
 * Top-Attached Notch Container with Nebula-Style Concave Top Fillets
 * and Smoothly Curved Convex Bottom Corners.
 */
Item {
    id: root

    property bool leftFillet: true
    property bool rightFillet: true
    property real filletRadius: 12
    property real bottomRadius: 12
    property real contentSpacing: 7
    property real horizontalPadding: 10
    property real earWidth: 0

    default property alias content: contentRow.data
    readonly property real contentImplicitWidth: contentRow.implicitWidth

    implicitHeight: 34
    implicitWidth: Math.max(80, contentRow.implicitWidth 
                   + (leftFillet ? filletRadius : 0) 
                   + (rightFillet ? filletRadius : 0) 
                   + (horizontalPadding * 2))
    width: implicitWidth
    height: implicitHeight

    property bool attachedBottom: false

    readonly property string fillPath: {
        const rTopLeft = root.leftFillet ? root.filletRadius : 0
        const rTopRight = root.rightFillet ? root.filletRadius : 0
        const rBotLeft = root.bottomRadius
        const rBotRight = root.bottomRadius
        const minW = rTopLeft + rBotLeft + rBotRight + rTopRight + 4
        const w = Math.max(root.width, minW)
        const h = root.height

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            let curX = 0
            if (rTopLeft > 0) {
                p += `A ${rTopLeft} ${rTopLeft} 0 0 0 ${rTopLeft} ${h - rTopLeft} `
                curX = rTopLeft
            }
            p += `L ${curX} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${curX + rBotLeft} 0 `

            const rightWallX = w - rTopRight
            p += `L ${rightWallX - rBotRight} 0 `
            p += `A ${rBotRight} ${rBotRight} 0 0 1 ${rightWallX} ${rBotRight} `

            if (rTopRight > 0) {
                p += `L ${rightWallX} ${h - rTopRight} `
                p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h} `
            } else {
                p += `L ${w} ${h} `
            }

            p += `L 0 ${h} Z`
            return p
        }

        let p = "M 0 0 "
        let curX = 0
        if (rTopLeft > 0) {
            p += `A ${rTopLeft} ${rTopLeft} 0 0 1 ${rTopLeft} ${rTopLeft} `
            curX = rTopLeft
        }
        p += `L ${curX} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${curX + rBotLeft} ${h} `

        const rightWallX = w - rTopRight
        p += `L ${rightWallX - rBotRight} ${h} `
        p += `A ${rBotRight} ${rBotRight} 0 0 0 ${rightWallX} ${h - rBotRight} `

        if (rTopRight > 0) {
            p += `L ${rightWallX} ${rTopRight} `
            p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0 `
        } else {
            p += `L ${w} 0 `
        }

        p += `L 0 0 Z`
        return p
    }

    readonly property string strokePath: {
        const rTopLeft = root.leftFillet ? root.filletRadius : 0
        const rTopRight = root.rightFillet ? root.filletRadius : 0
        const rBotLeft = root.bottomRadius
        const rBotRight = root.bottomRadius
        const minW = rTopLeft + rBotLeft + rBotRight + rTopRight + 4
        const w = Math.max(root.width, minW)
        const h = root.height

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            let curX = 0
            if (rTopLeft > 0) {
                p += `A ${rTopLeft} ${rTopLeft} 0 0 0 ${rTopLeft} ${h - rTopLeft} `
                curX = rTopLeft
            }
            p += `L ${curX} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${curX + rBotLeft} 0 `

            const rightWallX = w - rTopRight
            p += `L ${rightWallX - rBotRight} 0 `
            p += `A ${rBotRight} ${rBotRight} 0 0 1 ${rightWallX} ${rBotRight} `

            if (rTopRight > 0) {
                p += `L ${rightWallX} ${h - rTopRight} `
                p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h}`
            } else {
                p += `L ${w} ${h}`
            }
            return p
        }

        let p = "M 0 0 "
        let curX = 0
        if (rTopLeft > 0) {
            p += `A ${rTopLeft} ${rTopLeft} 0 0 1 ${rTopLeft} ${rTopLeft} `
            curX = rTopLeft
        }
        p += `L ${curX} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${curX + rBotLeft} ${h} `

        const rightWallX = w - rTopRight
        p += `L ${rightWallX - rBotRight} ${h} `
        p += `A ${rBotRight} ${rBotRight} 0 0 0 ${rightWallX} ${h - rBotRight} `

        if (rTopRight > 0) {
            p += `L ${rightWallX} ${rTopRight} `
            p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0`
        } else {
            p += `L ${w} 0`
        }
        return p
    }

    Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: true
        layer.smooth: true

        // Filled background body with VisionOS frosted glass depth
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: root.attachedBottom ? root.height : 0
                x2: 0; y2: root.attachedBottom ? 0 : root.height
                GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.60) }
                GradientStop { position: 0.45; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r * 0.75, Theme.bg.g * 0.75, Theme.bg.b * 0.75, 0.82) }
            }

            PathSvg {
                path: root.fillPath
            }
        }

        // VisionOS Specular Rim (Crisp, light-catching frosted glass bevel)
        ShapePath {
            strokeWidth: 1.5
            strokeColor: Qt.rgba(1.0, 1.0, 1.0, 0.45)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }

        // Accent refraction rim
        ShapePath {
            strokeWidth: 1.0
            strokeColor: Qt.alpha(Theme.accent, 0.40)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }
    }

    property bool isPlaying: false
    property string trackTitle: ""
    property real musicPulseVal: 0.90

    SequentialAnimation {
        running: root.isPlaying
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "musicPulseVal"; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "musicPulseVal"; to: 0.40; duration: 1400; easing.type: Easing.InOutSine }
    }

    // Track change accent shimmer sweep
    Rectangle {
        id: trackShimmer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 70
        x: -90
        z: 3
        opacity: 0.0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.accent, 0.45) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    SequentialAnimation {
        id: trackSweepAnim
        ParallelAnimation {
            NumberAnimation { target: trackShimmer; property: "opacity"; from: 0.0; to: 0.8; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: trackShimmer; property: "x"; from: -90; to: root.width + 40; duration: 420; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: trackShimmer; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.OutQuad }
    }

    onTrackTitleChanged: {
        if (trackTitle.length > 0 && root.isPlaying) {
            trackSweepAnim.restart()
        }
    }

    // VisionOS specular glass glow line along bottom rim
    Rectangle {
        anchors.bottom: root.attachedBottom ? undefined : parent.bottom
        anchors.top: root.attachedBottom ? parent.top : undefined
        anchors.bottomMargin: root.attachedBottom ? 0 : 1
        anchors.topMargin: root.attachedBottom ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(10, root.width - (root.filletRadius * 2 + root.bottomRadius * 2 + 10))
        height: 1.6
        radius: 0.8
        z: 2
        opacity: root.isPlaying ? root.musicPulseVal : 0.90
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.15; color: Qt.alpha(Theme.accent, 0.6) }
            GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.95) }
            GradientStop { position: 0.85; color: Qt.alpha(Theme.accent, 0.6) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

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
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: (root.leftFillet ? root.filletRadius : 0) + root.horizontalPadding
        spacing: root.contentSpacing
    }
}

