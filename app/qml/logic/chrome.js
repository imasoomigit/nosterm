/*******************************************************************************
* Visibility rules for every piece of on-screen chrome.
*
* The nostalgic mode contract, as agreed for full screen and windowed use:
*
*   - Full screen is the pure experience.  Nothing on screen may hint that
*     there is a graphical interface behind the terminal, and everything is
*     reachable from the keyboard.  The menu bar can still be revealed by
*     touching the top edge of the screen with the pointer (that reveal is
*     a transient QML flag; chrome.js only decides the steady state).
*
*   - Windowed, the menu bar and the right-click menu are back: leaving
*     full screen brings the menu bar and it STAYS until you go full screen
*     again.  The tab strip and the size overlay remain hidden, so nothing
*     else still suggests a GUI.
*
* Pure function so the contract can be asserted directly by the test suite.
*/

/**
 * @param {Object} s settings snapshot
 *   nostalgicMode  hide chrome (default)
 *   fullscreen      this window is currently full screen
 *   showMenubar     legacy "show menu bar" switch, honoured only when the
 *                   nostalgic mode is off
 *   showTerminalSize  legacy size overlay switch
 *   tabCount        how many tabs the window currently has
 *   isMacOS         platform flag
 * @return {Object} boolean flags for each chrome element
 */
function visibility(s) {
    var cfg = s || {}
    var nostalgic = cfg.nostalgicMode !== false   // default ON
    var fullscreen = cfg.fullscreen === true
    var tabCount = Number(cfg.tabCount)
    if (isNaN(tabCount) || tabCount < 0)
        tabCount = 0

    if (nostalgic) {
        // Full screen: nothing at all.  Windowed: menu bar and context
        // menu, because that is how you get anywhere with a mouse once
        // you have left the immersive view.
        var menubar = !fullscreen
        var contextMenu = !fullscreen
        return {
            menubar: menubar,
            tabBar: false,
            contextMenu: contextMenu,
            sizeOverlay: false,
            settingsWindow: true,   // reachable, just never advertised
            anythingVisible: menubar || contextMenu
        }
    }

    // Without nostalgic mode the historical behaviour is preserved: on macOS
    // the menu bar is always there, elsewhere it is opt-in.  Full screen and
    // windowed behave the same, as they always have.
    var menubar = cfg.isMacOS === true || cfg.showMenubar === true
    var sizeOverlay = cfg.showTerminalSize !== false

    return {
        menubar: menubar,
        tabBar: tabCount > 1,
        contextMenu: true,
        sizeOverlay: sizeOverlay,
        settingsWindow: true,
        anythingVisible: menubar || tabCount > 1 || sizeOverlay
    }
}

/** Is there any chrome at all?  Takes the same snapshot as visibility(). */
function hasChrome(s) {
    var v = visibility(s)
    return v.menubar || v.tabBar || v.contextMenu || v.sizeOverlay
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        visibility: visibility,
        hasChrome: hasChrome
    }
}
