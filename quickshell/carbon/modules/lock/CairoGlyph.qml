import QtQuick
import QtQuick.Shapes
import "../../Singletons"
import "CairoHinglishMap.js" as GlyphMap

/**
 * CairoGlyph.qml:
 * Native Vector Glyph Renderer with GPU CurveRenderer Anti-Aliasing for Carbon // Cairo.
 * Evaluates 24x24 PathSvg geometry mathematically across native 86x86 bounds.
 */
Item {
    id: root
    width: 86
    height: 86

    property int stage: -1
    property string motif: ""
    property color glyphColor: Theme.m3primary || Theme.accent || "#c0c4ee"

    readonly property string svgPathString: GlyphMap.GLYPH_PATHS[root.motif] || ""
    readonly property bool hasValidGlyph: root.svgPathString.length > 0

    visible: hasValidGlyph

    ParallelAnimation {
        id: popAnim
        NumberAnimation {
            target: root
            property: "scale"
            from: 0.35
            to: 1.0
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.8
        }
        NumberAnimation {
            target: root
            property: "rotation"
            from: -14
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    onStageChanged: {
        if (stage === 0 && hasValidGlyph) {
            popAnim.restart()
        }
    }

    onMotifChanged: {
        if (stage === 0 && hasValidGlyph) {
            popAnim.restart()
        }
    }

    onVisibleChanged: {
        if (visible && (stage === 0 || stage === -1)) {
            popAnim.restart()
        }
    }

    Component.onCompleted: {
        if (stage === 0 && hasValidGlyph) {
            popAnim.restart()
        }
    }

    // Soft glow aura behind the crisp vector core (dual-tone depth)
    Rectangle {
        id: glowAura
        anchors.fill: parent
        radius: width / 2
        color: root.glyphColor
        opacity: 0.22
    }

    Shape {
        id: vectorShape
        anchors.fill: parent
        // Qt6 GPU analytical curve anti-aliasing for razor-sharp edges at any scale:
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        smooth: true

        ShapePath {
            strokeWidth: -1 // No stroke, pure fill
            strokeColor: "transparent"
            fillColor: Qt.lighter(root.glyphColor, 1.25)
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                path: root.svgPathString
            }
        }

        // Scale the 24x24 PathSvg geometry mathematically inside the Shape
        // instead of scaling a rasterized texture:
        transform: Scale {
            xScale: vectorShape.width / 24.0
            yScale: vectorShape.height / 24.0
        }
    }
}
