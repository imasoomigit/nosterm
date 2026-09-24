/*******************************************************************************
* Qt Quick test: the zoom key bindings, windowed and full screen.
*
* Production (TerminalWindow.qml) builds the physical spellings of
* "bigger"/"smaller" through Instantiator -- Repeater refuses non-Item
* delegates, so the Shortcuts it appeared to declare were never created,
* which is exactly how "Ctrl +" went dead in full screen -- with
* Application context so they match in every window state.  Every case
* below is therefore asserted in BOTH states, firing each spelling as the
* physical key press it stands for (sequences from Platform.zoomSpellings,
* the production source of truth).
*******************************************************************************/
import QtQuick
import QtTest

import "../app/qml/logic/platform.js" as Platform

Rectangle {
    id: host
    width: 400
    height: 300
    color: "black"

    property int zoomInHits: 0
    property int zoomOutHits: 0

    // Exactly what TerminalWindow declares: Instantiator, Application scope.
    Instantiator {
        model: Platform.zoomSpellings(Qt.platform.os, "zoomIn")
        delegate: Shortcut {
            required property string modelData
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: host.zoomInHits++
        }
    }
    Instantiator {
        model: Platform.zoomSpellings(Qt.platform.os, "zoomOut")
        delegate: Shortcut {
            required property string modelData
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: host.zoomOutHits++
        }
    }

    TestCase {
        name: "ZoomShortcuts"
        when: windowShown

        /**
         * The physical key press one spelling stands for: "Ctrl++" is the
         * unshifted "+" (numpad / direct-Plus keyboards), "Ctrl+Shift++"
         * the US "+" key with Shift held, "Ctrl+=" the plain "=" key --
         * each with the primary modifier of the platform.
         */
        function pressSpelling(sequence) {
            var primary = sequence.indexOf("Meta") === 0
                    ? Qt.MetaModifier : Qt.ControlModifier
            if (sequence.indexOf("Shift++") !== -1)
                keyClick(Qt.Key_Plus, primary | Qt.ShiftModifier)
            else if (sequence.indexOf("=") !== -1)
                keyClick(Qt.Key_Equal, primary)
            else if (sequence.slice(-2) === "++")
                keyClick(Qt.Key_Plus, primary)
            else if (sequence.slice(-2) === "+-")
                keyClick(Qt.Key_Minus, primary)
            else
                verify(false, "unexpected zoom spelling: " + sequence)
        }

        /** Fire every spelling of `name` once; return the expected hits. */
        function fireSpellings(name) {
            var spellings = Platform.zoomSpellings(Qt.platform.os, name)
            verify(spellings.length > 0, "the platform offers spellings")
            if (name === "zoomIn")
                host.zoomInHits = 0
            else
                host.zoomOutHits = 0
            for (var i = 0; i < spellings.length; i++)
                pressSpelling(spellings[i])
            wait(50)
            return spellings.length
        }

        function test_biggerAndSmallerFireFullscreen() {
            var window = host.Window.window
            window.visibility = Window.FullScreen
            wait(200)
            compare(window.visibility, Window.FullScreen,
                    "the test window never went full screen")

            var ins = fireSpellings("zoomIn")
            compare(host.zoomInHits, ins,
                    "every 'bigger' spelling fires full screen")
            var outs = fireSpellings("zoomOut")
            compare(host.zoomOutHits, outs,
                    "the 'smaller' spelling fires full screen")

            window.visibility = Window.Windowed
            wait(50)
        }

        function test_biggerAndSmallerFireWindowed() {
            host.Window.window.visibility = Window.Windowed
            wait(50)

            var ins = fireSpellings("zoomIn")
            compare(host.zoomInHits, ins,
                    "every 'bigger' spelling fires windowed")
            var outs = fireSpellings("zoomOut")
            compare(host.zoomOutHits, outs,
                    "the 'smaller' spelling fires windowed")
        }
    }
}
