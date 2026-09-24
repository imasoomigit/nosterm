/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
import QtQuick 2.2
import QtQuick.Controls 2.0
import CoolRetroTerm 1.0

import "utils.js" as Utils
import "logic/defaults.js" as RetroDefaults
import "logic/pfkeys.js" as PfKeys
import "logic/ibmprofile.js" as IbmProfile
import "logic/chrome.js" as Chrome
import "logic/aliases.js" as Aliases
import "logic/profiles.js" as Profiles
import "logic/colormode.js" as ColorMode

QtObject {
    readonly property string version: appVersion
    readonly property int profileVersion: 2

    // STATIC CONSTANTS ////////////////////////////////////////////////////////
    readonly property real screenCurvatureSize: 0.6
    readonly property real minimumFontScaling: 0.25
    readonly property real maximumFontScaling: 2.50

    readonly property int defaultMargin: 16

    readonly property real minBurnInFadeTime: 0.16
    readonly property real maxBurnInFadeTime: 1.6

    property bool isMacOS: Qt.platform.os === "osx"

    // GENERAL SETTINGS ///////////////////////////////////////////////////////
    property bool showMenubar: false

    // RETRO / IBM EXTRAS /////////////////////////////////////////////////////
    // Nostalgic mode is the chrome contract from logic/chrome.js: full screen
    // shows nothing at all - no menu, no tab strip, no context menu, no size
    // overlay - so nothing hints there is a GUI behind the phosphor and every
    // action stays on the keyboard (touch the top edge to peek at the menu).
    // Windowed, the menu bar and the right-click menu are back for the mouse
    // and stay until full screen is entered again.
    property bool nostalgicMode: true

    // Keep the CMS command aliases (FILEL, COPYFILE, ...) in the shell
    // profile files: ~/.bashrc everywhere, ~/.zshrc on macOS and every
    // profile file that already exists.  On Windows the very same
    // ~/.bashrc is the Git Bash profile, which is how the aliases ride
    // along as a top up over Git Bash.  Unticking strips the block.
    property bool shellAliases: true

    // On screen IBM 3270 style PF/PA key legend.
    property bool showPfKeys: false
    // JSON produced by logic/pfkeys.js.  pfAssignments is derived from it so
    // that rewriting the string rebuilds every bound Shortcut delegate.
    property string pfKeys: ""
    readonly property var pfAssignments: PfKeys.parse(pfKeys)

    function setPfAssignments(assignments) {
        pfKeys = PfKeys.serialize(assignments)
    }

    // Audible feedback (optional, and silent unless explicitly enabled).
    property bool audioEnabled: false
    property bool keyClick: true
    property real keyClickVolume: 0.5
    // Which bundled keyboard tick plays: the factory one, two deeper
    // picks -- or, with keyClick false, nothing at all.
    property string keyClickSound: "tick"  // "tick" | "deep" | "deeper"
    property bool bell: true
    property real bellVolume: 0.5

    // iTerm2 style highlight of the row the cursor sits on.
    property bool highlightActiveLine: false
    property real activeLineOpacity: 0.18

    // Block / half block cursor, as on 3270 and PC BIOS screens.
    property string cursorStyle: "block"   // "block" | "half"

    // Colours of the on-glass PF/PA legend (see PfKeyBar.qml): the two
    // foregrounds take "" meaning "the phosphor colour" -- the arrow
    // shades itself down from it -- and the backgrounds are clear by
    // default, so a default panel prints exactly the text it always did.
    property string legendTextColor: ""
    property string legendTextBgColor: "#00000000"
    property string legendArrowColor: ""
    property string legendArrowBgColor: "#00000000"
    // Type of the legend: "" follows the screen's own face; the scale is
    // a coefficient of the screen font's pixel size (1.0 = the same size
    // as the terminal's output).
    property string legendFontFamily: ""
    property real legendFontScale: 1.0

    /**
     * Replace one PF/PA slot.  `patch` is merged over the existing entry and
     * the whole assignment list is re-serialized, which rebuilds every bound
     * Shortcut delegate in every window.
     */
    function patchPfAssignment(index, patch) {
        var assignments = PfKeys.parse(pfKeys)
        if (index < 0 || index >= assignments.length)
            return

        var entry = {}
        var existing = assignments[index]
        for (var key in existing) {
            if (Object.prototype.hasOwnProperty.call(existing, key))
                entry[key] = existing[key]
        }
        if (patch) {
            for (var name in patch) {
                if (Object.prototype.hasOwnProperty.call(patch, name))
                    entry[name] = patch[name]
            }
        }
        assignments[index] = entry
        pfKeys = PfKeys.serialize(assignments)
    }

    /** Give every slot back its factory assignment. */
    function resetPfAssignments() {
        pfKeys = PfKeys.serialize(PfKeys.defaultAssignments())
    }

    /**
     * Visibility of the chrome that belongs to the application rather than to
     * a single window (menu bar, context menu, size overlay).  Derived from
     * logic/chrome.js so the "nostalgic mode shows nothing" contract is a
     * single tested function.
     */
    readonly property var chrome: Chrome.visibility({
        nostalgicMode: nostalgicMode,
        showMenubar: showMenubar,
        showTerminalSize: showTerminalSize,
        isMacOS: isMacOS
    })

    property bool showTerminalSize: true
    property real windowScaling: 1.0

    property int effectsFrameSkip: 3
    property bool verbose: false

    property real bloomQuality: 0.5
    property real burnInQuality: 0.5

    property bool blinkingCursor: false


    // PROFILE SETTINGS ///////////////////////////////////////////////////////
    property real windowOpacity: 1.0
    property real ambientLight: 0.2
    property real contrast: 0.80
    property real brightness: 0.5

    property bool useCustomCommand: false
    property string customCommand: ""

    property string _backgroundColor: "#000000"
    property string _fontColor: "#ff8100"
    property string _frameColor: "#ffffff"
    property string saturatedColor: Utils.mix(Utils.strToColor(_fontColor), Utils.strToColor("#FFFFFF"), (saturationColor * 0.5))
    property color fontColor: Utils.mix(Utils.strToColor(_backgroundColor), Utils.strToColor(saturatedColor), (0.7 + (contrast * 0.3)))
    property color backgroundColor: Utils.mix(Utils.strToColor(saturatedColor), Utils.strToColor(_backgroundColor), (0.7 + (contrast * 0.3)))
    property color frameColor: Utils.strToColor(_frameColor)

    property real staticNoise: 0.12
    property real screenCurvature: 0.3
    property real glowingLine: 0.2
    property real burnIn: 0.25
    property real bloom: 0.55

    property real chromaColor: 0.25
    /**
     * What the glass does with the console's colours: "monochrome"
     * simulates a single phosphor (every colour is read as the luminance
     * it carried), "color" lets the tty's own hues through.  See
     * logic/colormode.js for the two names and for how a profile recorded
     * before this field existed is read.
     */
    property string colorMode: "monochrome"
    property real saturationColor: 0.25

    property real jitter: 0.2

    property real horizontalSync: 0.08
    property real flickering: 0.1

    property real rgbShift: 0.0

    property real _frameShininess: 0.2
    property real frameShininess: _frameShininess * 0.5

    property real _frameSize: 0.2
    property real frameSize: _frameSize * 0.05

    property real _screenRadius: 0.2
    property real screenRadius: Utils.lint(4.0, 120.0, _screenRadius)

    property real _margin: 0.5
    property real margin: Utils.lint(1.0, 40.0, _margin) + (1.0 - Math.SQRT1_2) * screenRadius

    readonly property bool frameEnabled: ambientLight > 0 || _frameSize > 0 || screenCurvature > 0

    readonly property int no_rasterization: 0
    readonly property int scanline_rasterization: 1
    readonly property int pixel_rasterization: 2
    readonly property int subpixel_rasterization: 3
    readonly property int modern_rasterization: 4

    property alias rasterization: fontManager.rasterization

    readonly property int bundled_fonts: 0
    readonly property int system_fonts: 1

    property alias fontSource: fontManager.fontSource

    // FONTS //////////////////////////////////////////////////////////////////
    readonly property real baseFontScaling: 0.75
    property alias fontScaling: fontManager.fontScaling
    property real totalFontScaling: baseFontScaling * fontScaling

    property alias fontWidth: fontManager.fontWidth
    property alias lineSpacing: fontManager.lineSpacing

    property alias lowResolutionFont: fontManager.lowResolutionFont

    property alias fontName: fontManager.fontName
    property alias filteredFontList: fontManager.filteredFontList

    property FontManager fontManager: FontManager {
        id: fontManager
        baseFontScaling: baseFontScaling
    }

    // The computed screen font, mirrored for UI that has to read like the
    // screen: the off-side PF panel and the retro-styled dialogs.  Low
    // resolution fonts are drawn scaled to the target height, so the raw
    // signal pixelSize alone would not match what the terminal shows.
    property string terminalFontFamily: "monospace"
    property real terminalFontPixelSize: 12
    property real terminalFontWidth: 1.0

    // QtObject has no default property: the mirror has to hang off an
    // explicit child property, exactly like fontManager and storage.
    property Connections fontMirror: Connections {
        target: fontManager
        function onTerminalFontChanged(fontFamily, pixelSize, lineSpacing,
                                       screenScaling, fontWidth) {
            terminalFontFamily = fontFamily
            terminalFontPixelSize = pixelSize * screenScaling
            terminalFontWidth = fontWidth
        }
    }

    signal initializedSettings

    function incrementScaling() {
        fontScaling = Math.min(fontScaling + 0.05, maximumFontScaling)
    }

    function decrementScaling() {
        fontScaling = Math.max(fontScaling - 0.05, minimumFontScaling)
    }

    function close() {
        storeSettings()
        storeCustomProfiles()
        Qt.quit()
    }

    property Storage storage: Storage {}

    function stringify(obj) {
        var replacer = function (key, val) {
            return val.toFixed ? Number(val.toFixed(4)) : val
        }
        return JSON.stringify(obj, replacer, 2)
    }

    function composeSettingsString() {
        var settings = {
            "effectsFrameSkip": effectsFrameSkip,
            "windowScaling": windowScaling,
            "showTerminalSize": showTerminalSize,
            "fontScaling": fontScaling,
            "showMenubar": showMenubar,
            "shellAliases": shellAliases,
            "bloomQuality": bloomQuality,
            "burnInQuality": burnInQuality,
            "useCustomCommand": useCustomCommand,
            "customCommand": customCommand,
            "colorMode": colorMode,

            // Retro / IBM extras.  RetroDefaults.merge() is the single place
            // that validates them, and it is covered by tests/logic.
            "nostalgicMode": nostalgicMode,
            "showPfKeys": showPfKeys,
            "pfKeys": pfKeys,
            "audioEnabled": audioEnabled,
            "keyClick": keyClick,
            "keyClickVolume": keyClickVolume,
            "keyClickSound": keyClickSound,
            "bell": bell,
            "bellVolume": bellVolume,
            "highlightActiveLine": highlightActiveLine,
            "activeLineOpacity": activeLineOpacity,
            "cursorStyle": cursorStyle,
            "legendTextColor": legendTextColor,
            "legendTextBgColor": legendTextBgColor,
            "legendArrowColor": legendArrowColor,
            "legendArrowBgColor": legendArrowBgColor,
            "legendFontFamily": legendFontFamily,
            "legendFontScale": legendFontScale
        }
        return stringify(settings)
    }

    function composeProfileObject() {
        var profile = {
            "backgroundColor": _backgroundColor,
            "fontColor": _fontColor,
            "flickering": flickering,
            "horizontalSync": horizontalSync,
            "staticNoise": staticNoise,
            "chromaColor": chromaColor,
            "colorMode": colorMode,
            "saturationColor": saturationColor,
            "screenCurvature": screenCurvature,
            "glowingLine": glowingLine,
            "burnIn": burnIn,
            "bloom": bloom,
            "rasterization": rasterization,
            "jitter": jitter,
            "rgbShift": rgbShift,
            "brightness": brightness,
            "contrast": contrast,
            "ambientLight": ambientLight,
            "windowOpacity": windowOpacity,
            "fontName": fontName,
            "fontSource": fontSource,
            "fontWidth": fontWidth,
            "lineSpacing": lineSpacing,
            "margin": _margin,
            "blinkingCursor": blinkingCursor,
            "frameSize": _frameSize,
            "screenRadius": _screenRadius,
            "frameColor": _frameColor,
            "frameShininess": _frameShininess
        }

        // The IBM extras travel with the profile too: PF/PA legend and
        // assignments, sound, cursor and active-line band.  See
        // RetroDefaults.pickIbmExtras for the exact set; nostalgicMode is
        // deliberately not a profile field (chrome stays app-wide).
        var extras = RetroDefaults.pickIbmExtras({
            "showPfKeys": showPfKeys,
            "pfKeys": pfKeys,
            "audioEnabled": audioEnabled,
            "keyClick": keyClick,
            "keyClickVolume": keyClickVolume,
            "keyClickSound": keyClickSound,
            "bell": bell,
            "bellVolume": bellVolume,
            "highlightActiveLine": highlightActiveLine,
            "activeLineOpacity": activeLineOpacity,
            "cursorStyle": cursorStyle,
            "legendTextColor": legendTextColor,
            "legendTextBgColor": legendTextBgColor,
            "legendArrowColor": legendArrowColor,
            "legendArrowBgColor": legendArrowBgColor,
            "legendFontFamily": legendFontFamily,
            "legendFontScale": legendFontScale
        })
        for (var extraKey in extras) {
            if (Object.prototype.hasOwnProperty.call(extras, extraKey))
                profile[extraKey] = extras[extraKey]
        }
        return profile
    }

    function composeProfileString() {
        return stringify(composeProfileObject())
    }

    function loadSettings() {
        var settingsString = storage.getSetting("_CURRENT_SETTINGS")
        var profileString = storage.getSetting("_CURRENT_PROFILE")

        if (!settingsString)
            return
        if (!profileString)
            return

        loadSettingsString(settingsString)
        loadProfileString(profileString)

        if (verbose)
            console.log("Loading settings: " + settingsString + profileString)
    }

    function storeSettings() {
        var settingsString = composeSettingsString()
        var profileString = composeProfileString()

        storage.setSetting("_CURRENT_SETTINGS", settingsString)
        storage.setSetting("_CURRENT_PROFILE", profileString)

        if (verbose) {
            console.log("Storing settings: " + settingsString)
            console.log("Storing profile: " + profileString)
        }
    }

    function loadSettingsString(settingsString) {
        var settings = JSON.parse(settingsString)

        showTerminalSize = settings.showTerminalSize
                !== undefined ? settings.showTerminalSize : showTerminalSize

        effectsFrameSkip = settings.effectsFrameSkip !== undefined ? settings.effectsFrameSkip : effectsFrameSkip
        windowScaling = settings.windowScaling
                !== undefined ? settings.windowScaling : windowScaling

        fontScaling = settings.fontScaling !== undefined ? settings.fontScaling : fontScaling

        showMenubar = settings.showMenubar !== undefined ? settings.showMenubar : showMenubar

        shellAliases = settings.shellAliases !== undefined ? settings.shellAliases : shellAliases

        bloomQuality = settings.bloomQuality !== undefined ? settings.bloomQuality : bloomQuality
        burnInQuality = settings.burnInQuality
                !== undefined ? settings.burnInQuality : burnInQuality

        useCustomCommand = settings.useCustomCommand
                !== undefined ? settings.useCustomCommand : useCustomCommand
        customCommand = settings.customCommand
                !== undefined ? settings.customCommand : customCommand

        // The colour mode rides in both blobs, exactly like the IBM
        // extras: the profile is the look and wins, this is the fallback
        // for a profile too old to carry an opinion of its own.
        colorMode = ColorMode.isValid(settings.colorMode) ? settings.colorMode
                : colorMode

        // Retro / IBM extras: merge repairs types, falls back to the defaults
        // for anything missing and ignores keys it does not know about.
        var retro = RetroDefaults.merge(settings)
        nostalgicMode = retro.nostalgicMode
        showPfKeys = retro.showPfKeys
        pfKeys = retro.pfKeys
        audioEnabled = retro.audioEnabled
        keyClick = retro.keyClick
        keyClickVolume = retro.keyClickVolume
        keyClickSound = retro.keyClickSound
        bell = retro.bell
        bellVolume = retro.bellVolume
        highlightActiveLine = retro.highlightActiveLine
        activeLineOpacity = retro.activeLineOpacity
        cursorStyle = retro.cursorStyle
        legendTextColor = retro.legendTextColor
        legendTextBgColor = retro.legendTextBgColor
        legendArrowColor = retro.legendArrowColor
        legendArrowBgColor = retro.legendArrowBgColor
        legendFontFamily = retro.legendFontFamily
        legendFontScale = retro.legendFontScale
    }

    // SHELL ALIAS BLOCK /////////////////////////////////////////////////////
    /**
     * Install (or refresh) the managed CMS alias block in every shell
     * profile target for this platform.  Every decision - which files,
     * which text, how to merge - lives in logic/aliases.js; this side
     * only performs the I/O through the fileIO context object.
     */
    function syncShellAliases() {
        var home = fileIO.homeUrl()
        var exists = function (name) { return fileIO.exists(home + "/" + name) }
        var names = Aliases.targets(Qt.platform.os, exists)
        var text = Aliases.block(Qt.platform.os)

        for (var i = 0; i < names.length; i++) {
            var url = home + "/" + names[i]
            var current = fileIO.read(url)
            var updated = Aliases.upsert(current, text)
            if (updated !== current) {
                fileIO.write(url, updated)
                if (verbose)
                    console.log("CMS aliases written to " + url)
            }
        }
    }

    /**
     * Remove every trace of the block (switching the setting off).  Files
     * that do not exist read as "" and are left untouched.
     */
    function removeShellAliases() {
        var home = fileIO.homeUrl()
        var names = [".bashrc", ".zshrc", ".bash_profile", ".profile"]
        for (var i = 0; i < names.length; i++) {
            var url = home + "/" + names[i]
            var current = fileIO.read(url)
            var updated = Aliases.strip(current)
            if (updated !== current)
                fileIO.write(url, updated)
        }
    }

    onShellAliasesChanged: {
        if (shellAliases)
            syncShellAliases()
        else
            removeShellAliases()
    }

    function loadProfileString(profileString) {
        var settings = JSON.parse(profileString)

        _backgroundColor = settings.backgroundColor
                !== undefined ? settings.backgroundColor : _backgroundColor
        _fontColor = settings.fontColor !== undefined ? settings.fontColor : _fontColor

        horizontalSync = settings.horizontalSync
                !== undefined ? settings.horizontalSync : horizontalSync
        flickering = settings.flickering !== undefined ? settings.flickering : flickering
        staticNoise = settings.staticNoise !== undefined ? settings.staticNoise : staticNoise
        chromaColor = settings.chromaColor !== undefined ? settings.chromaColor : chromaColor
        // The colour mode is a look, so it belongs to the profile.  A
        // profile saved before the field existed only carries the old
        // chroma slider, and that is where the mode comes from then.
        colorMode = ColorMode.isValid(settings.colorMode) ? settings.colorMode
                : (settings.chromaColor !== undefined
                   ? ColorMode.infer(settings.chromaColor) : colorMode)
        saturationColor = settings.saturationColor
                !== undefined ? settings.saturationColor : saturationColor
        screenCurvature = settings.screenCurvature
                !== undefined ? settings.screenCurvature : screenCurvature
        glowingLine = settings.glowingLine !== undefined ? settings.glowingLine : glowingLine

        burnIn = settings.burnIn !== undefined ? settings.burnIn : burnIn
        bloom = settings.bloom !== undefined ? settings.bloom : bloom

        rasterization = settings.rasterization
                !== undefined ? settings.rasterization : rasterization

        jitter = settings.jitter !== undefined ? settings.jitter : jitter

        rgbShift = settings.rgbShift !== undefined ? settings.rgbShift : rgbShift

        ambientLight = settings.ambientLight !== undefined ? settings.ambientLight : ambientLight
        contrast = settings.contrast !== undefined ? settings.contrast : contrast
        brightness = settings.brightness !== undefined ? settings.brightness : brightness
        windowOpacity = settings.windowOpacity
                !== undefined ? settings.windowOpacity : windowOpacity

        fontSource = settings.fontSource !== undefined ? settings.fontSource : fontSource
        fontName = settings.fontName !== undefined ? settings.fontName : fontName
        fontWidth = settings.fontWidth !== undefined ? settings.fontWidth : fontWidth
        lineSpacing = settings.lineSpacing !== undefined ? settings.lineSpacing : lineSpacing

        _margin = settings.margin !== undefined ? settings.margin : _margin
        _frameSize = settings.frameSize !== undefined ? settings.frameSize : _frameSize
        _screenRadius = settings.screenRadius !== undefined ? settings.screenRadius : _screenRadius
        _frameColor = settings.frameColor !== undefined ? settings.frameColor : _frameColor
        _frameShininess = settings.frameShininess !== undefined ? settings.frameShininess : _frameShininess

        blinkingCursor = settings.blinkingCursor !== undefined ? settings.blinkingCursor : blinkingCursor

        applyProfileExtras(RetroDefaults.profileExtras(settings))

        // A load is not a change: what composeProfileString() now answers
        // is what the profile already holds, so the autosave must not turn
        // the very act of choosing a profile into a write to it.
        rebaseAutoSave()
    }

    /**
     * Apply the IBM extras a profile specifies.  Fields the profile does not
     * carry (every profile saved before this feature, and the older visual
     * built-ins) keep their current value -- see defaults.profileExtras.
     */
    function applyProfileExtras(extras) {
        if (extras.showPfKeys !== undefined)          showPfKeys = extras.showPfKeys
        if (extras.pfKeys !== undefined)              pfKeys = extras.pfKeys
        if (extras.audioEnabled !== undefined)        audioEnabled = extras.audioEnabled
        if (extras.keyClick !== undefined)            keyClick = extras.keyClick
        if (extras.keyClickVolume !== undefined)      keyClickVolume = extras.keyClickVolume
        if (extras.keyClickSound !== undefined)       keyClickSound = extras.keyClickSound
        if (extras.bell !== undefined)                bell = extras.bell
        if (extras.bellVolume !== undefined)          bellVolume = extras.bellVolume
        if (extras.highlightActiveLine !== undefined) highlightActiveLine = extras.highlightActiveLine
        if (extras.activeLineOpacity !== undefined)   activeLineOpacity = extras.activeLineOpacity
        if (extras.cursorStyle !== undefined)         cursorStyle = extras.cursorStyle
        if (extras.legendTextColor !== undefined)     legendTextColor = extras.legendTextColor
        if (extras.legendTextBgColor !== undefined)   legendTextBgColor = extras.legendTextBgColor
        if (extras.legendArrowColor !== undefined)    legendArrowColor = extras.legendArrowColor
        if (extras.legendArrowBgColor !== undefined)  legendArrowBgColor = extras.legendArrowBgColor
        if (extras.legendFontFamily !== undefined)    legendFontFamily = extras.legendFontFamily
        if (extras.legendFontScale !== undefined)     legendFontScale = extras.legendFontScale
    }

    function storeCustomProfiles() {
        storage.setSetting("_CUSTOM_PROFILES", composeCustomProfilesString())
    }

    function loadCustomProfiles() {
        var customProfileString = storage.getSetting("_CUSTOM_PROFILES")
        if (customProfileString === undefined)
            customProfileString = "[]"
        loadCustomProfilesString(customProfileString)
    }

    function loadCustomProfilesString(customProfilesString) {
        var customProfiles = JSON.parse(customProfilesString)
        for (var i = 0; i < customProfiles.length; i++) {
            var profile = customProfiles[i]

            if (verbose)
                console.log("Loading custom profile: " + stringify(profile))

            profilesList.append(profile)
        }
    }

    function composeCustomProfilesString() {
        var customProfiles = []
        for (var i = 0; i < profilesList.count; i++) {
            var profile = profilesList.get(i)
            if (profile.builtin)
                continue
            customProfiles.push({
                                    "text": profile.text,
                                    "obj_string": profile.obj_string,
                                    "builtin": false
                                })
        }
        return stringify(customProfiles)
    }

    function loadProfile(index) {
        var profile = profilesList.get(index)
        loadProfileString(profile.obj_string)
        // Loading names the profile: from here on Save writes into it.
        setActiveProfile(profile.text)
    }

    function appendCustomProfile(name, profileString) {
        profilesList.append({
                                "text": name,
                                "obj_string": profileString,
                                "builtin": false
                            })
    }

    // ACTIVE PROFILE /////////////////////////////////////////////////////////
    /**
     * The profile Save writes to: the one that was loaded (from the list,
     * the Profiles menu or --profile) or, failing that, the default.  ""
     * means nothing is active yet, and Save has to ask for a name once.
     */
    property string activeProfileName: ""

    /** The profile the app opens with.  "" = open on the stored snapshot. */
    property string defaultProfileName: ""

    /**
     * Pristine copies of the built-ins, captured before any stored
     * override is applied: what Reset puts back after a Save overwrote
     * them.  Custom profiles have no entry here, so they do not reset.
     */
    property var factoryProfiles: ({})

    /** Saved changes made to built-in profiles: name -> obj_string. */
    property var builtinOverrides: ({})

    function persistActiveProfile() {
        storage.setSetting("_ACTIVE_PROFILE", activeProfileName)
    }

    function persistDefaultProfile() {
        storage.setSetting("_DEFAULT_PROFILE", defaultProfileName)
    }

    function storeBuiltinOverrides() {
        storage.setSetting("_BUILTIN_OVERRIDES", stringify(builtinOverrides))
    }

    /** Snapshot the built-ins exactly as they ship, before any override. */
    function captureFactoryProfiles() {
        factoryProfiles = Profiles.factoryMap(profilesList)
    }

    /** Re-apply the changes the user saved over the built-ins. */
    function loadBuiltinOverrides() {
        builtinOverrides = Profiles.parseOverrides(
                    storage.getSetting("_BUILTIN_OVERRIDES"))
        var changes = Profiles.overridesToApply(builtinOverrides, profilesList)
        for (var i = 0; i < changes.length; i++) {
            profilesList.setProperty(changes[i].index, "obj_string",
                                      changes[i].obj_string)
        }
    }

    /** Mark `name` active -- the Save target -- and remember it. */
    function setActiveProfile(name) {
        if (activeProfileName === name)
            return
        activeProfileName = name
        persistActiveProfile()
    }

    /**
     * The Save button: overwrite the active profile (or, with none, the
     * default) with the current values.  No name prompt, ever, unless
     * nothing at all is active -- and that ask happens only once, because
     * the name it collects becomes the active profile.
     *
     * Returns false only in that last case: the caller then shows the
     * name dialog (SettingsGeneralTab).
     */
    function saveActiveProfile() {
        var name = Profiles.saveTargetName(profilesList, activeProfileName,
                                            defaultProfileName)
        if (name === "")
            return false
        return writeProfile(name, composeProfileString())
    }

    /** Save under a fresh name: the very first Save, when nothing is active. */
    function saveAsNewProfile(name) {
        if (!name)
            return false
        appendCustomProfile(name, composeProfileString())
        storeCustomProfiles()
        setActiveProfile(name)
        return true
    }

    /** The one place a profile's contents are ever written. */
    function writeProfile(name, profileString) {
        var index = getProfileIndexByName(name)
        if (index === -1)
            return false
        profilesList.setProperty(index, "obj_string", profileString)

        if (profilesList.get(index).builtin) {
            // Built-ins live in code and are rebuilt on every start: keep
            // the change in the override map so it survives the restart.
            builtinOverrides[name] = profileString
            storeBuiltinOverrides()
        } else {
            storeCustomProfiles()
        }
        setActiveProfile(name)
        return true
    }

    // LIVE AUTOSAVE //////////////////////////////////////////////////////////
    /**
     * Nothing the settings dialog changes may be lost to "I forgot to press
     * Save".  A slow poll compares both composed blobs with the last ones
     * written and rewrites only on a real difference, so a slider drag is
     * one write at the end instead of one per tick, and a profile that was
     * merely loaded is never rewritten (loading rebases the baseline).
     *
     * Both halves go down: the snapshot is what the next start shows, and
     * the *profile* is what "saved as part of the profile" means -- but
     * only when a profile is active, because with none the Save button is
     * still the thing that asks for a name, once.
     */
    property string _autoSaveProfile: ""
    property string _autoSaveSettings: ""

    property Timer autoSaveTimer: Timer {
        interval: 750
        repeat: true
        running: false
        onTriggered: autoSaveTick()
    }

    /** What is on screen right now, recorded as "there is nothing to save". */
    function rebaseAutoSave() {
        _autoSaveProfile = composeProfileString()
        _autoSaveSettings = composeSettingsString()
    }

    function autoSaveTick() {
        var profile = composeProfileString()
        var settings = composeSettingsString()
        if (profile === _autoSaveProfile && settings === _autoSaveSettings)
            return
        _autoSaveProfile = profile
        _autoSaveSettings = settings

        storage.setSetting("_CURRENT_SETTINGS", settings)
        storage.setSetting("_CURRENT_PROFILE", profile)

        if (activeProfileName !== "")
            writeProfile(activeProfileName, profile)
    }

    /**
     * Point every future start at `name`; "" takes the default away
     * again.  The values are brought in by the startup path, not from
     * here -- this only records the choice.
     */
    function setDefaultProfile(name) {
        var valid = (name && getProfileIndexByName(name) !== -1) ? name : ""
        if (defaultProfileName === valid)
            return
        defaultProfileName = valid
        persistDefaultProfile()
    }

    /**
     * Put a built-in back exactly as it shipped: the stored override is
     * dropped and the factory copy restored -- onto the screen as well
     * when it is the active profile.  Custom profiles have no factory
     * copy and do not reset.
     */
    function resetProfile(name) {
        var factory = factoryProfiles ? factoryProfiles[name] : undefined
        if (factory === undefined)
            return false
        var index = getProfileIndexByName(name)
        if (index === -1)
            return false
        profilesList.setProperty(index, "obj_string", factory)
        if (builtinOverrides[name] !== undefined) {
            delete builtinOverrides[name]
            storeBuiltinOverrides()
        }
        if (activeProfileName === name)
            loadProfileString(factory)
        return true
    }

    /**
     * Drop a custom profile, releasing the active and default markers it
     * may be carrying.  Built-ins cannot be removed.
     */
    function removeProfile(index) {
        if (index < 0 || index >= profilesList.count)
            return false
        if (profilesList.get(index).builtin)
            return false
        var name = profilesList.get(index).text
        profilesList.remove(index)
        if (activeProfileName === name)
            setActiveProfile("")
        if (defaultProfileName === name)
            setDefaultProfile("")
        storeCustomProfiles()
        return true
    }

    // PROFILES ///////////////////////////////////////////////////////////////
    property ListModel profilesList: ListModel {
        ListElement {
            text: "Default Amber"
            obj_string: '{
                "ambientLight": 0.3,
                "backgroundColor": "#000000",
                "bloom": 0.6,
                "brightness": 0.5,
                "burnIn": 0.3,
                "chromaColor": 0.2,
                "contrast": 0.8,
                "flickering": 0.1,
                "fontColor": "#ff8100",
                "fontName": "TERMINESS_SCALED",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.2,
                "horizontalSync": 0.1,
                "jitter": 0.2,
                "rasterization": 0,
                "rgbShift": 0,
                "saturationColor": 0.2,
                "screenCurvature": 0.2,
                "screenRadius": 0.1,
                "staticNoise": 0.1,
                "windowOpacity": 1,
                "margin": 0.3,
                "blinkingCursor": false,
                "frameSize": 0.1,
                "frameColor": "#cfcfcf",
                "frameShininess": 0.3
            }'
            builtin: true
        }
        ListElement {
            text: "Monochrome Green"
            obj_string: '{
                "ambientLight": 0.3,
                "backgroundColor": "#000000",
                "bloom": 0.5,
                "brightness": 0.5,
                "burnIn": 0.3,
                "chromaColor": 0.0,
                "contrast": 0.8,
                "flickering": 0.1,
                "fontColor": "#0ccc68",
                "fontName": "DEPARTURE_MONO_SCALED",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.2,
                "horizontalSync": 0.1,
                "jitter": 0.2,
                "rasterization": 0,
                "rgbShift": 0,
                "saturationColor": 0.0,
                "screenCurvature": 0.3,
                "screenRadius": 0.2,
                "staticNoise": 0.1,
                "windowOpacity": 1,
                "margin": 0.3,
                "blinkingCursor": false,
                "frameSize": 0.1,
                "frameColor": "#d4d4d4",
                "frameShininess": 0.1
            }'
            builtin: true
        }
        ListElement {
            text: "Deep Blue"
            obj_string: '{
                "ambientLight": 0.0,
                "backgroundColor": "#000000",
                "bloom": 0.6,
                "brightness": 0.5,
                "burnIn": 0.3,
                "chromaColor": 1.0,
                "contrast": 0.8,
                "flickering": 0.1,
                "fontColor": "#7fb4ff",
                "fontName": "BIGBLUE_TERMINAL_SCALED",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.2,
                "horizontalSync": 0.1,
                "jitter": 0.2,
                "rasterization": 0,
                "rgbShift": 0,
                "saturationColor": 0.2,
                "screenCurvature": 0.4,
                "screenRadius": 0.1,
                "staticNoise": 0.1,
                "windowOpacity": 1,
                "margin": 0.3,
                "blinkingCursor": false,
                "frameSize": 0.1,
                "frameColor": "#ffffff",
                "frameShininess": 0.9
            }'
            builtin: true
        }
        ListElement {
            text: "Commodore 64"
            obj_string: '{
                "ambientLight": 0.4,
                "backgroundColor": "#3b3b8f",
                "bloom": 0.4,
                "brightness": 0.6,
                "burnIn": 0.1,
                "chromaColor": 0.0,
                "contrast": 0.7,
                "flickering": 0.1,
                "fontColor": "#a9a7ff",
                "fontName": "COMMODORE_64_SCALED",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.1,
                "horizontalSync": 0.0,
                "jitter": 0.0,
                "rasterization": 1,
                "rgbShift": 0,
                "saturationColor": 0,
                "screenCurvature": 0.5,
                "screenRadius": 0.1,
                "staticNoise": 0.1,
                "windowOpacity": 1,
                "margin": 0.3,
                "blinkingCursor": false,
                "frameSize": 0.5,
                "frameColor": "#999999",
                "frameShininess": 0.0
            }'
            builtin: true
        }
        ListElement {
            text: "Commodore PET"
            obj_string: '{
                "ambientLight": 0.0,
                "backgroundColor": "#000000",
                "bloom": 0.4,
                "brightness": 0.5,
                "burnIn": 0.4,
                "chromaColor": 0,
                "contrast": 0.8,
                "flickering": 0.2,
                "fontColor": "#ffffff",
                "fontName": "COMMODORE_PET_SCALED",
                "fontSource": 0,
                "fontWidth": 1.25,
                "lineSpacing": 0.1,
                "glowingLine": 0.3,
                "horizontalSync": 0.2,
                "jitter": 0.15,
                "rasterization": 1,
                "rgbShift": 0.0,
                "saturationColor": 0,
                "screenCurvature": 0.7,
                "screenRadius": 0.3,
                "staticNoise": 0.2,
                "windowOpacity": 1,
                "margin": 0.2,
                "blinkingCursor": false,
                "frameSize": 0.5,
                "frameColor": "#000000",
                "frameShininess": 0.6
            }'
            builtin: true
        }
        ListElement {
            text: "Apple ]["
            obj_string: '{
                "ambientLight": 1.0,
                "backgroundColor": "#001100",
                "bloom": 0.3,
                "brightness": 0.5,
                "burnIn": 0.3,
                "chromaColor": 0,
                "contrast": 0.8,
                "flickering": 0.2,
                "fontColor": "#4dff6b",
                "fontName": "APPLE_II_SCALED",
                "fontSource": 0,
                "fontWidth": 1.25,
                "lineSpacing": 0.1,
                "glowingLine": 0.3,
                "horizontalSync": 0.2,
                "jitter": 0.2,
                "rasterization": 1,
                "rgbShift": 0.0,
                "saturationColor": 0,
                "screenCurvature": 0.5,
                "screenRadius": 0.3,
                "staticNoise": 0.2,
                "windowOpacity": 1,
                "margin": 0.0,
                "blinkingCursor": false,
                "frameSize": 0.2,
                "frameColor": "#ffffff",
                "frameShininess": 0.8
            }'
            builtin: true
        }
        ListElement {
            text: "Atari 400"
            obj_string: '{
                "ambientLight": 0.1,
                "backgroundColor": "#0f1f5a",
                "bloom": 0.1,
                "brightness": 0.6,
                "burnIn": 0.2,
                "chromaColor": 0,
                "contrast": 0.9,
                "flickering": 0.1,
                "fontColor": "#8ed6ff",
                "fontName": "ATARI_400_SCALED",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.1,
                "horizontalSync": 0.0,
                "jitter": 0.0,
                "rasterization": 1,
                "rgbShift": 0.0,
                "saturationColor": 0,
                "screenCurvature": 0.4,
                "screenRadius": 0.2,
                "staticNoise": 0.1,
                "windowOpacity": 1,
                "margin": 0.2,
                "blinkingCursor": false,
                "frameSize": 0.4,
                "frameColor": "#cccccc",
                "frameShininess": 0.3
            }'
            builtin: true
        }
        ListElement {
            text: "IBM VGA 8x16"
            obj_string: '{
                "ambientLight": 0.2,
                "backgroundColor": "#000000",
                "bloom": 0.2,
                "brightness": 0.6,
                "burnIn": 0.1,
                "chromaColor": 0.5,
                "contrast": 1.0,
                "flickering": 0.1,
                "fontColor": "#c0c0c0",
                "fontName": "IBM_VGA_8x16",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.1,
                "horizontalSync": 0.0,
                "jitter": 0.0,
                "rasterization": 1,
                "rgbShift": 0.1,
                "saturationColor": 0,
                "screenCurvature": 0.3,
                "screenRadius": 0.1,
                "staticNoise": 0.0,
                "windowOpacity": 1,
                "margin": 0.2,
                "blinkingCursor": false,
                "frameSize": 0.1,
                "frameColor": "#ffffff",
                "frameShininess": 0.3
            }'
            builtin: true
        }
        ListElement {
            text: "IBM 3278 Reborn"
            obj_string: '{
                "ambientLight": 0.2,
                "backgroundColor": "#000000",
                "bloom": 0.2,
                "brightness": 0.5,
                "burnIn": 0.5,
                "chromaColor": 0,
                "contrast": 0.8,
                "flickering": 0,
                "fontColor": "#3cff7a",
                "fontName": "IBM_3278",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.0,
                "horizontalSync": 0,
                "jitter": 0,
                "rasterization": 4,
                "rgbShift": 0,
                "saturationColor": 0,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.0,
                "windowOpacity": 1,
                "margin": 0.1,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#ffffff",
                "frameShininess": 0.2
            }'
            builtin: true
        }
        ListElement {
            text: "Neon Cyan"
            obj_string: '{
                "ambientLight": 0.1,
                "backgroundColor": "#001018",
                "bloom": 0.6,
                "brightness": 0.6,
                "burnIn": 0.1,
                "chromaColor": 1,
                "contrast": 0.9,
                "flickering": 0.1,
                "fontColor": "#52f7ff",
                "fontName": "IOSEVKA",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.2,
                "horizontalSync": 0.0,
                "jitter": 0.1,
                "rasterization": 4,
                "rgbShift": 0.0,
                "saturationColor": 0.6,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.1,
                "windowOpacity": 0.8,
                "margin": 0.1,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#c3c3c3",
                "frameShininess": 0.2
            }'
            builtin: true
        }
        ListElement {
            text: "Ghost Terminal"
            obj_string: '{
                "ambientLight": 0.3,
                "backgroundColor": "#0b1014",
                "bloom": 0.3,
                "brightness": 0.6,
                "burnIn": 0.2,
                "chromaColor": 0,
                "contrast": 0.5,
                "flickering": 0.0,
                "fontColor": "#a6b3c0",
                "fontName": "JETBRAINS_MONO",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.1,
                "horizontalSync": 0.0,
                "jitter": 0.0,
                "rasterization": 4,
                "rgbShift": 0.0,
                "saturationColor": 0.0,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.1,
                "windowOpacity": 0.7,
                "margin": 0.1,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#a7a7a7",
                "frameShininess": 0.2
            }'
            builtin: true
        }
        ListElement {
            text: "Plasma"
            obj_string: '{
                "ambientLight": 0.1,
                "backgroundColor": "#070014",
                "bloom": 0.7,
                "brightness": 0.6,
                "burnIn": 0.1,
                "chromaColor": 1,
                "contrast": 0.8,
                "flickering": 0.1,
                "fontColor": "#ff9bd6",
                "fontName": "FIRA_CODE",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.2,
                "horizontalSync": 0.0,
                "jitter": 0.1,
                "rasterization": 4,
                "rgbShift": 0.1,
                "saturationColor": 0.8,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.1,
                "windowOpacity": 1.0,
                "margin": 0.1,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#d0d0d0",
                "frameShininess": 0.2
            }'
            builtin: true
        }
        ListElement {
            text: "Boring"
            obj_string: '{
                "ambientLight": 0.1,
                "backgroundColor": "#000000",
                "bloom": 0.5,
                "brightness": 0.5,
                "burnIn": 0.05,
                "chromaColor": 1,
                "contrast": 0.8,
                "flickering": 0.0,
                "fontColor": "#ffffff",
                "fontName": "JETBRAINS_MONO",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.1,
                "horizontalSync": 0,
                "jitter": 0.0,
                "rasterization": 4,
                "rgbShift": 0,
                "saturationColor": 0.0,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.0,
                "windowOpacity": 1.0,
                "margin": 0.0,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#c0c0c0",
                "frameShininess": 0.2
            }'
            builtin: true
        }
        ListElement {
            text: "E-Ink"
            obj_string: '{
                "ambientLight": 0.6,
                "backgroundColor": "#f2f2ec",
                "bloom": 0.0,
                "brightness": 1.0,
                "burnIn": 0.6,
                "chromaColor": 0,
                "contrast": 0.5,
                "flickering": 0.0,
                "fontColor": "#101010",
                "fontName": "HACK",
                "fontSource": 0,
                "fontWidth": 1,
                "lineSpacing": 0.1,
                "glowingLine": 0.0,
                "horizontalSync": 0.0,
                "jitter": 0.0,
                "rasterization": 4,
                "rgbShift": 0,
                "saturationColor": 0,
                "screenCurvature": 0,
                "screenRadius": 0.0,
                "staticNoise": 0.0,
                "windowOpacity": 1,
                "margin": 0.1,
                "blinkingCursor": false,
                "frameSize": 0,
                "frameColor": "#cdcdcd",
                "frameShininess": 0.2
            }'
            builtin: true
        }
    }

    function getProfileIndexByName(name) {
        for (var i = 0; i < profilesList.count; i++) {
            if (profilesList.get(i).text === name)
                return i
        }
        return -1
    }

    /**
     * Append the built-in "IUT-MarkazMohasebat" mainframe profile: an exact
     * IBM 3278 look with the blinking block cursor and every IBM extra on.
     * ListElement literals cannot call JS, so it is composed here at runtime.
     */
    function appendBuiltinIbmProfile() {
        if (getProfileIndexByName("IUT-MarkazMohasebat") !== -1)
            return
        var keys = IbmProfile.mainframeKeys(PfKeys.defaultAssignments())
        profilesList.append({
                                "text": "IUT-MarkazMohasebat",
                                "obj_string": stringify(
                                    IbmProfile.mainframeProfile(
                                        PfKeys.serialize(keys))),
                                "builtin": true
                            })
    }

    Component.onCompleted: {
        // Manage the arguments from the QML side.
        var args = Qt.application.arguments
        if (args.indexOf("--verbose") !== -1) {
            verbose = true
        }
        // A clean run ignores every stored choice, profiles included.
        var cleanRun = args.indexOf("--default-settings") !== -1

        // The mainframe profile must exist before --profile can name it.
        appendBuiltinIbmProfile()
        // Factory copies first, then whatever the user saved over them:
        // Reset puts the former back, Save keeps refreshing the latter.
        captureFactoryProfiles()
        if (!cleanRun)
            loadBuiltinOverrides()

        if (!cleanRun) {
            loadSettings()
        }

        loadCustomProfiles()

        // Which profile the app opens with, and which one Save writes to.
        var storedDefault = cleanRun ? ""
                                     : (storage.getSetting("_DEFAULT_PROFILE") || "")
        var storedActive = cleanRun ? ""
                                     : (storage.getSetting("_ACTIVE_PROFILE") || "")
        defaultProfileName = Profiles.startupDefaultName(profilesList,
                                                          storedDefault)
        if (defaultProfileName !== storedDefault)
            persistDefaultProfile()

        var profileArgPosition = args.indexOf("--profile")
        var profileArg = profileArgPosition !== -1
                ? args[profileArgPosition + 1] : ""
        if (profileArgPosition !== -1
                && Profiles.indexOfName(profilesList, profileArg) === -1) {
            console.log("Warning: selected profile is not valid; ignoring it")
        }

        // --profile and the default bring their values with them; last
        // session's active profile is only named again, because its
        // values already sit in the snapshot loadSettings() applied --
        // so unsaved tweaks from last time are not thrown away.
        var loadName = Profiles.startupLoadName(profilesList, profileArg,
                                                 defaultProfileName)
        if (loadName !== "") {
            loadProfile(getProfileIndexByName(loadName))
        } else {
            var activeName = Profiles.startupActiveName(profilesList,
                                                         profileArg,
                                                         defaultProfileName,
                                                         storedActive)
            if (activeProfileName !== activeName) {
                activeProfileName = activeName
                persistActiveProfile()
            }
        }

        // Keep the CMS alias block in step with the setting.  A clean
        // (--default-settings) run stays side-effect free outside the app.
        if (!cleanRun && shellAliases)
            syncShellAliases()

        // Everything the screen shows has just been loaded: record it as
        // "already saved", then let the poll watch for the first change.
        rebaseAutoSave()
        autoSaveTimer.running = true

        initializedSettings()
    }

    // VARS ///////////////////////////////////////////////////////////////////
    property Label _sampleLabel: Label {
        text: "100%"
    }
    property real labelWidth: _sampleLabel.width
}
