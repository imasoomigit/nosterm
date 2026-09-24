/*******************************************************************************
* IBM 3270 style PF / PA key model.
*
* Loaded by QML ("import logic/pfkeys.js" as PfKeys) *and* by the Node test
* suite, so plain ECMAScript only.
*
* Reference behaviour we mirror:
*   - Twelve PF keys, PF1..PF12, exactly as on the 3270/3279/3179 keyboards.
*   - Three Program Attention keys, PA1..PA3.  PA1 is the classic TSO
*     "attention" / break key.
*   - Applications assign a *function* to each key and the terminal displays
*     that function as a legend (e.g. "F1=Help F3=Exit").  The legend is
*     informational only: it is not something you click.
*   - IBM PC/3270 default bindings for the PA keys are Ctrl+F1..Ctrl+F3.
*******************************************************************************/

var PF_COUNT = 12
var PA_COUNT = 3
var KEY_COUNT = PF_COUNT + PA_COUNT

/**
 * Catalogue of assignable functions.
 *
 *   pass  - the key is not intercepted at all and is forwarded to the shell
 *           (identical to a terminal without this feature).
 *   app   - an application command (window / tab / settings management).
 *   term  - a synthetic keystroke injected into the terminal.
 *
 * `payload` holds the bytes injected for `term` actions; control characters
 * are written as real control characters (U+0003, U+0015, ...).
 */
var ACTIONS = [
    { id: "pass",        label: "Off",         kind: "pass", payload: "" },
    // --- the window / menu functions the PF panel is made of -------------
    { id: "help",        label: "Help",        kind: "app",  payload: "" },
    { id: "splitVertical", label: "Split Vertical",  kind: "app", payload: "" },
    { id: "splitHorizontal", label: "Split Horizontal", kind: "app", payload: "" },
    { id: "newWindow",   label: "New Window",  kind: "app",  payload: "" },
    { id: "nextWindow",  label: "Next Window", kind: "app",  payload: "" },
    { id: "prevWindow",  label: "Previous Window", kind: "app", payload: "" },
    { id: "closeWindow", label: "Close Window",kind: "app",  payload: "" },
    { id: "newTab",      label: "New Tab",     kind: "app",  payload: "" },
    { id: "closeTab",    label: "Close Tab",   kind: "app",  payload: "" },
    { id: "fullscreen",  label: "Exit Full Screen", kind: "app", payload: "" },
    // Screen size as a bindable function, so it also works where a
    // keyboard chord might be swallowed (full screen, a system that owns
    // the modifiers): the same rungs the View menu's Zoom In / Zoom Out
    // climb.  Not on a factory key -- offered in the editor.
    { id: "bigger",      label: "Bigger",     kind: "app",  payload: "" },
    { id: "smaller",     label: "Smaller",    kind: "app",  payload: "" },
    { id: "settings",    label: "Settings",    kind: "app",  payload: "" },
    // SAVE PROFILE: the settings dialog's Save, made bindable like every
    // other menu function.  Not on a factory key -- offered in the editor,
    // the way FILEL and XEDIT are.
    { id: "saveProfile", label: "Save Profile", kind: "app", payload: "" },
    { id: "toggleKeySound", label: "Key Sound", kind: "app", payload: "" },
    { id: "quit",        label: "Exit",        kind: "app",  payload: "" },
    { id: "copy",        label: "Copy",        kind: "app",  payload: "" },
    { id: "paste",       label: "Paste",       kind: "app",  payload: "" },
    // 3270 Attention: interrupts the running task, i.e. sends SIGINT (Ctrl+C).
    { id: "interrupt",   label: "Attention",   kind: "term", payload: "\u0003" },
    // 3270 ERASE INPUT: POSIX equivalent clears the current input line (Ctrl+U).
    { id: "eraseInput",  label: "Erase Input", kind: "term", payload: "\u0015" },
    // FILEL: the classic file/directory listing.  Resolved per platform by
    // commandFor() below: ls(1) on unix, dir on Windows because it answers
    // to both cmd.exe and PowerShell (PowerShell aliases it to
    // Get-ChildItem), so one command covers both shells.
    { id: "fileList",    label: "FILEL",       kind: "term", payload: "" },
    // XEDIT: the mainframe line editor, so open an editor right here.
    // Resolved per platform: vi on unix (POSIX guarantees it exists),
    // notepad on Windows (works in cmd.exe and PowerShell alike).
    { id: "xedit",       label: "XEDIT",       kind: "term", payload: "" },
    { id: "sendText",    label: "Send Text",   kind: "term", payload: "" }
]

function actionById(id) {
    for (var i = 0; i < ACTIONS.length; i++) {
        if (ACTIONS[i].id === id)
            return ACTIONS[i]
    }
    return null
}

function isKnownAction(id) { return actionById(id) !== null }

function actionIds() {
    var out = []
    for (var i = 0; i < ACTIONS.length; i++)
        out.push(ACTIONS[i].id)
    return out
}

