/*******************************************************************************
* Qt Quick test: the HELP input box.
*
* The dialog collects a topic and announces it; the window turns that into
* `man -k .` (blank topic: list every page, the way CMS HELP with no
* operand listed the command set) or `man <topic>` through
* PfKeys.helpCommand(), whose mapping is asserted right here and in the
* Node suite.  The dialog's own contract: the field exists, Enter and the
* button both submit, Escape closes without submitting, and it starts
* hidden.
*******************************************************************************/
import QtQuick
import QtTest

import "../app/qml" as App
import "../app/qml/logic/pfkeys.js" as PfKeys

Rectangle {
    id: host
    width: 640
    height: 480
    color: "black"

    App.HelpDialog {
        id: dialog
    }

    TestCase {
        name: "HelpDialogTests"
        when: windowShown

        function init() {
            dialog.close()
        }

        function test_startsHiddenWithAField() {
            compare(dialog.visible, false)
            verify(findChild(dialog, "helpTopicField") !== null)
            verify(findChild(dialog, "helpSubmitButton") !== null)
            verify(findChild(dialog, "helpCancelButton") !== null)
        }

        function test_blankTopicSubmitsAsBlank() {
            var field = findChild(dialog, "helpTopicField")
            var got = []
            dialog.submitted.connect(function(t) { got.push(t) })

            dialog.openForHelp()
            field.text = ""
            findChild(dialog, "helpSubmitButton").clicked()

            tryCompare(got, "length", 1)
            compare(got[0], "", "a blank topic must submit as blank (-> man -k .)")
            compare(dialog.visible, false, "submitting closes the box")
        }

        function test_enterInTheFieldSubmitsTheTopic() {
            var field = findChild(dialog, "helpTopicField")
            var got = []
            dialog.submitted.connect(function(t) { got.push(t) })

            dialog.openForHelp()
            field.text = "printf"
            field.accepted()    // what Enter on the TextField emits

            tryCompare(got, "length", 1)
            compare(got[0], "printf")
            compare(dialog.visible, false, "submitting closes the box")
        }

        function test_escapeClosesWithoutSubmitting() {
            var got = 0
            dialog.submitted.connect(function() { got++ })

            dialog.openForHelp()
            keyClick(Qt.Key_Escape)

            tryCompare(dialog, "visible", false)
            compare(got, 0, "Escape must not submit a topic")
        }

        function test_helpCommandMapsTopicToMan() {
            // The other half of the contract, asserted where it lives.
            compare(PfKeys.helpCommand(""), "man -k .\r")
            compare(PfKeys.helpCommand("   "), "man -k .\r")
            compare(PfKeys.helpCommand(undefined), "man -k .\r")
            compare(PfKeys.helpCommand(null), "man -k .\r")
            compare(PfKeys.helpCommand("printf"), "man -- 'printf'\r")
            compare(PfKeys.helpCommand("echo hi"), "man -- 'echo hi'\r")
            compare(PfKeys.helpCommand("a'b"), "man -- 'a'\\''b'\r")
        }

        function test_isStyledToMatchTheMachine() {
            // Retro defaults, set as properties: the window paints itself
            // with them instead of whatever palette the desktop wears.
            compare(String(dialog.color), String(dialog.bgColor))
            compare(String(dialog.bgColor), "#000000")
            compare(String(dialog.fgColor), "#3cff7a")
        }
    }
}
