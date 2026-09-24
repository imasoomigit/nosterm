/*******************************************************************************
* One pane of a terminal: the phosphor picture plus everything the shell
* talks to -- session, focus, title, size, PF help, PA/PF text injection.
*
* Panes carry no CRT of their own any more.  The whole tab, divided or
* not, is displayed through a single CrtUnit (see CrtUnit.qml), so
* splitting the terminal never splits the curved frame around it: the
* frame, the curvature and every screen-wide effect are drawn once, over
* the whole picture, and the panes are just content inside it.
*
* The mouse mapping has to know that too: warpSurface / warpVirtualSize
* hand the pane the geometry of the item whose shader actually curves the
* picture, so a click lands on the right cell even on the far side of a
* split.  Null makes the pane its own unit, which is exactly the legacy
* single-pane behaviour.
*******************************************************************************/
import QtQuick 2.2

Item {
    id: pane

    property alias title: terminal.title
    property alias terminalSize: terminal.terminalSize
    /** Virtual resolution and texture density, summed up by the unit. */
    property alias virtualResolution: terminal.virtualResolution
    property alias scaleTexture: terminal.scaleTexture

    property bool isActive: false

    /** The item whose CRT shader warps the picture (the tab's stage). */
    property Item warpSurface: null
    /** Virtual size of the whole warped picture (the stage's contents). */
    property size warpVirtualSize: terminal.virtualResolution

    signal sessionFinished()
    /** A pane's HELP field was submitted: forward it out of the pane. */
    signal helpSubmitted(string topic)
    /** The phosphor painted: the unit's burn-in trail wants refreshing. */
    signal imagePainted()

    PreprocessedTerminal {
        id: terminal
        anchors.fill: parent
        isActive: pane.isActive
        warpSurface: pane.warpSurface
        warpVirtualSize: pane.warpVirtualSize
        onSessionFinished: pane.sessionFinished()
        onHelpSubmitted: function(topic) { pane.helpSubmitted(topic) }
    }

    // The burn-in trail lives on the unit now, but it still moves on
    // every paint -- of either pane.
    Connections {
        target: terminal.kterminal
        function onImagePainted() {
            pane.imagePainted()
        }
    }

    function activate() {
        terminal.mainTerminal.forceActiveFocus()
    }

    /** Inject raw text into this terminal (IBM PA keys, PF macros). */
    function sendText(text) {
        return terminal.sendText(text)
    }

    /** Open this pane's PF HELP cell for typing (window Help / PF1). */
    function requestHelpInput() {
        return terminal.requestHelpInput()
    }
}