/** Default key sequence for a slot: "F1".."F12", then Ctrl+F1..Ctrl+F3. */
function defaultKeyFor(index) {
    if (index < PF_COUNT)
        return "F" + (index + 1)
    // IBM PC/3270 defaults: PA1 = Ctrl+F1, PA2 = Ctrl+F2, PA3 = Ctrl+F3.
    return "Ctrl+F" + (index - PF_COUNT + 1)
}

function defaultLabelFor(index) {
    return index < PF_COUNT ? ("PF" + (index + 1)) : ("PA" + (index - PF_COUNT + 1))
}

/**
 * The factory PF panel: window and menu functions, laid out the way the
 * mainframe panels showed theirs (PF1 = Help, PF2 = Split, PF3 = End of a
 * screen, ..., PF12 = a fresh window).  Shaped after the official IBM
 * defaults -- ISPF F1=Help F2=Split F3=Exit F9=Swap, CMS F3=Quit F4=Return
 * -- with the slots this terminal cares about filled from the menu.
 *
 * Shell commands are deliberately NOT part of it: the CMS command set
 * (FILEL, HELP, ...) lives in the shell alias block (logic/aliases.js), so
 * the panel stays functions-only exactly like ISPF / CMS panels did.
 */
var PF_DEFAULT_ACTIONS = [
    "help",            // PF1  (ISPF F1 = Help)
    "splitVertical",   // PF2  (ISPF F2 = Split)
    "closeWindow",     // PF3  (ISPF F3 = End / Exit)
    "nextWindow",      // PF4
    "prevWindow",      // PF5
    "splitHorizontal", // PF6
    "toggleKeySound",  // PF7  key click on / off
    "settings",        // PF8
    "newTab",          // PF9
    "quit",            // PF10 (EXIT)
    "fullscreen",      // PF11 (exit full screen)
    "newWindow"        // PF12 (NEW WINDOW)
]

/**
 * Defaults: every PF key carries a menu function, PA1 is the 3270
 * attention/break key, PA2 and PA3 ship unassigned.
 */
function defaultAssignments() {
    var out = []
    for (var i = 0; i < KEY_COUNT; i++) {
        var action = "pass"
        if (i < PF_COUNT)
            action = PF_DEFAULT_ACTIONS[i]
        else if (i === PF_COUNT)     // PA1
            action = "interrupt"
        out.push({
            key: defaultKeyFor(i),
            label: defaultLabelFor(i),
            action: action,
            payload: ""
        })
    }
    return out
}

/** Coerce anything into a well formed assignment array of KEY_COUNT entries. */
function normalize(assignments) {
    var defs = defaultAssignments()
    var src = (assignments && assignments.length !== undefined) ? assignments : []
    var out = []

    for (var i = 0; i < KEY_COUNT; i++) {
        var given = (i < src.length && src[i] && typeof src[i] === "object") ? src[i] : null
        var def = defs[i]

        var action = (given && given.action !== undefined) ? String(given.action) : def.action
        if (!isKnownAction(action))
            action = def.action

        var key = (given && given.key !== undefined && String(given.key).length > 0)
                ? String(given.key) : def.key

        var label = (given && given.label !== undefined && String(given.label).length > 0)
                ? String(given.label) : def.label

        var payload = (given && given.payload !== undefined) ? String(given.payload) : ""

        out.push({ key: key, label: label, action: action, payload: payload })
    }
    return out
}

/** The legend shown on screen: the key's function, or "" when passed through. */
function legend(assignment) {
    if (!assignment)
        return ""
    var act = actionById(assignment.action)
    if (!act || act.kind === "pass")
        return ""
    // "Send Text" always shows what it sends; everything else shows its name.
    if (act.id === "sendText")
        return assignment.payload ? String(assignment.payload) : act.label
    return act.label
}

/**
 * Does this slot need a QML Shortcut registered?
 *   - "pass" must NOT be registered, so the raw key reaches the shell.
 *   - everything else is registered, which also prevents the terminal widget
 *     from consuming the keystroke (Qt resolves ShortcutOverride first).
 */
function intercepts(assignment) {
    var act = assignment ? actionById(assignment.action) : null
    return !!act && act.kind !== "pass"
}

/** Is this slot a plain PF key (F1..F12) rather than a PA key? */
function isPf(index) { return index >= 0 && index < PF_COUNT }

/** Human readable slot name, used by the settings editor and tests. */
function slotName(index) { return defaultLabelFor(index) }

/**
 * Actions that may legally be bound to `index`, given a map of action ids the
 * OS already owns (action id -> true) which we must not steal.
 */
function assignableActions(index, ownedByOs) {
    var out = []
    for (var i = 0; i < ACTIONS.length; i++) {
        var act = ACTIONS[i]
        if (act.kind === "pass") {
            out.push(act)                      // "Off" is always available
        } else if (ownedByOs && ownedByOs[act.id]) {
            continue                           // reserved elsewhere
        } else {
            out.push(act)
        }
    }
    return out
}

