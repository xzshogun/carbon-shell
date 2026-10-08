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

    Behavior on width {
        NumberAnimation {
            duration: 320
            easing.bezierCurve: Theme.animCurves.expressiveDefaultSpatial
        }
    }
    height: implicitHeight
    Behavior on height {
        NumberAnimation {
            duration: 320
            easing.bezierCurve: Theme.animCurves.expressiveDefaultSpatial
        }
    }

    property bool attachedBottom: false
    property bool hasAttachedPopup: false

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
            if (root.hasAttachedPopup) {
                p += `L ${curX} 0 `
                p += `L ${rightWallX} 0 `
                if (rTopRight > 0) {
                    p += `L ${rightWallX} ${h - rTopRight} `
                    p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h} `
                } else {
                    p += `L ${w} ${h} `
                }
                p += `L 0 ${h} Z`
                return p
            }

            p += `L ${curX} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${curX + rBotLeft} 0 `

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

        const rightWallX = w - rTopRight
        if (root.hasAttachedPopup) {
            p += `L ${curX} ${h} `
            p += `L ${rightWallX} ${h} `
            if (rTopRight > 0) {
                p += `L ${rightWallX} ${rTopRight} `
                p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0 `
            } else {
                p += `L ${w} 0 `
            }
            p += `L 0 0 Z`
            return p
        }

        p += `L ${curX} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${curX + rBotLeft} ${h} `

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

            const rightWallX = w - rTopRight
            if (root.hasAttachedPopup) {
                p += `L ${curX} 0 `
                if (rTopRight > 0) {
                    p += `M ${rightWallX} 0 `
                    p += `L ${rightWallX} ${h - rTopRight} `
                    p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h}`
                } else {
                    p += `M ${w} 0 L ${w} ${h}`
                }
                return p
            }

            p += `L ${curX} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${curX + rBotLeft} 0 `

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

        const rightWallX = w - rTopRight
        if (root.hasAttachedPopup) {
            // Leave bottom open to seamlessly merge with the attached popup card
            p += `L ${curX} ${h} `
            if (rTopRight > 0) {
                p += `M ${rightWallX} ${h} `
                p += `L ${rightWallX} ${rTopRight} `
                p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0`
            } else {
                p += `M ${w} ${h} L ${w} 0`
            }
            return p
        }

        p += `L ${curX} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${curX + rBotLeft} ${h} `

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

    property real notchOpacity: 0.90

    Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: true
        layer.smooth: true

        // Filled background body
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.notchOpacity)

            PathSvg {
                path: root.fillPath
            }
        }

        // Clean border outline
        ShapePath {
            strokeWidth: 1.2
            strokeColor: Theme.isDark ? Qt.alpha(Theme.outline, 0.45) : Qt.rgba(0, 0, 0, 0.12)
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
        anchors.top: root.attachedBottom ? undefined : parent.top
        anchors.topMargin: root.attachedBottom ? undefined : Math.max(0, (Math.min(root.height, 34) - contentRow.height) / 2)
        anchors.bottom: root.attachedBottom ? parent.bottom : undefined
        anchors.bottomMargin: root.attachedBottom ? Math.max(0, (Math.min(root.height, 34) - contentRow.height) / 2) : undefined
        anchors.left: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : parent.left)
        anchors.leftMargin: (!root.rightFillet && root.leftFillet) ? undefined : ((root.leftFillet && root.rightFillet) ? undefined : ((root.leftFillet ? root.filletRadius : 0) + root.horizontalPadding))
        anchors.right: (!root.rightFillet && root.leftFillet) ? parent.right : undefined
        anchors.rightMargin: (!root.rightFillet && root.leftFillet) ? root.horizontalPadding : undefined
        anchors.horizontalCenter: (root.leftFillet && root.rightFillet) ? parent.horizontalCenter : undefined
        spacing: root.contentSpacing
    }
}

