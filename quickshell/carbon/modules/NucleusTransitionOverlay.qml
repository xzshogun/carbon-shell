import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * NucleusTransitionOverlay:
 * Fullscreen cinematic mode-switch transition from bar mode to nucleus mode (~2.3s total).
 * 
 * Timeline Architecture:
 * - 0–600ms: Bar collapse toward center (easeInCubic, 10px dot, icons fade, vertical speed lines)
 * - 100–700ms: Suction (18 thin accent lines converge inward toward center)
 * - 600–1300ms: Impact (white flash 250ms, expanding 70px white disc, 190px teal ring, delayed purple ring)
 * - 650–1950ms: Kinetic Text ("Wooshh!!", heavy italic, letter-by-letter 28ms stagger over 320ms,
 *               3-layer chromatic stack, 7 speed-trail lines, drift & fade at 1500–1900ms)
 * - 900–1600ms: Atom arrives (easeOutCubic, 8px teal dot, 22px/40px rings, 2 purple & 4 teal electrons)
 * - 1900ms+: "nucleus mode" caption fades in, hands over seamlessly to real resting nucleus
 * 
 * Rules:
 * - Driven strictly from a single scrubbable `timeMs` property.
 * - Smooth easing only, no wobble/spring overshoot.
 * - Text rendered exclusively on primary screen.
 * - Respects reduced motion (300ms simple fade).
 * - Zero timers or residual processes once completed.
 */
