/*******************************************************************************
* Platform-aware key sequence resolution.
*
* This file is loaded both by QML (import "logic/platform.js" as Platform) and
* by the Node test suite (require(...)).  It must therefore stay free of any
* Qt/QML specific construct: plain ECMAScript only, no ".pragma" directives.
*******************************************************************************/

/** Normalize the many spellings of an OS name onto three canonical buckets. */
function normalizeOs(os) {
    if (os === undefined || os === null)
        return "linux"

    var s = String(os).toLowerCase()
    if (s === "osx" || s === "macos" || s === "mac" || s === "darwin" || s === "ios")
        return "mac"
    if (s === "win32" || s === "windows" || s === "win" || s === "win64")
        return "windows"
    // "x11", "wayland", "linux", "freebsd", "unix", ...
    return "linux"
}

function isMac(os) { return normalizeOs(os) === "mac" }

/**
 * The application-wide key map.
 *
 * Every entry uses the sequence that is conventional on that platform, so the
 * same *function* always lives on the same *place* as it does natively:
 *
 *   mac     Cmd+N new window, Cmd+W close tab, Cmd+Shift+W close window,
 *           Cmd+` next window, Cmd+, settings, Cmd+Q quit.
 *   win     Ctrl+Shift+N new window, Ctrl+W close tab,
 *           Ctrl+Shift+W close window, Alt+` next window,
 *           Ctrl+, settings, Ctrl+Shift+Q quit.
 *   linux   Identical to Windows; Alt+` is also the GNOME/KDE
 *           "switch windows of this application" binding.
 *
 * @param {string} os  Qt.platform.os value ("osx", "win32", "x11", ...).
 * @return {Object<string,string>}
 */
function sequences(os) {
    var mac = isMac(os)

    return {
        newWindow:    mac ? "Meta+N"        : "Ctrl+Shift+N",
        closeWindow:  mac ? "Meta+Shift+W"  : "Ctrl+Shift+W",
        newTab:       mac ? "Meta+T"        : "Ctrl+Shift+T",
        closeTab:     mac ? "Meta+W"        : "Ctrl+W",
        // Cmd+` / Alt+` is the native "next window of this application"
        // binding on macOS and on GNOME/KDE respectively.
        nextWindow:   mac ? "Meta+`"        : "Alt+`",
        prevWindow:   mac ? "Meta+Shift+`"  : "Alt+Shift+`",
        fullscreen:   "StandardKey.FullScreen",
        settings:     mac ? "Meta+,"        : "Ctrl+,",
        quit:         mac ? "StandardKey.Quit" : "Ctrl+Shift+Q",
        copy:         mac ? "StandardKey.Copy" : "Ctrl+Shift+C",
        paste:        mac ? "StandardKey.Paste": "Ctrl+Shift+V",
        // Qt's ZoomIn binding ("Ctrl++") only matches a keypress whose
        // Shift has been folded into the key, and it never matches the
        // plain "=" key -- on a real US keyboard neither press reaches it.
        // It stays the *displayed* binding; alternates() below hands the
        // physical spellings to the window (see TerminalWindow.qml).
        zoomIn:       mac ? "StandardKey.ZoomIn" : "Ctrl++",
        zoomOut:      "StandardKey.ZoomOut"
    }
}

/** Resolve one sequence, falling back to a sensible default if unknown. */
function sequence(os, name) {
    var map = sequences(os)
    if (map[name] === undefined)
        return ""
    return map[name]
}

/**
 * Extra sequences that also trigger a function, on top of the one shown
 * in the menu.
 *
 * zoomIn: Qt's StandardKey.ZoomIn resolves to "Ctrl++", which only ever
 * matches a keypress whose Shift was folded away -- while pressing the
 * "+" key actually delivers Ctrl+Shift+'+' and the "=" key delivers
 * Ctrl+'=' (verified against QKeySequence::matches on Qt 6.8).  Both
 * physical spellings are therefore bound by hand next to the standard
 * one, so "bigger fonts" always has a key.  Every spelling returned here
 * uses a different key or modifier set than the primary binding, so no
 * single keypress can ever match two of them at once.
 */
function alternates(os, name) {
    if (name !== "zoomIn")
        return []
    return isMac(os) ? ["Meta+Shift++", "Meta+="]
                     : ["Ctrl+Shift++", "Ctrl+="]
}

/**
 * Every physical spelling that must hold a *live* shortcut for a zoom key
 * -- the guaranteed floor under the menu Action, whose own registration
 * resolves through a window context that could fail to match in full
 * screen (TerminalWindow.qml registers these Application-scoped).
 *
 * Unlike alternates() this list deliberately INCLUDES the standard
 * spelling: Qt prefers the Action when both hold the same sequence (no
 * ambiguity deadlock, verified on Qt 6.8), so the overlap is safe, and
 * the Shortcut is what still works precisely when the Action cannot.
 * No two spellings in the list can match one keypress: each uses a
 * different key or modifier set.
 *
 *   zoomIn:   Ctrl+'+' (numpad / direct-Plus keyboards), Ctrl+Shift+'+'
 *             and Ctrl+'=' (US "=").
 *   zoomOut:  Ctrl+'-'.
 *
 * macOS carries BOTH modifier families: Cmd is the convention the menu
 * shows and StandardKey.ZoomIn binds it, while the plain Ctrl spellings
 * are registered next to it because Cmd combinations are exactly what
 * the system and the (auto-hidden, full screen) native menu bar tend to
 * own -- and a Ctrl chord is never claimed by macOS.
 */
function zoomSpellings(os, name) {
    var ctrl = isMac(os)
    if (name === "zoomIn")
        return ctrl ? ["Meta++", "Meta+Shift++", "Meta+=",
                       "Ctrl++", "Ctrl+Shift++", "Ctrl+="]
                    : ["Ctrl++", "Ctrl+Shift++", "Ctrl+="]
    if (name === "zoomOut")
        return ctrl ? ["Meta+-", "Ctrl+-"] : ["Ctrl+-"]
    return []
}

/**
 * Sequences we claim must never be swallowed by the OS in a way that makes the
 * app unusable.  Returns the subset of `names` that Qt can register at all
 * (non-empty, well formed).
 */
function usableSequences(os, names) {
    var out = {}
    for (var i = 0; i < names.length; i++) {
        var s = sequence(os, names[i])
        if (s && s.length > 0)
            out[names[i]] = s
    }
    return out
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        normalizeOs: normalizeOs,
        isMac: isMac,
        sequences: sequences,
        sequence: sequence,
        alternates: alternates,
        zoomSpellings: zoomSpellings,
        usableSequences: usableSequences
    }
}
