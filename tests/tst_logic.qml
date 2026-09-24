/*******************************************************************************
* Qt Quick test: the shared logic modules as the QML engine sees them.
*
* Every module under app/qml/logic is loaded both by QML and by the Node suite
* (tests/logic).  Node can only prove the ECMAScript half of that promise;
* these tests import the very same files through the QML engine, so a Qt only
* construct (or a `module.exports` guard gone wrong) cannot slip through.
*******************************************************************************/
import QtTest

import "../app/qml/logic/aliases.js" as Aliases
import "../app/qml/logic/chrome.js" as Chrome
import "../app/qml/logic/colormode.js" as ColorMode
import "../app/qml/logic/defaults.js" as Defaults
import "../app/qml/logic/ibmprofile.js" as IbmProfile
import "../app/qml/logic/linehighlight.js" as LineLogic
import "../app/qml/logic/pfkeys.js" as PfKeys
import "../app/qml/logic/platform.js" as Platform
import "../app/qml/logic/sound.js" as Sound
import "../app/qml/logic/windows.js" as Windows

TestCase {
    name: "LogicModulesTests"

    /***************************************************************************
    * Chrome: full screen is the pure experience; leaving it brings the menu.
    ***************************************************************************/
    function test_nostalgicModeIsTheDefaultWindowed() {
        var v = Chrome.visibility({})
        compare(v.menubar, true)            // menu is back while windowed
        compare(v.tabBar, false)            // tab strip never under nostalgia
        compare(v.contextMenu, true)        // right-click too
        compare(v.sizeOverlay, false)
        compare(v.anythingVisible, true)
        compare(v.settingsWindow, true)     // reachable, never advertised
        compare(Chrome.hasChrome({}), true)
    }

    function test_nostalgicFullScreenShowsNothing() {
        var v = Chrome.visibility({ fullscreen: true })
        compare(v.menubar, false)
        compare(v.tabBar, false)
        compare(v.contextMenu, false)
        compare(v.sizeOverlay, false)
        compare(v.anythingVisible, false)
        compare(v.settingsWindow, true)
        compare(Chrome.hasChrome({ nostalgicMode: true, fullscreen: true }), false)
    }

    function test_nostalgicModeWinsOverEveryLegacySwitch() {
        var v = Chrome.visibility({
            nostalgicMode: true,
            showMenubar: true,
            showTerminalSize: true,
            tabCount: 4,
            isMacOS: true
        })
        compare(v.menubar, true)            // windowed: menu and...
        compare(v.contextMenu, true)        // ...right-click are for the mouse
        compare(v.tabBar, false)            // the legacy switches stay off
        compare(v.sizeOverlay, false)
        compare(v.anythingVisible, true)

        // ... and both disappear again the moment the window is full screen.
        v = Chrome.visibility({
            nostalgicMode: true, showMenubar: true, showTerminalSize: true,
            tabCount: 4, isMacOS: true, fullscreen: true
        })
        compare(v.menubar, false)
        compare(v.contextMenu, false)
        compare(v.sizeOverlay, false)
        compare(v.anythingVisible, false)
        compare(Chrome.hasChrome(
                    { nostalgicMode: true, fullscreen: true }), false)
    }

    function test_legacyBehaviourIsPreservedWhenNostalgicModeIsOff() {
        var mac = Chrome.visibility({
            nostalgicMode: false, isMacOS: true, tabCount: 2, showTerminalSize: true
        })
        compare(mac.menubar, true)          // macOS always owns a menu bar
        compare(mac.tabBar, true)
        compare(mac.contextMenu, true)
        compare(mac.sizeOverlay, true)
        compare(mac.anythingVisible, true)

        var linux = Chrome.visibility({
            nostalgicMode: false, isMacOS: false, showMenubar: false,
            tabCount: 1, showTerminalSize: false
        })
        compare(linux.menubar, false)
        compare(linux.tabBar, false)
        compare(linux.contextMenu, true)    // still a real terminal context menu
        compare(linux.sizeOverlay, false)
        compare(linux.anythingVisible, false)

        // The legacy branch never cared about full screen; it still does not.
        var macFs = Chrome.visibility({
            nostalgicMode: false, isMacOS: true, fullscreen: true,
            tabCount: 0, showTerminalSize: true
        })
        compare(macFs.menubar, true)
        compare(macFs.contextMenu, true)
    }

    /***************************************************************************
    * FILEL / XEDIT: mainframe functions resolved per platform.
    ***************************************************************************/
    function test_fileListAndXeditFollowThePlatform() {
        compare(PfKeys.commandFor("fileList", "x11"), "ls\r")
        compare(PfKeys.commandFor("fileList", "wayland"), "ls\r")
        compare(PfKeys.commandFor("fileList", "mac"), "ls\r")
        compare(PfKeys.commandFor("fileList", "win32"), "dir\r")
        compare(PfKeys.commandFor("fileList", "windows"), "dir\r")

        compare(PfKeys.commandFor("xedit", "x11"), "vi\r")
        compare(PfKeys.commandFor("xedit", "mac"), "vi\r")
        compare(PfKeys.commandFor("xedit", "win32"), "notepad\r")
        compare(PfKeys.commandFor("xedit", "windows"), "notepad\r")

        compare(PfKeys.commandFor("interrupt", "x11"), "")
        compare(PfKeys.commandFor("sendText", "win32"), "")

        compare(PfKeys.legend({ action: "fileList" }), "FILEL")
        compare(PfKeys.intercepts({ action: "fileList" }), true)
        compare(PfKeys.legend({ action: "xedit" }), "XEDIT")
        compare(PfKeys.intercepts({ action: "xedit" }), true)
    }

    /***************************************************************************
    * IUT-MarkazMohasebat: the built-in mainframe profile.
    ***************************************************************************/
    function test_mainframeProfileWiresEverythingOn() {
        var keys = IbmProfile.mainframeKeys(PfKeys.defaultAssignments())
        compare(keys.length, PfKeys.KEY_COUNT)
        compare(keys[4].action, "prevWindow")      // PF5 = Previous Window
        compare(keys[5].action, "splitHorizontal") // PF6 = Split Horizontal
        compare(keys[4].key, "F5")
        compare(keys[12].action, "interrupt")    // PA1 = Attention survives

        var p = IbmProfile.mainframeProfile(PfKeys.serialize(keys))
        // Green over black, the real 3278 face, flat glass...
        compare(p.fontColor, "#3cff7a")
        compare(p.backgroundColor, "#000000")
        compare(p.fontName, "IBM_3278")
        compare(p.screenCurvature, 0)
        // ... with the S/370 station's blinking block cursor.
        compare(p.blinkingCursor, true)
        compare(p.cursorStyle, "block")
        // Everything IBM, switched on at once.
        compare(p.showPfKeys, true)
        compare(p.audioEnabled, true)
        compare(p.keyClick, true)
        compare(p.bell, true)
        compare(p.highlightActiveLine, true)
        // Green over black on one phosphor: the profile says so itself,
        // and does not need the old chroma value to be inferred from.
        compare(p.colorMode, "monochrome")
        compare(ColorMode.shaderChromaFlag(p.colorMode), 0)

        var slots = PfKeys.parse(p.pfKeys)
        compare(slots[4].action, "prevWindow")
        compare(slots[12].action, "interrupt")
    }

    function test_ibmExtrasTravelThroughProfiles() {
        // Save side: always the full set.
        var saved = Defaults.pickIbmExtras({
            showPfKeys: true, pfKeys: "[]", audioEnabled: true,
            keyClick: true, keyClickVolume: 0.7, bell: true, bellVolume: 0.3,
            highlightActiveLine: true, activeLineOpacity: 0.4,
            cursorStyle: "half"
        })
        compare(saved.showPfKeys, true)
        compare(saved.keyClickVolume, 0.7)
        compare(saved.cursorStyle, "half")

        // Load side: present fields apply, absent ones stay undefined so the
        // caller keeps the current value (older visual-only profiles).
        var partial = Defaults.profileExtras({ showPfKeys: true, keyClickVolume: 2 })
        compare(partial.showPfKeys, true)
        compare(partial.keyClickVolume, 1)       // clamped, but present
        compare(partial.cursorStyle === undefined, true)
        compare(partial.audioEnabled === undefined, true)
        compare(partial.nostalgicMode === undefined, true) // chrome never a profile field

        // Wrong types are dropped, not trusted.
        var hostile = Defaults.profileExtras({ pfKeys: 42, bell: "loud" })
        compare(hostile.pfKeys === undefined, true)
        compare(hostile.bell === undefined, true)
    }

    /***************************************************************************
    * Shell aliases: the CMS command block lives in the profile files.
    ***************************************************************************/
    function test_cmsAliasBlockIsManagedAndIdempotent() {
        var installed = Aliases.upsert("", Aliases.block())
        compare(installed.indexOf(Aliases.START_MARKER), 0)
        compare(Aliases.upsert(installed, Aliases.block()), installed)

        var user = "export EDITOR=vim\n"
        var withBlock = Aliases.upsert(user, Aliases.block())
        compare(withBlock.indexOf(user), 0)

        var stripped = Aliases.strip(withBlock)
        compare(stripped.indexOf(Aliases.START_MARKER), -1)
        compare(stripped.indexOf(Aliases.END_MARKER), -1)
        verify(stripped.indexOf("export EDITOR=vim") >= 0,
               "user content survives the strip")
        compare(Aliases.strip(stripped), stripped)
        compare(Aliases.strip(""), "")
        // A file that only holds the block ends up empty.
        compare(Aliases.strip(Aliases.upsert("", Aliases.block())), "")
    }

    function test_cmsAliasesCoverTheCommandList() {
        var block = Aliases.block()
        var expected = {
            FILEL: "ls", FILELIST: "ls", LISTFILE: "ls -l", COPYFILE: "cp",
            ERASE: "rm -i", RENAME: "mv", TYPE: "cat", ACCESS: "mount",
            RELEASE: "umount", FORMAT: "mkfs"
        }
        for (var name in expected) {
            verify(block.indexOf("alias " + name + "='" + expected[name] + "'") >= 0,
                   name + " alias missing from the block")
        }
        // SAVE / FILE / FFILE are named as XEDIT side commands, not aliased.
        verify(block.indexOf("XEDIT") >= 0, "XEDIT note missing")
    }

    function test_aliasTargetsMatchThePlatform() {
        var none = function () { return false }
        compare(Aliases.targets("linux", none).join(","), ".bashrc")
        // Git Bash reads ~/.bashrc: the top-up story on Windows.
        compare(Aliases.targets("windows", none).join(","), ".bashrc")
        // macOS defaults to zsh, so ~/.zshrc is ensured as well.
        compare(Aliases.targets("osx", none).join(","), ".bashrc,.zshrc")

        var hasProfile = function (name) { return name === ".profile" }
        compare(Aliases.targets("linux", hasProfile).join(","), ".bashrc,.profile")
    }

    /***************************************************************************
    * Shortcuts: the same function always lives in the same place as natively.
    ***************************************************************************/
    function test_shortcutsFollowThePlatformConvention() {
        // macOS
        compare(Platform.sequence("mac", "newWindow"), "Meta+N")
        compare(Platform.sequence("osx", "newTab"), "Meta+T")
        compare(Platform.sequence("macos", "closeTab"), "Meta+W")
        compare(Platform.sequence("darwin", "closeWindow"), "Meta+Shift+W")
        compare(Platform.sequence("mac", "nextWindow"), "Meta+`")
        compare(Platform.sequence("mac", "prevWindow"), "Meta+Shift+`")
        compare(Platform.sequence("mac", "settings"), "Meta+,")
        compare(Platform.sequence("mac", "quit"), "StandardKey.Quit")

        // Windows
        compare(Platform.sequence("win32", "newWindow"), "Ctrl+Shift+N")
        compare(Platform.sequence("windows", "closeWindow"), "Ctrl+Shift+W")
        compare(Platform.sequence("win", "closeTab"), "Ctrl+W")
        compare(Platform.sequence("win32", "nextWindow"), "Alt+`")
        compare(Platform.sequence("win32", "quit"), "Ctrl+Shift+Q")

        // Linux: identical to Windows, Alt+` is GNOME/KDE "switch windows".
        compare(Platform.sequence("x11", "newWindow"), "Ctrl+Shift+N")
        compare(Platform.sequence("wayland", "newTab"), "Ctrl+Shift+T")
        compare(Platform.sequence("linux", "nextWindow"), "Alt+`")
        compare(Platform.sequence("linux", "prevWindow"), "Alt+Shift+`")
        compare(Platform.sequence("linux", "settings"), "Ctrl+,")
        compare(Platform.sequence("freebsd", "copy"), "Ctrl+Shift+C")
        compare(Platform.sequence("x11", "paste"), "Ctrl+Shift+V")

        // Platform agnostic functions stay on Qt's own standard keys.
        compare(Platform.sequence("linux", "fullscreen"), "StandardKey.FullScreen")
        compare(Platform.sequence("mac", "fullscreen"), "StandardKey.FullScreen")
        compare(Platform.sequence("mac", "zoomIn"), "StandardKey.ZoomIn")
        compare(Platform.sequence("win32", "zoomOut"), "StandardKey.ZoomOut")
        compare(Platform.sequence("mac", "copy"), "StandardKey.Copy")
        compare(Platform.sequence("mac", "paste"), "StandardKey.Paste")
        compare(Platform.sequence("win32", "paste"), "Ctrl+Shift+V")

        // Unknown functions resolve to nothing rather than to garbage.
        compare(Platform.sequence("linux", "teleport"), "")
        compare(Platform.isMac("osx"), true)
        compare(Platform.isMac("x11"), false)
    }

    /***************************************************************************
    * Multi window arithmetic.
    ***************************************************************************/
    function test_windowsCycleAndWrap() {
        compare(Windows.cycleIndex(0, 3, 1), 1)
        compare(Windows.cycleIndex(2, 3, 1), 0)      // wraps forward
        compare(Windows.cycleIndex(0, 3, -1), 2)     // wraps backward
        compare(Windows.cycleIndex(-1, 3, 1), 1)     // unknown active -> first
        compare(Windows.shouldCycle(0, 3), true)
        compare(Windows.shouldCycle(0, 1), false)    // one window: stay quiet
        compare(Windows.shouldCycle(0, 0), false)
        compare(Windows.wrap(5, 3), 2)
        compare(Windows.wrap(-1, 3), 2)
        compare(Windows.wrap(2, 0), -1)
    }

    function test_newWindowPicksAProfileToLoad() {
        // A named profile (the submenu) wins outright.
        compare(Windows.newWindowLoadName("IUT-MarkazMohasebat", ""),
                "IUT-MarkazMohasebat")
        compare(Windows.newWindowLoadName("IUT-MarkazMohasebat", "Deep Blue"),
                "IUT-MarkazMohasebat")
        // Plain "New Window" (no argument) opens on the default profile...
        compare(Windows.newWindowLoadName(undefined, "Deep Blue"), "Deep Blue")
        // ...and with none configured it loads nothing rather than guessing.
        compare(Windows.newWindowLoadName(undefined, ""), "")
        compare(Windows.newWindowLoadName(undefined, undefined), "")
        // "" is the explicit "load nothing": what the first window says, so
        // startup's --profile / default / snapshot choice survives.
        compare(Windows.newWindowLoadName("", "Deep Blue"), "")
        compare(Windows.newWindowLoadName(null, "Deep Blue"), "")
        compare(Windows.newWindowLoadName(42, "Deep Blue"), "")
        compare(Windows.newWindowLoadName({}, "Deep Blue"), "")
    }

    function test_closingAWindowPicksTheRightSuccessor() {
        compare(Windows.indexAfterRemoval(1, 1, 3), 1)   // active closed
        compare(Windows.indexAfterRemoval(2, 2, 3), 1)   // last one closed
        compare(Windows.indexAfterRemoval(0, 2, 3), 0)   // an earlier one
        compare(Windows.indexAfterRemoval(1, 2, 3), 1)   // a later one
        compare(Windows.indexAfterRemoval(0, 0, 1), -1)  // nothing left
    }

    /***************************************************************************
    * IBM PF / PA keys.
    ***************************************************************************/
    function test_pfDefaultsMatchTheMainframe() {
        var defs = PfKeys.defaultAssignments()
        compare(defs.length, PfKeys.KEY_COUNT)       // 12 PF + 3 PA
        compare(PfKeys.PF_COUNT, 12)
        compare(PfKeys.PA_COUNT, 3)

        compare(defs[0].key, "F1")
        compare(defs[11].key, "F12")
        compare(defs[11].label, "PF12")

        // The factory panel: the menu functions, in the IBM order.
        compare(defs[0].action, "help")            // PF1  ISPF F1 = Help
        compare(defs[1].action, "splitVertical")   // PF2  ISPF F2 = Split
        compare(defs[3].action, "nextWindow")      // PF4
        compare(defs[4].action, "prevWindow")      // PF5
        compare(defs[10].action, "fullscreen")     // PF11 exit full screen
        compare(defs[11].action, "newWindow")      // PF12

        // IBM PC / 3270 default bindings for the program attention keys.
        compare(defs[12].key, "Ctrl+F1")
        compare(defs[13].key, "Ctrl+F2")
        compare(defs[14].key, "Ctrl+F3")
        compare(defs[12].label, "PA1")

        // PA1 is the classic TSO Attention (break) key, wired to SIGINT.
        compare(defs[12].action, "interrupt")
        compare(PfKeys.actionById("interrupt").payload, "\u0003")
        // ERASE INPUT is Ctrl+U on POSIX.
        compare(PfKeys.actionById("eraseInput").payload, "\u0015")
    }

    function test_onlyAssignedKeysAreIntercepted() {
        var defs = PfKeys.defaultAssignments()

        // The factory panel: every PF key carries a menu function and
        // prints its legend, exactly like an ISPF / CMS panel did.
        for (var i = 0; i < PfKeys.PF_COUNT; i++) {
            compare(PfKeys.intercepts(defs[i]), true)
            compare(PfKeys.legend(defs[i]) !== "", true)
            compare(PfKeys.actionById(defs[i].action).kind, "app",
                    "PF" + (i + 1) + " is an app function, not a command")
        }

        compare(PfKeys.intercepts(defs[12]), true)   // PA1 Attention
        compare(PfKeys.intercepts(defs[13]), false)  // PA2 unassigned
        compare(PfKeys.intercepts(defs[14]), false)  // PA3 unassigned
        compare(PfKeys.legend(defs[12]), "Attention")
        compare(PfKeys.anyIntercepting(defs), true)

        // Out of the box the twelve PF keys plus PA1 claim their slots;
        // PA2 and PA3 keep passing through.
        var claimed = []
        var normalized = PfKeys.normalize([])
        for (var j = 0; j < normalized.length; j++) {
            if (PfKeys.intercepts(normalized[j]))
                claimed.push(j)
        }
        compare(claimed.join(","), "0,1,2,3,4,5,6,7,8,9,10,11,12")
        compare(PfKeys.collisions(normalized).length, 0)
    }

    function test_normalizeRepairsHostileInput() {
        var out = PfKeys.normalize([
            { action: "nonsense", key: "", label: "" },
            "not an object"
        ])
        compare(out.length, PfKeys.KEY_COUNT)
        compare(out[0].action, "help")            // unknown action -> default
        compare(out[0].key, "F1")                // empty key -> default
        compare(out[0].label, "PF1")             // empty label -> default
        compare(out[1].key, "F2")                // non object -> all defaults
        compare(out[12].action, "interrupt")     // untouched default survives
    }

    function test_macroTextBehavesLikeTheEnterKey() {
        // \n in a macro has to reach the shell as a carriage return.
        compare(PfKeys.macroText("ls \\n"), "ls \r")
        compare(PfKeys.macroText("\\r"), "\r")
        compare(PfKeys.macroText("\\t"), "\t")
        compare(PfKeys.macroText("\\e"), "\u001b")
        compare(PfKeys.macroText("\\\\"), "\\")
        compare(PfKeys.macroText("plain"), "plain")
        compare(PfKeys.macroText(undefined), "")
    }

    function test_helpCommandMapsTopicToMan() {
        // Blank topic -> list the whole manual with `man -k .`.
        compare(PfKeys.helpCommand(""), "man -k .\r")
        compare(PfKeys.helpCommand("   "), "man -k .\r")
        compare(PfKeys.helpCommand(undefined), "man -k .\r")
        compare(PfKeys.helpCommand(null), "man -k .\r")
        // A topic -> that man page, quoted for the shell.
        compare(PfKeys.helpCommand("printf"), "man -- 'printf'\r")
        compare(PfKeys.helpCommand("echo hi"), "man -- 'echo hi'\r")
        compare(PfKeys.helpCommand("a'b"), "man -- 'a'\\''b'\r")
    }

    function test_serializeRoundTrips() {
        var defs = PfKeys.defaultAssignments()
        defs[0].action = "newWindow"
        defs[0].payload = ""

        var restored = PfKeys.parse(PfKeys.serialize(defs))
        compare(restored.length, defs.length)
        compare(restored[0].action, "newWindow")
        compare(restored[12].action, "interrupt")

        compare(PfKeys.parse("{ not json").length, PfKeys.KEY_COUNT)
        compare(PfKeys.parse(undefined).length, PfKeys.KEY_COUNT)
    }

    /***************************************************************************
    * Sound gating.
    ***************************************************************************/
    function test_soundGates() {
        var on = { audioEnabled: true, keyClick: true, bell: true }
        compare(Sound.shouldClick(on, {}), true)
        compare(Sound.shouldBell(on), true)

        compare(Sound.shouldClick({ audioEnabled: false, keyClick: true }, {}), false)
        compare(Sound.shouldBell({ audioEnabled: false, bell: true }), false)
        compare(Sound.shouldClick({ audioEnabled: true, keyClick: false }, {}), false)
        compare(Sound.shouldBell({ audioEnabled: true, bell: false }), false)

        compare(Sound.shouldClick(on, { isAutoRepeat: true }), false)
        compare(Sound.shouldClick(on, { isModifierOnly: true }), false)
        compare(Sound.shouldClick(on, { fromPaste: true }), false)
    }

    function test_volumesAreClamped() {
        compare(Sound.volume(0.5), 0.5)
        compare(Sound.volume(2, 0.5), 1)
        compare(Sound.volume(-1, 0.5), 0)
        compare(Sound.volume(undefined, 0.25), 0.25)
        compare(Sound.volume(null, 0.75), 0.75)
        compare(Sound.volume("nope", 0.5), 0.5)
    }

    /***************************************************************************
    * Retro settings: defaults, tolerant merge, hostile JSON.
    ***************************************************************************/
    function test_retroDefaults() {
        var d = Defaults.defaults()
        compare(d.nostalgicMode, true)      // no chrome out of the box
        compare(d.showPfKeys, false)        // legend opt-in
        compare(d.audioEnabled, false)      // click opt-in
        compare(d.highlightActiveLine, false)
        compare(d.cursorStyle, "block")
        compare(d.activeLineOpacity, 0.18)
        compare(d.keyClickVolume, 0.5)
    }

    function test_storedSettingsAreRepaired() {
        var m = Defaults.merge({
            audioEnabled: "yes",            // wrong type -> default
            keyClickVolume: 9,              // out of range -> clamped
            bellVolume: -4,                 // out of range -> clamped
            activeLineOpacity: "0.5",       // numeric string -> accepted
            cursorStyle: "weird",           // unknown value -> default
            highlightActiveLine: true,
            unknownKey: "ignored"
        })
        compare(m.audioEnabled, false)
        compare(m.keyClickVolume, 1)
        compare(m.bellVolume, 0)
        compare(m.activeLineOpacity, 0.5)
        compare(m.cursorStyle, "block")
        compare(m.highlightActiveLine, true)
        compare(m.nostalgicMode, true)
        compare("unknownKey" in m, false)
    }

    function test_hostileJsonFallsBackToDefaults() {
        var d = Defaults.parse("{ not json")
        compare(d.nostalgicMode, true)
        compare(d.cursorStyle, "block")
        compare(Defaults.parse(undefined).audioEnabled, false)
        compare(Defaults.parse("").showPfKeys, false)

        var round = Defaults.parse(Defaults.serialize({ showPfKeys: true }))
        compare(round.showPfKeys, true)
        compare(round.nostalgicMode, true)
    }

    /***************************************************************************
    * Colour mode: monochrome simulation or the console's own colours.
    ***************************************************************************/
    function test_colourModeSelectsTheShaderVariant() {
        compare(ColorMode.MODES.join(","), "monochrome,color")
        compare(ColorMode.isValid("monochrome"), true)
        compare(ColorMode.isValid("color"), true)
        compare(ColorMode.isValid("colour"), false)
        compare(ColorMode.normalize("nonsense"), "monochrome")
        compare(ColorMode.modeIndex("color"), 1)
        compare(ColorMode.modeAt(1), "color")
        compare(ColorMode.modeAt(0), "monochrome")
        compare(ColorMode.modeAt(9), "monochrome")

        // The chroma variant is the mode: 1 keeps the console's hues.
        compare(ColorMode.shaderChromaFlag("color"), 1)
        compare(ColorMode.shaderChromaFlag("monochrome"), 0)
        compare(ColorMode.shaderChromaFlag(undefined), 0)
    }

    function test_profilesBeforeColourModeAreInferredFromChroma() {
        compare(ColorMode.infer(0), "monochrome")
        compare(ColorMode.infer(0.25), "monochrome")
        compare(ColorMode.infer(0.49), "monochrome")
        compare(ColorMode.infer(0.5), "color")
        compare(ColorMode.infer(1), "color")
        compare(ColorMode.infer(undefined), "monochrome")
        compare(ColorMode.infer(""), "monochrome")
        compare(ColorMode.infer(null), "monochrome")
        compare(ColorMode.infer("not a number"), "monochrome")
        compare(ColorMode.infer(true), "monochrome")
    }

    function test_phosphorPresetsAreBlackUnderAColouredFace() {
        compare(ColorMode.PHOSPHORS.length, 5)
        compare(ColorMode.phosphorNames().join(","),
                "Black/White,Black/Green,Black/Blue,Black/Yellow,Black/Red")
        for (var i = 0; i < ColorMode.PHOSPHORS.length; i++) {
            compare(ColorMode.PHOSPHORS[i].backgroundColor, "#000000")
            verify(ColorMode.PHOSPHORS[i].fontColor !== "#000000")
            compare(ColorMode.PHOSPHORS[i].name.indexOf("Black/"), 0)
        }
        compare(ColorMode.PHOSPHORS[1].fontColor, "#3cff7a")   // the IUT green

        compare(ColorMode.phosphorIndex("#3cff7a", "#000000"), 1)
        compare(ColorMode.phosphorIndex("#FFFFFF", "#000000"), 0)
        compare(ColorMode.phosphorIndex("#ff8100", "#000000"), -1)  // custom
        compare(ColorMode.phosphorIndex("#3cff7a", "#101010"), -1)
        compare(ColorMode.phosphorIndex(undefined, "#000000"), -1)
        compare(ColorMode.phosphorIndex("#3cff7a", "#00000000"), -1)
        compare(ColorMode.hex("#ff3cff7a"), "#3cff7a")
        compare(ColorMode.hex("#80ff0000"), "")
    }

    /***************************************************************************
    * Active line geometry.
    ***************************************************************************/
    function test_bandGeometry() {
        var r = LineLogic.bandRect(
                    { x: 40, y: 180, width: 10, height: 18 },
                    { screenX: 8, screenWidth: 624, terminalY: 4 })
        verify(r !== null)
        compare(r.x, 8)
        compare(r.y, 184)
        compare(r.width, 624)
        compare(r.height, 18)

        compare(LineLogic.bandRect(null, {}), null)
        compare(LineLogic.bandRect({ x: 0, y: 0, width: 0, height: 18 }, {}), null)
        compare(LineLogic.bandRect({ x: 0, y: 0, width: 10, height: 0 }, {}), null)

        compare(LineLogic.cursorRow({ x: 40, y: 180, width: 10, height: 18 }), 10)
        compare(LineLogic.cursorColumn({ x: 40, y: 180, width: 10, height: 18 }), 4)
        compare(LineLogic.cursorRow(null), -1)
        compare(LineLogic.bandOpacity(9), 1)
        compare(LineLogic.bandOpacity(-9), 0)
        compare(LineLogic.bandOpacity(undefined), 0)
    }
}