Item {
    id: root

    anchors.fill: parent

    /* ── Configuration & Properties ── */
    property bool isPrimaryScreen: false
    property string transitionWord: "Wooshh!!"
    property bool transitionEnabled: true

    /* ── Single Master Time Driver (ms) ── */
    property real timeMs: 0.0

    /* ── Signals ── */
    signal transitionFinished()

    /* ── Theme Accent Colors ── */
    readonly property color colTeal: (Theme.palette && Theme.palette.teal)
        ? Theme.col(Theme.palette.teal, Theme.accent)
        : Theme.accent
    readonly property color colPurple: (Theme.palette && Theme.palette.tertiary)
        ? Theme.col(Theme.palette.tertiary, Theme.m3tertiary)
        : Theme.m3tertiary
    readonly property color colWhite: "#FFFFFF"
    readonly property color colBg: Theme.bg || "#0e0e14"
    readonly property bool reducedMotion: Boolean(Theme.reducedMotion)

    /* ── Mathematical Easing Functions ── */
    function clamp(v, minVal, maxVal) {
        return Math.max(minVal, Math.min(maxVal, v))
    }
    function easeInCubic(t) {
        return t * t * t
    }
    function easeOutCubic(t) {
        var inv = 1.0 - t
        return 1.0 - inv * inv * inv
    }
    function easeInQuad(t) {
        return t * t
    }
    function easeOutQuad(t) {
        return 1.0 - (1.0 - t) * (1.0 - t)
    }
    function easeOutExpo(t) {
        return (t >= 1.0) ? 1.0 : (1.0 - Math.pow(2.0, -10.0 * t))
    }

    /* ── Playback Controller ── */
    function play() {
        if (!root.transitionEnabled) {
            root.transitionFinished()
            return
        }
        root.timeMs = 0.0
        timeDriver.restart()
    }

    NumberAnimation {
        id: timeDriver
        target: root
        property: "timeMs"
        from: 0.0
        to: root.reducedMotion ? 300.0 : 2300.0
        duration: root.reducedMotion ? 300 : 2300
        easing.type: Easing.Linear
        running: false
        onFinished: {
            root.transitionFinished()
        }
    }

    onTimeMsChanged: {
        renderCanvas.requestPaint()
    }

    /* ── Fullscreen Hardware-Accelerated Canvas Engine ── */
    Canvas {
        id: renderCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = root.width
            var h = root.height
            var cx = w / 2.0
            var cy = h / 2.0
            var t = root.timeMs

            // ── Reduced Motion Mode (Gentle 300ms crossfade) ───────────────
            if (root.reducedMotion) {
                var p = clamp(t / 300.0, 0.0, 1.0)
                ctx.fillStyle = Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, Math.sin(p * Math.PI) * 0.35)
                ctx.fillRect(0, 0, w, h)
                return
            }

            // ── 1. Fullscreen White Flash (600–850ms, gone in 250ms) ───────
            if (t >= 600.0 && t <= 850.0) {
                var pFlash = clamp((t - 600.0) / 250.0, 0.0, 1.0)
                var alphaFlash = 0.10 * (1.0 - pFlash)
                ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, alphaFlash)
                ctx.fillRect(0, 0, w, h)
            }

            // ── 2. Suction Lines (100–700ms, 18 thin accent lines) ─────────
            if (t >= 100.0 && t <= 700.0) {
                var pSuction = clamp((t - 100.0) / 600.0, 0.0, 1.0)
                var suctionEase = easeInQuad(pSuction)
                var rCurr = 280.0 - (280.0 - 15.0) * suctionEase
                var suctionAlpha = (1.0 - suctionEase) * Math.sin(pSuction * Math.PI) * 0.85

                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, suctionAlpha)
                ctx.lineWidth = 1.2
                var lineLen = 22.0

                for (var k = 0; k < 18; k++) {
                    var theta = k * (2.0 * Math.PI / 18.0)
                    var cosT = Math.cos(theta)
                    var sinT = Math.sin(theta)

                    ctx.beginPath()
                    ctx.moveTo(cx + rCurr * cosT, cy + rCurr * sinT)
                    ctx.lineTo(cx + (rCurr + lineLen) * cosT, cy + (rCurr + lineLen) * sinT)
                    ctx.stroke()
                }
            }

            // ── 3. Bar Collapse (0–600ms) ──────────────────────────────────
            if (t <= 600.0) {
                var pBar = clamp(t / 600.0, 0.0, 1.0)
                var barEase = easeInCubic(pBar)

                var bWidth = 520.0 - (520.0 - 10.0) * barEase
                var bHeight = 26.0 - (26.0 - 10.0) * barEase
                var bRadius = bHeight / 2.0
                var bY = 20.0 + (cy - 20.0) * barEase
                var bX = cx - bWidth / 2.0

                // Vertical speed lines rising above bar
                var speedLen = Math.sin(pBar * Math.PI) * 38.0
                if (speedLen > 1.0) {
                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, Math.sin(pBar * Math.PI) * 0.70)
                    ctx.lineWidth = 1.4

                    var offsets = [-140.0, -50.0, 50.0, 140.0]
                    for (var s = 0; s < offsets.length; s++) {
                        var sx = cx + offsets[s] * (1.0 - barEase * 0.8)
                        ctx.beginPath()
                        ctx.moveTo(sx, bY - bHeight / 2.0 - 3.0)
                        ctx.lineTo(sx, bY - bHeight / 2.0 - 3.0 - speedLen * (0.8 + 0.4 * Math.sin(s + pBar)))
                        ctx.stroke()
                    }
                }

                // Bar Body
                ctx.beginPath()
                ctx.roundRect(bX, bY - bHeight / 2.0, bWidth, bHeight, bRadius)
                ctx.fillStyle = Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.92)
                ctx.fill()
                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35 * (1.0 - barEase * 0.5))
                ctx.lineWidth = 1.0
                ctx.stroke()

                // Bar Mock Icons (fade out by ~40%)
                if (bWidth > 80.0) {
                    var iconAlpha = (1.0 - 0.40 * barEase) * clamp((bWidth - 80.0) / 100.0, 0.0, 1.0)
                    ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, iconAlpha * 0.6)
                    ctx.beginPath()
                    ctx.arc(cx - 30, bY, 2.5, 0, 2 * Math.PI)
                    ctx.arc(cx, bY, 2.5, 0, 2 * Math.PI)
                    ctx.arc(cx + 30, bY, 2.5, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }

            // ── 4. Impact (600–1300ms: Disc & Dual Shockwaves) ─────────────
            if (t >= 600.0) {
                // Expanding White Disc (600–900ms)
                if (t <= 900.0) {
                    var pDisc = clamp((t - 600.0) / 300.0, 0.0, 1.0)
                    var discR = 35.0 * easeOutCubic(pDisc)
                    var discA = 0.85 * (1.0 - pDisc)
                    ctx.beginPath()
                    ctx.arc(cx, cy, discR, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, discA)
                    ctx.fill()
                }

                // Teal Shockwave Ring (600–1300ms, expands to 190px / radius 95px)
                if (t <= 1300.0) {
                    var pTeal = clamp((t - 600.0) / 700.0, 0.0, 1.0)
                    var tealR = 95.0 * easeOutCubic(pTeal)
                    var tealA = 0.80 * (1.0 - pTeal)
                    var tealW = 3.0 - 2.5 * pTeal

                    ctx.beginPath()
                    ctx.arc(cx, cy, tealR, 0, 2 * Math.PI)
                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, tealA)
                    ctx.lineWidth = Math.max(0.5, tealW)
                    ctx.stroke()
                }

                // Purple Shockwave Ring (680–1380ms, delayed 80ms)
                if (t >= 680.0 && t <= 1380.0) {
                    var pPurp = clamp((t - 680.0) / 700.0, 0.0, 1.0)
                    var purpR = 95.0 * easeOutCubic(pPurp)
                    var purpA = 0.70 * (1.0 - pPurp)
                    var purpW = 2.5 - 2.0 * pPurp

                    ctx.beginPath()
                    ctx.arc(cx, cy, purpR, 0, 2 * Math.PI)
                    ctx.strokeStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, purpA)
                    ctx.lineWidth = Math.max(0.5, purpW)
                    ctx.stroke()
                }
            }

            // ── 5. Resting Carbon Atom Arrives (900–2300ms) ────────────────
            if (t >= 900.0) {
                var pAtom = clamp((t - 900.0) / 700.0, 0.0, 1.0)
                var atomScale = easeOutCubic(pAtom)

                var rInner = 22.0 * atomScale
                var rOuter = 40.0 * atomScale

                // 2 Faint Orbit Rings
                ctx.lineWidth = 1.0
                ctx.beginPath()
                ctx.arc(cx, cy, rInner, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.22 * atomScale)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.16 * atomScale)
                ctx.stroke()

                // Central Teal Nucleus Dot (8px radius / 16px diameter)
                var dotR = 8.0 * atomScale
                ctx.beginPath()
                ctx.arc(cx, cy, dotR, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 1.0)
                ctx.fill()
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth = 1.0
                ctx.stroke()

                // Rotating Electrons (fade in at 1100ms)
                if (t >= 1100.0) {
                    var pElec = clamp((t - 1100.0) / 300.0, 0.0, 1.0)
                    var rotInner = (t - 900.0) * 0.00085
                    var rotOuter = -(t - 900.0) * 0.00055

                    // 2 Purple electrons on Inner Ring (radius 22px)
                    for (var ei = 0; ei < 2; ei++) {
                        var aInner = rotInner + ei * Math.PI
                        var ex1 = cx + rInner * Math.cos(aInner)
                        var ey1 = cy + rInner * Math.sin(aInner)

                        ctx.beginPath()
                        ctx.arc(ex1, ey1, 3.0, 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, pElec)
                        ctx.fill()
                    }

                    // 4 Teal electrons on Outer Ring (radius 40px)
                    for (var eo = 0; eo < 4; eo++) {
                        var aOuter = rotOuter + eo * (Math.PI / 2.0)
                        var ex2 = cx + rOuter * Math.cos(aOuter)
                        var ey2 = cy + rOuter * Math.sin(aOuter)

                        ctx.beginPath()
                        ctx.arc(ex2, ey2, 3.0, 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, pElec)
                        ctx.fill()
                    }
                }
            }

            // ── 6. Kinetic Typography ("Wooshh!!", 650–1950ms) ─────────────
            // Rendered exclusively on primary monitor
            if (root.isPrimaryScreen && t >= 650.0 && t <= 1950.0) {
                var word = root.transitionWord || "Wooshh!!"
                var numLetters = word.length
                var textYBase = cy - 80.0

                // Exit drift and stretch (1500–1900ms)
                var pExit = clamp((t - 1500.0) / 400.0, 0.0, 1.0)
                var exitAlpha = 1.0 - pExit
                var exitYDrift = -18.0 * easeOutCubic(pExit)
                var exitScale = 1.0 + 0.60 * easeOutCubic(pExit)

                ctx.save()
                ctx.font = "italic bold 46px 'Valley Sans', 'Rubik', 'Outfit', sans-serif"
                ctx.textBaseline = "middle"

                // Measure total text width for centering
                var metrics = ctx.measureText(word)
                var totalW = metrics.width || (numLetters * 30.0)
                var startX = cx - (totalW / 2.0)

                // 7 Horizontal Speed-Trail Lines (700–1300ms)
                if (t >= 700.0 && t <= 1300.0) {
                    var pTrail = clamp((t - 700.0) / 600.0, 0.0, 1.0)
                    var trailMag = Math.sin(pTrail * Math.PI)
                    var trailLen = trailMag * 85.0
                    var trailA = trailMag * 0.70

                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, trailA)
                    ctx.lineWidth = 1.3

                    for (var tr = 0; tr < 7; tr++) {
                        var ly = textYBase - 22.0 + tr * 7.5
                        var lx = startX - 8.0
                        var lOff = Math.sin(tr * 1.5 + pTrail) * 12.0

                        ctx.beginPath()
                        ctx.moveTo(lx, ly)
                        ctx.lineTo(lx - (trailLen + lOff), ly)
                        ctx.stroke()
                    }
                }

                // Draw each letter with 28ms stagger over 320ms
                var curX = startX
                for (var i = 0; i < numLetters; i++) {
                    var ch = word.charAt(i)
                    var chWidth = ctx.measureText(ch).width

                    var tEnter = 650.0 + (i * 28.0)
                    var pEnter = clamp((t - tEnter) / 320.0, 0.0, 1.0)

                    if (pEnter > 0.001) {
                        var enterEase = easeOutExpo(pEnter)
                        var chSlide = -140.0 * (1.0 - enterEase)
                        var chStretch = 1.0 + 2.2 * (1.0 - enterEase)
                        var chAlpha = pEnter * exitAlpha

                        var finalScaleX = chStretch * exitScale
                        var finalScaleY = exitScale
                        var finalX = curX + chSlide
                        var finalY = textYBase + exitYDrift

                        ctx.save()
                        // Letter origin for transformation
                        ctx.translate(finalX, finalY)
                        ctx.transform(finalScaleX, 0, -0.20, finalScaleY, 0, 0) // Skew -0.2 & horizontal stretch

                        // Layer 1: Purple Offset Copy (+3, +3)
                        ctx.fillStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, chAlpha * 0.85)
                        ctx.fillText(ch, 3.0, 3.0)

                        // Layer 2: Teal Main Fill
                        ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, chAlpha)
                        ctx.fillText(ch, 0, 0)

                        // Layer 3: Thin White Stroke (1.0px)
                        ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, chAlpha * 0.90)
                        ctx.lineWidth = 1.0
                        ctx.strokeText(ch, 0, 0)

                        ctx.restore()
                    }
                    curX += chWidth
                }
                ctx.restore()
            }

            // ── 7. Bottom Caption (1900ms+) ────────────────────────────────
            if (t >= 1900.0) {
                var pCap = clamp((t - 1900.0) / 300.0, 0.0, 1.0)
                ctx.save()
                ctx.font = "bold 12px 'Valley Sans', 'Rubik', sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, pCap * 0.75)
                ctx.fillText("NUCLEUS MODE", cx, cy + 68.0)
                ctx.restore()
            }
        }
    }
}
