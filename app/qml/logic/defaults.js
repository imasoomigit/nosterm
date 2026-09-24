/*******************************************************************************
* Defaults + tolerant merging for the settings introduced by the retro
* feature set.  Pure ECMAScript so the round trip can be tested directly.
*******************************************************************************/

function defaults() {
    return {
        // The chrome contract (see chrome.js): full screen shows nothing at
        // all; windowed keeps the menu bar and the right-click menu.
        nostalgicMode: true,
        // On-screen IBM PF/PA key legend.
        showPfKeys: false,
        pfKeys: "",                 // JSON produced by pfkeys.serialize()
        // Audible IBM key click + terminal bell.
        audioEnabled: false,
        keyClick: true,
        keyClickVolume: 0.5,
        keyClickSound: "tick",       // "tick" | "deep" | "deeper"
        bell: true,
        bellVolume: 0.5,
        // iTerm2 style highlight of the row the cursor sits on.
        highlightActiveLine: false,
        activeLineOpacity: 0.18,
        // Block / half block cursor, as on 3270 and PC BIOS screens.
        cursorStyle: "block",       // "block" | "half"

        // Colours of the on-glass PF/PA legend.  The two foregrounds take
        // "" meaning "derive it from the phosphor colour" (the arrow
        // further shades it down, see PfKeyBar.qml); the backgrounds are
        // fully transparent by default, so nothing but the text prints.
        legendTextColor: "",
        legendTextBgColor: "#00000000",
        legendArrowColor: "",
        legendArrowBgColor: "#00000000",

        // Type of the legend: "" follows the screen's own face, and the
        // size is a coefficient of the screen font's pixel size -- 1.0
        // prints the legend at the very size of the terminal's output.
        legendFontFamily: "",
        legendFontScale: 1.0
    }
}

/** A colour setting spelled the way QML reads one: #rgb, #rrggbb, #rrggbbaa. */
function isHexColor(value) {
    return typeof value === "string" &&
            /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value)
}

/** A legend foreground: a hex colour, or "" to follow the phosphor. */
function isFgColor(value) {
    return value === "" || isHexColor(value)
}

/** The bundled keyboard tick samples (see logic/sound.js). */
var CLICK_SOUNDS = ["tick", "deep", "deeper"]

/** Is `value` one of the bundled keyboard tick samples? */
function isClickSound(value) {
    return typeof value === "string" && CLICK_SOUNDS.indexOf(value) !== -1
}

/**
 * Merge a stored (possibly partial, possibly hostile) object onto the defaults.
 * Unknown keys are ignored, wrong types are repaired.
 */
function merge(stored) {
    var out = defaults()
    if (!stored || typeof stored !== "object")
        return out

    if (typeof stored.nostalgicMode === "boolean") out.nostalgicMode = stored.nostalgicMode
    if (typeof stored.showPfKeys === "boolean")    out.showPfKeys = stored.showPfKeys
    if (typeof stored.pfKeys === "string")         out.pfKeys = stored.pfKeys

    if (typeof stored.audioEnabled === "boolean")  out.audioEnabled = stored.audioEnabled
    if (typeof stored.keyClick === "boolean")      out.keyClick = stored.keyClick
    if (typeof stored.bell === "boolean")          out.bell = stored.bell
    if (typeof stored.highlightActiveLine === "boolean")
        out.highlightActiveLine = stored.highlightActiveLine

    out.keyClickVolume = clampNumber(stored.keyClickVolume, out.keyClickVolume, 0, 1)
    out.bellVolume     = clampNumber(stored.bellVolume, out.bellVolume, 0, 1)
    out.activeLineOpacity = clampNumber(stored.activeLineOpacity, out.activeLineOpacity, 0, 1)

    if (stored.cursorStyle === "block" || stored.cursorStyle === "half")
        out.cursorStyle = stored.cursorStyle

    if (isClickSound(stored.keyClickSound))
        out.keyClickSound = stored.keyClickSound

    if (isFgColor(stored.legendTextColor))
        out.legendTextColor = stored.legendTextColor
    if (isHexColor(stored.legendTextBgColor))
        out.legendTextBgColor = stored.legendTextBgColor
    if (isFgColor(stored.legendArrowColor))
        out.legendArrowColor = stored.legendArrowColor
    if (isHexColor(stored.legendArrowBgColor))
        out.legendArrowBgColor = stored.legendArrowBgColor

    if (typeof stored.legendFontFamily === "string")
        out.legendFontFamily = stored.legendFontFamily
    out.legendFontScale = clampNumber(stored.legendFontScale,
                                      out.legendFontScale, 0.4, 3.0)

    return out
}

function clampNumber(value, fallback, min, max) {
    var v = Number(value)
    if (isNaN(v))
        return fallback
    return Math.max(min, Math.min(max, v))
}

