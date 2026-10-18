import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../Singletons"
import "CairoHinglishMap.js" as GlyphMap

/**
 * CairoStage.qml:
 * Carbon // Cairo Kinetic Lyric Standby & Lock Screen Engine
 *
 * Implements:
 *   - 100% Pitch-Black Stage (#000000) with CairoBorderGlow steady perimeter spotlight.
 *   - 5 Persistent Word Delegates in a True Upward-Gliding 3D Barrel.
 *   - Strictly Single-Word Highlighting: single shared Rectangle highlight block
 *     that glides dynamically to whichever word in Stage 0 is currently active.
 *   - Zero highlight on Stage 1 (middle) and Stage 2 (top).
 *   - 60fps Interpolated Audio Clock with live [ and ] hotkeys for fine-tuning sync offset.
 *   - Instant single-Enter unlock with radial iris reveal.
 */
Item {
    id: root
    anchors.fill: parent

    focus: true

    onVisibleChanged: {
        if (visible && lyricEngine) {
            lyricEngine.syncBaseTimeFromMpris()
        }
    }

    // Center coordinates on screen
    readonly property real cx: root.width / 2
    readonly property real cy: root.height / 2

    // ── Palette Tokens ─────────────────────────────────────────────────────
    readonly property color vibrantPrimary: Theme.m3primary || Theme.accent || Qt.rgba(0.46, 0.82, 0.98, 1.0)
    readonly property color highlightColor: root.vibrantPrimary

    readonly property real highlightLuminance: 0.299 * highlightColor.r + 0.587 * highlightColor.g + 0.114 * highlightColor.b
    readonly property color highlightedTextColor: Theme.m3onPrimary || ((highlightLuminance > 0.6) ? "#111418" : "#f7ebed")

    readonly property color bronzeColor: {
        var sec = Theme.m3secondary || Qt.rgba(0.77, 0.77, 0.87, 1.0)
        var dSec = Qt.darker(sec, 1.15)
        var b = Qt.color("#9c6e54")
        return Qt.rgba(
            dSec.r * 0.40 + b.r * 0.60,
            dSec.g * 0.40 + b.g * 0.60,
            dSec.b * 0.40 + b.b * 0.60,
            1.0
        )
    }

    // High-precision effective audio position from 60fps clock
    readonly property real effectivePositionMs: lyricEngine.effectivePositionMs

    // ── 1. Pure Pitch-Black Stage (0% Shaders / 0% Chrome) ────────────────
    Rectangle {
        id: pitchBlackBg
        anchors.fill: parent
        color: "#000000"
        border.width: 0
        z: 0
    }

    // ── 1a. ReactBits Deep Space Starfield & Meteor Shower Background ────
    Canvas {
        id: spaceShowerCanvas
        anchors.fill: parent
        z: 1
        opacity: 0.85

        property color starColor: "#ffffff"
        property color meteorAccent: root.highlightColor // Bound to live Matugen primary color
        property var stars: []
        property var meteors: []
        property real tickPhase: 0.0

        function initSpace() {
            var s = [];
            for (var i = 0; i < 48; i++) {
                s.push({
                    x: Math.random(),
                    y: Math.random(),
                    r: 0.7 + Math.random() * 1.3,
                    baseAlpha: 0.12 + Math.random() * 0.28,
                    speed: 0.8 + Math.random() * 2.2,
                    offset: Math.random() * 6.28
                });
            }
            stars = s;

            var m = [];
            for (var j = 0; j < 3; j++) {
                m.push(spawnMeteor(true));
            }
            meteors = m;
        }

        function spawnMeteor(randomProgress) {
            return {
                x: 0.15 + Math.random() * 0.85,
                y: randomProgress ? Math.random() * 0.8 : (-0.05 - Math.random() * 0.25),
                len: 95 + Math.random() * 85,
                speed: 0.0045 + Math.random() * 0.0035,
                alpha: 0.45 + Math.random() * 0.45,
                delay: randomProgress ? 0 : Math.floor(Math.random() * 90)
            };
        }

        Component.onCompleted: initSpace()

        Timer {
            interval: 16
            running: spaceShowerCanvas.visible
            repeat: true
            onTriggered: {
                spaceShowerCanvas.tickPhase += 0.035;
                for (var i = 0; i < spaceShowerCanvas.meteors.length; i++) {
                    var m = spaceShowerCanvas.meteors[i];
                    if (m.delay > 0) {
                        m.delay -= 1;
                        continue;
                    }
                    m.x -= m.speed * 0.78; // Diagonal 215-degree ReactBits meteor angle
                    m.y += m.speed;
                    if (m.x < -0.15 || m.y > 1.15) {
                        spaceShowerCanvas.meteors[i] = spaceShowerCanvas.spawnMeteor(false);
                    }
                }
                spaceShowerCanvas.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // 1. Subtle twinkling deep-space dust stars (kept subtle so lyrics stay 100% readable)
            for (var i = 0; i < stars.length; i++) {
                var st = stars[i];
                var tw = st.baseAlpha * (0.55 + 0.45 * Math.sin(tickPhase * st.speed + st.offset));
                ctx.fillStyle = "rgba(255, 255, 255, " + tw.toFixed(3) + ")";
                ctx.beginPath();
                ctx.arc(st.x * width, st.y * height, st.r, 0, Math.PI * 2);
                ctx.fill();
            }

            // 2. ReactBits-style diagonal shooting meteors with tapered glowing tails
            for (var j = 0; j < meteors.length; j++) {
                var m = meteors[j];
                if (m.delay > 0) continue;
                var headX = m.x * width;
                var headY = m.y * height;
                var tailX = headX + m.len * 0.78;
                var tailY = headY - m.len;

                var mr = Math.round(meteorAccent.r * 255);
                var mg = Math.round(meteorAccent.g * 255);
                var mb = Math.round(meteorAccent.b * 255);
                var grad = ctx.createLinearGradient(headX, headY, tailX, tailY);
                grad.addColorStop(0.0, "rgba(255, 255, 255, " + m.alpha.toFixed(3) + ")");
                grad.addColorStop(0.25, "rgba(" + mr + ", " + mg + ", " + mb + ", " + (m.alpha * 0.75).toFixed(3) + ")");
                grad.addColorStop(1.0, "rgba(0, 0, 0, 0.0)");

                ctx.strokeStyle = grad;
                ctx.lineWidth = 1.8;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(headX, headY);
                ctx.lineTo(tailX, tailY);
                ctx.stroke();

                // Glowing meteor head spark
                ctx.fillStyle = "rgba(255, 255, 255, " + Math.min(1.0, m.alpha + 0.2).toFixed(3) + ")";
                ctx.beginPath();
                ctx.arc(headX, headY, 1.9, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // ── 1b. 100% Native QML Hardware-Accelerated Ambient Edge Glow ──────
    Item {
        id: cairoAmbientBorder
        anchors.fill: parent
        z: 999

        property color glowColor: root.highlightColor
        property real beatPulse: 0.4
        property real orbitPhase: 0.0

        Timer {
            interval: 16
            running: true
            repeat: true
            property real t: 0
            onTriggered: {
                t += 0.09;
                cairoAmbientBorder.orbitPhase = (cairoAmbientBorder.orbitPhase + 0.0045) % 1.0;
                var synth = Math.pow(Math.max(0, Math.sin(t) * 0.65 + Math.sin(t * 2.2) * 0.35), 2.0);
                cairoAmbientBorder.beatPulse = 0.25 + 0.75 * synth;
            }
        }

        // 1. TOP INWARD AMBIENT NEON BLOOM (Fades smoothly from edge into the black void)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36 + cairoAmbientBorder.beatPulse * 48
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.28 + cairoAmbientBorder.beatPulse * 0.38) }
                GradientStop { position: 0.45; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.08 + cairoAmbientBorder.beatPulse * 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // 2. BOTTOM INWARD AMBIENT NEON BLOOM
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36 + cairoAmbientBorder.beatPulse * 48
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.08 + cairoAmbientBorder.beatPulse * 0.14) }
                GradientStop { position: 1.0; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.28 + cairoAmbientBorder.beatPulse * 0.38) }
            }
        }

        // 3. LEFT INWARD AMBIENT NEON BLOOM
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 36 + cairoAmbientBorder.beatPulse * 48
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.28 + cairoAmbientBorder.beatPulse * 0.38) }
                GradientStop { position: 0.45; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.08 + cairoAmbientBorder.beatPulse * 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // 4. RIGHT INWARD AMBIENT NEON BLOOM
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 36 + cairoAmbientBorder.beatPulse * 48
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.08 + cairoAmbientBorder.beatPulse * 0.14) }
                GradientStop { position: 1.0; color: Qt.rgba(cairoAmbientBorder.glowColor.r, cairoAmbientBorder.glowColor.g, cairoAmbientBorder.glowColor.b, 0.28 + cairoAmbientBorder.beatPulse * 0.38) }
            }
        }

        // 5. Clean Borderless Interior (Zero sharp perimeter boxes, soft inward bloom only)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 0
            border.color: "transparent"
        }
    }

    // ── 2. Cairo Lyric Engine ─────────────────────────────────────────────
    CairoLyricEngine {
        id: lyricEngine
        onBeatTriggered: (beatData) => root.handleBeatTriggered(beatData)
        onClearRequested: root.handleClearRequested()
        onAllWordsChanged: root.syncInitialCluster()
        onCurrentWordIndexChanged: {
            if (!root.hasActiveWords && lyricEngine.currentWordIndex >= 0) {
                root.syncInitialCluster()
            }
        }
    }

    // ── 3. Radial Iris Reveal Unlock Controller ──────────────────────────
    property real irisRadius: 0.0
    property bool unlocking: false

    signal unlocked()

    function triggerUnlock() {
        if (root.unlocking) return
        root.unlocking = true
        irisAnim.restart()
    }

    NumberAnimation {
        id: irisAnim
        target: root
        property: "irisRadius"
        from: 0.0
        to: 950.0
        duration: 480
        easing.type: Easing.InOutCubic
        onFinished: {
            root.unlocked()
            LockState.finishUnlock()
        }
    }

    property bool readyToUnlock: false
    Timer {
        interval: 350
        running: true
        repeat: false
        onTriggered: root.readyToUnlock = true
    }

    // Sync Offset Toast
    property string offsetToastText: ""
    property bool offsetToastVisible: false
    Timer {
        id: toastTimer
        interval: 1400
        onTriggered: root.offsetToastVisible = false
    }
    function showOffsetToast(val) {
        root.offsetToastText = "SYNC: " + (val > 0 ? "+" : "") + val + " ms"
        root.offsetToastVisible = true
        toastTimer.restart()
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_BracketLeft) {
            event.accepted = true
            lyricEngine.syncOffsetMs -= 50
            root.showOffsetToast(lyricEngine.syncOffsetMs)
        } else if (event.key === Qt.Key_BracketRight) {
            event.accepted = true
            lyricEngine.syncOffsetMs += 50
            root.showOffsetToast(lyricEngine.syncOffsetMs)
        } else if (root.readyToUnlock && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            event.accepted = true
            root.triggerUnlock()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 40
        onClicked: {
            root.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        root.forceActiveFocus()
        if (lyricEngine) {
            lyricEngine.syncBaseTimeFromMpris()
        }
        root.syncInitialCluster()
    }

    // ── 4. Reusable 3-Slot Barrel Word Delegate Component ────────────────
    component CairoWordDelegate: Item {
        id: delegateRoot
        width: root.width
        height: 140
        x: (root.width - width) / 2

        property int stage: 4 // -1: pre-entry, 0: active bottom, 1: middle, 2: top, 3: exiting, 4: idle
        property string chunkText: ""
        property var glyphInput: null
        property var glyphMotif: null
        property real currentDuration: 1.0
        property real chunkStartTime: 0.0
        property real chunkStartMs: 0
        property real chunkEndMs: 0
        property real vocalEndMs: 0
        property var rowWords: []
        clip: false


        // Spatial animated properties
        property real stageY: root.cy + 210
        property real stageOpacity: 0.0
        property real stageScaleX: 0.88
        property real stageScaleY: 0.50
        property real stageRotX: 8.0

        property bool enableAnim: true

        y: stageY - height / 2
        opacity: stageOpacity
        visible: stageOpacity > 0.005

        // Transitions: 340ms Easing.OutQuint across all barrel coordinates
        Behavior on stageY {
            enabled: delegateRoot.enableAnim && delegateRoot.stage >= 0
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on stageScaleX {
            enabled: delegateRoot.enableAnim && delegateRoot.stage >= 0
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on stageScaleY {
            enabled: delegateRoot.enableAnim && delegateRoot.stage >= 0
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on stageRotX {
            enabled: delegateRoot.enableAnim && delegateRoot.stage >= 0
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on stageOpacity {
            enabled: delegateRoot.enableAnim && delegateRoot.stage >= 0
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }

        transform: [
            Scale {
                origin.x: delegateRoot.width / 2
                origin.y: delegateRoot.height / 2
                xScale: delegateRoot.stageScaleX
                yScale: delegateRoot.stageScaleY
            },
            Rotation {
                origin.x: delegateRoot.width / 2
                origin.y: delegateRoot.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: delegateRoot.stageRotX
            }
        ]

        function calcFontSize(txt) {
            var len = (txt || "").length
            if (len > 12) return 86
            if (len > 8) return 102
            return 118
        }

        function spawnAtStage0() {
            enableAnim = false
            stageOpacity = 0.0
            stageY = root.cy + 210
            stageScaleX = 0.88
            stageScaleY = 0.50
            stageRotX = 8.0
            z = 30
            stage = 0
            enableAnim = true
            stageY = root.cy + 105
            stageOpacity = 1.0
            stageScaleX = 1.0
            stageScaleY = 1.0
            stageRotX = 0.0
        }

        function setStage(newStage) {
            stage = newStage
            if (newStage === -1) {
                // Stage -1 (Pre-Entry Spawn: 0ms teleport without downward animation)
                enableAnim = false
                stageOpacity = 0.0
                stageY = root.cy + 210
                stageScaleX = 0.88
                stageScaleY = 0.50
                stageRotX = 8.0
                z = 1
                enableAnim = true
            } else if (newStage === 0) {
                // Stage 0 (Bottom Active Spoken Row: glides up from +210 to +105)
                stageY = root.cy + 105
                stageOpacity = 1.0
                stageScaleX = 1.0
                stageScaleY = 1.0
                stageRotX = 0.0
                z = 30
            } else if (newStage === 1) {
                // Stage 1 (Middle Row — Just Passed)
                stageY = root.cy - 35
                stageOpacity = 0.85
                stageScaleX = 0.82
                stageScaleY = 0.68
                stageRotX = 20.0
                z = 20
            } else if (newStage === 2) {
                // Stage 2 (Top Row — Receding Barrel Edge)
                stageY = root.cy - 135
                stageOpacity = 0.42
                stageScaleX = 0.66
                stageScaleY = 0.44
                stageRotX = 38.0
                z = 10
            } else if (newStage === 3) {
                // Stage 3 (Exiting Top — Crushing Flat)
                stageY = root.cy - 195
                stageOpacity = 0.0
                stageScaleX = 0.54
                stageScaleY = 0.12
                stageRotX = 58.0
                z = 1
            } else {
                // Stage 4 (Idle Pool Dormant)
                enableAnim = false
                stageOpacity = 0.0
                stageY = root.cy + 400
                z = 0
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 24
            clip: false

            // 3-Layer Animated Kinetic Vector Glyph with CurveRenderer
            // Strictly visible only on Stage 0 (hidden on Stage 1 and Stage 2)
            CairoGlyph {
                id: glyphItem
                z: 50
                stage: delegateRoot.stage
                activeInStage0: delegateRoot.stage === 0
                glyphInput: delegateRoot.glyphInput ? delegateRoot.glyphInput : delegateRoot.glyphMotif
                glyphColor: root.vibrantPrimary
                anchors.verticalCenter: parent.verticalCenter
                width: 88
                height: 88
                opacity: (delegateRoot.stage === 0 && hasValidGlyph) ? 1.0 : 0.0
                visible: opacity > 0.01 && hasValidGlyph

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }

            // Word Box: holds the 0.45 translucent glass tape highlight behind the word text
            Item {
                id: wordBox
                anchors.verticalCenter: parent.verticalCenter
                width: wordText.implicitWidth + 52
                height: Math.max(80, wordText.implicitHeight)

                // Translucent Glass Tape highlight block
                Rectangle {
                    id: activeWordHighlight
                    z: -1
                    anchors.centerIn: parent
                    width: wordText.implicitWidth + 52
                    height: wordText.implicitHeight + 14
                    radius: 10
                    color: Qt.rgba(root.vibrantPrimary.r, root.vibrantPrimary.g, root.vibrantPrimary.b, 0.45)
                    border.width: 1.5
                    border.color: Qt.rgba(root.vibrantPrimary.r, root.vibrantPrimary.g, root.vibrantPrimary.b, 0.82)
                    opacity: (delegateRoot.stage === 0) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }
                }

                Text {
                    id: wordText
                    anchors.centerIn: parent
                    text: delegateRoot.chunkText
                    font.family: "Plus Jakarta Sans, Manrope, sans-serif"
                    font.weight: Font.ExtraBold
                    font.letterSpacing: -2.8
                    font.pixelSize: delegateRoot.calcFontSize(delegateRoot.chunkText)
                    color: (delegateRoot.stage === 0)
                           ? root.highlightedTextColor
                           : root.bronzeColor

                    Behavior on color {
                        ColorAnimation { duration: 90; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // ── 5. Delegate Pool Management ──────────────────────────────────────
    Item {
        id: stageContainer
        anchors.fill: parent
        z: 2
        visible: (lyricEngine.hasLyrics || root.hasActiveWords) && root.irisRadius < 900
        opacity: root.unlocking ? Math.max(0.0, 1.0 - root.irisRadius / 400.0) : 1.0

        CairoWordDelegate { id: d0 }
        CairoWordDelegate { id: d1 }
        CairoWordDelegate { id: d2 }
        CairoWordDelegate { id: d3 }
        CairoWordDelegate { id: d4 }
    }

    readonly property var delegates: [d0, d1, d2, d3, d4]
    property int poolPointer: 0

    readonly property bool hasActiveWords: {
        for (var i = 0; i < delegates.length; i++) {
            if (delegates[i].stage >= 0 && delegates[i].stage <= 2) return true
        }
        return false
    }

    function pushNewWord(beat) {
        handleBeatTriggered(beat)
    }

    function handleBeatTriggered(beat) {
        if (!beat) return

        // 1. Strictly shift active delegates by +1 exactly once per token change:
        // Stage 2 -> Stage 3 (exiting top)
        // Stage 1 -> Stage 2 (top row)
        // Stage 0 / -1 -> Stage 1 (middle row)
        // Stage 3 -> Stage 4 (idle pool)
        for (var i = 0; i < delegates.length; i++) {
            var d = delegates[i]
            if (d.stage === 2) {
                d.setStage(3)
            } else if (d.stage === 1) {
                d.setStage(2)
            } else if (d.stage === 0 || d.stage === -1) {
                d.setStage(1)
            } else if (d.stage === 3) {
                d.setStage(4)
            }
        }

        // 2. Pick next delegate from pool
        var nextD = delegates[poolPointer]
        poolPointer = (poolPointer + 1) % delegates.length

        // 3. Set content and spawn smoothly into Stage 0
        nextD.chunkText = beat.text
        nextD.glyphInput = beat.glyph || null
        nextD.glyphMotif = (beat.glyph && beat.glyph.motif) ? beat.glyph.motif : (typeof beat.glyph === "string" ? beat.glyph : "")
        nextD.currentDuration = beat.duration || 1.0
        nextD.chunkStartTime = beat.time || 0.0
        nextD.chunkStartMs = beat.startMs || Math.round(beat.time * 1000)
        nextD.chunkEndMs = beat.endMs || Math.round((beat.time + beat.duration) * 1000)
        nextD.vocalEndMs = beat.vocalEndMs || nextD.chunkEndMs
        nextD.rowWords = beat.rowWords || [{ text: beat.text, startMs: nextD.chunkStartMs, endMs: nextD.vocalEndMs }]

        nextD.spawnAtStage0()
    }

    function handleClearRequested() {
        if (!lyricEngine || !lyricEngine.hasLyrics || !lyricEngine.hasTrack) {
            for (var i = 0; i < delegates.length; i++) {
                var d = delegates[i]
                if (d.stage >= 0 && d.stage <= 2) {
                    d.setStage(3)
                }
            }
        }
    }

    function syncInitialCluster() {
        if (!lyricEngine || !lyricEngine.allWords || lyricEngine.allWords.length === 0) return
        var idx = lyricEngine.currentWordIndex
        if (idx < 0 || idx >= lyricEngine.allWords.length) return

        for (var i = 0; i < delegates.length; i++) {
            delegates[i].setStage(4)
        }

        if (idx >= 2) {
            var w2 = lyricEngine.allWords[idx - 2]
            d2.chunkText = w2.text
            d2.glyphInput = w2.glyph || null
            d2.glyphMotif = (w2.glyph && w2.glyph.motif) ? w2.glyph.motif : (typeof w2.glyph === "string" ? w2.glyph : "")
            d2.currentDuration = w2.duration || 1.0
            d2.chunkStartTime = w2.time || 0.0
            d2.chunkStartMs = w2.startMs || Math.round(w2.time * 1000)
            d2.chunkEndMs = w2.endMs || Math.round((w2.time + w2.duration) * 1000)
            d2.vocalEndMs = w2.vocalEndMs || d2.chunkEndMs
            d2.rowWords = w2.rowWords || [{ text: w2.text, startMs: d2.chunkStartMs, endMs: d2.vocalEndMs }]
            d2.setStage(2)
        }
        if (idx >= 1) {
            var w1 = lyricEngine.allWords[idx - 1]
            d1.chunkText = w1.text
            d1.glyphInput = w1.glyph || null
            d1.glyphMotif = (w1.glyph && w1.glyph.motif) ? w1.glyph.motif : (typeof w1.glyph === "string" ? w1.glyph : "")
            d1.currentDuration = w1.duration || 1.0
            d1.chunkStartTime = w1.time || 0.0
            d1.chunkStartMs = w1.startMs || Math.round(w1.time * 1000)
            d1.chunkEndMs = w1.endMs || Math.round((w1.time + w1.duration) * 1000)
            d1.vocalEndMs = w1.vocalEndMs || d1.chunkEndMs
            d1.rowWords = w1.rowWords || [{ text: w1.text, startMs: d1.chunkStartMs, endMs: d1.vocalEndMs }]
            d1.setStage(1)
        }
        var w0 = lyricEngine.allWords[idx]
        d0.chunkText = w0.text
        d0.glyphInput = w0.glyph || null
        d0.glyphMotif = (w0.glyph && w0.glyph.motif) ? w0.glyph.motif : (typeof w0.glyph === "string" ? w0.glyph : "")
        d0.currentDuration = w0.duration || 1.0
        d0.chunkStartTime = w0.time || 0.0
        d0.chunkStartMs = w0.startMs || Math.round(w0.time * 1000)
        d0.chunkEndMs = w0.endMs || Math.round((w0.time + w0.duration) * 1000)
        d0.vocalEndMs = w0.vocalEndMs || d0.chunkEndMs
        d0.rowWords = w0.rowWords || [{ text: w0.text, startMs: d0.chunkStartMs, endMs: d0.vocalEndMs }]
        d0.setStage(0)

        poolPointer = 3
    }


    // ── 6. Standby Fallback (Zero Chrome when no lyrics active) ───────────
    Item {
        id: standbyFallback
        anchors.centerIn: parent
        z: 1
        visible: !root.hasActiveWords && root.irisRadius < 900
        opacity: root.unlocking ? Math.max(0.0, 1.0 - root.irisRadius / 400.0) : (root.hasActiveWords ? 0.0 : 0.88)

        Behavior on opacity { NumberAnimation { duration: 250 } }

        Column {
            anchors.centerIn: parent
            spacing: 14

            CairoGlyph {
                glyphInput: "DHUN_VINYL"
                activeInStage0: true
                glyphColor: root.vibrantPrimary
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lyricEngine.hasTrack ? (LyricsService.trackTitle || "STANDBY") : "STANDBY"
                font.family: "Plus Jakarta Sans, Manrope, sans-serif"
                font.weight: Font.ExtraBold
                font.letterSpacing: 4.0
                font.pixelSize: 22
                color: root.vibrantPrimary
                opacity: 0.88
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lyricEngine.hasTrack ? (LyricsService.trackArtist || "") : ""
                font.family: "Plus Jakarta Sans, Manrope, sans-serif"
                font.weight: Font.DemiBold
                font.letterSpacing: 2.0
                font.pixelSize: 14
                color: root.bronzeColor
                opacity: 0.70
                visible: text.length > 0
            }
        }
    }

    // ── 7. Radial Iris Reveal Cutout Surface ──────────────────────────────
    Canvas {
        id: irisCanvas
        anchors.fill: parent
        z: 25
        visible: root.irisRadius > 0.1

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.irisRadius <= 0.1) return

            ctx.save()
            ctx.fillStyle = "#000000"
            ctx.beginPath()
            ctx.rect(0, 0, width, height)
            ctx.arc(root.cx, root.cy, root.irisRadius, 0, 2 * Math.PI, true)
            ctx.closePath()
            ctx.fill()
            ctx.restore()
        }
    }

    onIrisRadiusChanged: irisCanvas.requestPaint()

    // ── 8. Sync Offset OSD Toast ──────────────────────────────────────────
    Rectangle {
        id: offsetToastBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 36
        width: offsetToastLabel.contentWidth + 32
        height: 38
        radius: 8
        color: "#181a20"
        border.width: 1
        border.color: root.vibrantPrimary
        opacity: root.offsetToastVisible ? 0.94 : 0.0
        visible: opacity > 0.01
        z: 100

        Behavior on opacity { NumberAnimation { duration: 150 } }

        Text {
            id: offsetToastLabel
            anchors.centerIn: parent
            text: root.offsetToastText
            font.family: "Plus Jakarta Sans, Manrope, sans-serif"
            font.weight: Font.Bold
            font.pixelSize: 14
            color: root.vibrantPrimary
        }
    }
}
