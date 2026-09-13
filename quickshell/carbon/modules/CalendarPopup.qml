import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../Singletons"

/**
 * CalendarPopup: Ultra-compact, sleek month calendar card appearing directly below the dynamic island.
 * Scaled down to a small, refined footprint as requested.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 216
    implicitHeight: 206
    width: 216
    height: 206

    readonly property var now: new Date()
    property int year: now.getFullYear()
    property int month: now.getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["M", "T", "W", "T", "F", "S", "S"]

    ListModel { id: days }

    Component.onCompleted: rebuild()

    function rebuild() {
        days.clear()
        const first = new Date(root.year, root.month, 1)
        const startDay = (first.getDay() + 6) % 7
        const dim = new Date(root.year, root.month + 1, 0).getDate()
        const prevDim = new Date(root.year, root.month, 0).getDate()
        const t = new Date()
        for (let i = 0; i < 42; i++) {
            let d
            let m = root.month
            let yy = root.year
            let same = true
            if (i < startDay) {
                d = prevDim - startDay + i + 1
                m = m - 1
                same = false
            } else if (i >= startDay + dim) {
                d = i - startDay - dim + 1
                m = m + 1
                same = false
            } else {
                d = i - startDay + 1
            }
            if (m < 0) { m = 11; yy-- }
            if (m > 11) { m = 0; yy++ }
            const today = same && d === t.getDate() && m === t.getMonth() && yy === t.getFullYear()
            days.append({ day: d, same: same, today: today })
        }
    }

    function prev() {
        if (root.month === 0) { root.month = 11; root.year-- } else { root.month-- }
    }
    function next() {
        if (root.month === 11) { root.month = 0; root.year++ } else { root.month++ }
    }

    onMonthChanged: root.rebuild()
    onYearChanged: root.rebuild()

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 14
        color: Qt.rgba(0.08, 0.09, 0.12, 0.90)
        border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        /* VisionOS Specular Rim highlight */
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: card.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.open ? 0.20 : 0.06)
            z: 99
        }

        opacity: root.open ? 1 : 0
        x: root.open ? 0 : (root.barEdge === "left" ? -28 : (root.barEdge === "right" ? 28 : 0))
        y: root.open ? 0 : (root.barEdge === "top" ? -20 : (root.barEdge === "bottom" ? 20 : 0))
        scale: root.open ? 1.0 : 0.88
        transformOrigin: root.barEdge === "left" ? Item.BottomLeft :
                         (root.barEdge === "right" ? Item.BottomRight :
                         (root.barEdge === "bottom" ? Item.BottomRight : Item.TopRight))

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on opacity {
            NumberAnimation { duration: root.open ? 220 : 140; easing.type: Easing.OutCubic }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.open ? 320 : 160
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.35
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 320 : 160
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.35
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 300 : 150
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.38
            }
        }

        /* Ambient inner border glow */
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            opacity: root.open ? 1.0 : 0.0
            y: root.open ? 0 : 8
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            /* ── Month & Navigation Header ── */
            Row {
                width: parent.width
                height: 22

                /* Prev button */
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: prevHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "\u2039"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: prevHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prev()
                    }
                }

                /* Month & Year Title */
                Text {
                    width: parent.width - 40
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.monthNames[root.month] + " " + root.year
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.fg
                }

                /* Next button */
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: nextHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "\u203a"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: nextHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.next()
                    }
                }
            }

            /* ── Weekday Labels ── */
            Row {
                width: parent.width
                height: 14

                Repeater {
                    model: root.weekdayNames
                    Text {
                        width: parent.width / 7
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                    }
                }
            }

            /* ── Days Grid ── */
            Grid {
                id: daysGrid
                width: parent.width
                columns: 7
                rowSpacing: 1
                columnSpacing: 0

                Repeater {
                    model: days
                    Item {
                        width: daysGrid.width / 7
                        height: 22

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: model.today ? Theme.accent : (dayHov.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: String(model.day)
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.bold: model.today || model.same
                                color: model.today ? "#000000" : (model.same ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25))
                            }
                        }

                        MouseArea {
                            id: dayHov
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.anyHover = hover.hovered
        }
    }
}
