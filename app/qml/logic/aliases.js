/*******************************************************************************
* CMS command aliases, kept in the shell profile files.
*
* Loaded both by QML (import "logic/aliases.js" as Aliases) and by the Node
* test suite (require(...)), so it must stay plain ECMAScript: no Qt, no
* imports of other modules.
*
* The application maintains ONE marked, removable block in the user's shell
* startup files so the CMS functions of the VM/370 command set become
* ordinary typed commands:
*
*     FILEL, FILELIST  ->  ls            LISTFILE  ->  ls -l
*     COPYFILE         ->  cp            ERASE     ->  rm -i
*     RENAME           ->  mv            TYPE      ->  cat
*     ACCESS           ->  mount         RELEASE   ->  umount
*     FORMAT           ->  mkfs
*
* HELP             ->  man           (Linux and macOS only)
*
* HELP is a small shell *function*, not an alias, because it has to prompt:
* type HELP (or help) and press Enter with a topic to read that manual
* page, or with a blank topic to list the whole manual with `man -k .`,
* the way CMS HELP listed the command set.  It shadows the bash builtin of
* the same name on purpose.  Windows (Git Bash) does not get it: HELP and
* the prompt are written only for Linux and macOS.
*
* SAVE, FILE and FFILE belong to XEDIT itself (when the editor is assigned
* to a key), so they are named in the block but deliberately not aliased.
*
* Target files, exactly as requested -- "a bashrc or a profile file" on
* Linux and macOS, and on Windows the SAME ~/.bashrc because the app rides
* on top of Git Bash, which reads it too:
*
*   ~/.bashrc          always (created when missing)
*   ~/.zshrc           on macOS -- the default shell since Catalina, so
*                      without it the aliases would never load there -- and
*                      anywhere else it already exists
*   ~/.bash_profile,
*   ~/.profile         only when they already exist; we never invent
*                      profile files the user never had
*
* upsert() is idempotent (a second run rewrites the same bytes, and a
* duplicated or hand-moved block collapses back to one), strip() removes
* every trace when the setting is switched off.
*******************************************************************************/

var START_MARKER = "# >>> nostalgic-terminal CMS aliases (managed block) >>>"
var END_MARKER = "# <<< nostalgic-terminal CMS aliases <<<"

/** The CMS command set as [shell alias name, command] pairs. */
var ALIASES = [
    ["FILEL", "ls"],
    ["FILELIST", "ls"],
    ["LISTFILE", "ls -l"],
    ["COPYFILE", "cp"],
    ["ERASE", "rm -i"],
    ["RENAME", "mv"],
    ["TYPE", "cat"],
    ["ACCESS", "mount"],
    ["RELEASE", "umount"],
    ["FORMAT", "mkfs"]
]

/** Every spelling of Windows that can reach us (Qt ships several). */
function isWindows(os) {
    var s = String(os === undefined || os === null ? "" : os).toLowerCase()
    return s === "win32" || s === "windows" || s === "win" || s === "win64"
}

/**
 * The managed block as text (no trailing newline; upsert adds it).
 *
 * @param {string} os  Qt.platform.os value; HELP and its prompt are
 *                     written for Linux and macOS only, so a Windows
 *                     (Git Bash) block simply omits them.
 */
function block(os) {
    var lines = [START_MARKER]
    lines.push("# CMS command set (IBM VM/370 CMS Command Reference).")
    for (var i = 0; i < ALIASES.length; i++)
        lines.push("alias " + ALIASES[i][0] + "='" + ALIASES[i][1] + "'")

    if (!isWindows(os)) {
        lines.push("# HELP -> man: a topic opens its manual page, a blank")
        lines.push("# topic lists the whole manual with `man -k .`.")
        lines.push("help() {")
        lines.push("    printf 'Topic (blank = list all): '")
        lines.push("    topic=''")
        lines.push("    IFS= read -r topic || true")
        lines.push("    if [ -n \"$topic\" ]; then")
        lines.push("        man -- \"$topic\"")
        lines.push("    else")
        lines.push("        man -k .")
        lines.push("    fi")
        lines.push("}")
        lines.push("alias HELP='help'")
        lines.push("")
    }

    lines.push("# SAVE, FILE and FFILE belong to XEDIT itself, not the shell.")
    lines.push(END_MARKER)
    return lines.join("\n")
}

/** Every spelling of macOS/OS X that can reach us. */
function isMacOs(os) {
    var s = String(os === undefined || os === null ? "" : os).toLowerCase()
    return s === "osx" || s === "macos" || s === "mac" || s === "darwin"
}

function escapeRe(text) {
    return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

/** Matches one whole managed block, including its trailing newline. */
function blockRegex(flags) {
    return new RegExp(escapeRe(START_MARKER) + "[\\s\\S]*?" +
                      escapeRe(END_MARKER) + "\\n?", flags || "")
}

/**
 * Merge the block into a profile file's content: drop every existing copy
 * (stale, duplicated, hand-moved) and append exactly one fresh block at the
 * end.  Returns the new content; callers write only when it differs.
 */
function upsert(content, text) {
    var base = typeof content === "string" ? content : ""
    var blockText = typeof text === "string" && text.length > 0 ? text : block()

    base = base.replace(blockRegex("g"), "")
    if (base.length === 0)
        return blockText + "\n"
    if (base.charAt(base.length - 1) !== "\n")
        base += "\n"
    return base + blockText + "\n"
}

/** Remove every managed block; content without one passes through as-is. */
function strip(content) {
    var base = typeof content === "string" ? content : ""
    return base.replace(blockRegex("g"), "")
}

/**
 * Which profile files to write for this platform.
 *
 * @param {string} os      Qt.platform.os value ("linux", "osx", "windows", ...)
 * @param {Function} exists  probe: exists(basename) -> bool
 * @return {Array<string>} ordered basenames, never duplicated
 */
function targets(os, exists) {
    var probe = typeof exists === "function" ? exists : function () { return false }
    var out = [".bashrc"]

    if ((isMacOs(os) || probe(".zshrc")) && out.indexOf(".zshrc") === -1)
        out.push(".zshrc")
    if (probe(".bash_profile") && out.indexOf(".bash_profile") === -1)
        out.push(".bash_profile")
    if (probe(".profile") && out.indexOf(".profile") === -1)
        out.push(".profile")

    return out
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        START_MARKER: START_MARKER,
        END_MARKER: END_MARKER,
        ALIASES: ALIASES,
        isMacOs: isMacOs,
        isWindows: isWindows,
        block: block,
        upsert: upsert,
        strip: strip,
        targets: targets
    }
}
