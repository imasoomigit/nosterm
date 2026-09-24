/*******************************************************************************
* The HELP input box.
*
* Reached three ways, all landing on the same behaviour:
*   - PF1, whose factory assignment is Help (ISPF F1 = Help);
*   - the Help menu ("Help...");
*   - at the shell level, the HELP command from the alias block (Linux /
*     macOS), which prompts on its own.
*
* This dialog is deliberately dumb: it collects a topic and emits
* `submitted(topic)`.  The window turns that into a terminal command
* through PfKeys.helpCommand(): a blank topic runs `man -k .` (list the
* whole manual, the way CMS HELP with no operand listed the command set)
* and any other topic opens that manual page.
*
* Styled like the machine rather than like the desktop: the caller binds
* bgColor / fgColor / uiFontFamily from the active profile (defaults
* below), so it never wears the system palette.  It is a dialog, so unlike
* the PF panel it IS meant to be typed in -- but only into its own field:
* Escape or Cancel returns the keyboard to the terminal.
*
* Free of application globals on purpose: the Qt Quick test suite
* instantiates it standalone and reads the defaults.
*******************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: helpDialog

    title: qsTr("Help")
    width: 460
    height: 156
    minimumWidth: 380
    minimumHeight: 156

    /** Profile styling, bound by the window that opens the dialog. */
    property color bgColor: "#000000"
    property color fgColor: "#3cff7a"
    property string uiFontFamily: ""

    color: bgColor
    font.family: uiFontFamily
    palette {
        window: bgColor
        windowText: fgColor
        alternateBase: bgColor
        base: bgColor
        text: fgColor
        button: bgColor
        buttonText: fgColor
        light: fgColor
        midlight: fgColor
        dark: Qt.darker(fgColor, 1.6)
        mid: Qt.darker(fgColor, 1.6)
        shadow: Qt.darker(bgColor, 2.0)
        highlight: fgColor
        highlightedText: bgColor
    }

    /** The collected topic ("" = list the whole manual). */
    signal submitted(string topic)

    /** The one entry point: clear, show, and put the cursor in the field. */
    function openForHelp() {
        topicField.text = ""
        show()
        raise()
        requestActivate()
        topicField.forceActiveFocus()
    }

    function acceptTopic() {
        submitted(topicField.text)
        close()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: helpDialog.fgColor
            text: qsTr("Manual topic (leave blank to list every page with man -k .):")
        }

        TextField {
            id: topicField
            objectName: "helpTopicField"
            Layout.fillWidth: true
            placeholderText: qsTr("e.g. printf")
            color: helpDialog.fgColor
            font.family: helpDialog.uiFontFamily
            focus: true
            onAccepted: helpDialog.acceptTopic()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                objectName: "helpSubmitButton"
                text: qsTr("Help")
                onClicked: helpDialog.acceptTopic()
            }
            Button {
                objectName: "helpCancelButton"
                text: qsTr("Cancel")
                onClicked: helpDialog.close()
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: helpDialog.close()
    }

    onVisibleChanged: {
        if (visible)
            topicField.forceActiveFocus()
    }
}
