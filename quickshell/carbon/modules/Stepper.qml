import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Compact minutes stepper for the pomodoro configuration row:
 *   LABEL
 *   [−] 25m [+]
 * Scaled down to fit comfortably in compact 264px QuickSettings panel.
 */
Item {
    id: root
    signal changed(int delta)

    required property string label
    required property int minutes
    required property bool disabled

    implicitWidth: 76
    implicitHeight: 38

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.label
            font.family: Theme.font
            font.pixelSize: 8
            font.letterSpacing: 1
            color: root.disabled ? Theme.fgFaint : Theme.fgDim
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: decHov.hovered && !root.disabled ? Theme.bgHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "\u2212"
                    font.family: "Valley Sans"
                    font.pixelSize: 13
                    color: root.disabled ? Theme.fgFaint : Theme.fgDim
                }
                MouseArea {
                    id: decHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.disabled
                    onClicked: root.changed(-1)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: root.minutes + "m"
                font.family: "Valley Sans"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: root.disabled ? Theme.fgFaint : Theme.fg
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: incHov.hovered && !root.disabled ? Theme.bgHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "\u002b"
                    font.family: "Valley Sans"
                    font.pixelSize: 13
                    color: root.disabled ? Theme.fgFaint : Theme.fgDim
                }
                MouseArea {
                    id: incHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.disabled
                    onClicked: root.changed(1)
                }
            }
        }
    }
}