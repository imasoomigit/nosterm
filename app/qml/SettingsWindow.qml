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
import QtQuick.Controls
import QtQuick.Window 2.1
import QtQuick.Layouts 1.3
import QtQuick.Dialogs

import "menus"

ApplicationWindow {
    readonly property real tabButtonPadding: 10

    id: settings_window
    title: qsTr("Settings")
    // Room enough for the widest pane to print at its natural size: a row
    // squeezed below that is a row whose label runs into the control beside
    // it, which is exactly how the words ended up overlapping.
    width: 780
    height: 660
    minimumWidth: 460
    minimumHeight: 340

    // Worn like the machine, not like the desktop: the profile's own
    // phosphor on its own background, so the dialog never picks up the
    // system palette (some themes render it in alarming colours).
    color: appSettings.backgroundColor
    font.family: appSettings.terminalFontFamily
    palette {
        window: appSettings.backgroundColor
        windowText: appSettings.fontColor
        alternateBase: appSettings.backgroundColor
        base: appSettings.backgroundColor
        text: appSettings.fontColor
        button: appSettings.backgroundColor
        buttonText: appSettings.fontColor
        light: appSettings.fontColor
        midlight: appSettings.fontColor
        dark: Qt.darker(appSettings.fontColor, 1.6)
        mid: Qt.darker(appSettings.fontColor, 1.6)
        shadow: Qt.darker(appSettings.backgroundColor, 2.0)
        highlight: appSettings.fontColor
        highlightedText: appSettings.backgroundColor
    }

    Item {
        anchors { fill: parent; }

        // The strip and the way out share one header row, each in its own
        // slot.  Close used to be anchored over a full width TabBar, which
        // put it straight across the last tab.
        RowLayout {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top; }
            spacing: 8

            TabBar {
                id: bar
                Layout.fillWidth: true
                TabButton {
                    padding: tabButtonPadding
                    text: qsTr("General")
                }
                TabButton {
                    padding: tabButtonPadding
                    text: qsTr("Terminal")
                }
                TabButton {
                    padding: tabButtonPadding
                    text: qsTr("Effects")
                }
                TabButton {
                    padding: tabButtonPadding
                    text: qsTr("Retro")
                }
                TabButton {
                    padding: tabButtonPadding
                    text: qsTr("Advanced")
                }
            }

            // An explicit way out, independent of whatever title bar the
            // platform (or window manager) chooses to draw.
            Button {
                objectName: "settingsCloseButton"
                text: qsTr("Close")
                onClicked: settings_window.close()
            }
        }

        StackLayout {
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 16
            }

            currentIndex: bar.currentIndex

            // Every pane scrolls: the tab takes the room it needs when that
            // is more than the viewport, and takes the viewport when it is
            // less (which is what lets the fill* groups spread out as they
            // always did).  A pane can therefore never be pressed into a
            // shape smaller than its own content, however small the window
            // is dragged.
            ScrollView {
                id: generalPane
                clip: true
                SettingsGeneralTab {
                    width: generalPane.availableWidth
                    height: Math.max(generalPane.availableHeight, implicitHeight)
                }
            }
            ScrollView {
                id: terminalPane
                clip: true
                SettingsTerminalTab {
                    width: terminalPane.availableWidth
                    height: Math.max(terminalPane.availableHeight, implicitHeight)
                }
            }
            ScrollView {
                id: effectsPane
                clip: true
                SettingsEffectsTab {
                    width: effectsPane.availableWidth
                    height: Math.max(effectsPane.availableHeight, implicitHeight)
                }
            }
            SettingsRetroTab { }
            ScrollView {
                id: advancedPane
                clip: true
                SettingsAdvancedTab {
                    width: advancedPane.availableWidth
                    height: Math.max(advancedPane.availableHeight, implicitHeight)
                }
            }
        }
    }

    /**
     * macOS builds the menu bar from the *active* window, and this is a
     * window: with no bar of its own the whole menu emptied while Settings
     * was focused (Preferences was reachable exactly once) and could be
     * stranded on a fallback set after it closed.  So Settings offers the
     * terminal's own bar, aimed at whichever terminal window was last
     * active.  Shown on macOS only -- elsewhere the bar lives inside the
     * window, where a dialog has never had one.
     */
    menuBar: WindowMenu {
        target: appRoot.activeWindow
        visible: appSettings.isMacOS && appRoot.activeWindow !== null
    }

    // Hand focus back the moment the dialog goes, so the window the user
    // was working in -- and its menu bar -- is the active one again.
    onClosing: function(closeEvent) {
        appRoot.activateWindow(appRoot.activeWindow)
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: settings_window.close()
    }
}