/**
 * The IBM extras a profile carries, picked off a *current settings* snapshot
 * (profile save side).  Always all seventeen fields, so a profile recorded
 * today fully describes the mainframe half of the setup -- including the
 * legend colours.  nostalgicMode is deliberately absent: chrome is an
 * application preference, not a look.
 */
function pickIbmExtras(current) {
    var src = current || {}
    return {
        showPfKeys: src.showPfKeys === true,
        pfKeys: typeof src.pfKeys === "string" ? src.pfKeys : "",
        audioEnabled: src.audioEnabled === true,
        keyClick: src.keyClick === true,
        keyClickVolume: clampNumber(src.keyClickVolume, 0.5, 0, 1),
        keyClickSound: isClickSound(src.keyClickSound)
                ? src.keyClickSound : "tick",
        bell: src.bell === true,
        bellVolume: clampNumber(src.bellVolume, 0.5, 0, 1),
        highlightActiveLine: src.highlightActiveLine === true,
        activeLineOpacity: clampNumber(src.activeLineOpacity, 0.18, 0, 1),
        cursorStyle: src.cursorStyle === "half" ? "half" : "block",
        legendTextColor: isFgColor(src.legendTextColor) ? src.legendTextColor : "",
        legendTextBgColor: isHexColor(src.legendTextBgColor)
                ? src.legendTextBgColor : "#00000000",
        legendArrowColor: isFgColor(src.legendArrowColor) ? src.legendArrowColor : "",
        legendArrowBgColor: isHexColor(src.legendArrowBgColor)
                ? src.legendArrowBgColor : "#00000000",
        legendFontFamily: typeof src.legendFontFamily === "string"
                ? src.legendFontFamily : "",
        legendFontScale: clampNumber(src.legendFontScale, 1.0, 0.4, 3.0)
    }
}

/**
 * The IBM extras a stored profile actually specifies (profile load side).
 * Unlike merge() this does NOT fall back to the defaults: a field the
 * profile omits is simply absent, and the caller keeps the current value.
 * That is what lets the older visual-only built-ins load without stomping
 * the user's PF key setup, while "IBM Mainframe" overrides everything.
 * Wrong types are still dropped rather than trusted.
 */
function profileExtras(stored) {
    var out = {}
    if (!stored || typeof stored !== "object")
        return out

    if (typeof stored.showPfKeys === "boolean")    out.showPfKeys = stored.showPfKeys
    if (typeof stored.pfKeys === "string")         out.pfKeys = stored.pfKeys
    if (typeof stored.audioEnabled === "boolean")  out.audioEnabled = stored.audioEnabled
    if (typeof stored.keyClick === "boolean")      out.keyClick = stored.keyClick
    if (typeof stored.bell === "boolean")          out.bell = stored.bell
    if (typeof stored.highlightActiveLine === "boolean")
        out.highlightActiveLine = stored.highlightActiveLine

    if (stored.keyClickVolume !== undefined)
        out.keyClickVolume = clampNumber(stored.keyClickVolume, 0.5, 0, 1)
    if (stored.bellVolume !== undefined)
        out.bellVolume = clampNumber(stored.bellVolume, 0.5, 0, 1)
    if (stored.activeLineOpacity !== undefined)
        out.activeLineOpacity = clampNumber(stored.activeLineOpacity, 0.18, 0, 1)

    if (stored.cursorStyle === "block" || stored.cursorStyle === "half")
        out.cursorStyle = stored.cursorStyle

    if (isClickSound(stored.keyClickSound))
        out.keyClickSound = stored.keyClickSound

    if (isFgColor(stored.legendTextColor))
        out.legendTextColor = stored.legendTextColor
    if (isHexColor(stored.legendTextBgColor))
        out.legendTextBgColor = stored.legendTextBgColor
    if (isFgColor(stored.legendArrowColor))
        out.legendArrowColor = stored.legendArrowColor
    if (isHexColor(stored.legendArrowBgColor))
        out.legendArrowBgColor = stored.legendArrowBgColor

    if (typeof stored.legendFontFamily === "string")
        out.legendFontFamily = stored.legendFontFamily
    if (typeof stored.legendFontScale === "number"
            && !isNaN(stored.legendFontScale))
        out.legendFontScale = clampNumber(stored.legendFontScale, 1.0, 0.4, 3.0)

    return out
}

/** The subset that is persisted, ready to be JSON encoded. */
function serialize(stored) {
    return JSON.stringify(merge(stored))
}

function parse(json) {
    if (json === undefined || json === null || json === "")
        return defaults()
    try {
        return merge(JSON.parse(json))
    } catch (err) {
        return defaults()
    }
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        defaults: defaults,
        merge: merge,
        clampNumber: clampNumber,
        isHexColor: isHexColor,
        isFgColor: isFgColor,
        isClickSound: isClickSound,
        pickIbmExtras: pickIbmExtras,
        profileExtras: profileExtras,
        serialize: serialize,
        parse: parse
    }
}
