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
import QtQuick.Window 2.2

import "menus"
import "logic/windows.js" as Windows

QtObject {
    id: appRoot

    property ApplicationSettings appSettings: ApplicationSettings {
        // "": this is the first window, and the startup path has already
        // chosen --profile, the default or the stored snapshot.  Loading a
        // profile again here would override that.
        onInitializedSettings: appRoot.createWindow("")
    }

    property TimeManager timeManager: TimeManager {
        enableTimer: windowsModel.count > 0
    }

    property SettingsWindow settingsWindow: SettingsWindow {
        visible: false
    }

    property AboutDialog aboutDialog: AboutDialog {
        visible: false
    }

    property Component windowComponent: Component {
        TerminalWindow { }
    }

    property ListModel windowsModel: ListModel { }

    // Window the user is currently looking at; used to decide where a
    // next/previous cycle should start from.
    property var activeWindow: null

    /**
     * Open a window, on `profileName` when one was named (the "New Window
     * with Profile" submenu), else on the profile this app is configured to
     * open with, else on whatever is showing.  One shared settings object
     * makes this a global switch -- every window follows -- and the
     * autosave has already put the previous profile's tweaks into it, so
     * nothing is lost when the look changes.
     */
    function createWindow(profileName) {
        var loadName = Windows.newWindowLoadName(profileName,
                                                  appSettings.defaultProfileName)
        if (loadName !== "")
            appSettings.loadProfile(appSettings.getProfileIndexByName(loadName))

        var window = windowComponent.createObject(null)
        if (!window)
            return

        windowsModel.append({ window: window })
        window.show()
        // Born from a full screen session -> opens full screen: pressing
        // "new window" must never pop the user out of full screen.
        var bornFrom = appRoot.activeWindow
        if (bornFrom && Windows.inheritFullscreen(bornFrom.isFullscreen, false)
                && !window.isFullscreen)
            window.fullscreen = true
        window.requestActivate()
    }

    function indexOfWindow(window) {
        if (!window)
            return -1
        for (var i = 0; i < windowsModel.count; i++) {
            if (windowsModel.get(i).window === window)
                return i
        }
        return -1
    }

    function activateWindow(window) {
        if (!window)
            return
        // Switching away from a full screen session lands in full screen:
        // promote the target, never demote it (Windows.inheritFullscreen).
        var source = appRoot.activeWindow
        var wantFull = source && source !== window
                && Windows.inheritFullscreen(source.isFullscreen, window.isFullscreen)

        // Show + raise + requestActivate is what a platform's own
        // "next window" command does; doing the same keeps the switch
        // seamless, including while a window is fullscreen.
        if (window.visibility !== Window.FullScreen
                && window.visibility !== Window.Maximized)
            window.show()
        if (wantFull && !window.isFullscreen)
            window.fullscreen = true
        window.raise()
        window.requestActivate()
    }

    /**
     * Cycle to the adjacent window.  delta is +1 for "next window" and -1 for
     * "previous window"; the list wraps around in both directions.
     */
    function cycleWindows(delta) {
        var count = windowsModel.count
        if (count < 1)
            return null

        var next = Windows.cycleIndex(indexOfWindow(activeWindow), count, delta)
        if (next < 0)
            return null

        var window = windowsModel.get(next).window
        activateWindow(window)
        return window
    }

    function nextWindow() { return cycleWindows(1) }
    function previousWindow() { return cycleWindows(-1) }

    function closeWindow(window) {
        var removed = indexOfWindow(window)
        if (removed !== -1)
            windowsModel.remove(removed)

        if (activeWindow === window)
            activeWindow = null

        window.destroy()

        if (windowsModel.count === 0) {
            appSettings.close()
        }
    }
}
