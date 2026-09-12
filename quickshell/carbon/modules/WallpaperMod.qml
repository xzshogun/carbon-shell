import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string symlink: "/home/shogun/.config/hypr/current_wallpaper"
    readonly property string stateFile: "/home/shogun/.config/hypr/current_wallpaper_path"
    readonly property string modeConfigFile: "/home/shogun/.config/hypr/carbon-bar-mode.json"

    property string currentWpPath: ""
    property string pendingNewPath: ""
    property string activeBuffer: "A" // "A" or "B"
    property bool isAnimating: false

    // Animation settings (loaded from carbon-bar-mode.json)
    property string animType: "cinematic" // "cinematic", "crossfade", "slide-left", "slide-right", "zoom-out"
    property int animDuration: 800

    function getWallpaperType(filePath) {
        if (!filePath) return "image"
        const p = filePath.toLowerCase()
        if (p.includes("carbon-live") || p.includes("carbon-atom") || p.includes("carbon-lewis") || p.includes("carbon-quantum")) return "carbon-live"
        if (p.endsWith(".mp4") || p.endsWith(".m4v") || p.endsWith(".webm") || p.endsWith(".mkv")) return "video"
        if (p.endsWith(".gif")) return "gif"
        return "image"
    }

    readonly property string currentType: getWallpaperType(root.currentWpPath)

    function resolveWpUrl(filePath) {
        if (!filePath) return ""
        var clean = filePath.trim()
        if (clean.startsWith("file://")) clean = clean.substring(7)
        
        const parts = clean.split("/")
        const filename = parts[parts.length - 1]
        const safeScaled = "/home/shogun/.cache/carbon/wpscale/" + filename.replace(/\./g, "_") + ".jpg"
        
        return "file://" + safeScaled
    }

    /* ── Config Watcher (carbon-bar-mode.json) ─────────────────────── */
    FileView {
        id: modeConfigWatcher
        path: root.modeConfigFile
        watchChanges: true
        printErrors: false
        onFileChanged: {
            modeConfigWatcher.reload()
        }
        onLoaded: root.loadConfig()
    }

    function loadConfig() {
        try {
            const raw = modeConfigWatcher.text().trim()
            if (!raw) return
            const cfg = JSON.parse(raw)
            if (cfg.wallpaperAnimation) {
                root.animType = cfg.wallpaperAnimation
            }
            if (cfg.wallpaperDuration && cfg.wallpaperDuration > 100) {
                root.animDuration = cfg.wallpaperDuration
            }
        } catch (e) {}
    }

    /* ── State Watcher (current_wallpaper_path) ────────────────────── */
    FileView {
        id: stateWatcher
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: {
            stateWatcher.reload()
        }
        onLoaded: {
            const p = stateWatcher.text().trim()
            if (p && !root.currentWpPath) {
                root.initWallpaper(p)
            } else if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                root.applyNewWallpaper(p)
            }
        }
    }

    /* Fallback polling in case external tools change symlink directly */
    Process {
        id: wpReader
        command: ["sh", "-c", "readlink -f \"$HOME/.config/hypr/current_wallpaper\" 2>/dev/null || echo \"\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = wpReader.stdout.text.toString().trim()
                if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                    console.log("[WallpaperMod] wpReader detected new wallpaper:", p)
                    root.applyNewWallpaper(p)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!wpReader.running && !root.isAnimating) {
                wpReader.running = true
            }
        }
    }

    /* ── Initial Load ─────────────────────────────────────────────── */
    function initWallpaper(path) {
        if (!path) return
        console.log("[WallpaperMod] initWallpaper:", path)
        root.currentWpPath = path
        root.activeBuffer = "A"
        const type = getWallpaperType(path)

        if (type === "image") {
            bufA.source = resolveWpUrl(path)
            bufA.opacity = 1.0
            bufA.scale = 1.0
            bufA.x = 0
            bufA.visible = true
            bufB.visible = false
            imageContainer.opacity = 1.0
            imageContainer.visible = true
        } else if (type === "video") {
            videoPlayer.source = "file://" + path
            videoPlayer.play()
            videoOutput.opacity = 1.0
            videoOutput.visible = true
        } else if (type === "gif") {
            gifPlayer.source = "file://" + path
            gifPlayer.opacity = 1.0
            gifPlayer.visible = true
        } else if (type === "carbon-live") {
            carbonLiveBg.opacity = 1.0
            carbonLiveBg.visible = true
        }
    }

    /* ── Apply New Wallpaper with Smooth Animation ────────────────── */
    function applyNewWallpaper(newPath) {
        if (!newPath || newPath === root.currentWpPath) return
        if (newPath === root.pendingNewPath) return
        console.log("[WallpaperMod] applyNewWallpaper:", newPath, "from current:", root.currentWpPath)

        const newType = getWallpaperType(newPath)
        const oldType = getWallpaperType(root.currentWpPath)

        root.pendingNewPath = newPath

        if (newType === "image" && (oldType === "image" || !root.currentWpPath)) {
            // Dual-buffer Image-to-Image transition
            const incoming = (root.activeBuffer === "A" ? bufB : bufA)
            incoming.opacity = 0.0
            incoming.visible = true
            incoming.source = resolveWpUrl(newPath)
            console.log("[WallpaperMod] Set incoming source to:", incoming.source, "status is:", incoming.status)

            if (incoming.status === Image.Ready) {
                root.startImageTransition()
            }
        } else {
            root.startCrossTypeTransition(newPath, newType, oldType)
        }
    }

    /* ── Static Image-to-Image Animation Trigger ─────────────────── */
    function startImageTransition() {
        if (!root.pendingNewPath) return
        const incoming = (root.activeBuffer === "A" ? bufB : bufA)
        const outgoing = (root.activeBuffer === "A" ? bufA : bufB)
        console.log("[WallpaperMod] >>> startImageTransition! Incoming buffer:", (root.activeBuffer === "A" ? "B" : "A"), "animType:", root.animType)

        if (transitionAnim.running) {
            transitionAnim.stop()
        }

        // Set incoming starting transform based on animation type
        incoming.opacity = 0.0
        if (root.animType === "cinematic") {
            incoming.scale = 1.06
            incoming.x = 0
            incoming.y = 0
        } else if (root.animType === "slide-left") {
            incoming.scale = 1.0
            incoming.x = root.width
            incoming.y = 0
        } else if (root.animType === "slide-right") {
            incoming.scale = 1.0
            incoming.x = -root.width
            incoming.y = 0
        } else if (root.animType === "zoom-out") {
            incoming.scale = 0.94
            incoming.x = 0
            incoming.y = 0
        } else { // "crossfade"
            incoming.scale = 1.0
            incoming.x = 0
            incoming.y = 0
        }
        incoming.visible = true
        imageContainer.visible = true
        imageContainer.opacity = 1.0

        // Configure dynamic animation targets and endpoints
        animInOpacity.from = 0.0
        animInOpacity.to = 1.0
        animInScale.from = incoming.scale
        animInScale.to = 1.0
        animInX.from = incoming.x
        animInX.to = 0

        animOutOpacity.from = outgoing.opacity
        animOutOpacity.to = 0.0
        animOutScale.from = outgoing.scale
        animOutScale.to = (root.animType === "cinematic" ? 0.96 : (root.animType === "zoom-out" ? 1.05 : 1.0))
        animOutX.from = outgoing.x
        animOutX.to = (root.animType === "slide-left" ? -root.width * 0.35 : (root.animType === "slide-right" ? root.width * 0.35 : 0))

        transitionAnim.incomingTarget = incoming
        transitionAnim.outgoingTarget = outgoing
        root.isAnimating = true
        transitionAnim.start()
    }

    /* ── Cross-Type (Image <-> Video/GIF/Live) Transition ─────────── */
    function startCrossTypeTransition(newPath, newType, oldType) {
        root.isAnimating = true

        if (newType === "video") {
            videoPlayer.source = "file://" + newPath
            videoPlayer.play()
            videoOutput.visible = true
            crossFadeAnim.targetIn = videoOutput
        } else if (newType === "gif") {
            gifPlayer.source = "file://" + newPath
            gifPlayer.visible = true
            crossFadeAnim.targetIn = gifPlayer
        } else if (newType === "carbon-live") {
            carbonLiveBg.visible = true
            crossFadeAnim.targetIn = carbonLiveBg
        } else if (newType === "image") {
            const incoming = (root.activeBuffer === "A" ? bufB : bufA)
            incoming.opacity = 1.0
            incoming.scale = 1.0
            incoming.x = 0
            incoming.visible = true
            incoming.source = resolveWpUrl(newPath)
            imageContainer.visible = true
            crossFadeAnim.targetIn = imageContainer
        }

        // Outgoing target
        if (oldType === "video") crossFadeAnim.targetOut = videoOutput
        else if (oldType === "gif") crossFadeAnim.targetOut = gifPlayer
        else if (oldType === "carbon-live") crossFadeAnim.targetOut = carbonLiveBg
        else crossFadeAnim.targetOut = imageContainer

        crossFadeAnim.start()
    }

    /* ── Animation Definitions ───────────────────────────────────── */
    ParallelAnimation {
        id: transitionAnim
        property var incomingTarget: null
        property var outgoingTarget: null

        NumberAnimation {
            id: animInOpacity
            target: transitionAnim.incomingTarget
            property: "opacity"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animInScale
            target: transitionAnim.incomingTarget
            property: "scale"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animInX
            target: transitionAnim.incomingTarget
            property: "x"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: animOutOpacity
            target: transitionAnim.outgoingTarget
            property: "opacity"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animOutScale
            target: transitionAnim.outgoingTarget
            property: "scale"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animOutX
            target: transitionAnim.outgoingTarget
            property: "x"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        onFinished: {
            console.log("[WallpaperMod] >>> transitionAnim finished!")
            if (transitionAnim.outgoingTarget) {
                transitionAnim.outgoingTarget.visible = false
                transitionAnim.outgoingTarget.source = ""
            }
            root.activeBuffer = (root.activeBuffer === "A" ? "B" : "A")
            root.currentWpPath = root.pendingNewPath
            root.pendingNewPath = ""
            root.isAnimating = false
        }
    }

    ParallelAnimation {
        id: crossFadeAnim
        property var targetIn: null
        property var targetOut: null

        NumberAnimation {
            target: crossFadeAnim.targetIn
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: crossFadeAnim.targetOut
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        onFinished: {
            if (crossFadeAnim.targetOut) {
                crossFadeAnim.targetOut.visible = false
                if (crossFadeAnim.targetOut === videoOutput) {
                    videoPlayer.stop()
                    videoPlayer.source = ""
                } else if (crossFadeAnim.targetOut === gifPlayer) {
                    gifPlayer.source = ""
                }
            }
            root.currentWpPath = root.pendingNewPath
            root.pendingNewPath = ""
            root.isAnimating = false
        }
    }

    /* ── Static Image Container (Dual-Buffer Ping-Pong) ───────────── */
    Item {
        id: imageContainer
        anchors.fill: parent
        clip: true
        visible: false
        opacity: 0.0

        Image {
            id: bufA
            anchors.fill: parent
            sourceSize.width: 1920
            sourceSize.height: 1080
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            cache: true
            visible: false
            opacity: 0.0
            scale: 1.0

            onStatusChanged: {
                console.log("[WallpaperMod] bufA statusChanged:", status, "source:", source)
                if (status === Image.Error && source.toString().indexOf("/wpscale/") !== -1 && root.pendingNewPath) {
                    console.log("[WallpaperMod] bufA fallback to raw file:", root.pendingNewPath)
                    source = "file://" + root.pendingNewPath
                    return
                }
                if (status === Image.Ready && root.pendingNewPath && root.pendingNewPath !== root.currentWpPath && root.activeBuffer === "B") {
                    root.startImageTransition()
                }
            }
        }

        Image {
            id: bufB
            anchors.fill: parent
            sourceSize.width: 1920
            sourceSize.height: 1080
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            cache: true
            visible: false
            opacity: 0.0
            scale: 1.0

            onStatusChanged: {
                console.log("[WallpaperMod] bufB statusChanged:", status, "source:", source)
                if (status === Image.Error && source.toString().indexOf("/wpscale/") !== -1 && root.pendingNewPath) {
                    console.log("[WallpaperMod] bufB fallback to raw file:", root.pendingNewPath)
                    source = "file://" + root.pendingNewPath
                    return
                }
                if (status === Image.Ready && root.pendingNewPath && root.pendingNewPath !== root.currentWpPath && root.activeBuffer === "A") {
                    root.startImageTransition()
                }
            }
        }
    }

    /* ── Video Wallpaper (.mp4, .webm) ────────────────────────────── */
    MediaPlayer {
        id: videoPlayer
        videoOutput: videoOutput
        loops: MediaPlayer.Infinite
        audioOutput: null
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: false
        opacity: 0.0
        fillMode: VideoOutput.PreserveAspectCrop
    }

    /* ── Animated GIF Wallpaper (.gif) ────────────────────────────── */
    AnimatedImage {
        id: gifPlayer
        anchors.fill: parent
        visible: false
        opacity: 0.0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    /* ── Native Carbon Live Animated Wallpaper ────────────────────── */
    Rectangle {
        id: carbonLiveBg
        anchors.fill: parent
        color: root.isLightMode ? "#FFFFFF" : "#000000"
        visible: false
        opacity: 0.0

        CarbonLewisWallpaper {
            anchors.centerIn: parent
            isLight: root.isLightMode
        }
    }

    readonly property bool isLightMode: {
        const p = (root.pendingNewPath || root.currentWpPath).toLowerCase()
        return p.includes("white") || p.includes("light")
    }
}
