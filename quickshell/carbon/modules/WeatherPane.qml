import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Singletons"

/**
 * WeatherPane: Weather configuration & live monitor pane for QuickSettings.
 * Allows user to paste an API key or custom weather API endpoint URL,
 * specify a custom city/location, and view live conditions.
 */
Item {
    id: root

    implicitWidth: 264
    implicitHeight: 296

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            anchors.right: flick.right
            anchors.rightMargin: 1
        }

        ColumnLayout {
            id: contentCol
            width: flick.width - 10
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 6

        /* ── Header: Live Status Card ────────────────────────────── */
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 10
            color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.45)
            border.color: WeatherService.isError ? Theme.err : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Weather Icon Box
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: WeatherService.icon || "partly_cloudy_day"
                        font.family: Theme.fontIcon
                        font.pixelSize: 26
                        color: Theme.accentLit
                    }
                }

                // Temp & Condition
                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Row {
                        spacing: 4
                        Text {
                            text: WeatherService.temp
                            font.family: "Open Sans"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: Theme.fg
                        }
                        Text {
                            text: WeatherService.condition
                            font.family: "Open Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: WeatherService.condition === "No API Key" ? Theme.warn : Theme.fgDim
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                        }
                    }

                    Text {
                        text: WeatherService.city.length > 0 ? WeatherService.city : (WeatherService.hasKey ? "Auto-detected Location" : "Key required")
                        font.family: "Open Sans"
                        font.pixelSize: 10
                        color: Theme.fgDim
                        elide: Text.ElideRight
                        width: 130
                    }

                    Row {
                        spacing: 8
                        visible: WeatherService.hasKey
                        Row {
                            spacing: 2
                            Text {
                                text: "air"
                                font.family: Theme.fontIcon
                                font.pixelSize: 11
                                color: Theme.fgFaint
                            }
                            Text {
                                text: WeatherService.wind
                                font.family: Theme.font
                                font.pixelSize: 9
                                color: Theme.fgFaint
                            }
                        }
                        Row {
                            spacing: 2
                            Text {
                                text: "water_drop"
                                font.family: Theme.fontIcon
                                font.pixelSize: 11
                                color: Theme.fgFaint
                            }
                            Text {
                                text: WeatherService.humidity
                                font.family: Theme.font
                                font.pixelSize: 9
                                color: Theme.fgFaint
                            }
                        }
                    }
                }
            }
        }

        /* ── API Provider Info / Helper Banner ─────────────────────── */
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 6
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "key"
                    font.family: Theme.fontIcon
                    font.pixelSize: 13
                    color: Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: "Free key: weatherapi.com or openweathermap.org"
                    font.family: "Open Sans"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Theme.accent
                    elide: Text.ElideRight
                }
            }
        }

        /* ── Input 1: API Key or Custom Endpoint URL ──────────────── */
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "WEATHER API KEY / URL"
                    font.family: "Open Sans"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: WeatherService.provider
                    font.family: "Open Sans"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 6
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5)
                border.color: keyInput.activeFocus ? Theme.accent : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 4

                    TextInput {
                        id: keyInput
                        Layout.fillWidth: true
                        text: WeatherService.configApiKey.length > 0 ? WeatherService.configApiKey : WeatherService.configApiUrl
                        font.family: "Open Sans"
                        font.pixelSize: 11
                        color: Theme.fg
                        selectByMouse: true
                        selectionColor: Theme.accent
                        clip: true

                        Text {
                            visible: parent.text.length === 0 && !parent.activeFocus
                            text: "Paste WeatherAPI / OpenWeather key..."
                            font.family: "Open Sans"
                            font.pixelSize: 10
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Clear button
                    Rectangle {
                        visible: keyInput.text.length > 0
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 8
                        color: clearHov.containsMouse ? Theme.bgHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: Theme.fontIcon
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                        MouseArea {
                            id: clearHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: keyInput.text = ""
                        }
                    }
                }
            }
        }

        /* ── Input 2: City / Location (Optional) ──────────────────── */
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: "CITY / LOCATION (OPTIONAL)"
                font.family: "Open Sans"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.fgDim
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 6
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5)
                border.color: cityInput.activeFocus ? Theme.accent : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                border.width: 1

                TextInput {
                    id: cityInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    text: WeatherService.configCity
                    font.family: "Open Sans"
                    font.pixelSize: 11
                    color: Theme.fg
                    selectByMouse: true
                    selectionColor: Theme.accent
                    clip: true

                    Text {
                        visible: parent.text.length === 0 && !parent.activeFocus
                        text: "e.g. London, Tokyo (or leave blank for IP auto)"
                        font.family: "Open Sans"
                        font.pixelSize: 10
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        /* ── Status / Feedback line ──────────────────────────────── */
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: WeatherService.isError ? Theme.err : (WeatherService.isFetching ? Theme.warn : (WeatherService.hasKey ? Theme.ok : Theme.warn))
            }

            Text {
                Layout.fillWidth: true
                text: WeatherService.statusMessage
                font.family: "Open Sans"
                font.pixelSize: 9
                color: WeatherService.isError ? Theme.err : Theme.fgDim
                elide: Text.ElideRight
            }
        }

        /* ── Buttons Row: Save & Clear ────────────────────────────── */
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Clear Key button
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 28
                radius: 6
                color: resetHov.containsMouse ? Theme.bgHover : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Clear Key"
                    font.family: "Open Sans"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Theme.fgDim
                }
                MouseArea {
                    id: resetHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        keyInput.text = ""
                        cityInput.text = ""
                        WeatherService.saveAndFetch("", "", "")
                    }
                }
            }

            // Save & Update Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 6
                color: saveHov.containsMouse ? Theme.accentLit : Theme.accent
                scale: saveHov.pressed ? 0.96 : (saveHov.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: WeatherService.isFetching ? "hourglass_empty" : "check"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: Theme.isDark ? "#0e0e12" : "#ffffff"
                    }
                    Text {
                        text: WeatherService.isFetching ? "Connecting..." : "Save & Update"
                        font.family: "Open Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.isDark ? "#0e0e12" : "#ffffff"
                    }
                }

                MouseArea {
                    id: saveHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const val = keyInput.text.trim()
                        let newUrl = ""
                        let newKey = ""
                        if (val.startsWith("http://") || val.startsWith("https://")) {
                            newUrl = val
                        } else {
                            newKey = val
                        }
                        const newCity = cityInput.text.trim()
                        WeatherService.saveAndFetch(newUrl, newKey, newCity)
                    }
                }
            }
        }
    }
}
}
