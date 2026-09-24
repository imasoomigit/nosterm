/*******************************************************************************
* Window list arithmetic.
*
* Kept pure so the ordering rules can be unit tested without a window system:
* cycling wraps around, and a stale/unknown active index behaves like index 0.
*******************************************************************************/

/** Clamp/wrap an index into [0, count). Returns -1 when there is nothing. */
function wrap(index, count) {
    if (!(count > 0))
        return -1
    var i = Math.trunc(index)
    if (isNaN(i))
        i = 0
    return ((i % count) + count) % count
}

/** Index of the window that should be activated after a step of `delta`. */
function cycleIndex(activeIndex, count, delta) {
    if (!(count > 0))
        return -1
    // A negative or non numeric index means "we don't know which window is
    // active"; start from the first one rather than from the end of the list.
    var current = activeIndex
    if (typeof current !== "number" || isNaN(current) || current < 0)
        current = 0
    current = wrap(current, count)
    return wrap(current + (Math.trunc(delta) || 0), count)
}

/**
 * Whether cycling is meaningful at all.  A single window is left alone so we
 * do not waste an activate/raise round trip (and so the shortcut stays quiet).
 */
function shouldCycle(activeIndex, count) {
    if (!(count > 1))
        return false
    if (typeof activeIndex !== "number" || isNaN(activeIndex) || activeIndex < 0)
        return true
    return wrap(activeIndex, count) >= 0
}

/**
 * Closing order: when the active window is removed, which index becomes
 * active?  Mirrors how tab strips and browsers pick the successor.
 */
function indexAfterRemoval(activeIndex, removedIndex, count) {
    if (!(count > 0))
        return -1
    var active = wrap(activeIndex, count)
    var removed = wrap(removedIndex, count)
    if (removed < 0 || active < 0)
        return 0
    if (count - 1 <= 0)
        return -1

    if (active < removed)
        return active                      // windows after it shift down by one
    if (active > removed)
        return wrap(active - 1, count - 1)

    // The active window is the one being removed: its successor slides into
    // the same slot, unless it was the very last one, in which case fall back
    // to the previous window (what browsers and tab strips do).
    if (removed >= count - 1)
        return wrap(active - 1, count - 1)
    return active
}

/**
 * Full screen carries across the session: a window created from (or
 * switched to while) a full screen window is active must be full screen
 * too.  Promotion only -- an already-full-screen target is never demoted.
 */
function inheritFullscreen(sourceFullscreen, targetFullscreen) {
    return sourceFullscreen === true || targetFullscreen === true
}

/**
 * Which profile a File > New Window opens on.
 *
 * Two different callers go through here, told apart by what they pass:
 *
 *   - `undefined` is the plain File > New Window command, which names no
 *     profile of its own.  It falls back to the profile this app is
 *     configured to open with -- that is what "start with the default
 *     profile" means -- and with no default configured it answers "" rather
 *     than guessing at a factory look nobody chose.  The "New Window with
 *     Profile" submenu instead passes a name, and a name always wins.
 *   - `""` (or anything that is not a name) is the explicit answer "load
 *     nothing", and is how the very first window opens: the startup path
 *     has already applied --profile, the default or the stored snapshot,
 *     and re-loading here would throw that away.
 *
 * Settings are one shared object, so whichever answer comes back is a global
 * switch: every window follows.
 *
 * @param {string|undefined} requested  a profile name, "" for none, or
 *                                      undefined for the plain command
 * @param {string} defaultName          the configured default profile, or ""
 * @return {string} the profile name to load, or "" to load none
 */
function newWindowLoadName(requested, defaultName) {
    if (requested === undefined)
        return typeof defaultName === "string" ? defaultName : ""
    return typeof requested === "string" ? requested : ""
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        wrap: wrap,
        cycleIndex: cycleIndex,
        shouldCycle: shouldCycle,
        indexAfterRemoval: indexAfterRemoval,
        inheritFullscreen: inheritFullscreen,
        newWindowLoadName: newWindowLoadName
    }
}
