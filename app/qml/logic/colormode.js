/*******************************************************************************
 * Monochrome simulation vs. true TTY colour.
 *
 * The switch decides what the CRT shader does with the picture the terminal
 * painted:
 *
 *   "monochrome"  Everything on the glass -- terminal output, the active-line
 *                 band and the PF legend -- collapses onto the profile's one
 *                 phosphor.  The luminance the console colour carried is what
 *                 decides how brightly it burns, so a dim cyan still reads
 *                 dim and a bright red reads bright.
 *
 *   "color"       The texture keeps the hues the tty painted.  Coloured
 *                 output prints in its own colour; the tty's plain white and
 *                 grey text carries no hue of its own, so it wears the
 *                 profile phosphor instead -- which is what keeps the Font
 *                 colour meaningful while the console's colours come through.
 *
 * The shader variant is chosen from this mode (see ShaderTerminal.qml), and
 * the five monochrome pairs are offered as presets that set the profile's
 * Font colour so the frame, the cursor, the legend and the phosphor all
 * agree.
 *
 * Pure ECMAScript so every decision can be asserted directly by the suite.
 */

var MODE_MONOCHROME = "monochrome"
var MODE_COLOR = "color"

/** Both modes, in the order the settings UI lists them. */
var MODES = [MODE_MONOCHROME, MODE_COLOR]

/** Is `value` one of the two mode names? */
function isValid(value) {
    return typeof value === "string" && MODES.indexOf(value) !== -1
}

/** A mode name, or monochrome for anything at all unexpected. */
function normalize(value) {
    return isValid(value) ? value : MODE_MONOCHROME
}

/** The settings-UI index that shows `value`. */
function modeIndex(value) {
    return normalize(value) === MODE_COLOR ? 1 : 0
}

/** The mode name a settings-UI index stands for. */
function modeAt(index) {
    return index === 1 ? MODE_COLOR : MODE_MONOCHROME
}

/**
 * The mode of a profile recorded before this field existed.  Those carried
 * only the old chroma slider, where 0 meant "one phosphor, none of the
 * console's hue" and 1 meant "as much of it as the phosphor could show".
 * Half way over reads as a colour profile.
 *
 * @param {number|string} chromaValue  the profile's chromaColor
 * @return {string} a mode name
 */
function infer(chromaValue) {
    // Only a number, or something spelled like one: a stray boolean must
    // never be able to promote a profile to colour.
    if (typeof chromaValue !== "number" && typeof chromaValue !== "string")
        return MODE_MONOCHROME
    var v = Number(chromaValue)
    if (isNaN(v))
        return MODE_MONOCHROME
    return v >= 0.5 ? MODE_COLOR : MODE_MONOCHROME
}

/**
 * The five monochrome pairs on offer.  Choosing one sets the profile's Font
 * colour and pins the background to black; the Font picker still allows any
 * custom shade after that.
 */
var PHOSPHORS = [
    { id: "white",  name: "Black/White",
      fontColor: "#ffffff", backgroundColor: "#000000" },
    { id: "green",  name: "Black/Green",
      fontColor: "#3cff7a", backgroundColor: "#000000" },
    { id: "blue",   name: "Black/Blue",
      fontColor: "#7fb4ff", backgroundColor: "#000000" },
    { id: "yellow", name: "Black/Yellow",
      fontColor: "#ffb000", backgroundColor: "#000000" },
    { id: "red",    name: "Black/Red",
      fontColor: "#ff5b4d", backgroundColor: "#000000" }
]

/** The preset names, ready to be handed to a ComboBox as its model. */
function phosphorNames() {
    var names = []
    for (var i = 0; i < PHOSPHORS.length; i++)
        names.push(PHOSPHORS[i].name)
    return names
}

/**
 * Compare two colour spellings as lowercase #rrggbb.  QML is allowed to
 * write an opaque colour as #aarrggbb, so an ff alpha is dropped; anything
 * that is not a plain colour reads as "" and never matches a preset.
 */
function hex(value) {
    if (typeof value !== "string")
        return ""
    var s = value.replace(/\s+/g, "").toLowerCase()
    if (s.charAt(0) !== "#")
        return ""
    if (s.length === 9 && s.substring(1, 3) === "ff")
        s = "#" + s.substring(3)
    return s.length === 7 ? s : ""
}

/**
 * Which preset the current colours already are.
 *
 * @param {string} fontColor        the profile's raw Font colour
 * @param {string} backgroundColor  the profile's raw Background colour
 * @return {number} index into PHOSPHORS, or -1 for a custom pair
 */
function phosphorIndex(fontColor, backgroundColor) {
    var font = hex(fontColor)
    var background = hex(backgroundColor)
    if (font === "" || background === "")
        return -1
    for (var i = 0; i < PHOSPHORS.length; i++) {
        if (PHOSPHORS[i].fontColor === font
                && PHOSPHORS[i].backgroundColor === background)
            return i
    }
    return -1
}

/**
 * Which shader variant a mode needs: CRT_CHROMA == 1 keeps the console's own
 * hues, == 0 collapses everything onto the phosphor.
 *
 * @param {string} value  a mode name (anything invalid reads monochrome)
 * @return {number} 1 for colour, 0 for monochrome
 */
function shaderChromaFlag(value) {
    return normalize(value) === MODE_COLOR ? 1 : 0
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        MODE_MONOCHROME: MODE_MONOCHROME,
        MODE_COLOR: MODE_COLOR,
        MODES: MODES,
        isValid: isValid,
        normalize: normalize,
        modeIndex: modeIndex,
        modeAt: modeAt,
        infer: infer,
        PHOSPHORS: PHOSPHORS,
        phosphorNames: phosphorNames,
        hex: hex,
        phosphorIndex: phosphorIndex,
        shaderChromaFlag: shaderChromaFlag
    }
}
