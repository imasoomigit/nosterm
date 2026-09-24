/*******************************************************************************
* The one CRT a tab is displayed through.
*
* Before panes existed, each terminal was its own monitor: the shader
* drew the bezel, curved the glass and ran every screen effect over that
* pane's picture.  Splitting therefore split the monitor too -- two
* curved frames side by side, each warping its own half.
*
* This unit turns that around: the panes lay their contents out in a
* stage (the tab's children), the stage is captured as one texture and
* the classic two-pass shader chain runs over the whole picture exactly
* once.  One curvature, one bezel, one set of flicker / noise / bloom /
* burn-in -- divided or not, the monitor stays whole.
*
* Pipeline: stage -> stageSource -> static pass (curve, rgb shift,
* bloom, shine) -> frameBuffer -> dynamic pass (phosphor effects,
* bezel) -> screen.  Identical to the old per-pane chain, just with the
* pane's raw texture replaced by the composed stage texture.
*******************************************************************************/
import QtQuick 2.2
import Qt5Compat.GraphicalEffects

import "utils.js" as Utils

ShaderTerminal {
    id: crt

    /** The picture: the tab's panes and their dividing rule. */
    property Item contentStage

    /** Virtual resolution of the whole picture (the panes summed up). */
    property size contentVirtualResolution: Qt.size(1, 1)

    /** Texture density of the contents (the densest pane). */
    property real contentScale: 1

    readonly property bool loadBloomEffect:
        appSettings.bloom > 0 || appSettings._frameShininess > 0

    opacity: appSettings.windowOpacity * 0.3 + 0.7

    source: stageSource
    burnInEffect: burnIn
    virtualResolution: contentVirtualResolution
    screenResolution: Qt.size(
        terminalWindow.width * Screen.devicePixelRatio * appSettings.windowScaling,
        terminalWindow.height * Screen.devicePixelRatio * appSettings.windowScaling
    )
    bloomSource: bloomSourceLoader.item

    /**
     * The stage as one texture: the monitor's input.  Its density matches
     * the old per-pane capture (virtual pixels times the panes' texture
     * scale), so the shader samples it exactly like it used to sample the
     * pane.
     */
    ShaderEffectSource {
        id: stageSource
        sourceItem: crt.contentStage
        hideSource: true
        textureSize: Qt.size(
            Math.max(1, crt.contentVirtualResolution.width * crt.contentScale),
            Math.max(1, crt.contentVirtualResolution.height * crt.contentScale))
    }

    /**
     * Burn-in over the whole picture, sized like the old per-pane trail
     * was (virtual pixels times texture density, times the quality).
     * Refreshes are driven by the panes: see notePaint().
     */
    Item {
        id: burnInContainer

        property int burnInScaling: crt.contentScale * appSettings.burnInQuality

        width: Math.round(appSettings.lowResolutionFont
               ? crt.virtualResolution.width * Math.max(1, burnInScaling)
               : crt.virtualResolution.width * crt.contentScale * appSettings.burnInQuality)

        height: Math.round(appSettings.lowResolutionFont
                ? crt.virtualResolution.height * Math.max(1, burnInScaling)
                : crt.virtualResolution.height * crt.contentScale * appSettings.burnInQuality)

        BurnInEffect {
            id: burnIn
            contentSource: stageSource
        }
    }

    /** Call when any pane's phosphor painted: keeps the trail moving. */
    function notePaint() {
        if (burnIn.item)
            burnIn.completelyUpdate()
    }

    /**
     * Startup self-check, two seconds in.  The stage-size bindings are
     * the one failure here that no offscreen test can see: if they never
     * resolve, the monitor samples a 1x1 placeholder and the screen is
     * uniformly black -- silent.  So report the size that was reached,
     * and shout when it was never reached.
     */
    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: {
            var v = crt.contentVirtualResolution
            if (v.width <= 1 || v.height <= 1)
                console.warn("CrtUnit: picture size never resolved ("
                             + v + ") -- the stage bindings in "
                             + "TerminalTabs.qml are stuck; the screen "
                             + "would be blank")
            else
                console.log("CrtUnit: stage connected " + v.width + "x"
                            + v.height + " texture "
                            + stageSource.textureSize.width + "x"
                            + stageSource.textureSize.height)
        }
    }

    //  EFFECTS  ////////////////////////////////////////////////////////////////
    Loader {
        id: bloomEffectLoader
        active: crt.loadBloomEffect
        asynchronous: true
        width: crt.width * appSettings.bloomQuality
        height: crt.height * appSettings.bloomQuality

        sourceComponent: FastBlur {
            radius: Utils.lint(16, 64, appSettings.bloomQuality)
            source: stageSource
            transparentBorder: true
        }
    }
    Loader {
        id: bloomSourceLoader
        active: crt.loadBloomEffect
        asynchronous: true
        sourceComponent: ShaderEffectSource {
            id: _bloomEffectSource
            sourceItem: bloomEffectLoader.item
            wrapMode: ShaderEffectSource.Repeat
            hideSource: true
            smooth: true
            visible: false
        }
    }
}
