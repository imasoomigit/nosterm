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
import QtQuick
import QtQml
import QtQuick.Window
import QtQuick.Controls

import "menus"
import "logic/platform.js" as Platform
import "logic/pfkeys.js" as PfKeys
import "logic/chrome.js" as Chrome
import "logic/sound.js" as SoundLogic

ApplicationWindow {
    id: terminalWindow

    width: 1024
    height: 768

    // Show the window once it is ready.
    Component.onCompleted: {
        visible = true
    }

    minimumWidth: 320
    minimumHeight: 240

    visible: false

    property bool fullscreen: false
    // Read the *real* window state: the green button and any window-manager
    // full screen path change `visibility` without touching our flag.
    readonly property bool isFullscreen: visibility === Window.FullScreen

    // Top-edge pointer reveal: the "touch the top of the screen" menu
    // mechanism.  Transient -- cleared the moment the window leaves full
    // screen, however it leaves.
    property bool menubarReveal: false

    onFullscreenChanged: {
        menubarReveal = false
        visibility = (fullscreen ? Window.FullScreen : Window.Windowed)
    }
    onVisibilityChanged: function(visibility) {
        if (visibility !== Window.FullScreen)
            menubarReveal = false
    }

    /**
     * Chrome for *this* window.  Nostalgic mode hides the menu bar and the
     * context menu only while full screen; leaving full screen brings the
     * menu bar back and it stays until you go full screen again.
     */
    readonly property var chrome: Chrome.visibility({
        nostalgicMode: appSettings.nostalgicMode,
        showMenubar: appSettings.showMenubar,
        showTerminalSize: appSettings.showTerminalSize,
        isMacOS: appSettings.isMacOS,
        fullscreen: isFullscreen
    })

    menuBar: WindowMenu { target: terminalWindow }

    /**
     * Everything a menu bar needs, published as a single property.
     *
     * macOS builds the menu bar from the *active* window, and Settings is a
     * window too: it has to offer the very same bar (aimed at whichever
     * terminal window was last active) or the whole menu empties while it is
     * focused.  A menu bar living in another file cannot see this file's ids,
     * so the actions go out as properties.
     *
     * "bigger"/"smaller" rather than "zoomIn"/"zoomOut": those names belong
     * to the ids these point at, and a property may not shadow them.
     */
    property QtObject menuActions: QtObject {
        readonly property Action fullscreen: fullscreenAction
        readonly property Action newWindow: newWindowAction
        readonly property Action newTab: newTabAction
        readonly property Action closeTab: closeTabAction
        readonly property Action closeWindow: closeWindowAction
        readonly property Action quit: quitAction
        readonly property Action settings: showsettingsAction
        readonly property Action copy: copyAction
        readonly property Action paste: pasteAction
        readonly property Action nextWindow: nextWindowAction
        readonly property Action previousWindow: previousWindowAction
        readonly property Action splitVertical: splitVerticalAction
        readonly property Action splitHorizontal: splitHorizontalAction
        readonly property Action bigger: zoomIn
        readonly property Action smaller: zoomOut
        readonly property Action keySound: toggleKeySoundAction
        readonly property Action help: helpAction
        readonly property Action about: showAboutAction
    }

    /**
     * Optional IBM style audio for the whole window.  Kept here rather than
     * per terminal so that one window has exactly one sound, whichever tab is
     * showing and whether the press came from the terminal or a PF key.
     */
    property SoundManager soundManager: SoundManager {
        active: appSettings.audioEnabled
        clickEnabled: appSettings.keyClick
        bellEnabled: appSettings.bell
        clickVolume: appSettings.keyClickVolume
        clickSource: SoundLogic.sampleSource(appSettings.keyClickSound)
        bellVolume: appSettings.bellVolume
    }

    /**
     * The HELP input: PF1 and the Help menu first try to open the topic
     * field right in the PF panel on the glass (the way a mainframe let
     * you type into its own legend area).  A blank topic becomes
     * `man -k .` (list every page, the way CMS HELP with no operand
     * listed the command set), anything else opens that page.  When the
     * legend is not printed there is no cell to type into, and the
     * dialog below takes over.
     */
    HelpDialog {
        id: helpDialog
        // Dress it like the machine: profile phosphor, screen font.
        bgColor: appSettings.backgroundColor
        fgColor: appSettings.fontColor
        uiFontFamily: appSettings.terminalFontFamily
        onSubmitted: function(topic) { terminalWindow.submitHelpTopic(topic) }
    }

    /** Turn a HELP topic into the man command the terminal runs. */
    function submitHelpTopic(topic) {
        terminalTabs.sendTextToCurrent(PfKeys.helpCommand(topic))
    }

    property real normalizedWindowScale: 1024 / ((0.5 * width + 0.5 * height))

    color: "#00000000"

    title: terminalTabs.currentTitle

    // Let the window manager aware of which window we are on, so that
    // "next window" starts from the right place.
    onActiveChanged: {
        if (active)
            appRoot.activeWindow = terminalWindow
    }

    /**
     * Resolve one entry of the platform key map.
     *
     * Everything is a plain sequence string ("Ctrl+Shift+N") except the few
     * functions where Qt already knows the platform's own convention: those
     * are spelled "StandardKey.X" here and handed to Qt as the real enum, so
     * the shortcut lands exactly where the OS puts it.
     */
    function keySequence(name) {
        switch (name) {
        case "StandardKey.FullScreen": return StandardKey.FullScreen
        case "StandardKey.Quit":       return StandardKey.Quit
        case "StandardKey.Copy":       return StandardKey.Copy
        case "StandardKey.Paste":      return StandardKey.Paste
        case "StandardKey.ZoomIn":     return StandardKey.ZoomIn
        case "StandardKey.ZoomOut":    return StandardKey.ZoomOut
        default:                       return name
        }
    }

    /** The sequence for a named function on the current platform. */
    function seq(name) {
        return keySequence(Platform.sequence(Qt.platform.os, name))
    }

    Action {
        id: fullscreenAction
        text: qsTr("Fullscreen")
        // F11 (Windows/Linux) or Cmd+Ctrl+F (macOS): the native binding on
        // every platform, so it works whether or not a menu bar is showing.
        shortcut: seq("fullscreen")
        // Toggle against the real window state: the green button can enter
        // full screen without setting our flag, and leaving that way can
        // leave the flag stuck on.  Whatever path is taken, `visibility`
        // ends up truthful, which is what the chrome rules read.
        onTriggered: {
            if (isFullscreen) {
                fullscreen = false
                visibility = Window.Windowed
            } else {
                fullscreen = true
                visibility = Window.FullScreen
            }
        }
        checkable: true
        checked: isFullscreen
    }
    Action {
        id: newWindowAction
        text: qsTr("New Window")
        shortcut: seq("newWindow")
        onTriggered: appRoot.createWindow()
    }
    Action {
        id: nextWindowAction
        text: qsTr("Next Window")
        shortcut: seq("nextWindow")
        onTriggered: appRoot.nextWindow()
    }
    Action {
        id: previousWindowAction
        text: qsTr("Previous Window")
        shortcut: seq("prevWindow")
        onTriggered: appRoot.previousWindow()
    }
    Action {
        id: closeWindowAction
        text: qsTr("Close Window")
        shortcut: seq("closeWindow")
        onTriggered: terminalWindow.close()
    }
    Action {
        id: quitAction
        text: qsTr("Quit")
        shortcut: seq("quit")
        onTriggered: appSettings.close()
    }
    Action {
        id: showsettingsAction
        text: qsTr("Settings")
        shortcut: seq("settings")
        onTriggered: {
            settingsWindow.show()
            settingsWindow.requestActivate()
            settingsWindow.raise()
        }
    }
    Action {
        id: copyAction
        text: qsTr("Copy")
        shortcut: seq("copy")
    }
    Action {
        id: pasteAction
        text: qsTr("Paste")
        shortcut: seq("paste")
    }
    Action {
        id: zoomIn
        text: qsTr("Zoom In")
        shortcut: seq("zoomIn")
        onTriggered: appSettings.incrementScaling()
    }
    Action {
        id: zoomOut
        text: qsTr("Zoom Out")
        shortcut: seq("zoomOut")
        onTriggered: appSettings.decrementScaling()
    }
    // The physical spellings of "bigger": Qt's ZoomIn binding only ever
    // matches an unshifted "+" key, a US "+" arrives as Ctrl+Shift+'+'
    // and "=" as Ctrl+'=' -- and on direct-Plus / numpad keyboards the
    // plain Ctrl+'+' press is the one that works.  They are built with
    // Instantiator, NOT Repeater: Repeater refuses non-Item delegates
    // ("Delegate must be of Item type") so the Shortcuts it appeared to
    // declare were never created at all.  Application context, so they
    // still match in full screen where the menu Action's window context
    // can fail to resolve; when both are live for one sequence Qt
    // prefers the Action, so the overlap is safe (see zoomSpellings).
    Instantiator {
        model: Platform.zoomSpellings(Qt.platform.os, "zoomIn")
        delegate: Shortcut {
            required property string modelData
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: zoomIn.trigger()
        }
    }
    Instantiator {
        model: Platform.zoomSpellings(Qt.platform.os, "zoomOut")
        delegate: Shortcut {
            required property string modelData
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: zoomOut.trigger()
        }
    }
    Action {
        id: showAboutAction
        text: qsTr("About")
        onTriggered: {
            aboutDialog.show()
            aboutDialog.requestActivate()
            aboutDialog.raise()
        }
    }
    Action {
        id: newTabAction
        text: qsTr("New Tab")
        shortcut: seq("newTab")
        onTriggered: terminalTabs.addTab()
    }
    Action {
        id: closeTabAction
        text: qsTr("Close Tab")
        shortcut: seq("closeTab")
        onTriggered: terminalTabs.closeTab(terminalTabs.currentIndex)
    }
    Action {
        id: helpAction
        text: qsTr("Help…")
        // Type the topic straight into the PF HELP cell on the glass;
        // with the legend hidden, fall back to the dialog.
        onTriggered: {
            if (!terminalTabs.requestHelpInput())
                helpDialog.openForHelp()
        }
    }
    Action {
        id: splitVerticalAction
        text: qsTr("Split Vertical")
        onTriggered: terminalTabs.split(1)
    }
    Action {
        id: splitHorizontalAction
        text: qsTr("Split Horizontal")
        onTriggered: terminalTabs.split(2)
    }
    Action {
        id: toggleKeySoundAction
        text: qsTr("Key Click Sound")
        checkable: true
        checked: appSettings.keyClick
        // trigger() flips `checked` first; SoundLogic also arms the master
        // audio gate when the click turns on, so it is actually audible.
        onTriggered: {
            var s = SoundLogic.toggleKeyClick({
                keyClick: !checked,
                audioEnabled: appSettings.audioEnabled
            })
            appSettings.keyClick = s.keyClick
            appSettings.audioEnabled = s.audioEnabled
        }
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+1" : "Alt+1"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 0) terminalTabs.currentIndex = 0
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+2" : "Alt+2"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 1) terminalTabs.currentIndex = 1
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+3" : "Alt+3"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 2) terminalTabs.currentIndex = 2
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+4" : "Alt+4"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 3) terminalTabs.currentIndex = 3
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+5" : "Alt+5"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 4) terminalTabs.currentIndex = 4
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+6" : "Alt+6"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 5) terminalTabs.currentIndex = 5
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+7" : "Alt+7"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 6) terminalTabs.currentIndex = 6
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+8" : "Alt+8"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 7) terminalTabs.currentIndex = 7
    }
    Shortcut {
        sequence: appSettings.isMacOS ? "Meta+9" : "Alt+9"
        context: Qt.WindowShortcut
        onActivated: if (terminalTabs.count > 8) terminalTabs.currentIndex = 8
    }

    /***************************************************************************
    * IBM 3270 style PF / PA keys.
    *
    * One Shortcut per slot, scoped to this window.  A slot claims its key
    * only while the PF panel is showing: with the panel hidden the raw
    * F-keys fall through to the shell untouched (nothing changes for
    * anyone who never turned the panel on), a slot whose function is "Off"
    * never claims anything, and everything else is claimed here before the
    * terminal widget ever sees it.
    *
    * The legend these keys belong to is printed by PfKeyBar on its own
    * strip of chassis below the CRT (see TerminalTabs.qml), and it
    * deliberately has no mouse handling at all.
    ***************************************************************************/
    Instantiator {
        model: appSettings.pfAssignments.length
        delegate: Shortcut {
            sequence: index < appSettings.pfAssignments.length
                      ? appSettings.pfAssignments[index].key : ""
            context: Qt.WindowShortcut
            enabled: appSettings.showPfKeys
                     && index < appSettings.pfAssignments.length
                     && PfKeys.intercepts(appSettings.pfAssignments[index])
            onActivated: terminalWindow.dispatchPfAction(index)
        }
    }

    /** Execute the function bound to PF/PA slot `index`. */
    function dispatchPfAction(index) {
        // The Shortcut consumed the keystroke, so the terminal never saw it:
        // click here to keep the tactile feedback consistent.
        if (soundManager)
            soundManager.keyClick()

        var assignments = appSettings.pfAssignments
        if (index < 0 || index >= assignments.length)
            return

        var assignment = assignments[index]
        var action = PfKeys.actionById(assignment.action)
        if (!action)
            return

        if (action.kind === "term") {
            // Attention (Ctrl+C), Erase Input (Ctrl+U) and user macros all
            // travel the same way: straight into the active terminal.
            // FILEL and XEDIT resolve per platform first (ls/dir, vi/notepad).
            var text = action.id === "sendText"
                    ? PfKeys.macroText(assignment.payload)
                    : (PfKeys.commandFor(action.id, Qt.platform.os) || action.payload)
            terminalTabs.sendTextToCurrent(text)
            return
        }

        dispatchAppAction(action.id)
    }

    /** Map an action id onto the QAction that implements it. */
    function dispatchAppAction(id) {
        switch (id) {
        case "newWindow":   newWindowAction.trigger(); break
        case "nextWindow":  appRoot.nextWindow(); break
        case "prevWindow":  appRoot.previousWindow(); break
        case "closeWindow": closeWindowAction.trigger(); break
        case "newTab":      newTabAction.trigger(); break
        case "closeTab":    closeTabAction.trigger(); break
        case "fullscreen":  fullscreenAction.trigger(); break
        // The View menu's zoom, bindable to a PF key: same rungs, so the
        // legend and the keyboard never disagree about size.
        case "bigger":      zoomIn.trigger(); break
        case "smaller":     zoomOut.trigger(); break
        case "settings":    showsettingsAction.trigger(); break
        case "help":        helpAction.trigger(); break
        case "saveProfile":
            // Nothing active yet: bring the profile panel up, where the
            // name prompt explains itself; otherwise it saved silently.
            if (!appSettings.saveActiveProfile())
                showsettingsAction.trigger()
            break
        case "quit":        quitAction.trigger(); break
        case "splitVertical":   splitVerticalAction.trigger(); break
        case "splitHorizontal": splitHorizontalAction.trigger(); break
        case "toggleKeySound":  toggleKeySoundAction.trigger(); break
        case "copy":        copyAction.trigger(); break
        case "paste":       pasteAction.trigger(); break
        default: break
        }
    }

    TerminalTabs {
        id: terminalTabs
        width: parent.width
        height: (parent.height + Math.abs(y))
        onHelpSubmitted: function(topic) { terminalWindow.submitHelpTopic(topic) }
    }
    Loader {
        anchors.centerIn: parent
        active: appSettings.chrome.sizeOverlay
        sourceComponent: SizeOverlay {
            z: 3
            terminalSize: terminalTabs.terminalSize
        }
    }
    onClosing: {
        appRoot.closeWindow(terminalWindow)
    }
}
