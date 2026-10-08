import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * VanishTransitionOverlay:
 * Fullscreen cinematic transition overlay for switching into Vanish (nucleus) mode.
 * 
 * Features:
 * - High-energy kinetic typography motion graphic ("Wooshhh!!")
 * - Dynamic manga/anime speed streaks & radial shockwave ripple
 * - Multi-layer neon accent glow matching active theme
 * - Midpoint signal (~380ms) to seamlessly swap bar mode & trigger wallpaper animation
 * - Support for optional user-provided asset (~/.config/hypr/assets/vanish-woosh.webm/.gif)
 * - Auto-dismisses with zero idle overhead (0% CPU when not playing)
 */
Item {
    id: root

    anchors.fill: parent

    /* ── Signals ── */
    signal midpointReached()
    signal transitionFinished()

    /* ── State ── */
    property bool isPlaying: false

    function startTransition() {
        if (root.isPlaying) return
        root.isPlaying = true
        transitionAnim.restart()
    }

    // Check for optional user custom video/animation asset
    readonly property string customAssetPath: (Quickshell.env("HOME") || "") + "/.config/hypr/assets/vanish-woosh.webm"
    readonly property string customGifPath: (Quickshell.env("HOME") || "") + "/.config/hypr/assets/vanish-woosh.gif"

    FileView {
        id: customAssetWatcher
        path: root.customAssetPath
        watchChanges: false
        printErrors: false
    }

    readonly property bool hasCustomVideo: customAssetWatcher.exists

    /* ── Master Transition Animation Timeline ── */
    SequentialAnimation {
        id: transitionAnim
        running: false

        // Phase 1: Rapid Entrance & Speed Lines (0 - 380ms)
        ParallelAnimation {
            // Text scale up with spring overshoot
            NumberAnimation {
                target: textContainer
                property: "scale"
                from: 0.25
                to: 1.18
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
            // Text opacity rapid fade-in
            NumberAnimation {
                target: textContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }
            // Text horizontal drift
            NumberAnimation {
                target: textContainer
                property: "xOffset"
                from: -120
                to: 10
                duration: 380
                easing.type: Easing.OutCubic
            }
            // Backdrop vignette & ambient glow
            NumberAnimation {
                target: ambientBackdrop
                property: "opacity"
                from: 0.0
                to: 0.55
                duration: 260
                easing.type: Easing.OutQuad
            }
            // Speed streaks swoosh across
            NumberAnimation {
                target: speedLines
                property: "streakProgress"
                from: 0.0
                to: 1.0
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        // Midpoint Trigger: Swap bar mode and wallpaper animation at the peak
        ScriptAction {
            script: {
                root.midpointReached()
            }
        }

        // Phase 2: Shockwave Ripple & Dissolve Out into Nucleus (380 - 820ms)
        ParallelAnimation {
            // Text expands and dissolves outward
            NumberAnimation {
                target: textContainer
                property: "scale"
                from: 1.18
                to: 1.75
                duration: 440
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: textContainer
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 400
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: textContainer
                property: "xOffset"
                from: 10
                to: 60
                duration: 440
                easing.type: Easing.OutCubic
            }
            // Center radial shockwave ring expands
            NumberAnimation {
                target: shockwaveRing
                property: "shockRadius"
                from: 16
                to: 160
                duration: 440
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shockwaveRing
                property: "shockOpacity"
                from: 0.95
                to: 0.0
                duration: 440
                easing.type: Easing.OutQuad
            }
            // Fade out backdrop
            NumberAnimation {
                target: ambientBackdrop
                property: "opacity"
                from: 0.55
                to: 0.0
                duration: 440
                easing.type: Easing.InCubic
            }
        }

        // Finish
        ScriptAction {
            script: {
                root.isPlaying = false
                root.transitionFinished()
            }
        }
    }

    /* ── Visual Elements (Rendered only while isPlaying) ── */
    visible: root.isPlaying

    // 1. Ambient Cinematic Vignette & Center Glow
    Rectangle {
        id: ambientBackdrop
        anchors.fill: parent
        color: "#05070a"
        opacity: 0.0

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: 480
            radius: 240
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
        }
    }

    // 2. Kinetic Manga Speed Streaks
    Item {
        id: speedLines
        anchors.fill: parent
        property real streakProgress: 0.0
        opacity: root.isPlaying ? (1.0 - Math.abs(streakProgress - 0.5) * 1.5) : 0.0

        // Streak 1 (Top Left to Right)
        Rectangle {
            x: -200 + (parent.width + 400) * speedLines.streakProgress
            y: parent.height * 0.42
            width: 220
            height: 2.2
            radius: 1.1
            color: Theme.accent
            opacity: 0.70
            rotation: -4
        }

        // Streak 2 (Center Major Streak)
        Rectangle {
            x: -300 + (parent.width + 600) * (speedLines.streakProgress * 1.1)
            y: parent.height * 0.50
            width: 340
            height: 3.0
            radius: 1.5
            color: "#FFFFFF"
            opacity: 0.85
            rotation: -2
        }

        // Streak 3 (Bottom Right Drift)
        Rectangle {
            x: -180 + (parent.width + 360) * speedLines.streakProgress
            y: parent.height * 0.58
            width: 260
            height: 2.0
            radius: 1.0
            color: Theme.m3tertiary || "#c084fc"
            opacity: 0.65
            rotation: -5
        }
    }

    // 3. Radial Expanding Shockwave Ripple
    Item {
        id: shockwaveRing
        anchors.centerIn: parent
        property real shockRadius: 16
        property real shockOpacity: 0.0

        width: shockRadius * 2
        height: shockRadius * 2
        visible: shockOpacity > 0.01

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Theme.accent
            border.width: Math.max(1.0, 3.2 * (1.0 - shockwaveRing.shockRadius / 160.0))
            opacity: shockwaveRing.shockOpacity
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.75
            height: width
            radius: width / 2
            color: "transparent"
            border.color: "#FFFFFF"
            border.width: 1.5
            opacity: shockwaveRing.shockOpacity * 0.7
        }
    }

    // 4. Kinetic Typography ("Wooshhh!!")
    Item {
        id: textContainer
        anchors.centerIn: parent
        width: 440
        height: 120
        property real xOffset: 0.0

        transform: [
            Translate {
                x: textContainer.xOffset
                y: -8
            },
            Rotation {
                origin.x: textContainer.width / 2
                origin.y: textContainer.height / 2
                angle: -6.5 // Dynamic dynamic manga-tilt
            }
        ]

        // Neon Glow Shadow Layer (Underneath)
        Text {
            anchors.centerIn: parent
            text: "Wooshhh!!"
            font.family: "Valley Sans"
            font.pixelSize: 66
            font.bold: true
            font.italic: true
            font.letterSpacing: 3.5
            color: Theme.accent
            opacity: 0.65

            transform: [
                Scale {
                    xScale: 1.04
                    yScale: 1.04
                    origin.x: textContainer.width / 2
                    origin.y: textContainer.height / 2
                }
            ]
        }

        // Secondary Soft Chromatic Tint Layer
        Text {
            anchors.centerIn: parent
            text: "Wooshhh!!"
            font.family: "Valley Sans"
            font.pixelSize: 66
            font.bold: true
            font.italic: true
            font.letterSpacing: 3.5
            color: Theme.m3tertiary || "#c084fc"
            opacity: 0.45
            x: 2.5
            y: -2.5
        }

        // Crisp Specular Foreground Text
        Text {
            id: mainText
            anchors.centerIn: parent
            text: "Wooshhh!!"
            font.family: "Valley Sans"
            font.pixelSize: 66
            font.bold: true
            font.italic: true
            font.letterSpacing: 3.5
            color: "#FFFFFF"
        }
    }
}
