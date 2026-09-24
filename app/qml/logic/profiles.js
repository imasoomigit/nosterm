/*******************************************************************************
* Profile bookkeeping: which profile Save writes to, which profile the app
* opens with, and the factory originals the built-ins reset to.
*
* Loaded by QML ("import logic/profiles.js" as Profiles) *and* by the Node
* test suite, so plain ECMAScript only.  Every function is pure: it receives
* the profile list -- an array of {text, obj_string, builtin} in the tests,
* the ListModel in QML -- and answers a question.  The storage writes stay
* in ApplicationSettings.qml, where the database actually lives.
*******************************************************************************/

/** Entry accessors that work for both arrays and ListModels. */
function entryCount(list) {
    if (!list)
        return 0
    return (typeof list.get === "function") ? list.count : list.length
}

function entryAt(list, i) {
    if (!list)
        return null
    return (typeof list.get === "function") ? list.get(i) : list[i]
}

/** Index of the profile called `name`, or -1 (unknown, null, ""). */
function indexOfName(list, name) {
    if (name === undefined || name === null || name === "")
        return -1
    for (var i = 0; i < entryCount(list); i++) {
        var entry = entryAt(list, i)
        if (entry && entry.text === name)
            return i
    }
    return -1
}

/** Is `name` one of the shipped built-ins (which carry a factory copy)? */
function isBuiltin(list, name) {
    var index = indexOfName(list, name)
    return index >= 0 && !!entryAt(list, index).builtin
}

/**
 * Where the Save button writes when pressed: the active profile (the one
 * that was loaded), else the default profile, else "" -- and "" is the one
 * case where the caller has to ask for a name, exactly once, because
 * nothing at all is active yet.
 */
function saveTargetName(list, activeName, defaultName) {
    if (indexOfName(list, activeName) >= 0)
        return activeName
    if (indexOfName(list, defaultName) >= 0)
        return defaultName
    return ""
}

/**
 * Which profile's values the app opens with: --profile wins, then the
 * stored default.  "" = open on the stored snapshot, loading nothing.
 */
function startupLoadName(list, argName, defaultName) {
    if (indexOfName(list, argName) >= 0)
        return argName
    if (indexOfName(list, defaultName) >= 0)
        return defaultName
    return ""
}

/**
 * Which profile is *active* at startup, i.e. the one the next Save writes
 * to: --profile, then the default, then last session's active profile.
 * The last one is only named, never loaded -- its values are already in
 * the snapshot loadSettings() applied -- so unsaved tweaks survive.
 */
function startupActiveName(list, argName, defaultName, storedActiveName) {
    var candidates = [argName, defaultName, storedActiveName]
    for (var i = 0; i < candidates.length; i++) {
        if (indexOfName(list, candidates[i]) >= 0)
            return candidates[i]
    }
    return ""
}

/** The default profile name to restore: valid name or "". */
function startupDefaultName(list, storedDefaultName) {
    return indexOfName(list, storedDefaultName) >= 0 ? storedDefaultName : ""
}

/**
 * Pristine copies of every profile in the list, by name.  Captured before
 * any stored override is applied, so it is what "Reset" puts back.
 */
function factoryMap(list) {
    var out = {}
    for (var i = 0; i < entryCount(list); i++) {
        var entry = entryAt(list, i)
        if (entry && entry.text)
            out[entry.text] = entry.obj_string
    }
    return out
}

/** Saved built-in overrides from storage, tolerant of missing garbage. */
function parseOverrides(json) {
    if (typeof json !== "string" || json === "")
        return {}
    try {
        var parsed = JSON.parse(json)
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return {}
        return parsed
    } catch (err) {
        return {}
    }
}

/**
 * The override records that may legally be applied to `list`: only string
 * values, only for entries that exist and are built-ins.  Returned as
 * {index, name, obj_string} so the caller can setProperty() them on.
 */
function overridesToApply(overrides, list) {
    var out = []
    if (!overrides || typeof overrides !== "object")
        return out
    for (var i = 0; i < entryCount(list); i++) {
        var entry = entryAt(list, i)
        if (!entry || !entry.builtin)
            continue
        var value = overrides[entry.text]
        if (typeof value === "string")
            out.push({ index: i, name: entry.text, obj_string: value })
    }
    return out
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        entryCount: entryCount,
        entryAt: entryAt,
        indexOfName: indexOfName,
        isBuiltin: isBuiltin,
        saveTargetName: saveTargetName,
        startupLoadName: startupLoadName,
        startupActiveName: startupActiveName,
        startupDefaultName: startupDefaultName,
        factoryMap: factoryMap,
        parseOverrides: parseOverrides,
        overridesToApply: overridesToApply
    }
}
