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
import QtQuick.Controls 2.0

import QMLTermWidget 2.0

import "menus"
import "utils.js" as Utils

Item{
    id: terminalContainer
    signal sessionFinished()

    /** A HELP topic was typed into the PF panel: carry it up to the window. */
    signal helpSubmitted(string topic)

    property size virtualResolution: Qt.size(kterminal.totalWidth, kterminal.totalHeight)
    property alias mainTerminal: kterminal

    /**
     * The item whose CRT shader warps the picture: the tab's stage, which
     * may hold several panes (see CrtUnit.qml).  Null makes this pane its
     * own unit, which is exactly the legacy single-pane mapping -- used
     * as the fallback until the stage is there.
     */
    property Item warpSurface: null
    /** Virtual size of the whole warped picture (the stage's contents). */
    property size warpVirtualSize: virtualResolution

    property real fontWidth: 1.0
    property real screenScaling: 1.0
    property real scaleTexture: 1.0
    property alias title: ksession.title
    property alias kterminal: kterminal
    property bool isActive: false

    property size terminalSize: kterminal.terminalSize
    property size fontMetrics: kterminal.fontMetrics

    // Cursor cell in terminal coordinates, refreshed while the active line
    // highlight is enabled.  Null whenever we cannot honestly know it.
    property var cursorRect: null

    function refreshCursorRect() {
        cursorRect = (typeof termQuery !== "undefined" && termQuery)
                ? termQuery.cursorRectangle(kterminal) : null
    }

    /**
     * Inject raw text into the terminal, one character at a time.
     *
     * Used by the IBM PA keys (Attention, Erase Input) and by user macros
     * bound to a PF key.  Characters are fed through the widget's own
     * simulateKeyPress() slot so they take exactly the same path as a real
     * keystroke, keyboard translator and flow control checks included.
     */
    function sendText(text) {
        if (!text)
            return false
        for (var i = 0; i < text.length; i++) {
            var character = text.charAt(i)
            kterminal.simulateKeyPress(0, 0, true, 0, character)
        }
        return true
    }

    /**
     * Make this pane's PF HELP cell editable, so the topic is typed right
     * on the glass (PF1 / the Help menu).  False when the legend is not
     * printed -- the window falls back to the dialog then.
     */
    function requestHelpInput() {
        if (!screenContent.showLegend)
            return false
        return pfLegend.beginHelpInput()
    }

    // Manage copy and paste
    Connections {
        target: copyAction

        onTriggered: {
            if (terminalContainer.isActive) {
                kterminal.copyClipboard()
            }
        }
    }
    Connections {
        target: pasteAction

        onTriggered: {
            if (terminalContainer.isActive) {
                kterminal.pasteClipboard()
            }
        }
    }

    // The terminal beeped: let the window's sound manager decide whether it
    // is allowed to be audible right now.
    Connections {
        target: kterminal
        enabled: terminalWindow.active && terminalContainer.isActive

        function onNotifyBell(bellMessage) {
            if (terminalWindow.soundManager)
                terminalWindow.soundManager.bell()
        }
    }

    //When settings are updated sources need to be redrawn.
    Connections {
        target: appSettings

        onFontScalingChanged: {
            terminalContainer.updateSources()
        }

        onFontWidthChanged: {
            terminalContainer.updateSources()
        }
    }
    Connections {
        target: terminalContainer

        onWidthChanged: {
            terminalContainer.updateSources()
        }

        onHeightChanged: {
            terminalContainer.updateSources()
        }
    }

    function updateSources() {
        kterminal.update()
    }

    /**
     * Everything that is drawn onto the phosphor lives in here: the terminal
     * widget, the active line highlight and the off-side PF key legend.
     * This whole item is what the CRT shader samples, so all three glow,
     * curve and flicker together instead of the overlays looking pasted on.
     *
     * The legend is part of the monitor but never part of the screen the
     * shell drives: it prints into a strip carved off the bottom of the
     * widget's area (see legendReserve), so the PTY grid -- and with it the
     * cursor -- ends above it and no program output can scroll onto it.
     * It fills its parent, which is the same size the terminal widget used
     * to have, so every other geometry calculation below is unchanged.
     */
    Item {
        id: screenContent
        anchors.fill: parent

        readonly property bool showLegend: appSettings.showPfKeys && !pfLegend.empty

        QMLTermWidget {
            id: kterminal

            property int textureResolutionScale: appSettings.lowResolutionFont ? Screen.devicePixelRatio : 1
            property int margin: appSettings.margin / screenScaling
            property int totalWidth: Math.floor(parent.width / (screenScaling * fontWidth))
            property int totalHeight: Math.floor(parent.height / screenScaling)
            /** Strip reserved for the on-glass PF legend: outside the grid. */
            property int legendReserve: screenContent.showLegend ? pfLegend.height : 0

            property int rawWidth: totalWidth - 2 * margin
            property int rawHeight: Math.max(1, totalHeight - 2 * margin - legendReserve)

            textureSize: Qt.size(width / textureResolutionScale, height / textureResolutionScale)

            width: ensureMultiple(rawWidth, Screen.devicePixelRatio)
            height: ensureMultiple(rawHeight, Screen.devicePixelRatio)

            /** Ensure size is a multiple of factor. This is needed for pixel perfect scaling on highdpi screens. */
            function ensureMultiple(size, factor) {
                return Math.round(size / factor) * factor;
            }

            // A full height block cursor is what the 3270s and the PC BIOS
            // used; the half height variant is offered for the look of the
            // later LCD terminals.
            fullCursorHeight: appSettings.cursorStyle !== "half"
            blinkingCursor: appSettings.blinkingCursor

            colorScheme: "cool-retro-term"

            /**
             * Observe every keystroke that reaches the terminal so the
             * optional IBM key click can sound, without ever consuming any of
             * them.  Forcing `accepted` back to false guarantees the event
             * continues on to the widget exactly as it would have.
             */
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                event.accepted = false

                var manager = terminalWindow.soundManager
                if (!manager)
                    return
                manager.keyClick({
                    isAutoRepeat: event.isAutoRepeat,
                    isModifierOnly: isModifierOnly(event.key)
                })
            }

            function isModifierOnly(key) {
                switch (key) {
                case Qt.Key_Shift:
                case Qt.Key_Control:
                case Qt.Key_Alt:
                case Qt.Key_Meta:
                case Qt.Key_AltGr:
                case Qt.Key_Super_L:
                case Qt.Key_Super_R:
                case Qt.Key_Hyper_L:
                case Qt.Key_Hyper_R:
                case Qt.Key_Mode_switch:
                    return true
                default:
                    return false
                }
            }

            session: QMLTermSession {
                id: ksession

                onFinished: {
                    terminalContainer.sessionFinished()
                }
            }

            QMLTermScrollbar {
                id: kterminalScrollbar
                terminal: kterminal
                anchors.margins: width * 0.5
                width: terminal.fontMetrics.width * 0.75
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    color: "white"
                    opacity: 0.7
                }
            }

            function handleFontChanged(fontFamily, pixelSize, lineSpacing, screenScaling, fontWidth, fallbackFontFamily, lowResolutionFont) {
                kterminal.lineSpacing = lineSpacing;
                kterminal.antialiasText = !lowResolutionFont;
                kterminal.smooth = !lowResolutionFont;
                kterminal.enableBold = !lowResolutionFont;
                kterminal.enableItalic = !lowResolutionFont;

                kterminal.font = Qt.font({
                    family: fontFamily,
                    pixelSize: pixelSize
                });

                terminalContainer.fontWidth = fontWidth;
                terminalContainer.screenScaling = screenScaling;
                scaleTexture = Math.max(1.0, Math.floor(screenScaling * appSettings.windowScaling));
            }

            Connections {
                target: appSettings

                onWindowScalingChanged: {
                    scaleTexture = Math.max(1.0, Math.floor(terminalContainer.screenScaling * appSettings.windowScaling));
                }
            }

            function startSession() {
                // Retrieve the variable set in main.cpp if arguments are passed.
                if (defaultCmd) {
                    ksession.setShellProgram(defaultCmd);
                    ksession.setArgs(defaultCmdArgs);
                } else if (appSettings.useCustomCommand) {
                    var args = Utils.tokenizeCommandLine(appSettings.customCommand);
                    ksession.setShellProgram(args[0]);
                    ksession.setArgs(args.slice(1));
                } else if (!defaultCmd && appSettings.isMacOS) {
                    // OSX Requires the following default parameters for auto login.
                    ksession.setArgs(["-i", "-l"]);
                }

                if (workdir)
                    ksession.initialWorkingDirectory = workdir;

                ksession.startShellProgram();
                forceActiveFocus();
            }
            Component.onCompleted: {
                appSettings.fontManager.terminalFontChanged.connect(handleFontChanged);
                appSettings.fontManager.refresh()
                startSession();
            }
            Component.onDestruction: {
                appSettings.fontManager.terminalFontChanged.disconnect(handleFontChanged);
            }
        }

        // iTerm2 style highlight of the cursor's row.  Sits above the widget
        // because the terminal paints its own opaque background; the opacity
        // is low enough that the glyphs stay readable underneath.
        LineHighlight {
            objectName: "activeLineHighlight"
            z: 1
            screenX: 0
            screenWidth: kterminal.width
            terminalY: 0
            cursorRect: terminalContainer.cursorRect
            highlightEnabled: appSettings.highlightActiveLine
            requestedOpacity: appSettings.activeLineOpacity
            tint: appSettings.fontColor
        }

        // Keeps the row under the cursor known without needing a change
        // signal the terminal widget does not provide.
        Timer {
            id: cursorTimer
            interval: 66
            repeat: true
            triggeredOnStart: true
            running: appSettings.highlightActiveLine
                     && terminalWindow.active
                     && terminalContainer.isActive
            onTriggered: terminalContainer.refreshCursorRect()
        }

        // The off-side PF panel, printed at the foot of the picture the way
        // ISPF printed it at the foot of the screen: part of the monitor
        // (inside the frame, in the very texture the CRT shader samples, so
        // it glows and curves with everything else) -- but laid into the
        // strip legendReserve carves off the terminal's grid, so neither
        // output nor cursor can ever reach it.
        PfKeyBar {
            id: pfLegend
            objectName: "pfKeyBar"
            z: 1
            clip: true
            visible: screenContent.showLegend
            anchors {
                left: kterminal.left
                right: kterminal.right
                top: kterminal.bottom
            }
            height: Math.min(implicitHeight, Math.floor(screenContent.height * 0.5))
            model: appSettings.pfAssignments
            // The legend's own colours: the phosphor unless one is set,
            // clear chips behind the words unless one is set -- and the
            // arrow shades whatever the text colour is down to 60%, the
            // look it always printed with, unless coloured by hand.
            textColor: appSettings.legendTextColor !== ""
                    ? appSettings.legendTextColor : appSettings.fontColor
            textBgColor: appSettings.legendTextBgColor
            arrowColor: appSettings.legendArrowColor !== ""
                    ? appSettings.legendArrowColor
                    : Qt.rgba(pfLegend.textColor.r, pfLegend.textColor.g,
                              pfLegend.textColor.b, 0.6)
            arrowBgColor: appSettings.legendArrowBgColor
            // Honest light: ON only when the click would actually sound
            // (master gate AND click switch).
            keySoundOn: appSettings.audioEnabled && appSettings.keyClick
            // Same face, size and pitch as the screen itself -- unless the
            // legend is dressed by hand: its own family ("" = the screen's)
            // and its own size coefficient (1.0 = the screen font's pixel
            // size) both live in the legend settings.
            fontFamily: appSettings.legendFontFamily !== ""
                    ? appSettings.legendFontFamily : appSettings.terminalFontFamily
            fontPixelSize: appSettings.terminalFontPixelSize
            fontWidth: appSettings.terminalFontWidth
            fontScale: appSettings.legendFontScale
            inputBgColor: appSettings.backgroundColor

            // Topic collected: give the keyboard back to the screen, then
            // carry it up so the window turns it into a man command.
            onHelpSubmitted: function(topic) {
                kterminal.forceActiveFocus()
                terminalContainer.helpSubmitted(topic)
            }
            // Escape in the field: just hand the keyboard back.
            onHelpCanceled: kterminal.forceActiveFocus()
        }
    }

    Component {
        id: shortContextMenu
        ShortContextMenu { }
    }

    Component {
        id: fullContextMenu
        FullContextMenu { }
    }

    Loader {
        id: menuLoader
        // Full screen in nostalgic mode drops the context menu altogether:
        // right click goes straight through to the terminal, as it would on
        // a real one.  Windowed, it is back -- short while the menu bar can
        // carry the rest, full when it cannot.
        sourceComponent: !terminalWindow.chrome.contextMenu ? null
                         : (appSettings.isMacOS || (terminalWindow.chrome.menubar && !terminalWindow.isFullscreen) ? shortContextMenu : fullContextMenu)
    }
    property alias contextmenu: menuLoader.item

    MouseArea {
        property real margin: appSettings.margin
        property real frameSize: appSettings.frameSize * terminalWindow.normalizedWindowScale

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        anchors.fill: parent
        cursorShape: kterminal.terminalUsesMouse ? Qt.ArrowCursor : Qt.IBeamCursor
        onWheel: function(wheel) {
            if (wheel.modifiers & Qt.ControlModifier) {
               wheel.angleDelta.y > 0 ? zoomIn.trigger() : zoomOut.trigger();
            } else {
                var coord = correctDistortion(wheel.x, wheel.y);
                kterminal.simulateWheel(coord.x, coord.y, wheel.buttons, wheel.modifiers, wheel.angleDelta);
            }
        }
        onDoubleClicked: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseDoubleClick(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onPressed: function(mouse) {
            kterminal.forceActiveFocus()
            if ((!kterminal.terminalUsesMouse || mouse.modifiers & Qt.ShiftModifier) && mouse.button == Qt.RightButton) {
                if (contextmenu)
                    contextmenu.popup();
            } else {
                var coord = correctDistortion(mouse.x, mouse.y);
                kterminal.simulateMousePress(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers)
            }
        }
        onReleased: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseRelease(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }
        onPositionChanged: function(mouse) {
            var coord = correctDistortion(mouse.x, mouse.y);
            kterminal.simulateMouseMove(coord.x, coord.y, mouse.button, mouse.buttons, mouse.modifiers);
        }

        /**
         * Invert the CRT warp for a point of this pane.
         *
         * The warp may belong to a bigger unit than the pane: split tabs
         * are curved once, over the whole stage (CrtUnit), so the point is
         * first taken into the warping item's coordinates, run through the
         * shader's own mapping (margin, frame inset, barrel), and finally
         * handed back as a cell of this pane -- the panes tile the stage,
         * so their virtual sizes tile the virtual whole.
         *
         * With no stage (warpSurface null) every step collapses to the
         * original single-pane formula, term for term.
         */
        function correctDistortion(x, y) {
            var surface = warpSurface ? warpSurface : terminalContainer;
            var stageWidth = surface.width;
            var stageHeight = surface.height;

            var point = terminalContainer.mapToItem(surface, x, y);
            var origin = terminalContainer.mapToItem(surface, 0, 0);

            x = (point.x - margin) / stageWidth;
            y = (point.y - margin) / stageHeight;

            x = x * (1 + frameSize * 2) - frameSize;
            y = y * (1 + frameSize * 2) - frameSize;

            var cc = Qt.size(0.5 - x, 0.5 - y);
            var distortion = (cc.height * cc.height + cc.width * cc.width)
                    * appSettings.screenCurvature * appSettings.screenCurvatureSize
                    * terminalWindow.normalizedWindowScale;
            x = x - cc.width  * (1 + distortion) * distortion;
            y = y - cc.height * (1 + distortion) * distortion;

            // The whole picture in virtual pixels, then this pane's slice.
            var unitWidth = warpVirtualSize.width;
            var unitHeight = warpVirtualSize.height;
            var spanWidth = (terminalContainer.width / stageWidth) * unitWidth;
            var spanHeight = (terminalContainer.height / stageHeight) * unitHeight;
            var offsetX = (origin.x / stageWidth) * unitWidth;
            var offsetY = (origin.y / stageHeight) * unitHeight;

            return Qt.point(
                        spanWidth > 0
                            ? ((x * unitWidth - offsetX) / spanWidth) * kterminal.totalWidth : 0,
                        spanHeight > 0
                            ? ((y * unitHeight - offsetY) / spanHeight) * kterminal.totalHeight : 0)
        }
    }
    /**
     * The phosphor picture as a texture -- and this pane's visible item:
     * the stage the CRT unit samples is made of exactly these quads, one
     * per pane, laid side by side.  (The unit runs them through the shader
     * chain that used to live per pane: see CrtUnit.qml.)
     */
    ShaderEffectSource{
        id: kterminalSource
        anchors.fill: parent
        sourceItem: screenContent
        hideSource: true
        wrapMode: ShaderEffectSource.Repeat
        textureSize: Qt.size(kterminal.totalWidth * scaleTexture, kterminal.totalHeight * scaleTexture)
        sourceRect: Qt.rect(-kterminal.margin, -kterminal.margin, kterminal.totalWidth, kterminal.totalHeight)
    }
}
