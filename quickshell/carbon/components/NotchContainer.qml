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

        // Filled background body with VisionOS glass depth
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: root.attachedBottom ? root.height : 0
                x2: 0; y2: root.attachedBottom ? 0 : root.height
                GradientStop { position: 0.0; color: Qt.tint(Theme.bg, Qt.rgba(1.0, 1.0, 1.0, 0.07)) }
                GradientStop { position: 0.6; color: Theme.bg }
                GradientStop { position: 1.0; color: Qt.darker(Theme.bg, 1.15) }
            }

            PathSvg {
                path: root.fillPath
            }
        }

        // Ambient glass outline
        ShapePath {
            strokeWidth: 1.2
            strokeColor: Qt.alpha(Theme.outline, 0.45)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }

        // VisionOS Specular Highlight Catch (Crisp light catching the bottom curved edge)
        ShapePath {
            strokeWidth: 0.8
            strokeColor: Qt.alpha(Theme.fg, 0.32)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
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
        height: 1
        radius: 0.5
        z: 2
        opacity: 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: Qt.alpha(Theme.accent, 0.4) }
            GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.65) }
            GradientStop { position: 0.8; color: Qt.alpha(Theme.accent, 0.4) }
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

