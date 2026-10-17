import QtQuick
import QtQuick.Shapes
import "../../Singletons"
import "CairoHinglishMap.js" as GlyphMap

/**
 * CairoGlyph.qml:
 * 3-Layer Animated Kinetic Vector Glyph Assembly for Carbon // Cairo.
 * Evaluates 24x24 PathSvg geometry mathematically across native bounds.
 *
 * Layers:
 *   - Soft Radial Ambient Glow
 *   - Layer A: Translucent Rotating/Breathing Halo (Counter-Motion)
 *   - Layer B: Sculpted Hero Core (100% Opacity, Bright Accent)
 *   - Layer C: Active Micro-Motion Satellites (92% Specular White-Tinted Accent)
 */
Item {
    id: glyphRoot
    width: 92
    height: 92

    // Bound from parent delegate in CairoStage.qml or standalone:
    property int stage: -1
    property bool activeInStage0: stage === 0 || (stage === -1 && (motif.length > 0 || (glyphData && (glyphData.corePath || glyphData.length))))

    property color glyphColor: Theme.m3primary || Theme.accent || "#ff7b3a"
    property color accentColor: glyphColor // Bound to live Matugen primary

    property string motif: ""
    property var glyphData: null

    // Gracefully resolve 3-layer definition object from explicit glyphData, motif lookup, or fallback:
    readonly property var activeGlyphData: {
        if (glyphData) {
            if (typeof glyphData === "object" && glyphData.corePath !== undefined) {
                return {
                    corePath: glyphData.corePath || "",
                    haloPath: glyphData.haloPath || "",
                    satPath: glyphData.satPath || "",
                    animType: glyphData.animType || "orbit"
                };
            }
            if (typeof glyphData === "string" && glyphData.length > 0) {
                return {
                    corePath: glyphData,
                    haloPath: "",
                    satPath: "",
                    animType: "pulse"
                };
            }
        }
        if (motif && motif.length > 0) {
            var mKey = motif.toUpperCase();
            var mLower = motif.toLowerCase();
            var pool = (GlyphMap.KINETIC_GLYPHS) ? GlyphMap.KINETIC_GLYPHS : (GlyphMap.GLYPH_OBJECTS || {});
            var o = pool[motif] || pool[mKey] || pool[mLower] || (GlyphMap.GLYPH_OBJECTS ? (GlyphMap.GLYPH_OBJECTS[motif] || GlyphMap.GLYPH_OBJECTS[mKey] || GlyphMap.GLYPH_OBJECTS[mLower]) : null);
            if (o) {
                return {
                    corePath: o.corePath || "",
                    haloPath: o.haloPath || "",
                    satPath: o.satPath || "",
                    animType: o.animType || "orbit"
                };
            }
            if (GlyphMap.GLYPH_PATHS && (GlyphMap.GLYPH_PATHS[motif] || GlyphMap.GLYPH_PATHS[mKey] || GlyphMap.GLYPH_PATHS[mLower])) {
                return {
                    corePath: GlyphMap.GLYPH_PATHS[motif] || GlyphMap.GLYPH_PATHS[mKey] || GlyphMap.GLYPH_PATHS[mLower],
                    haloPath: "",
                    satPath: "",
                    animType: "pulse"
                };
            }
        }
        return {
            corePath: "",
            haloPath: "",
            satPath: "",
            animType: "orbit"
        };
    }

    readonly property bool hasValidGlyph: (activeGlyphData.corePath || "").length > 0

    opacity: activeInStage0 && hasValidGlyph ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

    // Elastic Entry Spring Pop when word lands in Stage 0:
    scale: activeInStage0 ? 1.0 : 0.32
    rotation: activeInStage0 ? 0 : -15
    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.85 } }
    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // Continuous 60fps internal phase driver (0.0 -> 2*PI) while visible:
    property real phase: 0.0
    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 2400
        loops: Animation.Infinite
        running: glyphRoot.visible
    }

    // Soft radial ambient glow behind the 3 layers:
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.78
        height: parent.height * 0.78
        radius: width / 2
        color: Qt.rgba(glyphRoot.accentColor.r, glyphRoot.accentColor.g, glyphRoot.accentColor.b, 0.16)
        scale: 1.0 + 0.08 * Math.sin(glyphRoot.phase)
    }

    // LAYER A: Back Ambient Halo / Secondary Wave (28-30% Opacity, Counter-Motion)
    Shape {
        id: haloLayer
        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.30
        visible: (glyphRoot.activeGlyphData.haloPath || "").length > 0
        rotation: glyphRoot.activeGlyphData.animType === "spin" ? -(glyphRoot.phase * 180 / Math.PI)
                : (glyphRoot.activeGlyphData.animType === "sway" ? Math.sin(glyphRoot.phase) * 9 : 0)
        scale: (glyphRoot.width / 24.0) * (1.0 + 0.06 * Math.cos(glyphRoot.phase))
        transformOrigin: Item.Center

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: glyphRoot.accentColor
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: glyphRoot.activeGlyphData.haloPath || "" }
        }
    }

    // LAYER B: Sculpted Hero Core (100% Opacity, Bright Lighter Accent)
    Shape {
        id: coreLayer
        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer
        rotation: glyphRoot.activeGlyphData.animType === "spin" ? (glyphRoot.phase * 180 / Math.PI) : 0
        scale: (glyphRoot.width / 24.0) * (glyphRoot.activeGlyphData.animType === "pulse" ? (1.0 + 0.08 * Math.abs(Math.sin(glyphRoot.phase * 1.5))) : 1.0)
        transformOrigin: Item.Center

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: Qt.lighter(glyphRoot.accentColor, 1.28)
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: glyphRoot.activeGlyphData.corePath || "" }
        }
    }

    // LAYER C: Active Micro-Motion Satellites (92% Specular White-Tinted Accent)
    Shape {
        id: satelliteLayer
        width: 24
        height: 24
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.92
        visible: (glyphRoot.activeGlyphData.satPath || "").length > 0
        scale: glyphRoot.width / 24.0
        transformOrigin: Item.Center

        // Dynamic micro-motion offsets by animType:
        transform: Translate {
            x: glyphRoot.activeGlyphData.animType === "scan" ? Math.sin(glyphRoot.phase) * 9.0
             : (glyphRoot.activeGlyphData.animType === "orbit" ? Math.cos(glyphRoot.phase) * 5.0 : 0)
            y: glyphRoot.activeGlyphData.animType === "float" ? -Math.abs(Math.sin(glyphRoot.phase)) * 10.0
             : (glyphRoot.activeGlyphData.animType === "orbit" ? Math.sin(glyphRoot.phase) * 5.0 : 0)
        }

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: Qt.lighter(glyphRoot.accentColor, 1.65)
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: glyphRoot.activeGlyphData.satPath || "" }
        }
    }
}
