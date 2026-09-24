/*******************************************************************************
* The built-in "IUT-MarkazMohasebat" mainframe profile.
*
* Kept as pure functions rather than a ListElement literal for two reasons:
*   - its PF/PA assignments come straight from pfkeys.js (passed in, so this
*     file stays import-free and loads both under QML and under Node), and
*   - everything can be asserted directly by the test suite.
*
* Visual half: an exact copy of the built-in "IBM 3278 Reborn" look -- the
* S/370 era display station: green phosphor on black, the real 3278 face,
* flat glass with no consumer CRT wobble -- with the one difference the
* real terminal had: a blinking block cursor.
*
* Mainframe half: everything IBM switched on at once -- the PF/PA legend on
* screen, the factory key assignments (window and menu functions, the way
* ISPF/CMS panels showed theirs; shell commands such as FILEL are NOT put
* on PF keys -- they live in the shell alias block instead), the IBM key
* click and bell, the 3270 block cursor and the active-line band.
*
* @param {Array} assignments  PfKeys.defaultAssignments() (or any list)
* @return {Array} a defensive copy of the assignments, unchanged
*/
function mainframeKeys(assignments) {
    var out = []
    var src = (assignments && assignments.length !== undefined) ? assignments : []
    for (var i = 0; i < src.length; i++) {
        var a = src[i] || {}
        out.push({
            key: a.key,
            label: a.label,
            action: a.action,
            payload: a.payload
        })
    }
    return out
}

/**
 * @param {string} pfKeysJson  PfKeys.serialize(mainframeKeys(defaults))
 * @return {Object} a complete profile object
 */
function mainframeProfile(pfKeysJson) {
    return {
        // --- look: IBM 3278 Reborn, green over black, S/370 station ------
        ambientLight: 0.2,
        backgroundColor: "#000000",
        bloom: 0.2,
        brightness: 0.5,
        burnIn: 0.5,
        chromaColor: 0,
        // One phosphor on black: monochrome simulation, the way the real
        // display station printed it.  See logic/colormode.js.
        colorMode: "monochrome",
        contrast: 0.8,
        flickering: 0,
        fontColor: "#3cff7a",
        fontName: "IBM_3278",
        fontSource: 0,
        fontWidth: 1,
        lineSpacing: 0.1,
        glowingLine: 0,
        horizontalSync: 0,
        jitter: 0,
        rasterization: 4,
        rgbShift: 0,
        saturationColor: 0,
        screenCurvature: 0,
        screenRadius: 0,
        staticNoise: 0,
        windowOpacity: 1,
        margin: 0.1,
        // The 3270-family cursor is a block that blinks.
        blinkingCursor: true,
        frameSize: 0,
        frameColor: "#ffffff",
        frameShininess: 0.2,

        // --- the mainframe half: all IBM extras active --------------------
        showPfKeys: true,
        pfKeys: typeof pfKeysJson === "string" ? pfKeysJson : "",
        audioEnabled: true,
        keyClick: true,
        keyClickVolume: 0.5,
        keyClickSound: "tick",
        bell: true,
        bellVolume: 0.5,
        highlightActiveLine: true,
        activeLineOpacity: 0.18,
        cursorStyle: "block",
        // Legend colours: "" follows the profile's own phosphor, so the
        // legend prints in the same green as the screen, and the chips
        // stay clear -- nothing on this panel but the words themselves.
        legendTextColor: "",
        legendTextBgColor: "#00000000",
        legendArrowColor: "",
        legendArrowBgColor: "#00000000",
        // Type: the screen's own face at the screen's own size, so the
        // legend prints as large as the output it captions.
        legendFontFamily: "",
        legendFontScale: 1.0
    }
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        mainframeKeys: mainframeKeys,
        mainframeProfile: mainframeProfile
    }
}