/** JSON round trip helpers, tolerant of garbage input. */
function serialize(assignments) {
    return JSON.stringify(normalize(assignments))
}

function parse(json) {
    if (json === undefined || json === null || json === "")
        return defaultAssignments()
    if (typeof json !== "string")
        return normalize(json)
    try {
        return normalize(JSON.parse(json))
    } catch (err) {
        return defaultAssignments()
    }
}

/** True when at least one slot actually intercepts a key. */
function anyIntercepting(assignments) {
    var list = normalize(assignments)
    for (var i = 0; i < list.length; i++) {
        if (intercepts(list[i]))
            return true
    }
    return false
}

/** Groups of slot indexes that claim the same key sequence. */
function collisions(assignments) {
    var list = normalize(assignments)
    var seen = {}
    var out = []
    for (var i = 0; i < list.length; i++) {
        var k = String(list[i].key).toLowerCase()
        if (seen[k] === undefined)
            seen[k] = []
        seen[k].push(i)
    }
    for (var key in seen) {
        if (Object.prototype.hasOwnProperty.call(seen, key) && seen[key].length > 1)
            out.push(seen[key])
    }
    return out
}

/**
 * Decode the payloads we inject into the terminal.
 * Supports \n \r \t \e and \\, which is all a macro realistically needs.
 */
function decodePayload(text) {
    if (text === undefined || text === null)
        return ""
    var out = ""
    var s = String(text)
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i)
        if (c !== "\\" || i + 1 >= s.length) {
            out += c
            continue
        }
        var next = s.charAt(++i)
        if (next === "n") out += "\n"
        else if (next === "r") out += "\r"
        else if (next === "t") out += "\t"
        else if (next === "e") out += "\u001b"
        else if (next === "\\") out += "\\"
        else { out += "\\"; out += next }
    }
    return out
}

/**
 * Text actually handed to the terminal for a macro.  Decodes the escapes and
 * turns a line feed into a carriage return: pressing Enter on a terminal
 * sends CR, so a macro that spells out \n has to behave like the Enter key.
 */
function macroText(text) {
    return decodePayload(text).replace(/\n/g, "\r")
}

/**
 * The bytes a catalog action injects for the platform we are running on.
 * `os` is Qt.platform.os ("windows"/"win32", "osx", "x11", ...).  Actions whose
 * payload is fixed (Attention, Erase Input) return "" and the caller falls
 * back to the catalog payload.
 *
 *   FILEL -> ls on unix; dir on Windows, because dir answers to cmd.exe
 *            AND to PowerShell (it is an alias for Get-ChildItem there), so
 *            one command covers both shells exactly as requested.
 *   XEDIT -> vi on unix (POSIX guarantees vi exists, so XEDIT always finds
 *            an editor just like on the mainframe); notepad on Windows,
 *            which both shells understand too.
 */
function commandFor(id, os) {
    // Qt spells the platform differently across versions ("win32" or
    // "windows"), and the caller passes Qt.platform.os straight through,
    // so accept every common spelling rather than trusting one of them.
    var s = String(os === undefined || os === null ? "" : os).toLowerCase()
    var windows = s === "win32" || s === "windows" || s === "win" || s === "win64"
    if (id === "fileList")
        return windows ? "dir\r" : "ls\r"
    if (id === "xedit")
        return windows ? "notepad\r" : "vi\r"
    return ""
}

/**
 * Quote one argument for the shell that runs HELP's command: single quotes,
 * with the classic '\'' dance for any quote inside the topic.
 */
function shellQuote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'"
}

/**
 * The command the HELP input box (PF1 or the Help menu) hands to the
 * terminal.  A blank topic lists the whole manual with `man -k .` -- the
 * way CMS HELP with no operand listed the command set -- and any other
 * topic opens that manual page.  CR-terminated, like commandFor().
 */
function helpCommand(topic) {
    var t = (topic === undefined || topic === null) ? "" : String(topic)
    t = t.replace(/^\s+|\s+$/g, "")
    if (t.length === 0)
        return "man -k .\r"
    return "man -- " + shellQuote(t) + "\r"
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        PF_COUNT: PF_COUNT,
        PA_COUNT: PA_COUNT,
        KEY_COUNT: KEY_COUNT,
        ACTIONS: ACTIONS,
        actionById: actionById,
        isKnownAction: isKnownAction,
        actionIds: actionIds,
        defaultKeyFor: defaultKeyFor,
        defaultLabelFor: defaultLabelFor,
        defaultAssignments: defaultAssignments,
        normalize: normalize,
        legend: legend,
        intercepts: intercepts,
        isPf: isPf,
        slotName: slotName,
        assignableActions: assignableActions,
        serialize: serialize,
        parse: parse,
        anyIntercepting: anyIntercepting,
        collisions: collisions,
        decodePayload: decodePayload,
        macroText: macroText,
        commandFor: commandFor,
        shellQuote: shellQuote,
        helpCommand: helpCommand,
        PF_DEFAULT_ACTIONS: PF_DEFAULT_ACTIONS
    }
}
