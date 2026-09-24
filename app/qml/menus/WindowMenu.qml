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
import QtQuick.Controls 2.3

MenuBar {
    id: defaultMenuBar

    /**
     * The terminal window these menus act on.
     *
     * A menu bar is built from the *active* window, and Settings is a window
     * too: with no bar of its own the macOS menu emptied while it was focused
     * and could be stranded on a fallback set after it closed.  Settings
     * therefore offers this very same bar aimed at whichever terminal window
     * was last active -- which only works because every item reaches its
     * action through `target` instead of through an id, and an id is not
     * visible from outside the file that declares it.
     *
     * null -> no terminal window to act on, and nothing prints.
     */
    property var target: null

    /** The target's published action set (see TerminalWindow.menuActions). */
    readonly property var actionSet: target ? target.menuActions : null

    // Per window: hidden while that window is full screen (nostalgic mode),
    // back the moment it returns to windowed -- or revealed transiently by
    // touching the top edge while full screen.
    visible: target && (target.chrome.menubar || target.menubarReveal)

    Menu {
        title: qsTr("File")
        MenuItem { action: actionSet ? actionSet.newWindow : null }
        Menu {
            id: profileMenu
            title: qsTr("New Window with Profile")
            Instantiator {
                model: appSettings.profilesList
                delegate: MenuItem {
                    text: model.text
                    // The submenu *names* the profile, so plain File > New
                    // Window keeps its default and this one overrides it.
                    onTriggered: appRoot.createWindow(text)
                }
                onObjectAdded: (index, object) => profileMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => profileMenu.removeItem(object)
            }
        }
        MenuItem { action: actionSet ? actionSet.newTab : null }
        MenuItem { action: actionSet ? actionSet.closeTab : null }
        MenuItem { action: actionSet ? actionSet.closeWindow : null }
        MenuSeparator { }
        MenuItem { action: actionSet ? actionSet.quit : null }
    }
    Menu {
        title: qsTr("Edit")
        MenuItem { action: actionSet ? actionSet.copy : null }
        MenuItem { action: actionSet ? actionSet.paste : null }
        MenuSeparator {}
        MenuItem { action: actionSet ? actionSet.settings : null }
    }
    Menu {
        id: windowMenu
        title: qsTr("Window")
        MenuItem { action: actionSet ? actionSet.nextWindow : null }
        MenuItem { action: actionSet ? actionSet.previousWindow : null }
        MenuSeparator { }
        MenuItem { action: actionSet ? actionSet.splitVertical : null }
        MenuItem { action: actionSet ? actionSet.splitHorizontal : null }
    }
    Menu {
        id: viewMenu
        title: qsTr("View")
        Instantiator {
            model: !appSettings.isMacOS ? 1 : 0
            delegate: MenuItem { action: actionSet ? actionSet.fullscreen : null }
            onObjectAdded: (index, object) => viewMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => viewMenu.removeItem(object)
        }
        MenuItem { action: actionSet ? actionSet.bigger : null }
        MenuItem { action: actionSet ? actionSet.smaller : null }
        MenuSeparator { }
        MenuItem { action: actionSet ? actionSet.keySound : null }
    }
    Menu {
        id: profilesMenu
        title: qsTr("Profiles")
        Instantiator {
            model: appSettings.profilesList
            delegate: MenuItem {
                text: model.text
                // loadProfile, not loadProfileString: choosing a profile
                // makes it the active one, so the next change -- autosaved
                // now -- lands in the profile that is actually showing.
                onTriggered: appSettings.loadProfile(index)
            }
            onObjectAdded: (index, object) => profilesMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => profilesMenu.removeItem(object)
        }
    }
    Menu {
        title: qsTr("Help")
        MenuItem { action: actionSet ? actionSet.help : null }
        MenuItem {
            action: actionSet ? actionSet.about : null
        }
    }
}
